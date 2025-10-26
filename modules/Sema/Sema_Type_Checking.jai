sema_typecheck :: (pg: *Ast.Program, st: *Symbol_Table, erp: *Error_Reporter) {
    push_allocator(st.allocator);
    for decl: pg.decls {
        if #complete decl.kind == {
            case .FN; typecheck_fn_decl(cast(*Ast.Fn_Decl) decl, st, erp, file_scope=true);
            case .VAR; typecheck_file_scope_var_decl(cast(*Ast.Var_Decl) decl, st, erp);
        }
    }
}

#scope_file

get_var_init_value :: (using var_decl: *Ast.Var_Decl, erp: *Error_Reporter) -> *Ident_Initial_Value {
    if init == null && storage_class == .EXTERN return Ident_Initial_Value_No_Init.new();
    if init == null && storage_class != .EXTERN return Ident_Initial_Value_Tentative.new();
    if init != null && init.kind == .CONSTANT {
        expr_constant := cast(*Ast.Expr_Constant) init;
        return Ident_Initial_Value_Initial.new(expr_constant.value);
    }

    error_report(erp, line, start, "non constant initializer");
    return Ident_Initial_Value_No_Init.new();
}

typecheck_file_scope_var_decl :: (using var_decl: *Ast.Var_Decl, st: *Symbol_Table, erp: *Error_Reporter) {
    initial_value := get_var_init_value(var_decl, erp);

    global := storage_class != .STATIC;
    found_old_decl, old_decl := table_find(st, ident);
    if found_old_decl {
        if old_decl.attr.kind != .STATIC error_report(erp, line, start, "** compiler bug ** file scope variable should have have static storage attribute");
        if old_decl.kind != .INT error_report(erp, line, start, "this is not type int");

        old_decl_attr := cast(*Ident_Attr_Static) old_decl.attr;

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
            initial_value = Ident_Initial_Value_Tentative.new();
        }
    }
    new_attr :=  Ident_Attr_Static.new(initial_value, global);
    table_set(st, copy_string(var_decl.ident), Symbol_Int.new(var_decl.ident, new_attr));
}

typecheck_local_var_decl :: (using var_decl: *Ast.Var_Decl, st: *Symbol_Table, erp: *Error_Reporter, can_be_static: bool = true) {
    found_old_decl, old_decl := table_find(st, var_decl.ident);

    if #complete storage_class == {
        case .EXTERN;
            if init != null error_report(erp, line, start, "initializer on local extern is not allowed");
            if found_old_decl && old_decl.kind != .INT error_report(erp, line, start, "not a int value");

            if !found_old_decl {
                attr := Ident_Attr_Static.new(Ident_Initial_Value_No_Init.new(), true);
                table_set(st, copy_string(var_decl.ident), Symbol_Int.new(var_decl.ident, attr));
            }
        case .STATIC;
            if !can_be_static error_report(erp, line, start, "static storage class not allowed");
            initial_value : *Ident_Initial_Value = ---;
            if init == null {
                initial_value = Ident_Initial_Value_Initial.new(0);
            } else if init.kind == .CONSTANT {
                expr_constant := cast(*Ast.Expr_Constant) init;
                initial_value = Ident_Initial_Value_Initial.new(expr_constant.value);
            } else {
                error_report(erp, line, start, "non-constant initializer on local static variable");
            }
            attr := Ident_Attr_Static.new(initial_value, false);
            table_set(st, copy_string(var_decl.ident), Symbol_Int.new(var_decl.ident, attr));
        case .NONE;
            table_set(st, copy_string(var_decl.ident), Symbol_Int.new(var_decl.ident, Ident_Attr_Local.new()));
            if var_decl.init typecheck_expr(var_decl.init, st, erp);
    }
}

