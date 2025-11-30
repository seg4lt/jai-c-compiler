sema_typecheck :: (pg: *Ast.Program, st: *Symbol_Table, erp: *Error_Reporter) {
    push_allocator(st.allocator);
    ctx := Typecheck_Ctx.{ st, erp, null };
    for decl: pg.decls {
        if #complete decl.kind == {
            case .FN; 
                typecheck_fn_decl(cast(*Ast.Fn_Decl) decl, *ctx, file_scope=true);
            case .VAR; 
                typecheck_file_scope_var_decl(cast(*Ast.Var_Decl) decl, *ctx);
        }
    }
}

#scope_file

Typecheck_Ctx :: struct {
    st: *Symbol_Table;
    erp: *Error_Reporter;
    return_type: *Ast.Builtin_Type;
}

clone_ctx :: (ctx: *Typecheck_Ctx, override_st: *Symbol_Table = null, override_erp: *Error_Reporter = null, override_return_type: *Ast.Builtin_Type = null) -> Typecheck_Ctx {
    return Typecheck_Ctx.{
        st = ifx override_st override_st else ctx.st,
        erp = ifx override_erp override_erp else ctx.erp,
        return_type = ifx override_return_type override_return_type else ctx.return_type,
    };
}

get_var_init_value :: (using var_decl: *Ast.Var_Decl, using ctx: *Typecheck_Ctx) -> Initial_Value {
    if init == null && storage_class == .EXTERN return no_initializer();
    if init == null && storage_class != .EXTERN return tentative();
    if init != null && init.kind == .CONSTANT {
        expr_constant := cast(*Ast.Expr_Constant) init;

        static_init : Static_Init = ---;
        if #complete expr_constant.value.kind == {
            case .INT; 
                static_init = static_init_int(expr_constant.value.(*Ast.Constant_Int).value);
            case .LONG;
                static_init = static_init_long(expr_constant.value.(*Ast.Constant_Long).value);
        }
        return initial(static_init);
    }

    error_report(erp, line, start, "non constant initializer");
    return no_initializer();
}

typecheck_file_scope_var_decl :: (using var_decl: *Ast.Var_Decl, using ctx: *Typecheck_Ctx) {
    initial_value := get_var_init_value(var_decl, ctx);
    if var_decl.init set_builtin_type(var_decl.init, get_owned_type(var_decl.type));

    global := storage_class != .STATIC;

    symbol_exists, existing_symbol := table_find(st, ident);

    if symbol_exists {
        if existing_symbol.kind != .VAR
            error_report(erp, line, start, "this is not type variable");
        
        existing_var := cast(*Symbol_Var) existing_symbol;
        if existing_var.attr.kind != .STATIC
            error_report(erp, line, start, "file scope variable should have static storage attribute");

        if storage_class == .EXTERN {
            global = existing_var.attr.global;
        } else if existing_var.attr.global != global {
            error_report(erp, line, start, "conflicting varaible linkage");
        }

        if existing_var.attr.initial_value.kind == .INITIAL {
            if initial_value.kind == .INITIAL {
                error_report(erp, line, start, "conflicting file scope variable defn");
            } else {
                initial_value = existing_var.attr.initial_value;
            }
        } else if initial_value.kind != .INITIAL && existing_var.attr.initial_value.kind == .TENTATIVE {
            initial_value = tentative();
        }

        if var_decl.type.kind != existing_var.type.kind 
            error_report(erp, line, start, "conflicting variable types");
    }

    new_attr := static_var(initial_value, global);
    owned_type : *Ast.Builtin_Type = get_owned_type(var_decl.type);
    table_set(st, copy_string(var_decl.ident), Symbol_Var.new(var_decl.ident, owned_type, new_attr));
}

get_owned_type :: (type: *Ast.Builtin_Type) -> *Ast.Builtin_Type {
    if #complete type.kind == {
        case .INT; return Ast.Builtin_Type_Int.new();
        case .LONG; return Ast.Builtin_Type_Long.new();
        case .FN;
            fn_type := type.(*Ast.Builtin_Type_Fn);
            owned_params: [..]*Ast.Builtin_Type;
            for param: fn_type.params {
                array_add(*owned_params, get_owned_type(param));
            }
            return Ast.Builtin_Type_Fn.new(owned_params, get_owned_type(fn_type.return_type));
    }
}

