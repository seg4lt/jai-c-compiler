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

typecheck_block_item :: (item: *Block_Item_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    if #complete item.type == {
        case .STMT;
            typecheck_stmt(item.as.stmt, st, erp);
        case .DECL;
            typecheck_decl(item.as.decl, st, erp);
    }
}

typecheck_decl :: (decl: *Decl_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    if decl.type == {
        case .FN; typecheck_fn_decl(decl.as.fn, st, erp);
        case .VAR; typecheck_var_decl(decl.as.var, st, erp);
    }
}

typecheck_var_decl :: (var_decl: *Var_Decl_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    success, entry := table_find_new(st, var_decl.ident);
    if !success {
        table_set(st, copy_string(var_decl.ident), make_symbol_int(var_decl.ident));
    }
    if var_decl.init typecheck_expr(var_decl.init, st, erp);
}

typecheck_stmt :: (stmt: *Stmt_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    assert(stmt != null, "stmt should not be null");
    if #complete stmt.type == {
        case .RETURN;
            typecheck_expr(stmt.as.return_stmt.expr, st, erp);
        case .EXPR;
            typecheck_expr(stmt.as.expr, st, erp);
        case .IF;
            typecheck_expr(stmt.as.if_stmt.condition, st, erp);
            typecheck_stmt(stmt.as.if_stmt.if_block, st, erp);
            if stmt.as.if_stmt.else_block != null {
                typecheck_stmt(stmt.as.if_stmt.else_block, st, erp);
            }
        case .LABEL;
            typecheck_stmt(stmt.as.label.stmt, st, erp);
        case .COMPOUND;
            typecheck_block(stmt.as.compound, st, erp);
        case .WHILE;
            typecheck_expr(stmt.as.while_stmt.condition, st, erp);
            typecheck_stmt(stmt.as.while_stmt.body, st, erp);
        case .DO_WHILE;
            typecheck_stmt(stmt.as.do_while.body, st, erp);
            typecheck_expr(stmt.as.do_while.condition, st, erp);
        case .FOR;
            for_stmt := stmt.as.for_stmt;
            if #complete for_stmt.init.type == {
                case .INIT_DECL; typecheck_decl(for_stmt.init.as.decl, st, erp);
                case .INIT_EXPR; if for_stmt.init.as.expr typecheck_expr(for_stmt.init.as.expr, st, erp);
            }
            if for_stmt.condition typecheck_expr(for_stmt.condition, st, erp);
            if for_stmt.post typecheck_expr(for_stmt.post, st, erp);
            typecheck_stmt(stmt.as.for_stmt.body, st, erp);
        case .SWITCH;
            switch_stmt := stmt.as.switch;
            if switch_stmt.condition.type == .VAR {
                var_stmt := switch_stmt.condition.as.var;
                success, entry := table_find_new(st, var_stmt);
                if success && entry.type == .FN {
                    error_report(erp, stmt.line, stmt.start, "switch condition % must be a variable", var_stmt);
                }
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

typecheck_expr :: (expr: *Expr_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    if expr.type == {
        case .UNARY;
            typecheck_expr(expr.as.unary.expr, st, erp);
        case .BINARY;
            binary := expr.as.binary;
            typecheck_expr(binary.left, st, erp);
            typecheck_expr(binary.right, st, erp);
        case .GROUP;
            typecheck_expr(expr.as.group, st, erp);
        case .ASSIGNMENT;
            assignment := expr.as.assignment;
            typecheck_expr(assignment.src, st, erp);
            typecheck_expr(assignment.dst, st, erp);
        case .TERNARY;
            ternary := expr.as.ternary;
            typecheck_expr(ternary.condition, st, erp);
            typecheck_expr(ternary.true_expr, st, erp);
            typecheck_expr(ternary.false_expr, st, erp);
        case .FN_CALL;
            fn_call := expr.as.fn_call;
            success, saved_symbol := table_find_new(st, fn_call.ident);
            
            if !success error_report(erp, expr.line, expr.start, "function % not defined", fn_call.ident);
            if saved_symbol.type != .FN error_report(erp, expr.line, expr.start, "only function can be called", saved_symbol.type);
                
            saved_fn_symbol := saved_symbol.as.fn;
            if saved_fn_symbol.params.count != fn_call.args.count
                error_report(erp, expr.line, expr.start, "function % expected % arguments, got %", fn_call.ident, saved_fn_symbol.params.count, fn_call.args.count);
                
            for fn_call.args typecheck_expr(it, st, erp);
        case .VAR;
            var := expr.as.var; 
            success, saved_symbol := table_find_new(st, var);
            if success && saved_symbol.type != .INT {
                error_report(erp, expr.line, expr.start, "function % cannot be used as variable", var);
            }
        case .CONSTANT; // noop
    }
}