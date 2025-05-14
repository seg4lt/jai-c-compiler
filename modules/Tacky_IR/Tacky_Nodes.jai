Program_Tacky :: struct {
    fn: Fn_Tacky;
}

Fn_Tacky :: struct {
    ident: string;
    instructions: []Instruction_Tacky;
}

Instruction_Type_Tacky :: enum {
    RETURN; 
    UNARY; 
    BINARY;
    COPY;
    JUMP;
    JUMP_IF_ZERO;
    JUMP_IF_NOT_ZERO;
    LABEL;
}

Instruction_Tacky :: struct {
    type: Instruction_Type_Tacky;
    as : union {
        ret: Val_Tacky;
        unary: struct { op: Unary_Op_Type_Tacky; src: Val_Tacky; dst: Val_Tacky;};
        binary: struct { op: Bin_Op_Type_Tacky; src1: Val_Tacky; src2: Val_Tacky; dst: Val_Tacky; };
        copy: struct {src: Val_Tacky; dst: Val_Tacky;};
        jump: string;
        jump_if_zero: struct {condition: Val_Tacky; ident: string;};
        jump_if_not_zero: struct {condition: Val_Tacky; ident: string;};
        label: string;
    };
}

Unary_Op_Type_Tacky :: enum {
  BITWISE_NOT; 
  NEGATE; 
  NOT;
}

Bin_Op_Type_Tacky ::enum {
    ADD;
    SUB;
    MUL;
    DIV;
    MOD;
    BITWISE_AND;
    BITWISE_OR;
    BITWISE_XOR;
    LEFT_SHIFT;
    RIGHT_SHIFT;

    EQUAL_EQUAL; 
    NOT_EQUAL;
    LESS; 
    LESS_EQUAL;
    GREATER; 
    GREATER_EQUAL;
}

Val_Tacky :: struct {
    type: enum { 
        CONSTANT; 
        VARIABLE; 
    };
    as: union {
        constant: int;
        variable: string;
    };
}

Tacky_Ctx :: struct {
    temp_var_index: int = 0;
    label_index: int = 0;
}
