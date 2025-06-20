sema_ident_resolution :: (ast: *Program_Ast, erp: *Error_Reporter) {
    new_scope: Scope_Idents;
    init(*new_scope);
    defer deinit(*new_scope);
    
    for fn: ast.fns {
        resolve_fn_decl(fn, *new_scope, erp, can_have_body=true);
    }
}

#scope_file

resolve_block :: (block: *Block_Ast, scope: *Scope_Idents, erp: *Error_Reporter) {
    resolve_block_item(*block.items, scope, erp);
}

resolve_block_item :: (block_items: *[..]*Block_Item_Ast, scope: *Scope_Idents, erp: *Error_Reporter) {
    // new_scope: Scope_Idents;
    // if   scope == null   init(*new_scope);
    // else new_scope = create_new_scope(scope);
    // defer deinit(*new_scope);

    for block_items.* {
        if #complete it.type == {
            case .DECL; resolve_decl(it.as.decl, scope, erp);
            case .STMT; resolve_stmt(it.as.stmt, scope, erp);
        }
    }
}

resolve_stmt :: (stmt: *Stmt_Ast, scope: *Scope_Idents, erp: *Error_Reporter) {
    if #complete stmt.type == {
        case .SWITCH;
            resolve_expr(stmt.as.switch.condition, scope, erp);
            nested_scope := create_new_scope(scope);
            resolve_block_item(*stmt.as.switch.body, *nested_scope, erp);
        case .RETURN;
            resolve_expr(stmt.as.return_stmt.expr, scope, erp);
        case .EXPR;
            resolve_expr(stmt.as.expr, scope, erp);
        case .IF;
            if_stmt := stmt.as.if_stmt;
            resolve_expr(if_stmt.condition, scope, erp);
            resolve_stmt(if_stmt.if_block, scope, erp);
            if if_stmt.else_block != null
                resolve_stmt(if_stmt.else_block, scope, erp);
        case .COMPOUND;
            compound := stmt.as.compound;
            nested_scope := create_new_scope(scope);
            defer deinit(*nested_scope);
            resolve_block(compound, *nested_scope, erp);
        case .FOR; resolve_for_stmt(stmt.as.for_stmt, scope, erp);
        case .DO_WHILE;
            do_while_stmt := stmt.as.do_while;
            resolve_stmt(do_while_stmt.body, scope, erp);
            resolve_expr(do_while_stmt.condition, scope, erp);
        case .WHILE;
            while_stmt := stmt.as.while_stmt;
            resolve_expr(while_stmt.condition, scope, erp);
            resolve_stmt(while_stmt.body, scope, erp);
        case .LABEL;
            resolve_stmt(stmt.as.label.stmt, scope, erp);
        case .CONTINUE; #through;
        case .BREAK; #through;
        case .GOTO; #through;
        case .DEFAULT; #through;
        case .CASE; #through;
        case .NULL;
            // noop
    }
}

resolve_decl :: (decl: *Decl_Ast, scope: *Scope_Idents, erp: *Error_Reporter) {
    if #complete decl.type == {
        case .VAR;
            var_decl := decl.as.var;
            success, entry := table_find_new(scope, var_decl.ident);
            if success && entry.from_current_scope {
                if entry.type == .VAR {
                    error_report(erp, var_decl.line, var_decl.start, "duplicate variable declaration! : %", var_decl.ident);
                }
                if entry.type == .FN && entry.external_linkage {
                    error_report(erp, var_decl.line, var_decl.start, "variable name conflicts with function name: %", var_decl.ident);
                }
            }
                
            new_ident := make_variable(var_decl.ident); 
            ident := Ident(string).{ 
                from_current_scope = true,
                external_linkage = false,
                name = new_ident,
                type = .VAR 
            };
            table_set(scope, var_decl.ident, ident);

            if var_decl.init resolve_expr(var_decl.init, scope, erp);
            var_decl.* = .{ new_ident, var_decl.init, var_decl.loc };
        case .FN; 
            resolve_fn_decl(decl.as.fn, scope, erp, can_have_body=false);
    }
}

