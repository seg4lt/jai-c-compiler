sema_ident_resolution :: (ast: *Ast.Program, erp: *Error_Reporter) {
    new_scope: Scope_Idents;
    init(*new_scope);

    for decl: ast.decls {
        if #complete decl.kind == {
            case .VAR; resolve_file_scope_var_decl(cast(*Ast.Var_Decl) decl, *new_scope, erp);
            case .FN; resolve_fn_decl(cast(*Ast.Fn_Decl) decl, *new_scope, erp, can_have_body=true);
        }
    }
}

#scope_file

resolve_block :: (block: *Ast.Block, scope: *Scope_Idents, erp: *Error_Reporter) {
    resolve_block_item(*block.items, scope, erp);
}

resolve_block_item :: (block_items: *[..]*Ast.Block_Item, scope: *Scope_Idents, erp: *Error_Reporter) {
    for block_items.* {
        if #complete it.kind == {
            case .DECL; 
                item_decl := cast(*Ast.Block_Item_Decl) it;
                resolve_decl(item_decl.decl, scope, erp);
            case .STMT; 
                item_stmt := cast(*Ast.Block_Item_Stmt) it;
                resolve_stmt(item_stmt.stmt, scope, erp);
        }
    }
}

resolve_stmt :: (stmt: *Ast.Stmt, scope: *Scope_Idents, erp: *Error_Reporter) {
    if #complete stmt.kind == {
        case .SWITCH;
            stmt_switch := cast(*Ast.Stmt_Switch) stmt;
            resolve_expr(stmt_switch.condition, scope, erp);
            nested_scope := create_new_scope(scope);
            resolve_block_item(*stmt_switch.body, *nested_scope, erp);
        case .RETURN;
            stmt_return := cast(*Ast.Stmt_Return) stmt;
            resolve_expr(stmt_return.expr, scope, erp);
        case .EXPR;
            stmt_expr := cast(*Ast.Stmt_Expr) stmt;
            resolve_expr(stmt_expr.expr, scope, erp);
        case .IF;
            stmt_if := cast(*Ast.Stmt_If) stmt;
            resolve_expr(stmt_if.condition, scope, erp);
            resolve_stmt(stmt_if.if_block, scope, erp);
            if stmt_if.else_block != null resolve_stmt(stmt_if.else_block, scope, erp);
        case .COMPOUND;
            stmt_compound := cast(*Ast.Stmt_Compound) stmt;
            nested_scope := create_new_scope(scope);
            resolve_block(stmt_compound.block, *nested_scope, erp);
        case .FOR;
            stmt_for := cast(*Ast.Stmt_For) stmt;
            resolve_for_stmt(stmt_for, scope, erp);
        case .DO_WHILE;
            stmt_do_while := cast(*Ast.Stmt_Do_While) stmt;
            resolve_stmt(stmt_do_while.body, scope, erp);
            resolve_expr(stmt_do_while.condition, scope, erp);
        case .WHILE;
            stmt_while := cast(*Ast.Stmt_While) stmt;
            resolve_expr(stmt_while.condition, scope, erp);
            resolve_stmt(stmt_while.body, scope, erp);
        case .LABEL;
            stmt_label := cast(*Ast.Stmt_Label) stmt;
            resolve_stmt(stmt_label.stmt, scope, erp);
        case .CONTINUE; #through;
        case .BREAK;    #through;
        case .GOTO;     #through;
        case .DEFAULT;  #through;
        case .CASE;     #through;
        case .NULL;     // noop
    }
}

resolve_decl :: (using decl: *Ast.Decl, scope: *Scope_Idents, erp: *Error_Reporter) {
    if #complete decl.kind == {
        case .VAR; resolve_local_var_decl(cast(*Ast.Var_Decl) decl, scope, erp);
        case .FN; resolve_fn_decl(cast(*Ast.Fn_Decl) decl, scope, erp, can_have_body=false);
    }
}

