Program_Ast :: struct {
    decls: [..]*Decl_Ast;
}

Storage_Class_Ast :: enum { EXTERN; STATIC; NONE; };

Block_Ast :: struct {
    items:     [..]*Block_Item_Ast;
    using loc: Source_Location;
}

Block_Item_Ast :: struct {
    type: enum { STMT; DECL; };
    using as: union {
        block_item_stmt: *Stmt_Ast;
        block_item_decl: *Decl_Ast;
    };
}

Decl_Ast :: struct {
    type:     enum { FN; VAR; };
    using as: union {
        decl_fn:  *Fn_Decl_Ast;
        decl_var: *Var_Decl_Ast;
    }
}

Fn_Decl_Ast :: struct {
    ident:         string;
    params:        [..]*Fn_Param;
    block:         *Block_Ast;
    storage_class: Storage_Class_Ast;
    using loc:     Source_Location;
}

Fn_Param :: struct {
    ident:     string;
    using loc: Source_Location;
}

Var_Decl_Ast :: struct {
    ident:         string;
    init:          *Expr_Ast; @Optional
    storage_class: Storage_Class_Ast;
    using loc:     Source_Location;
}

For_Init_Ast :: struct {
    type:     enum { DECL; EXPR; };
    using as: union {
        for_init_decl: *Decl_Ast;
        for_init_expr: *Expr_Ast; @Optional 
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
    using as: union {
        stmt_break:       string;
        stmt_case:        struct { value: string; label: string; };
        stmt_compound:    *Block_Ast;
        stmt_continue:    string;
        stmt_default:     string;
        stmt_do_while:    struct { body: *Stmt_Ast; condition: *Expr_Ast; label: string; };
        stmt_expr:        *Expr_Ast;
        stmt_for:         struct { init: *For_Init_Ast; condition: *Expr_Ast; @Optional post: *Expr_Ast; @Optional body: *Stmt_Ast; label: string; };
        stmt_goto:        string;
        stmt_if:          struct { condition: *Expr_Ast; if_block: *Stmt_Ast; else_block: *Stmt_Ast; @Optional  };
        stmt_label:       struct {label: string; stmt: *Stmt_Ast;};
        stmt_return:      struct { expr: *Expr_Ast; };
        stmt_switch:      Switch_Stmt_Ast;
        stmt_while:       struct { condition: *Expr_Ast; body: *Stmt_Ast; label: string; };
        // null : doesn't need value
    };
    using loc: Source_Location;
}

Switch_Stmt_Ast :: struct {
    condition:   *Expr_Ast;
    body:        [..]*Block_Item_Ast;
    label:       string;
    cases_label: [..]Case_Label_Info;
};

Case_Label_Info :: struct {
    label:      string;
    value:      string;
    is_default: bool = true;
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
        PREFIX;
        POSTFIX;
    };
    using as: union {
        expr_assignment: struct { dst: *Expr_Ast; src: *Expr_Ast; };
        expr_binary:     struct { op: Binary_Operator; left: *Expr_Ast; right: *Expr_Ast; };
        expr_constant:   int;
        expr_fn_call:    struct { ident: string; args: [..]*Expr_Ast; }
        expr_group:      *Expr_Ast;
        expr_ternary:    struct { condition: *Expr_Ast; true_expr: *Expr_Ast; false_expr: *Expr_Ast; };
        expr_unary:      struct { op: Unary_Operator; expr: *Expr_Ast; };
        expr_var:        string; 
        expr_postfix:    struct { op: Postfix_Operator; expr: *Expr_Ast; };
        expr_prefix:     struct { op: Prefix_Operator; expr: *Expr_Ast; };
    };
    using loc: Source_Location;
}

Postfix_Operator :: enum { ADD; SUBTRACT; }

Prefix_Operator :: Postfix_Operator; 

Unary_Operator :: enum { BITWISE_NOT; NEGATE; NOT; }

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

Source_Location :: struct {
    line, start: int;
}

#scope_module

program_new :: (decls: [..]*Decl_Ast) -> *Program_Ast #expand {
    return New(Program_Ast, .{ decls });
}

decl_fn_new :: (fn: *Fn_Decl_Ast) -> *Decl_Ast #expand {
    assert(fn != null, "fn cannot be null");
    return New(Decl_Ast, .{ type = .FN, as = .{ decl_fn = fn } });
}

fn_decl_new :: (ident: string, params: [..]*Fn_Param, block: *Block_Ast, storage_class: Storage_Class_Ast, line: int, start: int) -> *Fn_Decl_Ast #expand {
    assert(ident != "", "ident can't be null");
    return New(Fn_Decl_Ast, .{
        ident, params, block, storage_class, .{line, start}
    });
}