resolve_fn_decl :: (fn_decl: *Fn_Decl_Ast, scope: *Scope_Idents, erp: *Error_Reporter, can_have_body: bool = true) {
    success, entry := table_find_new(scope, fn_decl.ident);
    if success  {
        if entry.type == .FN && entry.has_body {
            error_report(erp, fn_decl.line, fn_decl.start, "duplicate function declaration! : %", fn_decl.ident);
        }
        if entry.type == .VAR && entry.from_current_scope {
            error_report(erp, fn_decl.line, fn_decl.start, "function name conflicts with variable name: %", fn_decl.ident);
        }
    }
        
    ident := Ident(string).{
        from_current_scope  = true,
        type                = .FN,
        external_linkage    = true,
        name                = fn_decl.ident,
        has_body            = fn_decl.block != null,
    };
    table_set(scope, fn_decl.ident, ident);
    
    scope_for_fn_param := create_new_scope(scope);
    defer deinit(*scope_for_fn_param);
    
    for param: fn_decl.params  {
        success, entry := table_find_new(*scope_for_fn_param, param.ident);
        if success && entry.from_current_scope {
            error_report(erp, param.line, param.start, "duplicate param name found: %", param.ident);
        }
        
        mapped_ident := make_variable(param.ident);
        ident := Ident(string).{
            from_current_scope  = true,
            type                = .VAR,
            external_linkage    = false,
            name                = mapped_ident,
        };
        table_set(*scope_for_fn_param, param.ident, ident);
    }
    
    if !can_have_body && fn_decl.block != null {
        error_report(erp, fn_decl.line, fn_decl.start, "function declaration cannot have body: %", fn_decl.ident);
    }
    
    if fn_decl.block resolve_block(fn_decl.block, *scope_for_fn_param, erp);
    // mark
}

resolve_expr :: (expr: *Expr_Ast, scope: *Scope_Idents, erp: *Error_Reporter) {
    if #complete expr.type == {
        case .CONSTANT; // noop
        case .UNARY;
            resolve_expr(expr.as.unary.expr, scope, erp);
        case .BINARY;
            resolve_expr(expr.as.binary.left, scope, erp);
            resolve_expr(expr.as.binary.right, scope, erp);
        case .GROUP;
            resolve_expr(expr.as.group, scope, erp);
        case .VAR;
            success, ident := table_find_new(scope, expr.as.var);
            if !success {
                error_report(erp, expr.loc.line, expr.loc.start, "undeclared variable: %", expr.as.var);
            }
            expr.as.var = ident.name;
        case .FN_CALL; 
            fn_call := expr.as.fn_call;
            success, ident := table_find_new(scope, fn_call.ident);
            if !success {
                error_report(erp, expr.line, expr.start, "undeclared function: %", fn_call.ident);
            }
            for fn_call.args resolve_expr(it, scope, erp);
            // TODO(Aman) still need to validate type checking? here or maybe tye checking pass?
            // mark
        case .ASSIGNMENT; resolve_assignment_expr(expr, scope, erp);
        case .TERNARY;
            ternary := expr.as.ternary;
            resolve_expr(ternary.condition, scope, erp);
            resolve_expr(ternary.true_expr, scope, erp);
            resolve_expr(ternary.false_expr, scope, erp);
    }
}

resolve_assignment_expr :: (expr: *Expr_Ast, scope: *Scope_Idents, erp: *Error_Reporter) {
    assignment := expr.as.assignment;
    // verify dst is valid lvalue
    if !(assignment.dst.type == .VAR || (assignment.dst.type == .GROUP && assignment.dst.as.group.type == .VAR)) {
        error_report(erp, expr.loc.line, expr.loc.start,"expected variable (invalid lvalue) found: %", expr.as.assignment.dst.*);
    }
    dst := ifx assignment.dst.type == .VAR then assignment.dst else assignment.dst.as.group;
    resolve_expr(dst, scope, erp);
    resolve_expr(assignment.src, scope, erp);
}

For_Stmt_Ast :: type_of(Stmt_Ast.as.for_stmt);

resolve_for_stmt :: (for_stmt: For_Stmt_Ast, scope: *Scope_Idents, erp: *Error_Reporter) {

    scope_for_init : Scope_Idents;
    defer deinit(*scope_for_init);
    scope_for_init = create_new_scope(scope);

    if #complete for_stmt.init.type == {
        case .INIT_DECL; resolve_decl(for_stmt.init.as.decl, *scope_for_init, erp);
        case .INIT_EXPR;
            if for_stmt.init.as.expr resolve_expr(for_stmt.init.as.expr, *scope_for_init, erp);
    }
    if for_stmt.condition resolve_expr(for_stmt.condition, *scope_for_init, erp);

    if for_stmt.post resolve_expr(for_stmt.post, *scope_for_init, erp);

    {
        scope_for_body : Scope_Idents;
        defer deinit(*scope_for_body);
        scope_for_body = create_new_scope(*scope_for_init);
        resolve_stmt(for_stmt.body, *scope_for_body, erp);
    }
}

Scope_Idents :: Table(string, Ident(string));

Ident :: struct(T: Type) {
    from_current_scope      : bool;
    type                    : enum { FN; VAR; };
    external_linkage        : bool;
    name                    : T;
    // only used for function - maybe this should be union types?
    has_body                : bool;
}

create_new_scope :: (scope: *Scope_Idents) -> Scope_Idents {
    new_table: Scope_Idents;
    init(*new_table);

    for scope {
        value := it;
        value.from_current_scope = false;
        table_set(*new_table, it_index, value);
    }
    return new_table;
}

#scope_module