resolve_file_scope_var_decl :: (using decl_var: *Ast.Var_Decl, scope: *Scope_Idents, erp: *Error_Reporter) {
    ident_info := Ident(string).{
        from_current_scope = true,
        external_linkage   = true,
        name               = ident,
        type               = .VAR
    };
    table_set(scope, ident, ident_info);
    if init resolve_expr(init, scope, erp);
}

resolve_local_var_decl :: (using decl_var: *Ast.Var_Decl, scope: *Scope_Idents, erp: *Error_Reporter) {
    found_old_entry, old_entry := table_find(scope, ident);
    if found_old_entry && old_entry.from_current_scope {
        if !(old_entry.external_linkage && storage_class == .EXTERN) {
            error_report(erp, line, start, "conflicting declaration! : %", ident);
        }
        if old_entry.type == .FN && old_entry.external_linkage {
            error_report(erp, line, start, "variable name conflicts with function name: %", ident);
        }
    }

    if storage_class == .EXTERN {
        ident_info := Ident(string).{
            from_current_scope = true,
            external_linkage   = true,
            name               = ident,
            type               = .VAR
        };
        table_set(scope, ident, ident_info);
        if init resolve_expr(init, scope, erp);
        return;
    }

    new_ident  := make_variable(ident);
    ident_info := Ident(string).{
        from_current_scope = true,
        external_linkage   = false,
        name               = new_ident,
        type               = .VAR
    };
    table_set(scope, ident, ident_info);
    if init resolve_expr(init, scope, erp);
    ident = new_ident;
}

resolve_fn_decl :: (using fn_decl: *Ast.Fn_Decl, scope: *Scope_Idents, erp: *Error_Reporter, can_have_body: bool = true) {
    found_old_entry, old_entry := table_find(scope, ident);
    if found_old_entry {
        if old_entry.type == .FN && old_entry.has_body && body != null {
            error_report(erp, line, start, "duplicate function declaration! : %", ident);
        }
        if old_entry.type == .FN {
            // MARK
        }
        if old_entry.type == .VAR && old_entry.from_current_scope {
            error_report(erp, line, start, "function name conflicts with variable name: %", ident);
        }
    }

    ident_info := Ident(string).{
        from_current_scope  = true,
        type                = .FN,
        external_linkage    = true,
        name                = ident,
        has_body            = body != null,
    };
    table_set(scope, ident, ident_info);

    scope_for_fn_param := create_new_scope(scope);

    for * param: params  {
        success, entry := table_find(*scope_for_fn_param, param.*.ident);
        if success && entry.from_current_scope {
            error_report(erp, param.*.line, param.*.start, "duplicate param name found: %", param.*.ident);
        }

        mapped_ident := make_variable(param.*.ident);
        ident := Ident(string).{
            from_current_scope  = true,
            type                = .VAR,
            external_linkage    = false,
            name                = mapped_ident,
        };
        table_set(*scope_for_fn_param, param.*.ident, ident);
        param.*.ident = mapped_ident;
    }

    if !can_have_body && body != null {
        error_report(erp, line, start, "function declaration cannot have body: %", ident);
    }

    if body resolve_block(body, *scope_for_fn_param, erp);
}

unwrap_group_expr :: (expr: *Ast.Expr) -> *Ast.Expr {
    if expr.kind == .GROUP {
        expr_group := cast(*Ast.Expr_Group) expr;
        return unwrap_group_expr(expr_group.expr);
    }
    return expr;
}