typecheck_fn_decl :: (using fn_decl: *Ast.Fn_Decl, st: *Symbol_Table, erp: *Error_Reporter, file_scope: bool = false) {
    fn_params: [..]Symbol_Fn.Symbol_Fn_Param;
    for param: params {
        array_add(*fn_params, Symbol_Fn.Symbol_Fn_Param.{ ident = copy_string(param.ident), type  = "int" });
    }

    already_defined := false;
    has_body        := body != null;
    global          := storage_class != .STATIC;

    if !file_scope && storage_class == .STATIC {
        error_report(erp, line, start, "function cannot have static storage class in block scope");
    }

    found_old_decl, old_decl := table_find(st, ident);
    if found_old_decl {
        if #complete old_decl.kind == {
            case .INT; error_report(erp, line, start, "function name conflicts with variable name: %", ident);
            case .FN;
                old_fn_decl := cast(*Symbol_Fn) old_decl;
                old_attr := cast(*Ident_Attr_Fn) old_decl.attr;

                if old_decl.attr.kind != .FN
                    error_report(erp, line, start, "** compiler bug ** symbol we saved for function name is not tagged as .FN!!!");

                already_defined = old_attr.defined;

                if already_defined && has_body {
                    error_report(erp, line, start, "duplicate function declaration! : %", ident);
                }

                if old_attr.global && storage_class == .STATIC {
                    error_report(erp, line, start, "duplicate function declaration! : %", ident);
                }
                // if previous declaration is not global (aka static)
                // and new declaration is global, we keep old linkage i.e. static
                global &= old_attr.global;

                if params.count != old_fn_decl.params.count {
                    error_report(erp, line, start, "function parameter count mismatch for %: expected %, got %",
                        ident, old_fn_decl.params.count, params.count);
                }
        }
    }
    fn_ident_attr := Ident_Attr_Fn.new(defined = has_body || already_defined, global = global);
    fn_symbol     := Symbol_Fn.new(ident, fn_params, "int", fn_ident_attr);

    // If we don't have this symbol on our table add one
    // Or we always update symbol table if current AST we are type checking happens to have a body
    // this is to make sure during ASM_IR phase we have same names for params
    if !found_old_decl || has_body table_set(st, copy_string(ident), fn_symbol);

    if has_body {
        for params table_set(st, copy_string(it.ident), Symbol_Int.new(it.ident, Ident_Attr_Local.new()));
        typecheck_block(body, st, erp);
    }
}

typecheck_block :: (block: *Ast.Block, st: *Symbol_Table, erp: *Error_Reporter) {
    for block.items typecheck_block_item(it, st, erp);
}

typecheck_block_item :: (item: *Ast.Block_Item, st: *Symbol_Table, erp: *Error_Reporter) {
    if #complete item.kind == {
        case .STMT; 
            item_stmt := cast(*Ast.Block_Item_Stmt) item;
            typecheck_stmt(item_stmt.stmt, st, erp);
        case .DECL; 
            item_decl := cast(*Ast.Block_Item_Decl) item;
            typecheck_decl(item_decl.decl, st, erp, file_scope = false);
    }
}

typecheck_decl :: (using decl: *Ast.Decl, st: *Symbol_Table, erp: *Error_Reporter, file_scope: bool, can_be_static: bool = true) {
    if kind == {
        case .FN; typecheck_fn_decl(cast(*Ast.Fn_Decl) decl, st, erp, file_scope);
        case .VAR; typecheck_local_var_decl(cast(*Ast.Var_Decl) decl, st, erp, can_be_static);
    }
}

