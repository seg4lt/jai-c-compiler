Program_Asm :: struct {
    fn: Fn_Asm;
}

Fn_Asm :: struct {
    ident: string;
    instructions: [..]Instruction_Asm;
}

Instruction_Asm :: struct {
    type : Instruction_Asm_Type;
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
        // cdq: no value needed
        // ret : no value needed
    };
}

Instruction_Asm_Type :: enum {MOV; UNARY; BINARY; IDIV; CDQ; ALLOCATE_STACK; RET; CMP; JMP; JMP_CC;SET_CC;LABEL; };

Cond_Code_Asm :: enum {EE; NE; G; GE; L; LE;}; 

Operand_Asm :: struct {
    type: enum {IMM; REG; PSEUDO; STACK;};
    as: union { imm: int; reg: Reg_Asm; pseudo: string; stack: int; }; 
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

Reg_Asm :: enum { AX; DX; R10; R11; RSP; RBP; RCX; }