resolve_expr :: (expr: *Ast.Expr, scope: *Scope_Idents, erp: *Error_Reporter) {
    if #complete expr.kind == {
        case .CAST; 
            expr_cast := expr.(*Ast.Expr_Cast);
            resolve_expr(expr_cast.expr, scope, erp);
        case .POSTFIX;
            expr_postfix := cast(*Ast.Expr_Postfix) expr;
            inner_expr := unwrap_group_expr(expr_postfix.expr);
            if inner_expr.kind != .VAR {
                error_report(erp, expr.line, expr.start, "expected variable in expr_postfix expression, found: %", inner_expr.*);
            }
            resolve_expr(expr_postfix.expr, scope, erp);
        case .PREFIX;
            expr_prefix := cast(*Ast.Expr_Prefix) expr;
            inner_expr := unwrap_group_expr(expr_prefix.expr);
            if inner_expr.kind != .VAR {
                error_report(erp, expr.line, expr.start, "expected variable in expr_prefix expression, found: %", inner_expr.*);
            }
            resolve_expr(expr_prefix.expr, scope, erp);
        case .UNARY;
            expr_unary := cast(*Ast.Expr_Unary) expr;
            resolve_expr(expr_unary.expr, scope, erp);
        case .BINARY;
            expr_binary := cast(*Ast.Expr_Binary) expr;
            resolve_expr(expr_binary.left, scope, erp);
            resolve_expr(expr_binary.right, scope, erp);
        case .GROUP;
            expr_group := cast(*Ast.Expr_Group) expr;
            resolve_expr(expr_group.expr, scope, erp);
        case .VAR;
            expr_var := cast(*Ast.Expr_Var) expr;
            success, ident := table_find(scope, expr_var.ident);
            if !success error_report(erp, expr.line, expr.start, "undeclared variable: %", expr_var.ident);
            expr_var.ident = ident.name;
        case .FN_CALL;
            expr_fn_call := cast(*Ast.Expr_Fn_Call) expr;
            success, ident := table_find(scope, expr_fn_call.ident);
            if !success error_report(erp, expr.line, expr.start, "undeclared function: %", expr_fn_call.ident);
            if success && ident.from_current_scope {
                expr_fn_call.ident = ident.name;
            }
            for expr_fn_call.args resolve_expr(it, scope, erp);
        case .ASSIGNMENT;
            resolve_assignment_expr(expr, scope, erp);
        case .TERNARY;
            expr_ternary := cast(*Ast.Expr_Ternary) expr;
            resolve_expr(expr_ternary.condition, scope, erp);
            resolve_expr(expr_ternary.true_expr, scope, erp);
            resolve_expr(expr_ternary.false_expr, scope, erp);
        case .CONSTANT; // noop
    }
}

resolve_assignment_expr :: (expr: *Ast.Expr, scope: *Scope_Idents, erp: *Error_Reporter) {
    expr_assignment := cast(*Ast.Expr_Assignment) expr;
    dst_inner_expr := unwrap_group_expr(expr_assignment.dst);
    if dst_inner_expr.kind != .VAR
        error_report(erp, expr.line, expr.start,"expected variable (invalid lvalue) found: %", expr_assignment.dst.*);

    resolve_expr(dst_inner_expr, scope, erp);
    resolve_expr(expr_assignment.src, scope, erp);
}

resolve_for_stmt :: (stmt_for: *Ast.Stmt_For, scope: *Scope_Idents, erp: *Error_Reporter) {
    scope_for_init : Scope_Idents;
    scope_for_init = create_new_scope(scope);

    if #complete stmt_for.init.kind == {
        case .DECL; 
            init_decl := cast(*Ast.For_Init_Decl) stmt_for.init;
            resolve_decl(init_decl.decl, *scope_for_init, erp);
        case .EXPR; 
            init_expr := cast(*Ast.For_Init_Expr) stmt_for.init;
            if init_expr.expr resolve_expr(init_expr.expr, *scope_for_init, erp);
    }

    if stmt_for.condition resolve_expr(stmt_for.condition, *scope_for_init, erp);
    if stmt_for.post resolve_expr(stmt_for.post, *scope_for_init, erp);
    resolve_stmt(stmt_for.body, *scope_for_init, erp);
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
        // @question : Is this enough for copying the scope variable
        value := it;
        value.from_current_scope = false;
        table_set(*new_table, it_index, value);
    }
    return new_table;
}

#scope_module