block_new :: (items: [..]*Block_Item_Ast, line: int, start: int) -> *Block_Ast #expand {
    return New(Block_Ast, .{items, .{line, start}});
}

block_item_stmt_new :: (stmt: *Stmt_Ast) -> *Block_Item_Ast #expand {
    assert(stmt != null, "stmt cannot be null");
    return New(Block_Item_Ast, .{ type = .STMT, as = .{ block_item_stmt = stmt } });
}

block_item_decl_new :: (decl: *Decl_Ast) -> *Block_Item_Ast #expand {
    assert(decl != null, "decl cannot be null");
    return New(Block_Item_Ast, .{ type = .DECL, as = .{ block_item_decl = decl } });
}

decl_var_new :: (ident: string, init: *Expr_Ast, storage_class: Storage_Class_Ast, line: int, start: int) -> *Decl_Ast #expand {
    assert(ident != "", "ident can't be null");
    var := New(Var_Decl_Ast, .{ident, init, storage_class, .{line, start}});
    return New(Decl_Ast, .{ type = .VAR, as = .{ decl_var = var } });
}

stmt_null_new :: (line: int, start: int) -> *Stmt_Ast #expand {
    return New(Stmt_Ast, .{ .NULL, .{}, .{line, start}});
}

stmt_compound_new :: (block: *Block_Ast) -> *Stmt_Ast #expand {
    assert(block != null, "block cannot be null");
    return New(Stmt_Ast, .{ type = .COMPOUND,  stmt_compound = block, line = block.line, start = block.start });
}

stmt_break_new :: (line: int, start: int) -> *Stmt_Ast #expand {
    return New(Stmt_Ast, .{ type = .BREAK, line = line, start = start });
}

stmt_continue_new :: (line: int, start: int) -> *Stmt_Ast #expand {
    stmt := New(Stmt_Ast);
    stmt.* = .{.CONTINUE, .{ stmt_continue = "$$$UNPROCESSED$$$" }, .{line, start}};
    return stmt;
}

stmt_goto_new :: (label: string, line: int, start: int) -> *Stmt_Ast #expand {
    assert(label != "", "label cannot be null");
    return New(Stmt_Ast, .{.GOTO, .{ stmt_goto = label }, .{line, start}});
}

stmt_label_new :: (label: string, l_stmt: *Stmt_Ast, line: int, start: int) -> *Stmt_Ast #expand {
    assert(label != "", "label cannot be null");
    return New(Stmt_Ast, .{.LABEL, .{ stmt_label = .{label, l_stmt } }, .{line, start}});
}

stmt_expr_new :: (expr: *Expr_Ast, line: int, start: int) -> *Stmt_Ast #expand {
    assert(expr != null, "expr cannot be null");
    return New(Stmt_Ast, .{.EXPR, .{ stmt_expr = expr }, .{line, start}});
}

stmt_while_new :: (condition: *Expr_Ast, body: *Stmt_Ast, line: int, start: int, label: string = "$$UNPROCESSED$$") -> *Stmt_Ast #expand {
    assert(condition != null, "condition cannot be null");
    assert(body != null, "body cannot be null");
    return New(Stmt_Ast, .{.WHILE, .{ stmt_while = .{ condition, body, label }}, .{line, start}});
}

stmt_do_while_new :: (body: *Stmt_Ast, condition: *Expr_Ast, line: int, start: int, label: string = "$$UNPROCESSED$$") -> *Stmt_Ast #expand {
    assert(body != null, "body cannot be null");
    assert(condition != null, "condition cannot be null");
    return New(Stmt_Ast, .{.DO_WHILE, .{ stmt_do_while = .{ body, condition, label }}, .{line, start}});
}

for_init_decl_new :: (decl: *Decl_Ast) -> *For_Init_Ast #expand {
    assert(decl != null, "decl cannot be null");
    return New(For_Init_Ast, .{ type = .DECL, as = .{ for_init_decl = decl }});
}

for_init_expr_new :: (expr: *Expr_Ast) -> *For_Init_Ast #expand {
    return New(For_Init_Ast, .{ type = .EXPR , as = .{ for_init_expr = expr }});
}

stmt_for_new :: (init: *For_Init_Ast, condition: *Expr_Ast, post: *Expr_Ast, body: *Stmt_Ast, line: int, start: int, label: string = "$$UNPROCESSED$$") -> *Stmt_Ast #expand {
    assert(init != null, "init cannot be null");
    assert(body != null, "body cannot be null");
    return New(Stmt_Ast, .{
        .FOR, 
        .{ stmt_for = .{ init, condition, post, body, label }},
        .{line, start}
    });
}

