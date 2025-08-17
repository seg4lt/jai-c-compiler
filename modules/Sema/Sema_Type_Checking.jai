sema_typecheck :: (pg: *Program_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    push_allocator(st.allocator);
    for fn: pg.fns typecheck_fn_decl(fn, st, erp);
}

#scope_file

typecheck_fn_decl :: (fn: *Fn_Decl_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    fn_params: [..]Symbol_Fn_Param;
    for param: fn.params {
        array_add(*fn_params, Symbol_Fn_Param.{ ident = copy_string(param.ident), type  = "int" });
    }
    
    has_body := fn.block != null;
    already_defined := false;
    
    success, prev_entry := table_find_new(st, fn.ident);
    if success {
        if #complete prev_entry.type == {
            case .INT;
                error_report(erp, fn.line, fn.start, "function name conflicts with variable name: %", fn.ident);
            case .FN;
                saved_fn := prev_entry.as.fn;
                already_defined = saved_fn.defined;
                if already_defined && has_body {
                    error_report(erp, fn.line, fn.start, "duplicate function declaration! : %", fn.ident);
                }
                if fn.params.count != saved_fn.params.count {
                    error_report(erp, fn.line, fn.start, "function parameter count mismatch for %: expected %, got %", 
                        fn.ident, prev_entry.as.fn.params.count, fn.params.count);
                }
        }
    }
    
    fn_type := make_symbol_fn(fn.ident, fn_params, "int", has_body || already_defined);
    table_set(st, copy_string(fn.ident), fn_type);
    
    if has_body {
        for fn.params table_set(st, copy_string(it.ident), make_symbol_int(it.ident));
        typecheck_block(fn.block, st, erp);
    }
}

typecheck_block :: (block: *Block_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    for block.items typecheck_block_item(it, st, erp);
}

typecheck_block_item :: (using item: *Block_Item_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    if #complete type == {
        case .STMT; typecheck_stmt(block_item_stmt, st, erp);
        case .DECL; typecheck_decl(block_item_decl, st, erp);
    }
}

typecheck_decl :: (using decl: *Decl_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    if decl.type == {
        case .FN; typecheck_fn_decl(decl_fn, st, erp);
        case .VAR; typecheck_var_decl(decl_var, st, erp);
    }
}

typecheck_var_decl :: (var_decl: *Var_Decl_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    success, entry := table_find_new(st, var_decl.ident);
    if !success {
        table_set(st, copy_string(var_decl.ident), make_symbol_int(var_decl.ident));
    }
    if var_decl.init typecheck_expr(var_decl.init, st, erp);
}

typecheck_stmt :: (using stmt: *Stmt_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    assert(stmt != null, "stmt should not be null");
    if #complete type == {
        case .RETURN;
            typecheck_expr(stmt_return.expr, st, erp);
        case .EXPR;
            typecheck_expr(stmt_expr, st, erp);
        case .IF;
            typecheck_expr(stmt_if.condition, st, erp);
            typecheck_stmt(stmt_if.if_block, st, erp);
            if stmt_if.else_block != null {
            typecheck_stmt(stmt_if.else_block, st, erp);
            }
        case .LABEL;
            typecheck_stmt(stmt_label.stmt, st, erp);
        case .COMPOUND;
            typecheck_block(stmt_compound, st, erp);
        case .WHILE;
            typecheck_expr(stmt_while.condition, st, erp);
            typecheck_stmt(stmt_while.body, st, erp);
        case .DO_WHILE;
            typecheck_stmt(stmt_do_while.body, st, erp);
            typecheck_expr(stmt_do_while.condition, st, erp);
        case .FOR;
            using stmt_for .init;
            if #complete stmt_for .init.type == {
                case .DECL; typecheck_decl(for_init_decl, st, erp);
                case .EXPR; if for_init_expr typecheck_expr(for_init_expr, st, erp);
            }
            if stmt_for .condition typecheck_expr(stmt_for .condition, st, erp);
            if stmt_for .post typecheck_expr(stmt_for .post, st, erp);
            typecheck_stmt(stmt_for.body, st, erp);
        case .SWITCH;
            switch_stmt := stmt_switch;
            if switch_stmt.condition.type == .VAR {
                expr_var := switch_stmt.condition.expr_var;
                success, entry := table_find_new(st, expr_var);
                if success && entry.type == .FN error_report(erp, stmt.line, stmt.start, "switch condition % must be a variable", expr_var);
            }
            for switch_stmt.body typecheck_block_item(it, st, erp);
        case .CASE;     #through;
        case .DEFAULT;  #through;
        case .CONTINUE; #through;
        case .BREAK;    #through;
        case .NULL;     #through;
        case .GOTO;     // noop
    }
}

typecheck_expr :: (using expr: *Expr_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    if #complete type == {
        case .POSTFIX;
            typecheck_expr(expr_postfix.expr, st, erp);
        case .PREFIX;
            typecheck_expr(expr_prefix.expr, st, erp);
        case .UNARY;
            typecheck_expr(expr_unary.expr, st, erp);
        case .BINARY;
            typecheck_expr(expr_binary.left, st, erp);
            typecheck_expr(expr_binary.right, st, erp);
        case .GROUP;
            typecheck_expr(expr_group, st, erp);
        case .ASSIGNMENT;
            typecheck_expr(expr_assignment.src, st, erp);
            typecheck_expr(expr_assignment.dst, st, erp);
        case .TERNARY;
            typecheck_expr(expr_ternary.condition, st, erp);
            typecheck_expr(expr_ternary.true_expr, st, erp);
            typecheck_expr(expr_ternary.false_expr, st, erp);
        case .FN_CALL;
            success, saved_symbol := table_find_new(st, expr_fn_call.ident);
            
            if !success error_report(erp, expr.line, expr.start, "function % not defined", expr_fn_call.ident);
            if saved_symbol.type != .FN error_report(erp, expr.line, expr.start, "only function can be called", saved_symbol.type);
                
            saved_fn_symbol := saved_symbol.as.fn;
            if saved_fn_symbol.params.count != expr_fn_call.args.count
                error_report(erp, expr.line, expr.start, "function % expected % arguments, got %", expr_fn_call.ident, saved_fn_symbol.params.count, expr_fn_call.args.count);
                
            for expr_fn_call.args typecheck_expr(it, st, erp);
        case .VAR;
            success, saved_symbol := table_find_new(st, expr_var);
            if success && saved_symbol.type != .INT {
                error_report(erp, expr.line, expr.start, "function % cannot be used as variable", expr_var);
            }
        case .CONSTANT; // noop
    }
}