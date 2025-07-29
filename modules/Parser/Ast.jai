Source_Location :: struct {
    line  : int;
    start : int;
}

Program_Ast :: struct {
    fns: [..]*Fn_Decl_Ast;
}

Block_Ast :: struct {
    items     : [..]*Block_Item_Ast;
    using loc : Source_Location;
}

Block_Item_Ast :: struct {
    type : enum { STMT; DECL; };
    as   : union {
        stmt: *Stmt_Ast;
        decl: *Decl_Ast;
    };
}

Decl_Ast :: struct {
    type : enum { FN; VAR; };
    as   : union {
        fn  : *Fn_Decl_Ast;
        var : *Var_Decl_Ast;
    }
}

Fn_Decl_Ast :: struct {
    ident     : string;
    params    : [..]*Fn_Param;
    block     : *Block_Ast;
    using loc : Source_Location;
}

Fn_Param :: struct {
    ident     : string;
    using loc : Source_Location;
}

Var_Decl_Ast :: struct {
    ident     : string;
    init      : *Expr_Ast; // Optional
    using loc : Source_Location;
}

For_Init_Ast :: struct {
    type : enum { INIT_DECL; INIT_EXPR; };
    as   : union {
        decl : *Decl_Ast;
        expr : *Expr_Ast; // Optional
    };
}

Stmt_Ast :: struct {
    type: enum { 
        BREAK;
        CASE;
        COMPOUND;
        CONTINUE;
        DEFAULT;
        DO_WHILE;
        EXPR;
        FOR;
        GOTO;
        IF;
        LABEL;
        NULL;
        RETURN;
        SWITCH;
        WHILE;
    };
    as: union {
        break_stmt    : string;
        case_stmt     : struct { value: string; label: string; };
        compound      : *Block_Ast;
        continue_stmt : string;
        default       : string;
        do_while      : struct {  body: *Stmt_Ast; condition: *Expr_Ast; label: string;};
        expr          : *Expr_Ast;
        for_stmt      : struct { init: *For_Init_Ast; condition: /* Optional */ *Expr_Ast; post: /* Optional */ *Expr_Ast; body: *Stmt_Ast; label: string; };
        goto          : string;
        if_stmt       : struct { condition: *Expr_Ast; if_block: *Stmt_Ast; else_block: /* Optional */ *Stmt_Ast;  };
        label         : struct {label: string; stmt: *Stmt_Ast;};
        return_stmt   : struct { expr: *Expr_Ast; };
        switch        : Switch_Stmt_Ast;
        while_stmt    : struct { condition: *Expr_Ast; body: *Stmt_Ast; label: string; };
        // null : doesn't need value
    };
    using loc: Source_Location;
}

Switch_Stmt_Ast :: struct {
    condition   : *Expr_Ast;
    body        : [..]*Block_Item_Ast;
    label       : string;
    cases_label : [..]Case_Label_Info;
};

Case_Label_Info :: struct {
    label       : string;
    value       : string;
    is_default  : bool = true;
}

Expr_Ast :: struct {
    type: enum {
        ASSIGNMENT;
        BINARY;
        CONSTANT;
        FN_CALL;
        GROUP;
        TERNARY;
        UNARY;
        VAR;
    }
    as: union {
        assignment  : struct { dst: *Expr_Ast; src: *Expr_Ast; };
        binary      : struct { op: Binary_Operator; left: *Expr_Ast; right: *Expr_Ast;};
        constant    : int;
        fn_call     : struct { ident: string; args: [..]*Expr_Ast; }
        group       : *Expr_Ast;
        ternary     : struct {condition: *Expr_Ast; true_expr: *Expr_Ast; false_expr: *Expr_Ast;};
        unary       : struct { op: Unary_Operator; expr: *Expr_Ast; };
        var         : string; 
    };
    // @refactor
    // Maybe should be be a expression type which has sub expression
    postfix :  enum { 
        DECR; 
        INCR; 
        NONE; 
    } = .NONE;
    using loc: Source_Location;
}

Unary_Operator :: enum {
    BITWISE_NOT;
    NEGATE;
    NOT;
}

Binary_Operator :: enum {
    ADD;
    AND;
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
    OR;
    RIGHT_SHIFT;
    SUB;
};

#scope_module

program_new :: (fns: [..]*Fn_Decl_Ast) -> *Program_Ast #expand {
    return New(Program_Ast, .{ fns });
}

