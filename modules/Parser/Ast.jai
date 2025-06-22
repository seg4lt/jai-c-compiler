Source_Location :: struct {
    line: int;
    start: int;
}

Program_Ast :: struct {
    fns: [..]*Fn_Decl_Ast;
}

Block_Ast :: struct {
    using loc: Source_Location;
    items: [..]*Block_Item_Ast;
}

Block_Item_Ast :: struct {
    type: enum { STMT; DECL; };
    as: union {
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
    ident: string;
    params: [..]*Fn_Param;
    block: *Block_Ast;
    using loc: Source_Location;
}

Fn_Param :: struct {
    ident: string;
    using loc: Source_Location;
}

Var_Decl_Ast :: struct {
    ident: string;
    init: * /*Optional*/ Expr_Ast;
    using loc: Source_Location;
}

For_Init_Ast :: struct {
    type: enum { INIT_DECL; INIT_EXPR; };
    as: union {
        decl: *Decl_Ast;
        expr: * /*Optional*/ Expr_Ast;
    };
}

Stmt_Ast :: struct {
    type: enum { RETURN; EXPR; IF; NULL; LABEL; GOTO; COMPOUND; BREAK;CONTINUE;WHILE;DO_WHILE;FOR;SWITCH;CASE; DEFAULT;};
    as: union {
        return_stmt: struct { expr: *Expr_Ast; };
        expr: *Expr_Ast;
        if_stmt: struct { condition: *Expr_Ast; if_block: *Stmt_Ast; else_block: /* Optional */ *Stmt_Ast;  };
        label: struct {label: string; stmt: *Stmt_Ast;};
        goto: string;
        compound: *Block_Ast;
        break_stmt: string;
        continue_stmt: string;
        while_stmt: struct { condition: *Expr_Ast; body: *Stmt_Ast; label: string; };
        do_while: struct {  body: *Stmt_Ast; condition: *Expr_Ast; label: string;};
        for_stmt: struct { init: *For_Init_Ast; condition: /* Optional */ *Expr_Ast; post: /* Optional */ *Expr_Ast; body: *Stmt_Ast; label: string; };
        switch: Switch_Stmt_Ast;
        case_stmt: struct { value: string; label: string; };
        default: string;
        // null : doesn't need value
    };
    loc: Source_Location;
}

Switch_Stmt_Ast :: struct {
    condition: *Expr_Ast;
    body: [..]*Block_Item_Ast;
    label: string;
    cases_label: [..]Case_Label_Info;
};

Case_Label_Info :: struct {
    label: string;
    value: string;
    is_default: bool = true;
}

Expr_Ast :: struct {
    type: enum {
        CONSTANT;
        UNARY;
        BINARY;
        GROUP;
        VAR;
        ASSIGNMENT;
        TERNARY;
        FN_CALL;
    }
    as: union {
        constant: int;
        unary: struct { op: Unary_Operator; expr: *Expr_Ast; };
        binary: struct { op: Binary_Operator; left: *Expr_Ast; right: *Expr_Ast;};
        group: *Expr_Ast;
        var: string; // this is when we use a variable
        assignment: struct { dst: *Expr_Ast; src: *Expr_Ast; };
        ternary: struct {condition: *Expr_Ast; true_expr: *Expr_Ast; false_expr: *Expr_Ast;};
        fn_call: struct { ident: string; args: [..]*Expr_Ast; }
    };
    postfix:  enum { NONE; INCR; DECR; } = .NONE;
    using loc: Source_Location;
}

Unary_Operator :: enum {
    BITWISE_NOT;
    NEGATE;
    NOT;
}

Binary_Operator :: enum {
    ADD; SUB; MUL; DIV; MOD;
    BITWISE_AND; BITWISE_OR; BITWISE_XOR;
    LEFT_SHIFT; RIGHT_SHIFT;
    AND; OR;
    NOT_EQUAL; EQUAL_EQUAL;
    GREATER; GREATER_EQUAL;
    LESS; LESS_EQUAL;
};

#scope_module

create_program_ast :: (fns: [..]*Fn_Decl_Ast) -> *Program_Ast {
    pg := New(Program_Ast);
    pg.* = .{ fns };
    return pg;
}

create_decl_ast_fn :: (fn: *Fn_Decl_Ast) -> *Decl_Ast {
    assert(fn != null, "fn cannot be null");
    // assert(fn.block == null, "fn decl cannot have body");
    decl := New(Decl_Ast);
    decl.* = .{.FN, .{ fn }};
    return decl;
}

create_fn_decl_ast :: (ident: string, params: [..]*Fn_Param, block: *Block_Ast, line: int, start: int) -> *Fn_Decl_Ast {
    assert(ident != "", "ident can't be null");

    fn := New(Fn_Decl_Ast);
    fn.* = .{ident, params, block, .{line, start}};
    return fn;
}

create_block_ast :: (items: [..]*Block_Item_Ast, line: int, start: int) -> *Block_Ast {
    block := New(Block_Ast);
    block.* = .{ .{line, start }, items};
    return block;
}

create_stmt_block_item :: (stmt: *Stmt_Ast) -> *Block_Item_Ast {
    assert(stmt != null, "stmt cannot be null");
    item := New(Block_Item_Ast);
    item.* = .{.STMT, .{ stmt = stmt }};
    return item;
}

create_decl_block_item :: (decl: *Decl_Ast) -> *Block_Item_Ast {
    assert(decl != null, "decl cannot be null");
    item := New(Block_Item_Ast);
    item.* = .{.DECL, .{ decl = decl }};
    return item;
}

create_var_decl_ast :: (ident: string, init: *Expr_Ast, line: int, start: int) -> *Decl_Ast {
    assert(ident != "", "ident can't be null");
    decl := New(Decl_Ast);
    var := New(Var_Decl_Ast);
    var.* = .{ident, init, .{line, start}};
    decl.* = .{.VAR, .{ var = var }};
    return decl;
}

create_null_stmt :: (line: int, start: int) -> *Stmt_Ast {
    stmt := New(Stmt_Ast);
    stmt.* = .{.NULL, .{}, .{line, start}};
    return stmt;
}

create_compound_stmt :: (block: *Block_Ast) -> *Stmt_Ast {
    assert(block != null, "block cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.COMPOUND, .{ compound = block }, block.loc};
    return stmt;
}

create_break_stmt :: (line: int, start: int) -> *Stmt_Ast {
    stmt := New(Stmt_Ast);
    stmt.* = .{.BREAK, .{ break_stmt = "$$$UNPROCESSED$$$" }, .{line, start}};
    return stmt;
}

create_continue_stmt :: (line: int, start: int) -> *Stmt_Ast {
    stmt := New(Stmt_Ast);
    stmt.* = .{.CONTINUE, .{ continue_stmt = "$$$UNPROCESSED$$$" }, .{line, start}};
    return stmt;
}

create_goto_stmt :: (label: string, line: int, start: int) -> *Stmt_Ast {
    assert(label != "", "label cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.GOTO, .{ goto = label }, .{line, start}};
    return stmt;
}

create_label_stmt :: (label: string, l_stmt: *Stmt_Ast, line: int, start: int) -> *Stmt_Ast {
    assert(label != "", "label cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.LABEL, .{ label = .{label, l_stmt } }, .{line, start}};
    return stmt;
}

create_expr_stmt :: (expr: *Expr_Ast, line: int, start: int) -> *Stmt_Ast {
    assert(expr != null, "expr cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.EXPR, .{ expr = expr }, .{line, start}};
    return stmt;
}

create_while_stmt :: (condition: *Expr_Ast, body: *Stmt_Ast, line: int, start: int, label: string = "$$UNPROCESSED$$") -> *Stmt_Ast {
    assert(condition != null, "condition cannot be null");
    assert(body != null, "body cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.WHILE, .{while_stmt = .{ condition, body, label }}, .{line, start}};
    return stmt;
}

create_do_while_stmt :: (body: *Stmt_Ast, condition: *Expr_Ast, line: int, start: int, label: string = "$$UNPROCESSED$$") -> *Stmt_Ast {
    assert(body != null, "body cannot be null");
    assert(condition != null, "condition cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.DO_WHILE, .{ do_while = .{ body, condition, label }}, .{line, start}};
    return stmt;
}

create_decl_for_init :: (decl: *Decl_Ast) -> *For_Init_Ast {
    assert(decl != null, "decl cannot be null");
    init := New(For_Init_Ast);
    init.* = .{.INIT_DECL, .{ decl = decl }};
    return init;
}

create_expr_for_init :: (expr: *Expr_Ast) -> *For_Init_Ast {
    init := New(For_Init_Ast);
    init.* = .{.INIT_EXPR, .{ expr = expr }};
    return init;
}

create_for_stmt :: (init: *For_Init_Ast, condition: *Expr_Ast, post: *Expr_Ast, body: *Stmt_Ast, line: int, start: int, label: string = "$$UNPROCESSED$$") -> *Stmt_Ast {
    assert(init != null, "init cannot be null");
    assert(body != null, "body cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.FOR, .{ for_stmt = .{ init, condition, post, body, label }}, .{line, start}};
    return stmt;
}

create_switch_stmt :: (condition: *Expr_Ast, body: [..]*Block_Item_Ast, line: int, start: int, label: string = "$$UNPROCESSED$$") -> *Stmt_Ast {
    assert(condition != null, "condition cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.SWITCH, .{ switch = .{ condition = condition, body = body, label = label }}, .{line, start}};
    return stmt;
}

create_case_stmt :: (value: string, line: int, start: int) -> *Stmt_Ast {
    assert(value != "", "value cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.CASE, .{ case_stmt = .{ value, "$$UNPROCESSED$$" }}, .{line, start}};
    return stmt;
}

create_if_stmt :: (condition: *Expr_Ast, if_block: *Stmt_Ast, else_block: *Stmt_Ast, line: int, start: int) -> *Stmt_Ast {
    assert(condition != null, "condition cannot be null");
    assert(if_block != null, "if_block cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.IF, .{ if_stmt = .{ condition, if_block, else_block }}, .{line, start}};
    return stmt;
}

create_return_stmt :: (expr: *Expr_Ast, line: int, start: int) -> *Stmt_Ast {
    assert(expr != null, "expr cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.RETURN, .{ return_stmt = .{ expr }}, .{line, start}};
    return stmt;
}

create_assignment_expr :: (dst: *Expr_Ast, src: *Expr_Ast, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast {
    assert(dst != null, "dst cannot be null");
    assert(src != null, "src cannot be null");
    expr := New(Expr_Ast);
    expr.* = .{.ASSIGNMENT, .{ assignment = .{ dst, src }}, postfix, .{line, start}};
    return expr;
}



create_ternary_expr :: (condition: *Expr_Ast, true_expr: *Expr_Ast, false_expr: *Expr_Ast, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast {
    assert(condition != null, "condition cannot be null");
    assert(true_expr != null, "true_expr cannot be null");
    assert(false_expr != null, "false_expr cannot be null");
    expr := New(Expr_Ast);
    expr.* = .{.TERNARY, .{ ternary = .{ condition, true_expr, false_expr }}, postfix, .{line, start}};
    return expr;
}

create_unary_expr :: (op: Unary_Operator, expr: *Expr_Ast, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast {
    assert(expr != null, "expr cannot be null");
    unary := New(Expr_Ast);
    unary .* = .{.UNARY, .{ unary = .{ op, expr }}, postfix, .{line, start}};
    return unary;
}

create_var_expr :: (ident: string, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast {
    assert(ident != "", "ident cannot be null");
    expr := New(Expr_Ast);
    expr.* = .{.VAR, .{ var = ident }, postfix, .{line, start}};
    return expr;
}

create_fn_call_expr :: (ident: string, args_list: [..]*Expr_Ast, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast {
    assert(ident != "", "ident cannot be null");
    expr := New(Expr_Ast);
    expr.* = .{.FN_CALL, .{ fn_call = .{ ident, args_list } }, postfix, .{line, start}};
    return expr;
}

create_group_expr :: (expr: *Expr_Ast, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast {
    assert(expr != null, "expr cannot be null");
    group := New(Expr_Ast);
    group.* = .{.GROUP, .{ group = expr }, postfix, .{line, start}};
    return group;
}

create_default_stmt :: (line: int, start: int) -> *Stmt_Ast {
    stmt := New(Stmt_Ast);
    stmt.* = .{.DEFAULT, .{ default = "$$UNPROCESSED$$" }, .{line, start}};
    return stmt;
}


#scope_export

create_binary_expr :: (op: Binary_Operator, left: *Expr_Ast, right: *Expr_Ast, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast {
    assert(left != null, "left cannot be null");
    assert(right != null, "right cannot be null");
    expr := New(Expr_Ast);
    expr.* = .{.BINARY, .{ binary = .{ op, left, right }}, postfix, .{line, start}};
    return expr;
}

create_constant_expr :: (constant: int, line: int, start: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast {
    expr := New(Expr_Ast);
    expr.* = .{.CONSTANT, .{ constant = constant }, postfix, .{line, start}};
    return expr;
}
