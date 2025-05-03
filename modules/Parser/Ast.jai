Program_Ast :: struct { 
    fn: *Fn_Ast; 
}

Fn_Ast :: struct {
    ident: string;
    block: *Block_Ast;
}

Block_Ast :: struct {
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
    ident: string;
    init: * /*Optional */ Expr_Ast;
}

For_Init_Ast :: struct {
    type: enum { INIT_DECL; INIT_EXPR; };
    as: union {
        decl: *Decl_Ast;
        expr: * /*Optional*/ Expr_Ast;
    };
}

Stmt_Ast :: struct {
    type: enum { RETURN; EXPR; IF; NULL; LABEL; GOTO; COMPOUND; BREAK;CONTINUE;WHILE;DO_WHILE;FOR;};
    as: union {
        return_stmt: struct { expr: *Expr_Ast; };
        expr: *Expr_Ast;
        if_stmt: struct { condition: *Expr_Ast; if_block: *Stmt_Ast; else_block: *Stmt_Ast; /* Optional */ };
        label: string;
        goto: string;
        compound: *Block_Ast; 
        break_stmt: string;
        continue_stmt: string;
        while_stmt: struct { condition: *Expr_Ast; body: *Stmt_Ast; label: string; };
        do_while: struct {  body: *Stmt_Ast; condition: *Expr_Ast; label: string;};
        for_stmt: struct { init: *For_Init_Ast; condition: /* Optional */ *Expr_Ast; post: /* Optional */ *Expr_Ast; body: *Stmt_Ast; label: string; }
        // null : doesn't need value
    };
}

Expr_Ast :: struct {
    type: enum { CONSTANT; UNARY; BINARY; GROUP; VAR; ASSIGNMENT; CONDITIONAL;}
    as: union {
        constant: int;
        unary: struct { op: Unary_Operator; expr: *Expr_Ast; };
        binary: struct { op: Binary_Operator; left: *Expr_Ast; right: *Expr_Ast;};
        group: *Expr_Ast;
        var: string; // this is when we use a variable
        assignment: struct { dst: *Expr_Ast; src: *Expr_Ast; };
        conditional: struct {condition: *Expr_Ast; true_block: *Expr_Ast; false_block: *Expr_Ast;};
    };
    postfix:  enum {NONE;INCR;DECR;} = .NONE;
}