decl_fn_new :: (fn: *Fn_Decl_Ast) -> *Decl_Ast #expand {
    assert(fn != null, "fn cannot be null");
    return New(Decl_Ast, .{ type = .FN, as = .{ fn = fn } });
}

fn_decl_new :: (ident: string, params: [..]*Fn_Param, block: *Block_Ast, line: int, start: int) -> *Fn_Decl_Ast #expand {
    assert(ident != "", "ident can't be null");
    return New(Fn_Decl_Ast, .{ident, params, block, .{line, start}});
}

block_new :: (items: [..]*Block_Item_Ast, line: int, start: int) -> *Block_Ast #expand {
    return New(Block_Ast, .{items, .{line, start}});
}

block_item_stmt_new :: (stmt: *Stmt_Ast) -> *Block_Item_Ast #expand {
    assert(stmt != null, "stmt cannot be null");
    return New(Block_Item_Ast, .{ .STMT, .{ stmt = stmt } });
}

block_item_decl_new :: (decl: *Decl_Ast) -> *Block_Item_Ast #expand {
    assert(decl != null, "decl cannot be null");
    return New(Block_Item_Ast, .{ .DECL, .{ decl = decl } });
}

decl_var_new :: (ident: string, init: *Expr_Ast, line: int, start: int) -> *Decl_Ast #expand {
    assert(ident != "", "ident can't be null");
    var := New(Var_Decl_Ast, .{ident, init, .{line, start}});
    return New(Decl_Ast, .{ .VAR, .{ var = var } });
}

stmt_null_new :: (line: int, start: int) -> *Stmt_Ast #expand {
    return New(Stmt_Ast, .{ .NULL, .{}, .{line, start}});
}

stmt_compound_new :: (block: *Block_Ast) -> *Stmt_Ast #expand {
    assert(block != null, "block cannot be null");
    return New(Stmt_Ast, .{ .COMPOUND, .{ compound = block }, block.loc });
}

stmt_break_new :: (line: int, start: int) -> *Stmt_Ast #expand {
    return New(Stmt_Ast, .{.BREAK, .{ break_stmt = "$$$$$$$$$" }, .{line, start}});
}

stmt_continue_new :: (line: int, start: int) -> *Stmt_Ast #expand {
    stmt := New(Stmt_Ast);
    stmt.* = .{.CONTINUE, .{ continue_stmt = "$$$UNPROCESSED$$$" }, .{line, start}};
    return stmt;
}

stmt_goto_new :: (label: string, line: int, start: int) -> *Stmt_Ast #expand {
    assert(label != "", "label cannot be null");
    return New(Stmt_Ast, .{.GOTO, .{ goto = label }, .{line, start}});
}

stmt_label_new :: (label: string, l_stmt: *Stmt_Ast, line: int, start: int) -> *Stmt_Ast #expand {
    assert(label != "", "label cannot be null");
    return New(Stmt_Ast, .{.LABEL, .{ label = .{label, l_stmt } }, .{line, start}});
}

stmt_expr_new :: (expr: *Expr_Ast, line: int, start: int) -> *Stmt_Ast #expand {
    assert(expr != null, "expr cannot be null");
    return New(Stmt_Ast, .{.EXPR, .{ expr = expr }, .{line, start}});
}

stmt_while_new :: (condition: *Expr_Ast, body: *Stmt_Ast, line: int, start: int, label: string = "$$UNPROCESSED$$") -> *Stmt_Ast #expand {
    assert(condition != null, "condition cannot be null");
    assert(body != null, "body cannot be null");
    return New(Stmt_Ast, .{.WHILE, .{while_stmt = .{ condition, body, label }}, .{line, start}});
}

stmt_do_while_new :: (body: *Stmt_Ast, condition: *Expr_Ast, line: int, start: int, label: string = "$$UNPROCESSED$$") -> *Stmt_Ast #expand {
    assert(body != null, "body cannot be null");
    assert(condition != null, "condition cannot be null");
    return New(Stmt_Ast, .{.DO_WHILE, .{ do_while = .{ body, condition, label }}, .{line, start}});
}

for_init_decl_new :: (decl: *Decl_Ast) -> *For_Init_Ast #expand {
    assert(decl != null, "decl cannot be null");
    return New(For_Init_Ast, .{.INIT_DECL, .{ decl = decl }});
}

for_init_expr_new :: (expr: *Expr_Ast) -> *For_Init_Ast #expand {
    return New(For_Init_Ast, .{.INIT_EXPR, .{ expr = expr }});
}

