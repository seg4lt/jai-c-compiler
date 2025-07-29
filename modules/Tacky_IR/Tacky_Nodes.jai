Program_Tacky :: struct {
    fns: [..]Fn_Tacky;
}

Fn_Tacky :: struct {
    ident        : string;
    instructions : []Instruction_Tacky;
}

Instruction_Type_Tacky :: enum {
    BINARY;
    COPY;
    FN_CALL;
    JUMP;
    JUMP_IF_NOT_ZERO;
    JUMP_IF_ZERO;
    LABEL;
    RETURN; 
    UNARY; 
}

Instruction_Tacky :: struct {
    type  : Instruction_Type_Tacky;
    as    : union {
        binary            : struct { op: Bin_Op_Type_Tacky; src1: Val_Tacky; src2: Val_Tacky; dst: Val_Tacky; };
        copy              : struct { src: Val_Tacky; dst: Val_Tacky; };
        fn_call           : struct { ident: string; args: [..]Val_Tacky; dst: Val_Tacky; };
        jump              : string;
        jump_if_not_zero  : struct { condition: Val_Tacky; ident: string; };
        jump_if_zero      : struct { condition: Val_Tacky; ident: string; };
        label             : string;
        ret               : Val_Tacky;
        unary             : struct { op: Unary_Op_Type_Tacky; src: Val_Tacky; dst: Val_Tacky; };
    };
}

Unary_Op_Type_Tacky :: enum {
  BITWISE_NOT; 
  NEGATE; 
  NOT;
}

Bin_Op_Type_Tacky :: enum {
    ADD;
    BITWISE_AND;
    BITWISE_OR;
    BITWISE_XOR;
    DIV;
    EQUAL_EQUAL; 
    GREATER; 
    GREATER_EQUAL;
    LEFT_SHIFT;
    LESS; 
    LESS_EQUAL;
    MOD;
    MUL;
    NOT_EQUAL;
    RIGHT_SHIFT;
    SUB;
}

Val_Tacky :: struct {
    type : enum { 
        CONSTANT; 
        VARIABLE; 
    };
    as : union {
        constant : int;
        variable : string;
    };
}

Tacky_Ctx :: struct {
    temp_var_index  : int = 0;
    label_index     : int = 0;
}
