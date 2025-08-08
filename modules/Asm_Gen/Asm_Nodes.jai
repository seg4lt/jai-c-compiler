Program_Asm :: struct {
    fns: [..]Fn_Asm;
}

Fn_Asm :: struct {
    ident        : string;
    instructions : [..]Instruction_Asm;
    stack_size   : int = 0;
}

Instruction_Asm :: struct {
    type : Instruction_Asm_Type;
    as   : union {
        allocate_stack    : int;
        binary            : struct { op: Bin_Op_Asm; src1: Operand_Asm; src2: Operand_Asm; } 
        call              : string;
        cmp               : struct { op1: Operand_Asm; op2: Operand_Asm; };
        deallocate_stack  : int;
        idiv              : Operand_Asm;
        jmp               : string;
        jmp_cc            : struct { cond_code: Cond_Code_Asm; ident: string; };
        label             : string;
        mov               : struct { src: Operand_Asm; dst: Operand_Asm; };
        push              : Operand_Asm;
        set_cc            : struct { cond_code: Cond_Code_Asm; operand: Operand_Asm; };
        unary             : struct { op: Unary_Op_Asm; operand: Operand_Asm; }
        // cdq            : no value needed
        // ret            : no value needed
    };
}

Instruction_Asm_Type :: enum {
    ALLOCATE_STACK;
    BINARY;
    CALL;
    CDQ;
    CMP;
    DEALLOCATE_STACK;
    IDIV;
    JMP;
    JMP_CC;
    LABEL;
    MOV;
    PUSH;
    RET;
    SET_CC;
    UNARY;
};

Cond_Code_Asm :: enum { EE; NE; G; GE; L; LE; }; 

Operand_Asm :: struct {
    type : enum { IMM; REG; PSEUDO; STACK; };
    using as   : union { 
        imm     : int;
        pseudo  : string;
        reg     : Register_Asm;
        stack   : int; 
    }; 
};

Unary_Op_Asm :: enum { NEG; BITWISE_NOT; NNOT; }

Bin_Op_Asm :: enum {
    ADD;
    BITWISE_AND;
    BITWISE_OR;
    BITWISE_XOR;
    EQUAL_EQUAL;
    GREATER;
    GREATER_EQUAL;
    LEFT_SHIFT;
    LESS;
    LESS_EQUAL;
    MUL;
    NOT_EQUAL;
    RIGHT_SHIFT;
    SUB;
}; 

Register_Asm :: struct {
    register : Register;
    size     : Register_Size;
};

Register_Size :: enum #specified { 
    BYTE  :: 1;
    WORD  :: 2;
    DWORD :: 4;
    QWORD :: 8;
}

Register :: enum { 
    AX;
    CX;
    DI;
    DX;
    R10;
    R11;
    R8;
    R9;
    RBP;
    RSP;
    SI;
}

#scope_module

COUNT_REGISTER_FOR_ARGS :: 6;
STACK_ALIGNMENT         :: 16;
PUSH_SIZE               :: 8; // we use push and it only works with 8 bytes


reg :: (register: Register, size: Register_Size) -> Operand_Asm #expand {
    return .{.REG, .{reg = .{register, size }}};
}

pseudo :: (ident: string) -> Operand_Asm #expand {
    return .{ .PSEUDO, .{ pseudo = copy_string(ident) } };
}

stack :: (position: int) -> Operand_Asm #expand {
    return .{ .STACK, .{ stack = position } }; 
}

imm :: (value: int) -> Operand_Asm #expand {
    return .{ .IMM, .{ imm = value } };
} 

ret :: () -> Instruction_Asm #expand {
    return .{.RET, .{}};
}

mov :: (src: Operand_Asm, dst: Operand_Asm) -> Instruction_Asm #expand {
    return .{ .MOV, .{ mov = .{ src, dst } } };
}

cmp :: (op1: Operand_Asm, op2: Operand_Asm) -> Instruction_Asm #expand {
    return .{ .CMP, .{ cmp = .{ op1, op2 } } };
}

set_cc :: (cond_code: Cond_Code_Asm, operand: Operand_Asm) -> Instruction_Asm #expand {
    return .{ .SET_CC, .{ set_cc = .{ cond_code, operand } } }; 
}

unary :: (op: Unary_Op_Asm, operand: Operand_Asm) -> Instruction_Asm #expand {
    return .{ .UNARY, .{ unary = .{ op, operand } } };
}

binary :: (op: Bin_Op_Asm, src1: Operand_Asm, src2: Operand_Asm) -> Instruction_Asm #expand {
    return .{ .BINARY, .{ binary = .{ op, src1, src2 } } };
}

cdq :: () -> Instruction_Asm #expand {
    return .{ .CDQ, .{} };
}

idiv :: (operand: Operand_Asm) -> Instruction_Asm #expand {
    return .{ .IDIV, .{ idiv = operand } };
}

label :: (ident: string) -> Instruction_Asm #expand {
    return .{ .LABEL, .{ label = copy_string(ident) } };
}

jmp_cc :: (cond_code: Cond_Code_Asm, ident: string) -> Instruction_Asm #expand {
    return .{ .JMP_CC, .{ jmp_cc = .{ cond_code, copy_string(ident) } } };
}

jmp :: (ident: string) -> Instruction_Asm #expand {
    return .{ .JMP, .{ jmp = copy_string(ident) } };
}

allocate_stack :: (size: int) -> Instruction_Asm #expand {
    return .{.ALLOCATE_STACK, .{allocate_stack = size}};
}

push :: (operand: Operand_Asm) -> Instruction_Asm #expand {
    return .{.PUSH, .{push = operand}};
}

call :: (ident: string) -> Instruction_Asm #expand {
    return .{.CALL, .{ call = copy_string(ident) }};
}

deallocate_stack :: (size: int) -> Instruction_Asm #expand {
    return .{.DEALLOCATE_STACK, .{ deallocate_stack = size }};
}