typecheck_local_var_decl :: (using var_decl: *Ast.Var_Decl, using ctx: *Typecheck_Ctx, can_be_static: bool = true) {
    symbol_exists, existing_symbol := table_find(st, var_decl.ident);
    if init set_builtin_type(init, get_owned_type(var_decl.type));
    if symbol_exists {
        if existing_symbol.kind != .VAR
            error_report(erp, line, start, "this is not type variable");
        
        existing_var := existing_symbol.(*Symbol_Var);

        if existing_var.type.kind != var_decl.type.kind
            error_report(erp, line, start, "conflicting variable types");
    
        var_symbol := existing_symbol.(*Symbol_Var);

        if var_symbol.type.kind != var_decl.type.kind
            error_report(erp, line, start, "conflicting variable types");
    }


    if #complete storage_class == {
        case .EXTERN;
            if init != null error_report(erp, line, start, "initializer on local extern is not allowed");
            if !symbol_exists {
                attr := static_var(no_initializer(), true);
                table_set(st, copy_string(var_decl.ident), Symbol_Var.new(var_decl.ident, get_owned_type(var_decl.type), attr));
            }
        case .STATIC;
            if !can_be_static 
                error_report(erp, line, start, "static storage class not allowed");

            initial_value : Initial_Value = ---;
            if init == null {
                if #complete var_decl.type.kind == {
                    case .INT; initial_value = initial(static_init_int(0));
                    case .LONG; initial_value = initial(static_init_long(0));
                    case .FN; unreachable("** compiler bug ** this is var decl ast");
                }
            } else if init.kind == .CONSTANT {
                expr_constant := cast(*Ast.Expr_Constant) init;
                static_init : Static_Init = ---;
                if #complete expr_constant.value.kind == {
                    case .INT;
                        static_init = static_init_int(expr_constant.value.(*Ast.Constant_Int).value);
                    case .LONG;
                        static_init = static_init_long(expr_constant.value.(*Ast.Constant_Long).value);
                }
                initial_value = initial(static_init);
            } else {
                error_report(erp, line, start, "non-constant initializer on local static variable");
            }
            attr := static_var(initial_value, false);
            table_set(st, copy_string(var_decl.ident), Symbol_Var.new(var_decl.ident, get_owned_type(var_decl.type), attr));
        case .NONE;
            table_set(st, copy_string(var_decl.ident), Symbol_Var.new(var_decl.ident, get_owned_type(var_decl.type), local_var()));
            if var_decl.init typecheck_expr(var_decl.init, ctx);
    }
}


typecheck_fn_decl :: (using fn_decl: *Ast.Fn_Decl, using ctx: *Typecheck_Ctx, file_scope: bool = false) {
    fn_params: [..]string;
    for param: params array_add(*fn_params, copy_string(param.ident));

    already_defined := false;
    has_body        := body != null;
    global          := storage_class != .STATIC;

    if !file_scope && storage_class == .STATIC {
        error_report(erp, line, start, "function cannot have static storage class in block scope");
    }

    symbol_exists, existing_symbol := table_find(st, ident);

    if symbol_exists {
        if existing_symbol.kind != .FN
            error_report(erp, line, start, "function name conflicts with variable name: %", ident);

        existing_fn_fn_type := existing_symbol.(*Symbol_Fn).type.(*Ast.Builtin_Type_Fn);

        // is fn_type same
        assert(fn_decl.type.kind == .FN, "** compiler bug ** this is fn decl ast");
        fn_type := fn_decl.type.(*Ast.Builtin_Type_Fn);

        if !is_builtin_type_same(fn_type.return_type, existing_fn_fn_type.return_type)
            error_report(erp, line, start, "conflicting function return types");
        
        if params.count != existing_fn_fn_type.params.count {
            error_report(erp, line, start, "function parameter count mismatch for %: expected %, got %",
                ident, existing_fn_fn_type.params.count, params.count);
        }
        for param: fn_type.params {
            if !is_builtin_type_same(param, existing_fn_fn_type.params[it_index])
                error_report(erp, line, start, "conflicting function parameter types");
        }
        // end of is fn_type same


        existing_fn := cast(*Symbol_Fn) existing_symbol;
        already_defined = existing_fn.defined;

        if already_defined && has_body 
            error_report(erp, line, start, "duplicate function declaration! : %", ident);

        if existing_fn.global && storage_class == .STATIC {
            error_report(erp, line, start, "duplicate function declaration! : %", ident);
        }
        global &= existing_fn.global;

        if params.count != existing_fn.params.count {
            error_report(erp, line, start, "function parameter count mismatch for %: expected %, got %",
                ident, existing_fn.params.count, params.count);
        }
    }
    fn_symbol := Symbol_Fn.new(ident, get_owned_type(fn_decl.type).(*Ast.Builtin_Type_Fn), fn_params, defined = has_body || already_defined, global = global);

    if !symbol_exists || has_body table_set(st, copy_string(ident,, st.allocator), fn_symbol);

    if has_body {
        fn_return_type := fn_decl.type.(*Ast.Builtin_Type_Fn).return_type;
        for params {
            param_type := type.(*Ast.Builtin_Type_Fn).params[it_index];
            table_set(st, copy_string(it.ident), Symbol_Var.new(it.ident, get_owned_type(param_type), local_var()));
        }
        typecheck_block(body, *(clone_ctx(ctx, override_return_type = fn_return_type)));
    }
}