typecheck_stmt :: (stmt: *Ast.Stmt, st: *Symbol_Table, erp: *Error_Reporter) {
    assert(stmt != null, "stmt should not be null");
    if #complete stmt.kind == {
        case .RETURN;
            stmt_return := cast(*Ast.Stmt_Return) stmt;
            typecheck_expr(stmt_return.expr, st, erp);
        case .EXPR;
            stmt_expr := cast(*Ast.Stmt_Expr) stmt;
            typecheck_expr(stmt_expr.expr, st, erp);
        case .IF;
            stmt_if := cast(*Ast.Stmt_If) stmt;
            typecheck_expr(stmt_if.condition, st, erp);
            typecheck_stmt(stmt_if.if_block, st, erp);
            if stmt_if.else_block != null typecheck_stmt(stmt_if.else_block, st, erp);
        case .LABEL;
            stmt_label := cast(*Ast.Stmt_Label) stmt;
            typecheck_stmt(stmt_label.stmt, st, erp);
        case .COMPOUND;
            stmt_compound := cast(*Ast.Stmt_Compound) stmt;
            typecheck_block(stmt_compound.block, st, erp);
        case .WHILE;
            stmt_while := cast(*Ast.Stmt_While) stmt;
            typecheck_expr(stmt_while.condition, st, erp);
            typecheck_stmt(stmt_while.body, st, erp);
        case .DO_WHILE;
            stmt_do_while := cast(*Ast.Stmt_Do_While) stmt;
            typecheck_stmt(stmt_do_while.body, st, erp);
            typecheck_expr(stmt_do_while.condition, st, erp);
        case .FOR;
            stmt_for := cast(*Ast.Stmt_For) stmt;
            if #complete stmt_for.init.kind == {
                case .DECL; 
                    init_decl := cast(*Ast.For_Init_Decl) stmt_for.init;
                    typecheck_decl(init_decl.decl, st, erp, file_scope = false, can_be_static = false);
                case .EXPR; 
                    init_expr := cast(*Ast.For_Init_Expr) stmt_for.init;
                    if init_expr.expr typecheck_expr(init_expr.expr, st, erp);
            }
            if stmt_for.condition typecheck_expr(stmt_for.condition, st, erp);
            if stmt_for.post typecheck_expr(stmt_for.post, st, erp);
            typecheck_stmt(stmt_for.body, st, erp);
        case .SWITCH;
            stmt_switch := cast(*Ast.Stmt_Switch) stmt;
            if stmt_switch.condition.kind == .VAR {
                expr_var := cast(*Ast.Expr_Var) stmt_switch.condition;
                success, entry := table_find(st, expr_var.ident);
                if success && entry.kind == .FN error_report(erp, stmt.line, stmt.start, "switch condition % must be a variable", expr_var.ident);
            }
            for stmt_switch.body typecheck_block_item(it, st, erp);
        case .CASE;     #through;
        case .DEFAULT;  #through;
        case .CONTINUE; #through;
        case .BREAK;    #through;
        case .NULL;     #through;
        case .GOTO;     // noop
    }
}

typecheck_expr :: (expr: *Ast.Expr, st: *Symbol_Table, erp: *Error_Reporter) {
    if #complete expr.kind == {
        case .POSTFIX;
            expr_postfix := cast(*Ast.Expr_Postfix) expr;
            typecheck_expr(expr_postfix.expr, st, erp);
        case .PREFIX;
            expr_prefix := cast(*Ast.Expr_Prefix) expr;
            typecheck_expr(expr_prefix.expr, st, erp);
        case .UNARY;
            expr_unary := cast(*Ast.Expr_Unary) expr;
            typecheck_expr(expr_unary.expr, st, erp);
        case .BINARY;
            expr_binary := cast(*Ast.Expr_Binary) expr;
            typecheck_expr(expr_binary.left, st, erp);
            typecheck_expr(expr_binary.right, st, erp);
        case .GROUP;
            expr_group := cast(*Ast.Expr_Group) expr;
            typecheck_expr(expr_group.expr, st, erp);
        case .ASSIGNMENT;
            expr_assignment := cast(*Ast.Expr_Assignment) expr;
            typecheck_expr(expr_assignment.src, st, erp);
            typecheck_expr(expr_assignment.dst, st, erp);
        case .TERNARY;
            expr_ternary := cast(*Ast.Expr_Ternary) expr;
            typecheck_expr(expr_ternary.condition, st, erp);
            typecheck_expr(expr_ternary.true_expr, st, erp);
            typecheck_expr(expr_ternary.false_expr, st, erp);
        case .FN_CALL;
            expr_fn_call := cast(*Ast.Expr_Fn_Call) expr;
            success, saved_symbol := table_find(st, expr_fn_call.ident);

            if !success error_report(erp, expr.line, expr.start, "function % not defined", expr_fn_call.ident);
            if saved_symbol.kind != .FN error_report(erp, expr.line, expr.start, "only function can be called", saved_symbol.kind);

            saved_fn_symbol := cast(*Symbol_Fn) saved_symbol;
            if saved_fn_symbol.params.count != expr_fn_call.args.count
                error_report(erp, expr.line, expr.start, "function % expected % arguments, got %", expr_fn_call.ident, saved_fn_symbol.params.count, expr_fn_call.args.count);

            for expr_fn_call.args typecheck_expr(it, st, erp);
        case .VAR;
            expr_var := cast(*Ast.Expr_Var) expr;
            success, saved_symbol := table_find(st, expr_var.ident);
            if success && saved_symbol.kind != .INT {
                error_report(erp, expr.line, expr.start, "function % cannot be used as variable", expr_var.ident);
            }
        case .CONSTANT; // noop
    }
}

#scope_file
using Symbol_Table;