stmt_for_new :: (init: *For_Init_Ast, condition: *Expr_Ast, post: *Expr_Ast, body: *Stmt_Ast, line: int, start: int, label: string = "$$UNPROCESSED$$") -> *Stmt_Ast #expand {
    assert(init != null, "init cannot be null");
    assert(body != null, "body cannot be null");
    return New(Stmt_Ast, .{
        .FOR, 
        .{ for_stmt = .{ init, condition, post, body, label }},
        .{line, start}
    });
}

stmt_switch_new :: (condition: *Expr_Ast, body: [..]*Block_Item_Ast, line: int, start: int, label: string = "$$$$$$$$$") -> *Stmt_Ast #expand {
    assert(condition != null, "condition cannot be null");
    return New(Stmt_Ast, .{
        .SWITCH,
        .{ switch = .{ condition = condition, body = body, label = label }}, 
        .{line, start}
    });
}

stmt_case_new :: (value: string, line: int, start: int) -> *Stmt_Ast #expand {
    assert(value != "", "value cannot be null");
    return New(Stmt_Ast, .{
        .CASE,
        .{ case_stmt = .{ value, "$$UNPROCESSED$$" }},
        .{line, start}
    });
}

stmt_if_new :: (condition: *Expr_Ast, if_block: *Stmt_Ast, else_block: *Stmt_Ast, line: int, start: int) -> *Stmt_Ast #expand {
    assert(condition != null, "condition cannot be null");
    assert(if_block != null, "if_block cannot be null");
    stmt := New(Stmt_Ast);
    return New(Stmt_Ast, .{
        .IF,
        .{ if_stmt = .{ condition, if_block, else_block }},
        .{line, start}
    });
}

stmt_return_new :: (expr: *Expr_Ast, line: int, start: int) -> *Stmt_Ast #expand {
    assert(expr != null, "expr cannot be null");
    return New(Stmt_Ast, .{.RETURN, .{ return_stmt = .{ expr }}, .{line, start}});
}

expr_assignment_new :: (dst: *Expr_Ast, src: *Expr_Ast, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast #expand {
    assert(dst != null, "dst cannot be null");
    assert(src != null, "src cannot be null");
    return New(Expr_Ast, .{.ASSIGNMENT, .{ assignment = .{ dst, src }}, postfix, .{line, start}});
}

expr_ternary_new :: (condition: *Expr_Ast, true_expr: *Expr_Ast, false_expr: *Expr_Ast, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast #expand {
    assert(condition != null, "condition cannot be null");
    assert(true_expr != null, "true_expr cannot be null");
    assert(false_expr != null, "false_expr cannot be null");
    return New(Expr_Ast, .{.TERNARY, .{ ternary = .{ condition, true_expr, false_expr }}, postfix, .{line, start}});
}

expr_unary_new :: (op: Unary_Operator, expr: *Expr_Ast, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast #expand {
    assert(expr != null, "expr cannot be null");
    return New(Expr_Ast, .{.UNARY, .{ unary = .{ op, expr }}, postfix, .{line, start}});
}

expr_var_new :: (ident: string, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast #expand {
    assert(ident != "", "ident cannot be null");
    return New(Expr_Ast, .{.VAR, .{ var = ident }, postfix, .{line, start}});
}

expr_fn_call_new :: (ident: string, args_list: [..]*Expr_Ast, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast #expand {
    assert(ident != "", "ident cannot be null");
    return New(Expr_Ast, .{.FN_CALL, .{ fn_call = .{ ident, args_list } }, postfix, .{line, start}});
}

expr_group_new :: (expr: *Expr_Ast, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast #expand {
    assert(expr != null, "expr cannot be null");
    return New(Expr_Ast, .{.GROUP, .{ group = expr }, postfix, .{line, start}});
}

stmt_default_new :: (line: int, start: int) -> *Stmt_Ast #expand {
    return New(Stmt_Ast, .{.DEFAULT, .{ default = "$$UNPROCESSED$$" }, .{line, start}});
}

#scope_export

expr_binary_new :: (op: Binary_Operator, left: *Expr_Ast, right: *Expr_Ast, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast #expand {
    assert(left != null, "left cannot be null");
    assert(right != null, "right cannot be null");
    return New(Expr_Ast, .{.BINARY, .{ binary = .{ op, left, right }}, postfix, .{line, start}});
}

expr_constant_new :: (constant: int, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast #expand {
    return New(Expr_Ast, .{.CONSTANT, .{ constant = constant }, postfix, .{line, start}});
}