typecheck_block :: (block: *Ast.Block, using ctx: *Typecheck_Ctx) {
    for block.items typecheck_block_item(it, ctx);
}

typecheck_block_item :: (item: *Ast.Block_Item, using ctx: *Typecheck_Ctx) {
    if #complete item.kind == {
        case .STMT; 
            item_stmt := cast(*Ast.Block_Item_Stmt) item;
            typecheck_stmt(item_stmt.stmt, ctx);
        case .DECL; 
            item_decl := cast(*Ast.Block_Item_Decl) item;
            typecheck_decl(item_decl.decl, ctx, file_scope = false);
    }
}

typecheck_decl :: (using decl: *Ast.Decl, using ctx: *Typecheck_Ctx, file_scope: bool, can_be_static: bool = true) {
    if kind == {
        case .FN; typecheck_fn_decl(cast(*Ast.Fn_Decl) decl, ctx, file_scope);
        case .VAR; typecheck_local_var_decl(cast(*Ast.Var_Decl) decl, ctx, can_be_static);
    }
}

typecheck_stmt :: (stmt: *Ast.Stmt, using ctx: *Typecheck_Ctx) {
    assert(stmt != null, "stmt should not be null");
    if #complete stmt.kind == {
        case .RETURN;
            stmt_return := cast(*Ast.Stmt_Return) stmt;
            typecheck_expr(stmt_return.expr, ctx);
            maybe_explicit_cast(stmt_return.expr, ctx.return_type);
            set_builtin_type(stmt_return.expr, ctx.return_type);
        case .EXPR;
            stmt_expr := cast(*Ast.Stmt_Expr) stmt;
            typecheck_expr(stmt_expr.expr, ctx);
        case .IF;
            stmt_if := cast(*Ast.Stmt_If) stmt;
            typecheck_expr(stmt_if.condition, ctx);
            typecheck_stmt(stmt_if.if_block, ctx);
            if stmt_if.else_block != null typecheck_stmt(stmt_if.else_block, ctx);
        case .LABEL;
            stmt_label := cast(*Ast.Stmt_Label) stmt;
            typecheck_stmt(stmt_label.stmt, ctx);
        case .COMPOUND;
            stmt_compound := cast(*Ast.Stmt_Compound) stmt;
            typecheck_block(stmt_compound.block, ctx);
        case .WHILE;
            stmt_while := cast(*Ast.Stmt_While) stmt;
            typecheck_expr(stmt_while.condition, ctx);
            typecheck_stmt(stmt_while.body, ctx);
        case .DO_WHILE;
            stmt_do_while := cast(*Ast.Stmt_Do_While) stmt;
            typecheck_stmt(stmt_do_while.body, ctx);
            typecheck_expr(stmt_do_while.condition, ctx);
        case .FOR;
            stmt_for := cast(*Ast.Stmt_For) stmt;
            if #complete stmt_for.init.kind == {
                case .DECL; 
                    init_decl := cast(*Ast.For_Init_Decl) stmt_for.init;
                    typecheck_decl(init_decl.decl, ctx, file_scope = false, can_be_static = false);
                case .EXPR; 
                    init_expr := cast(*Ast.For_Init_Expr) stmt_for.init;
                    if init_expr.expr typecheck_expr(init_expr.expr, ctx);
            }
            if stmt_for.condition typecheck_expr(stmt_for.condition, ctx);
            if stmt_for.post typecheck_expr(stmt_for.post, ctx);
            typecheck_stmt(stmt_for.body, ctx);
        case .SWITCH;
            stmt_switch := cast(*Ast.Stmt_Switch) stmt;
            if stmt_switch.condition.kind == .VAR {
                expr_var := cast(*Ast.Expr_Var) stmt_switch.condition;
                success, entry := table_find(st, expr_var.ident);
                if success && entry.kind == .FN error_report(erp, stmt.line, stmt.start, "switch condition % must be a variable", expr_var.ident);
            }
            for stmt_switch.body typecheck_block_item(it, ctx);
        case .CASE;     #through;
        case .DEFAULT;  #through;
        case .CONTINUE; #through;
        case .BREAK;    #through;
        case .NULL;     #through;
        case .GOTO;     // noop
    }
}

