Program_Asm :: struct {
    fns: [..]Fn_Asm;
}

Fn_Asm :: struct {
    ident: string;
    instructions: [..]Instruction_Asm;
    stack_size: int = 0;
}

Instruction_Asm :: struct {
    type: Instruction_Asm_Type;
    as: union {
        mov: struct {src: Operand_Asm; dst: Operand_Asm;};
        unary: struct {op: Unary_Op_Asm; operand: Operand_Asm;}
        binary: struct {op: Bin_Op_Asm; src1: Operand_Asm; src2: Operand_Asm;} 
        idiv: Operand_Asm;
        cmp: struct {op1: Operand_Asm; op2: Operand_Asm;};
        jmp: string;
        jmp_cc: struct {cond_code: Cond_Code_Asm; ident: string;};
        set_cc: struct {cond_code: Cond_Code_Asm; operand: Operand_Asm;};
        label: string;
        allocate_stack: int;
        deallocate_stack: int;
        push: Operand_Asm;
        call: string;
        // cdq: no value needed
        // ret : no value needed
    };
}

Instruction_Asm_Type :: enum {
    MOV;
    UNARY;
    BINARY;
    IDIV;
    CDQ;
    ALLOCATE_STACK;
    RET;
    CMP;
    JMP;
    JMP_CC;
    SET_CC;
    LABEL;
    DEALLOCATE_STACK;
    PUSH;
    CALL;
};

Cond_Code_Asm :: enum { EE; NE; G; GE; L; LE; }; 

Operand_Asm :: struct {
    type: enum { IMM; REG; PSEUDO; STACK; };
    as: union { 
        imm: int;
        reg: Register_Asm;
        pseudo: string;
        stack: int; 
    }; 
};

Unary_Op_Asm :: enum { NEG; BITWISE_NOT; NNOT; }

Bin_Op_Asm :: enum {
    ADD;
    SUB;
    MUL;
    BITWISE_OR;
    BITWISE_AND;
    BITWISE_XOR;
    LEFT_SHIFT;
    RIGHT_SHIFT;
    EQUAL_EQUAL;
    NOT_EQUAL;
    GREATER;
    GREATER_EQUAL;
    LESS;
    LESS_EQUAL;
}; 

Register_Asm :: struct {
    register: Register;
    size: Register_Size;
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
    DX;
    DI;
    SI;
    R8;
    R9;
    R10;
    R11;
    RSP;
    RBP;
}