stmt_switch_new :: (condition: *Expr_Ast, body: [..]*Block_Item_Ast, line: int, start: int, label: string = "$$$$$$$$$") -> *Stmt_Ast #expand {
    assert(condition != null, "condition cannot be null");
    return New(Stmt_Ast, .{
        .SWITCH,
        .{ stmt_switch = .{ condition = condition, body = body, label = label }}, 
        .{line, start}
    });
}

stmt_case_new :: (value: string, line: int, start: int) -> *Stmt_Ast #expand {
    assert(value != "", "value cannot be null");
    return New(Stmt_Ast, .{
        .CASE,
        .{ stmt_case = .{ value, "$$UNPROCESSED$$" }},
        .{line, start}
    });
}

stmt_if_new :: (condition: *Expr_Ast, if_block: *Stmt_Ast, else_block: *Stmt_Ast, line: int, start: int) -> *Stmt_Ast #expand {
    assert(condition != null, "condition cannot be null");
    assert(if_block != null, "if_block cannot be null");
    stmt := New(Stmt_Ast);
    return New(Stmt_Ast, .{
        .IF,
        .{ stmt_if = .{ condition, if_block, else_block }},
        .{line, start}
    });
}

stmt_return_new :: (expr: *Expr_Ast, line: int, start: int) -> *Stmt_Ast #expand {
    assert(expr != null, "expr cannot be null");
    return New(Stmt_Ast, .{.RETURN, .{ stmt_return = .{ expr }}, .{line, start}});
}

expr_prefix_new :: (op: Prefix_Operator, expr: *Expr_Ast, line: int, start: int) -> *Expr_Ast #expand {
    assert(expr != null, "expr cannot be null");
    return New(Expr_Ast, .{.PREFIX, .{ expr_prefix = .{ op, expr }}, .{line, start}});
}

expr_postfix_new :: (op: Postfix_Operator, expr: *Expr_Ast, line: int, start: int) -> *Expr_Ast #expand {
    assert(expr != null, "expr cannot be null");
    return New(Expr_Ast, .{.POSTFIX, .{ expr_postfix = .{ op, expr }}, .{line, start}});
}

expr_assignment_new :: (dst: *Expr_Ast, src: *Expr_Ast, line: int, start: int) -> *Expr_Ast #expand {
    assert(dst != null, "dst cannot be null");
    assert(src != null, "src cannot be null");
    return New(Expr_Ast, .{.ASSIGNMENT, .{ expr_assignment = .{ dst, src }}, .{line, start}});
}

expr_ternary_new :: (condition: *Expr_Ast, true_expr: *Expr_Ast, false_expr: *Expr_Ast, line: int, start: int) -> *Expr_Ast #expand {
    assert(condition != null, "condition cannot be null");
    assert(true_expr != null, "true_expr cannot be null");
    assert(false_expr != null, "false_expr cannot be null");
    return New(Expr_Ast, .{.TERNARY, .{ expr_ternary = .{ condition, true_expr, false_expr }}, .{line, start}});
}

expr_unary_new :: (op: Unary_Operator, expr: *Expr_Ast, line: int, start: int) -> *Expr_Ast #expand {
    assert(expr != null, "expr cannot be null");
    return New(Expr_Ast, .{.UNARY, .{ expr_unary = .{ op, expr }}, .{line, start}});
}

expr_var_new :: (ident: string, line: int, start: int) -> *Expr_Ast #expand {
    assert(ident != "", "ident cannot be null");
    return New(Expr_Ast, .{.VAR, .{ expr_var = ident }, .{line, start}});
}

expr_fn_call_new :: (ident: string, args_list: [..]*Expr_Ast, line: int, start: int) -> *Expr_Ast #expand {
    assert(ident != "", "ident cannot be null");
    return New(Expr_Ast, .{.FN_CALL, .{ expr_fn_call = .{ ident, args_list } }, .{line, start}});
}

expr_group_new :: (expr: *Expr_Ast, line: int, start: int) -> *Expr_Ast #expand {
    assert(expr != null, "expr cannot be null");
    return New(Expr_Ast, .{.GROUP, .{ expr_group = expr }, .{line, start}});
}

stmt_default_new :: (line: int, start: int) -> *Stmt_Ast #expand {
    return New(Stmt_Ast, .{.DEFAULT, .{ stmt_default = "$$UNPROCESSED$$" }, .{line, start}});
}

expr_binary_new :: (op: Binary_Operator, left: *Expr_Ast, right: *Expr_Ast, line: int, start: int) -> *Expr_Ast #expand {
    assert(left != null, "left cannot be null");
    assert(right != null, "right cannot be null");
    return New(Expr_Ast, .{.BINARY, .{ expr_binary = .{ op, left, right }}, .{line, start}});
}

expr_constant_new :: (constant: int, line: int, start: int) -> *Expr_Ast #expand {
    return New(Expr_Ast, .{.CONSTANT, .{ expr_constant = constant }, .{line, start}});
}