typecheck_expr :: (expr: *Ast.Expr, using ctx: *Typecheck_Ctx) {
    if #complete expr.kind == {
        case .CAST; 
            expr_cast := expr.(*Ast.Expr_Cast);
            typecheck_expr(expr_cast.expr, ctx);
            set_builtin_type(expr, expr_cast.target_type);
        case .POSTFIX;
            expr_postfix := cast(*Ast.Expr_Postfix) expr;
            typecheck_expr(expr_postfix.expr, ctx);
            set_builtin_type(expr, expr_postfix.expr.type);
        case .PREFIX;
            expr_prefix := cast(*Ast.Expr_Prefix) expr;
            typecheck_expr(expr_prefix.expr, ctx);
            set_builtin_type(expr, expr_prefix.expr.type);
        case .UNARY;
            expr_unary := cast(*Ast.Expr_Unary) expr;
            typecheck_expr(expr_unary.expr, ctx);
            if #complete expr_unary.op == {
                case .NEGATE;      set_builtin_type(expr, Ast.Builtin_Type_Int.new());
                case .BITWISE_NOT; #through;
                case .NOT;         set_builtin_type(expr, expr_unary.expr.type);
            }
        case .BINARY;
            expr_binary := cast(*Ast.Expr_Binary) expr;
            typecheck_expr(expr_binary.left, ctx);
            typecheck_expr(expr_binary.right, ctx);

            if expr_binary.op == .AND || expr_binary.op == .OR {
                set_builtin_type(expr, Ast.Builtin_Type_Int.new());
                return;
            }
            is_same, common_type := get_common_type(expr_binary.left.type, expr_binary.right.type);
            left_expr := maybe_explicit_cast(expr_binary.left, common_type);
            right_expr := maybe_explicit_cast(expr_binary.right, common_type);
            // we might have added a explicit cast so reassing is best bet
            expr_binary.left = left_expr;
            expr_binary.right = right_expr;

            if #complete expr_binary.op == {
                case .ADD; #through;
                case .SUB; #through;
                case .MUL; #through;
                case .DIV; #through;
                case .MOD;
                    set_builtin_type(expr, common_type);
                    return;

                case .AND; #through;
                case .BITWISE_AND; #through;
                case .BITWISE_OR; #through;
                case .BITWISE_XOR; #through;
                case .EQUAL_EQUAL; #through;
                case .GREATER; #through;
                case .GREATER_EQUAL; #through;
                case .LEFT_SHIFT; #through;
                case .LESS; #through;
                case .LESS_EQUAL; #through;
                case .NOT_EQUAL; #through;
                case .OR; #through;
                case .RIGHT_SHIFT;
                    set_builtin_type(expr, Ast.Builtin_Type_Int.new());
                    return;
            }
        case .GROUP;
            expr_group := cast(*Ast.Expr_Group) expr;
            typecheck_expr(expr_group.expr, ctx);
            set_builtin_type(expr, expr_group.expr.type);
        case .ASSIGNMENT;
            expr_assignment := cast(*Ast.Expr_Assignment) expr;
            typecheck_expr(expr_assignment.src, ctx);
            typecheck_expr(expr_assignment.dst, ctx);

            src := maybe_explicit_cast(expr_assignment.src, expr_assignment.dst.type);
            expr_assignment.src = src;
            set_builtin_type(expr, expr_assignment.dst.type);

        case .TERNARY;
            expr_ternary := cast(*Ast.Expr_Ternary) expr;
            typecheck_expr(expr_ternary.condition, ctx);
            typecheck_expr(expr_ternary.true_expr, ctx);
            typecheck_expr(expr_ternary.false_expr, ctx);

            _, common_type := get_common_type(expr_ternary.true_expr.type, expr_ternary.false_expr.type);

            true_expr := maybe_explicit_cast(expr_ternary.true_expr, common_type);
            false_expr := maybe_explicit_cast(expr_ternary.false_expr, common_type);

            expr_ternary.true_expr = true_expr;
            expr_ternary.false_expr = false_expr;
            set_builtin_type(expr, common_type);

        case .FN_CALL;
            expr_fn_call := cast(*Ast.Expr_Fn_Call) expr;
            success, saved_symbol := table_find(st, expr_fn_call.ident);

            if !success 
                error_report(erp, expr.line, expr.start, "function % not defined", expr_fn_call.ident);
            if saved_symbol.kind != .FN
                error_report(erp, expr.line, expr.start, "only function can be called", saved_symbol.kind);

            saved_fn_symbol := cast(*Symbol_Fn) saved_symbol;
            if saved_fn_symbol.params.count != expr_fn_call.args.count
                error_report(erp, expr.line, expr.start, "function % expected % arguments, got %", expr_fn_call.ident, saved_fn_symbol.params.count, expr_fn_call.args.count);

            converted_args: [..]*Ast.Expr;
            for expr_fn_call.args {
                typecheck_expr(it, ctx);
                _, common_type := get_common_type(it.type, saved_fn_symbol.type.params[it_index]);
                array_add(*converted_args, maybe_explicit_cast(it, common_type));
            }
            expr_fn_call.args = converted_args;
            set_builtin_type(expr, saved_fn_symbol.type.return_type);
        case .VAR;
            expr_var := cast(*Ast.Expr_Var) expr;
            success, saved_symbol := table_find(st, expr_var.ident);
            if success && saved_symbol.kind != .VAR {
                error_report(erp, expr.line, expr.start, "function % cannot be used as variable", expr_var.ident);
            }
            set_builtin_type(expr, saved_symbol.(*Symbol_Var).type);
        case .CONSTANT;
            expr_constant := expr.(*Ast.Expr_Constant);
            if #complete expr_constant.value.kind == {
                case .INT;
                    set_builtin_type(expr, Ast.Builtin_Type_Int.new());
                case .LONG;
                    set_builtin_type(expr, Ast.Builtin_Type_Long.new());
            }
    }
}

