sema_var_resolution :: (ast: *Program_Ast, error_reporter: *Error_Reporter) {
    block := ast.fn.block;
    resolve_block(block, null, error_reporter);
}

#scope_file

resolve_block :: (block: *Block_Ast, scope: *Scope_Idents, error_reporter: *Error_Reporter) {
    resolve_block_item(*block.items, scope, error_reporter);
}

resolve_block_item :: (block_items: *[..]*Block_Item_Ast, scope: *Scope_Idents, error_reporter: *Error_Reporter) {
    new_scope : Scope_Idents;

    if scope == null  {
        log("setting up totally new scope .. \n");
        init(*new_scope);
    } else   {
        log("setting up nested scope... \n");
        new_scope = create_new_scope(scope);
    }
    defer deinit(*new_scope);

    for block_items.* {
        if #complete it.type == {
            case .DECL; resolve_decl(it.as.decl, *new_scope, error_reporter);
            case .STMT; resolve_stmt(it.as.stmt, *new_scope, error_reporter);
        }
    }
}

resolve_stmt :: (stmt: *Stmt_Ast, scope: *Scope_Idents, error_reporter: *Error_Reporter) {
    if #complete stmt.type == {
        case .SWITCH;
            resolve_expr(stmt.as.switch.condition, scope, error_reporter);
            resolve_block_item(*stmt.as.switch.body, scope, error_reporter);
        case .RETURN;
            resolve_expr(stmt.as.return_stmt.expr, scope, error_reporter);
        case .EXPR;
            resolve_expr(stmt.as.expr, scope, error_reporter);
        case .IF;
            if_stmt := stmt.as.if_stmt;
            resolve_expr(if_stmt.condition, scope, error_reporter);
            resolve_stmt(if_stmt.if_block, scope, error_reporter);
            if if_stmt.else_block != null 
                resolve_stmt(if_stmt.else_block, scope, error_reporter);
        case .COMPOUND;
            compound := stmt.as.compound;
            resolve_block(compound, scope, error_reporter);
        case .FOR; resolve_for_stmt(stmt.as.for_stmt, scope, error_reporter);
        case .DO_WHILE;
            do_while_stmt := stmt.as.do_while;
            resolve_stmt(do_while_stmt.body, scope, error_reporter);
            resolve_expr(do_while_stmt.condition, scope, error_reporter);
        case .WHILE;
            while_stmt := stmt.as.while_stmt;
            resolve_expr(while_stmt.condition, scope, error_reporter);
            resolve_stmt(while_stmt.body, scope, error_reporter);
        case .LABEL;
            resolve_stmt(stmt.as.label.stmt, scope, error_reporter);
        case .CONTINUE; #through;
        case .BREAK; #through;
        case .GOTO; #through;
        case .DEFAULT; #through;
        case .CASE; #through;
        case .NULL;
            // noop
    }
}

resolve_decl:: (decl: *Decl_Ast, scope: *Scope_Idents, error_reporter: *Error_Reporter) {

    if #complete decl.type == {
        case .VAR;
            var_decl := decl.as.var;
            entry, success := table_find(scope, var_decl.ident);
            if success && entry.owing_block {
                error_report(error_reporter,var_decl.loc.line, var_decl.loc.start, "duplicate variable declaration! : %", var_decl.ident);
            } 
            new_ident := make_variable(var_decl.ident);
            table_set(scope, var_decl.ident, .{owing_block = true, name = new_ident});

            ifx var_decl.init resolve_expr(var_decl.init, scope, error_reporter);
            var_decl.* = .{ new_ident, var_decl.init, var_decl.loc };
        case .FN;
            unreachable("function declarations not yet supported");
    }

}

resolve_expr :: (expr: *Expr_Ast, scope: *Scope_Idents, error_reporter: *Error_Reporter) {
    if #complete expr.type == {
        case .CONSTANT; // noop
        case .UNARY; 
            resolve_expr(expr.as.unary.expr, scope, error_reporter);
        case .BINARY;
            resolve_expr(expr.as.binary.left, scope, error_reporter);
            resolve_expr(expr.as.binary.right, scope, error_reporter);
        case .GROUP;
            resolve_expr(expr.as.group, scope, error_reporter);
        case .VAR;
            ident, success := table_find(scope, expr.as.var);
            if !success {
                error_report(error_reporter, expr.loc.line, expr.loc.start, "undeclared variable: %", expr.as.var);
            }
            expr.as.var = ident.name;
        case .ASSIGNMENT; resolve_assignment_expr(expr, scope, error_reporter);
        case .TERNARY;
            ternary := expr.as.ternary;
            resolve_expr(ternary.condition, scope, error_reporter);
            resolve_expr(ternary.true_expr, scope, error_reporter);
            resolve_expr(ternary.false_expr, scope, error_reporter);
    }
}

resolve_assignment_expr :: (expr: *Expr_Ast, scope: *Scope_Idents, error_reporter: *Error_Reporter) {
    assignment := expr.as.assignment;
    // verify dst is valid lvalue
    if !(assignment.dst.type == .VAR || (assignment.dst.type == .GROUP && assignment.dst.as.group.type == .VAR)) {
        error_report(error_reporter, expr.loc.line, expr.loc.start,"expected variable (invalid lvalue) found: %", expr.as.assignment.dst.*);
    }
    dst := ifx assignment.dst.type == .VAR then assignment.dst else assignment.dst.as.group;
    resolve_expr(dst, scope, error_reporter);
    resolve_expr(assignment.src, scope, error_reporter);
}

For_Stmt_Ast :: type_of(Stmt_Ast.as.for_stmt);

resolve_for_stmt :: (for_stmt: For_Stmt_Ast, scope: *Scope_Idents, error_reporter: *Error_Reporter) {

    scope_for_init : Scope_Idents;
    defer deinit(*scope_for_init);
    scope_for_init = create_new_scope(scope);

    if #complete for_stmt.init.type == {
        case .INIT_DECL; resolve_decl(for_stmt.init.as.decl, *scope_for_init, error_reporter);
        case .INIT_EXPR;
            if for_stmt.init.as.expr resolve_expr(for_stmt.init.as.expr, *scope_for_init, error_reporter);
    }
    if for_stmt.condition resolve_expr(for_stmt.condition, *scope_for_init, error_reporter);

    if for_stmt.post resolve_expr(for_stmt.post, *scope_for_init, error_reporter);

    {
        scope_for_body : Scope_Idents;
        defer deinit(*scope_for_body);
        scope_for_body = create_new_scope(*scope_for_init);
        resolve_stmt(for_stmt.body, *scope_for_body, error_reporter);
    }
}

Scope_Idents :: Table(string, Ident(string));

Ident :: struct(T: Type) {
    owing_block: bool;
    name: T;
}

create_new_scope :: (scope: *Scope_Idents) -> Scope_Idents {
    new_table: Scope_Idents;
    init(*new_table);

    for scope {
        value := it;
        value.owing_block = false;
        table_set(*new_table, it_index, value);
    }
    return new_table;
}

#scope_module