sema_ident_resolution :: (ast: *Program_Ast, erp: *Error_Reporter) {
    new_scope: Scope_Idents;
    init(*new_scope);
    
    for fn: ast.fns {
        resolve_fn_decl(fn, *new_scope, erp, can_have_body=true);
    }
}

#scope_file

resolve_block :: (block: *Block_Ast, scope: *Scope_Idents, erp: *Error_Reporter) {
    resolve_block_item(*block.items, scope, erp);
}

resolve_block_item :: (block_items: *[..]*Block_Item_Ast, scope: *Scope_Idents, erp: *Error_Reporter) {
    for block_items.* {
        using it;
        if #complete type == {
            case .DECL; resolve_decl(block_item_decl, scope, erp);
            case .STMT; resolve_stmt(block_item_stmt, scope, erp);
        }
    }
}

resolve_stmt :: (using stmt: *Stmt_Ast, scope: *Scope_Idents, erp: *Error_Reporter) {
    if #complete type == {
        case .SWITCH;
            resolve_expr(stmt_switch.condition, scope, erp);
            nested_scope := create_new_scope(scope);
            resolve_block_item(*stmt_switch.body, *nested_scope, erp);
        case .RETURN;
            resolve_expr(stmt_return.expr, scope, erp);
        case .EXPR;
            resolve_expr(stmt_expr, scope, erp);
        case .IF;
            resolve_expr(stmt_if.condition, scope, erp);
            resolve_stmt(stmt_if.if_block, scope, erp);
            if stmt_if.else_block != null
            resolve_stmt(stmt_if.else_block, scope, erp);
        case .COMPOUND;
            compound := stmt_compound;
            nested_scope := create_new_scope(scope);
            resolve_block(compound, *nested_scope, erp);
        case .FOR; resolve_for_stmt(stmt_for, scope, erp);
        case .DO_WHILE;
            do_while_stmt := stmt_do_while;
            resolve_stmt(do_while_stmt.body, scope, erp);
            resolve_expr(do_while_stmt.condition, scope, erp);
        case .WHILE;
            resolve_expr(stmt_while.condition, scope, erp);
            resolve_stmt(stmt_while.body, scope, erp);
        case .LABEL;
            resolve_stmt(stmt_label.stmt, scope, erp);
        case .CONTINUE; #through;
        case .BREAK;    #through;
        case .GOTO;     #through;
        case .DEFAULT;  #through;
        case .CASE;     #through;
        case .NULL;     // noop
    }
}

resolve_decl :: (using decl: *Decl_Ast, scope: *Scope_Idents, erp: *Error_Reporter) {
    if #complete type == {
        case .VAR;
            success, entry := table_find_new(scope, decl_var.ident);
            if success && entry.from_current_scope {
                if entry.type == .VAR {
                    error_report(erp, decl_var.line, decl_var.start, "duplicate variable declaration! : %", decl_var.ident);
                }
                if entry.type == .FN && entry.external_linkage {
                    error_report(erp, decl_var.line, decl_var.start, "variable name conflicts with function name: %", decl_var.ident);
                }
            }
                
            new_ident := make_variable(decl_var.ident); 
            ident := Ident(string).{ 
                from_current_scope = true,
                external_linkage   = false,
                name               = new_ident,
                type               = .VAR 
            };
            table_set(scope, decl_var.ident, ident);

            if decl_var.init resolve_expr(decl_var.init, scope, erp);
            decl_var.ident = new_ident;
        case .FN; resolve_fn_decl(decl_fn, scope, erp, can_have_body=false);
    }
}