maybe_explicit_cast :: (expr: *Ast.Expr, target_type: *Ast.Builtin_Type) -> *Ast.Expr {
    if is_builtin_type_same(expr.type, target_type) return expr;
    cast_expr := Ast.Expr_Cast.new(target_type, expr, expr.line, expr.start);
    set_builtin_type(cast_expr, target_type);
    return cast_expr;
}

get_common_type :: (type1: *Ast.Builtin_Type, type2: *Ast.Builtin_Type) -> is_same: bool,  *Ast.Builtin_Type {
    if is_builtin_type_same(type1, type2) return true, type1;
    return false, Ast.Builtin_Type_Long.new();
}

is_builtin_type_same :: (type1: *Ast.Builtin_Type, type2: *Ast.Builtin_Type) -> bool {
    if #complete type1.kind == {
        case .INT; return type2.kind == .INT;
        case .LONG; return type2.kind == .LONG;
        case .FN; 
            if type2.kind != .FN return false;

            type1_fn_type := type1.(*Ast.Builtin_Type_Fn);
            type2_fn_type := type2.(*Ast.Builtin_Type_Fn);

            if !is_builtin_type_same(type1_fn_type.return_type, type2_fn_type.return_type) return false;
            if type1_fn_type.params.count != type2_fn_type.params.count return false;
            for param: type1_fn_type.params {
                if !is_builtin_type_same(param, type2_fn_type.params[it_index]) return false;
            }
            return true;
    }
    return false;
}

#scope_file
using Symbol_Table;
