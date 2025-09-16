sema_typecheck :: (pg: *Program_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    push_allocator(st.allocator);
    for *decl: pg.decls {
        using decl.*;
        if #complete type == {
            case .FN; typecheck_fn_decl(decl_fn, st, erp, file_scope=true);
            case .VAR; typecheck_file_scope_var_decl(decl_var, st, erp);
        }
    }
}

#scope_file

get_var_init_value :: (using var_decl: *Var_Decl_Ast, erp: *Error_Reporter) -> Ident_Initial_Value {
    if init == null && storage_class == .EXTERN return ident_initial_value_no_init();
    if init == null && storage_class != .EXTERN return ident_initial_value_tentative();
    if init != null && init.type == .CONSTANT   return ident_initial_value_initial(init.expr_constant);
    
    error_report(erp, line, start, "non constant initializer");
    return ident_initial_value_no_init();
}

typecheck_file_scope_var_decl :: (using var_decl: *Var_Decl_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    initial_value := get_var_init_value(var_decl, erp); 
    
    global := storage_class != .STATIC;
    found_old_decl, old_decl := table_find_new(st, ident);
    if found_old_decl {
        if old_decl.attr.kind != .STATIC error_report(erp, line, start, "** compiler bug ** file scope variable should have have static storage attribute");
        if old_decl.type != .INT error_report(erp, line, start, "this is not type int");
        
        old_decl_attr := old_decl.attr.static;
        
        if storage_class == .EXTERN {
            // if we see extern later, we use previous linkage state
            global = old_decl_attr.global; 
        } else if old_decl_attr.global != global {
            error_report(erp, line, start, "conflicting varaible linkage");
        }
        
        if old_decl_attr.initial_value.kind == .INITIAL {
            if initial_value.kind == .INITIAL {
                // Variable on file scope cannot be initialized twice
                error_report(erp, line, start, "conflicting file scope variable defn");
            } else {
                initial_value = old_decl_attr.initial_value;
            }
        } else if initial_value.kind != .INITIAL && old_decl_attr.initial_value.kind == .TENTATIVE {
            initial_value = ident_initial_value_tentative();
        } 
    }
    new_attr :=  ident_attr_static(initial_value, global);
    table_set(st, copy_string(var_decl.ident), make_symbol_int(var_decl.ident, new_attr));
}

typecheck_local_var_decl :: (using var_decl: *Var_Decl_Ast, st: *Symbol_Table, erp: *Error_Reporter, can_be_static: bool = true) {
    found_old_decl, old_decl := table_find_new(st, var_decl.ident);
    
    if #complete storage_class == {
        case .EXTERN;
            if init != null error_report(erp, line, start, "initializer on local extern is not allowed");
            if found_old_decl && old_decl.type != .INT error_report(erp, line, start, "not a int value");
            
            if !found_old_decl {
                attr := ident_attr_static(ident_initial_value_no_init(), true);
                table_set(st, copy_string(var_decl.ident), make_symbol_int(var_decl.ident, attr));
            }
        case .STATIC;
            if !can_be_static error_report(erp, line, start, "static storage class not allowed");
            initial_value : Ident_Initial_Value = ---;
            if init == null {
                initial_value = ident_initial_value_initial(0);
            } else if init.type == .CONSTANT {
                initial_value = ident_initial_value_initial(init.expr_constant);
            } else {
                error_report(erp, line, start, "non-constant initializer on local static variable");
            }
            attr := ident_attr_static(initial_value, false);
            table_set(st, copy_string(var_decl.ident), make_symbol_int(var_decl.ident, attr));
        case .NONE;
            table_set(st, copy_string(var_decl.ident), make_symbol_int(var_decl.ident, ident_attr_local()));
            if var_decl.init typecheck_expr(var_decl.init, st, erp);
    }
}

typecheck_fn_decl :: (fn: *Fn_Decl_Ast, st: *Symbol_Table, erp: *Error_Reporter, file_scope: bool) {
    fn_params: [..]Symbol_Fn_Param;
    for param: fn.params {
        array_add(*fn_params, Symbol_Fn_Param.{ ident = copy_string(param.ident), type  = "int" });
    }
    
    already_defined := false;
    has_body        := fn.block != null;
    global          := fn.storage_class != .STATIC;
    
    if !file_scope && fn.storage_class == .STATIC {
        error_report(erp, fn.line, fn.start, "function cannot have static storage class in block scope");
    }
    
    found_old_decl, old_decl := table_find_new(st, fn.ident);
    if found_old_decl {
        if #complete old_decl.type == {
            case .INT; error_report(erp, fn.line, fn.start, "function name conflicts with variable name: %", fn.ident);
            case .FN;
                old_fn_decl := old_decl.fn;
                old_attr := old_decl.attr;
                
                if old_attr.kind != .FN
                    error_report(erp, fn.line, fn.start, "** compiler bug ** symbol we saved for function name is not tagged as .FN!!!");
                
                already_defined = old_attr.fn.defined;
                
                if already_defined && has_body {
                    error_report(erp, fn.line, fn.start, "duplicate function declaration! : %", fn.ident);
                }
                
                if old_attr.fn.global && fn.storage_class == .STATIC {
                    error_report(erp, fn.line, fn.start, "duplicate function declaration! : %", fn.ident);
                }
                // if previous declaration is not global (aka static)
                // and new declaration is global, we keep old linkage i.e. static
                global &= old_attr.fn.global;
                
                if fn.params.count != old_fn_decl.params.count {
                    error_report(erp, fn.line, fn.start, "function parameter count mismatch for %: expected %, got %", 
                        fn.ident, old_decl.fn.params.count, fn.params.count);
                }
        }
    }
    fn_ident_attr := ident_attr_fn(defined = has_body || already_defined, global = global);
    fn_symbol     := make_symbol_fn(fn.ident, fn_params, "int", fn_ident_attr);
    
    // If we don't have this symbol on our table add one
    // Or we always update symbol table if current AST we are type checking happens to have a body
    // this is to make sure during ASM_IR phase we have same names for params
    if !found_old_decl || has_body table_set(st, copy_string(fn.ident), fn_symbol);
    
    if has_body {
        for fn.params table_set(st, copy_string(it.ident), make_symbol_int(it.ident, ident_attr_local()));
        typecheck_block(fn.block, st, erp);
    }
}

typecheck_block :: (block: *Block_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    for block.items typecheck_block_item(it, st, erp);
}

typecheck_block_item :: (using item: *Block_Item_Ast, st: *Symbol_Table, erp: *Error_Reporter) {
    if #complete type == {
        case .STMT; typecheck_stmt(block_item_stmt, st, erp);
        case .DECL; typecheck_decl(block_item_decl, st, erp, file_scope = false);
    }
}

typecheck_decl :: (using decl: *Decl_Ast, st: *Symbol_Table, erp: *Error_Reporter, file_scope: bool, can_be_static: bool = true) {
    if type == {
        case .FN; typecheck_fn_decl(decl_fn, st, erp, file_scope);
        case .VAR; typecheck_local_var_decl(decl_var, st, erp, can_be_static);
    }
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
            if stmt_if.else_block != null typecheck_stmt(stmt_if.else_block, st, erp);
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
                case .DECL; typecheck_decl(for_init_decl, st, erp, file_scope = false, can_be_static = false);
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