Unary_Operator :: enum {
    BITWISE_NOT; NEGATE; NOT;
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

create_program_ast :: (fn: *Fn_Ast) -> *Program_Ast {
    assert(fn != null, "fn cannot be null");
    pg := New(Program_Ast);
    pg.* = .{ fn = fn };
    return pg;
}

create_fn_ast :: (ident: string, block: *Block_Ast) -> *Fn_Ast {
    assert(ident != "", "ident cann't be null");
    assert(block != null, "block cannot be null");

    fn := New(Fn_Ast);
    fn.* = .{ident, block};
    return fn;
}

create_block_ast :: (items: [..]*Block_Item_Ast) -> *Block_Ast {
    block := New(Block_Ast);
    block.* = .{items};
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

create_decl_ast :: (ident: string, init: *Expr_Ast) -> *Decl_Ast {
    assert(ident != "", "ident can't be null");
    decl := New(Decl_Ast);
    decl.* = .{ident, init};
    return decl;
}

create_null_stmt :: () -> *Stmt_Ast {
    stmt := New(Stmt_Ast);
    stmt.* = .{.NULL, .{ }};
    return stmt;
}

create_compound_stmt :: (block: *Block_Ast) -> *Stmt_Ast {
    assert(block != null, "block cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.COMPOUND, .{ compound = block }};
    return stmt;
}

create_break_stmt :: () -> *Stmt_Ast {
    stmt := New(Stmt_Ast);
    stmt.* = .{.BREAK, .{ break_stmt = "$$$UNPROCESSED$$$" }};
    return stmt;
}

create_continue_stmt :: () -> *Stmt_Ast {
    stmt := New(Stmt_Ast);
    stmt.* = .{.CONTINUE, .{ continue_stmt = "$$$UNPROCESSED$$$" }};
    return stmt;
}

create_goto_stmt :: (label: string) -> *Stmt_Ast {
    assert(label != "", "label cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.GOTO, .{ goto = label }};
    return stmt;
}

create_label_stmt :: (label: string) -> *Stmt_Ast {
    assert(label != "", "label cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.LABEL, .{ label = label }};
    return stmt;
}

create_expr_stmt :: (expr: *Expr_Ast) -> *Stmt_Ast {
    assert(expr != null, "expr cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.EXPR, .{ expr = expr }};
    return stmt;
}

create_while_stmt :: (condition: *Expr_Ast, body: *Stmt_Ast, label: string = "$$UNPROCESSED$$") -> *Stmt_Ast {
    assert(condition != null, "condition cannot be null");
    assert(body != null, "body cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.WHILE, .{while_stmt = .{ condition, body, label }}};
    return stmt;
}

create_do_while_stmt :: (body: *Stmt_Ast, condition: *Expr_Ast, label: string = "$$UNPROCESSED$$") -> *Stmt_Ast {
    assert(body != null, "body cannot be null");
    assert(condition != null, "condition cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.DO_WHILE, .{ do_while = .{ body, condition, label }}};
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

create_for_stmt :: (init: *For_Init_Ast, condition: *Expr_Ast, post: *Expr_Ast, body: *Stmt_Ast, label: string = "$$UNPROCESSED$$") -> *Stmt_Ast {
    assert(init != null, "init cannot be null");
    assert(body != null, "body cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.FOR, .{ for_stmt = .{ init, condition, post, body, label }}};
    return stmt;
}

create_if_stmt :: (condition: *Expr_Ast, if_block: *Stmt_Ast, else_block: *Stmt_Ast) -> *Stmt_Ast {
    assert(condition != null, "condition cannot be null");
    assert(if_block != null, "if_block cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.IF, .{ if_stmt = .{ condition, if_block, else_block }}};
    return stmt;
}

create_return_stmt :: (expr: *Expr_Ast) -> *Stmt_Ast {
    assert(expr != null, "expr cannot be null");
    stmt := New(Stmt_Ast);
    stmt.* = .{.RETURN, .{ return_stmt = .{ expr }}};
    return stmt;
}

create_assignment_expr :: (dst: *Expr_Ast, src: *Expr_Ast, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast {
    assert(dst != null, "dst cannot be null");
    assert(src != null, "src cannot be null");
    expr := New(Expr_Ast);
    expr.* = .{.ASSIGNMENT, .{ assignment = .{ dst, src }}, postfix};
    return expr;
}

create_binary_expr :: (op: Binary_Operator, left: *Expr_Ast, right: *Expr_Ast, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast {
    assert(left != null, "left cannot be null");
    assert(right != null, "right cannot be null");
    expr := New(Expr_Ast);
    expr.* = .{.BINARY, .{ binary = .{ op, left, right }}, postfix};
    return expr;
}

create_ternary_expr :: (condition: *Expr_Ast, true_block: *Expr_Ast, false_block: *Expr_Ast, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast {
    assert(condition != null, "condition cannot be null");
    assert(true_block != null, "true_block cannot be null");
    assert(false_block != null, "false_block cannot be null");
    expr := New(Expr_Ast);
    expr.* = .{.CONDITIONAL, .{ conditional = .{ condition, true_block, false_block }}, postfix};
    return expr;
}

create_unary_expr :: (op: Unary_Operator, expr: *Expr_Ast, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast {
    assert(expr != null, "expr cannot be null");
    unary := New(Expr_Ast);
    unary .* = .{.UNARY, .{ unary = .{ op, expr }}, postfix};
    return unary;
}

create_var_expr :: (ident: string, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast {
    assert(ident != "", "ident cannot be null");
    expr := New(Expr_Ast);
    expr.* = .{.VAR, .{ var = ident }, postfix};
    return expr;
}

create_constant_expr :: (constant: int, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast {
    expr := New(Expr_Ast);
    expr.* = .{.CONSTANT, .{ constant = constant }, postfix};
    return expr;
}

create_group_expr :: (expr: *Expr_Ast, postfix: type_of(Expr_Ast.postfix) = .NONE) -> *Expr_Ast {
    assert(expr != null, "expr cannot be null");
    group := New(Expr_Ast);
    group.* = .{.GROUP, .{ group = expr }, postfix};
    return group;
}


#scope_export