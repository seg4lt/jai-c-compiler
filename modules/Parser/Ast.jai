Parser :: struct { 
    tokens: []Token; 
    start: int = 0; 
    current: int = 0;
}

Program_Ast_Node :: struct { 
    fn: *Fn_Ast_Node; 
}

Fn_Ast_Node :: struct {
    ident: string;
    block: *Block_Ast_Node;
}

Block_Ast_Node :: struct {
    items: [..]*Block_Item_Ast_Node;
}

Block_Item_Ast_Node :: struct {
    type: enum { STMT; DECL; };
    as: union {
        stmt: *Stmt_Ast_Node;
        decl: *Decl_Ast_Node;
    };
}

Decl_Ast_Node :: struct {
    ident: string;
    init: * /*Optional */ Expr_Ast_Node;
}

For_Init_Ast_Node :: struct {
    type: enum { INIT_DECL; INIT_EXPR; };
    as: union {
        decl: *Decl_Ast_Node;
        expr: * /*Optional*/ Expr_Ast_Node;
    };
}

Stmt_Ast_Node :: struct {
    type: enum { RETURN; EXPR; IF; NULL; LABEL; GOTO; COMPOUND; BREAK;CONTINUE;WHILE;DO_WHILE;FOR;};
    as: union {
        return_stmt: struct { expr: *Expr_Ast_Node; };
        expr: *Expr_Ast_Node;
        if_stmt: struct { condition: *Expr_Ast_Node; if_block: *Stmt_Ast_Node; else_block: *Stmt_Ast_Node; /* Optional */ };
        label: string;
        goto: string;
        compound: *Block_Ast_Node; 
        break_stmt: string;
        continue_stmt: string;
        while_stmt: struct { condition: *Expr_Ast_Node; body: *Stmt_Ast_Node; label: string; };
        do_while: struct {  body: *Stmt_Ast_Node; condition: *Expr_Ast_Node; label: string;};
        for_stmt: struct { init: *For_Init_Ast_Node; condition: /* Optional */ *Expr_Ast_Node; post: /* Optional */ *Expr_Ast_Node; body: *Stmt_Ast_Node; label: string; }
        // null : doesn't need value
    };
}

Expr_Ast_Node :: struct {
    type: enum { CONSTANT; UNARY; BINARY; GROUP; VAR; ASSIGNMENT; CONDITIONAL;}
    as: union {
        constant: int;
        unary: struct { op: enum {BITWISE_NOT; NEGATE; NOT;}; expr: *Expr_Ast_Node; };
        binary: struct { op: Bin_Op_Ast; left: *Expr_Ast_Node; right: *Expr_Ast_Node;};
        group: *Expr_Ast_Node;
        var: string; // this is when we use a variable
        assignment: struct { dst: *Expr_Ast_Node; src: *Expr_Ast_Node; };
        conditional: struct {condition: *Expr_Ast_Node; true_block: *Expr_Ast_Node; false_block: *Expr_Ast_Node;};
    };
    postfix:  enum {NONE;INCR;DECR;} = .NONE;
}
Bin_Op_Ast :: enum {
    ADD; SUB; MUL; DIV; MOD;
    BITWISE_AND; BITWISE_OR; BITWISE_XOR;
    LEFT_SHIFT; RIGHT_SHIFT;
    AND; OR;
    NOT_EQUAL; EQUAL_EQUAL;
    GREATER; GREATER_EQUAL;
    LESS; LESS_EQUAL;
};