resolve_fn_decl :: (fn_decl: *Fn_Decl_Ast, scope: *Scope_Idents, erp: *Error_Reporter, can_have_body: bool = true) {
    success, entry := table_find_new(scope, fn_decl.ident);
    if success {
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
    
    for * param: fn_decl.params  {
        success, entry := table_find_new(*scope_for_fn_param, param.*.ident);
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
    
    if !can_have_body && fn_decl.block != null {
        error_report(erp, fn_decl.line, fn_decl.start, "function declaration cannot have body: %", fn_decl.ident);
    }
    
    if fn_decl.block resolve_block(fn_decl.block, *scope_for_fn_param, erp);
}

unwrap_group_expr :: (using expr: *Expr_Ast) -> *Expr_Ast {
    if type == .GROUP return unwrap_group_expr(expr_group);
    return expr;
}

resolve_expr :: (using expr: *Expr_Ast, scope: *Scope_Idents, erp: *Error_Reporter) {
    if #complete type == {
        case .POSTFIX;
            inner_expr := unwrap_group_expr(expr_postfix.expr);
            if inner_expr.type != .VAR {
                error_report(erp, expr.loc.line, expr.loc.start, "expected variable in expr_postfix expression, found: %", inner_expr.*);
            }
            resolve_expr(expr_postfix.expr, scope, erp);
        case .PREFIX;
            inner_expr := unwrap_group_expr(expr_prefix.expr);
            if inner_expr.type != .VAR {
                error_report(erp, expr.loc.line, expr.loc.start, "expected variable in expr_prefix expression, found: %", inner_expr.*);
            }
            resolve_expr(expr_prefix.expr, scope, erp);
        case .UNARY;
            resolve_expr(expr_unary.expr, scope, erp);
        case .BINARY;
            resolve_expr(expr_binary.left, scope, erp);
            resolve_expr(expr_binary.right, scope, erp);
        case .GROUP;
            resolve_expr(expr_group, scope, erp);
        case .VAR;
            success, ident := table_find_new(scope, expr_var);
            if !success error_report(erp, expr.loc.line, expr.loc.start, "undeclared variable: %", expr_var);
            expr_var = ident.name;
        case .FN_CALL; 
            success, ident := table_find_new(scope, expr_fn_call.ident);
            
            if !success error_report(erp, expr.line, expr.start, "undeclared function: %", expr_fn_call.ident);
            
            if success && ident.from_current_scope {
                expr_fn_call.ident = ident.name;
                expr.as.expr_fn_call = expr_fn_call;
            }
            for expr_fn_call.args resolve_expr(it, scope, erp);
        case .ASSIGNMENT;
            resolve_assignment_expr(expr, scope, erp);
        case .TERNARY;
            resolve_expr(expr_ternary.condition, scope, erp);
            resolve_expr(expr_ternary.true_expr, scope, erp);
            resolve_expr(expr_ternary.false_expr, scope, erp);
        case .CONSTANT; // noop
    }
}

resolve_assignment_expr :: (using expr: *Expr_Ast, scope: *Scope_Idents, erp: *Error_Reporter) {
    dst_inner_expr := unwrap_group_expr(expr_assignment.dst);
    if dst_inner_expr.type != .VAR 
        error_report(erp, expr.loc.line, expr.loc.start,"expected variable (invalid lvalue) found: %", expr.as.expr_assignment.dst.*);
        
    resolve_expr(dst_inner_expr, scope, erp);
    resolve_expr(expr_assignment.src, scope, erp);
}

For_Stmt_Ast :: type_of(Stmt_Ast.stmt_for);

resolve_for_stmt :: (for_stmt: For_Stmt_Ast, scope: *Scope_Idents, erp: *Error_Reporter) {
    scope_for_init : Scope_Idents;
    scope_for_init = create_new_scope(scope);

    using for_stmt.init;
    if #complete for_stmt.init.type == {
        case .DECL; resolve_decl(for_init_decl, *scope_for_init, erp);
        case .EXPR; if for_init_expr resolve_expr(for_init_expr, *scope_for_init, erp);
    }
    
    if for_stmt.condition resolve_expr(for_stmt.condition, *scope_for_init, erp);
    if for_stmt.post      resolve_expr(for_stmt.post, *scope_for_init, erp);

    {
        scope_for_body : Scope_Idents;
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
        // @question : Is this enough for copying the scope variable
        value := it;
        value.from_current_scope = false;
        table_set(*new_table, it_index, value);
    }
    return new_table;
}

#scope_module
