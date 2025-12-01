gen_tacky :: (pg: *Ast.Program, st: *Symbol_Table, debug_log: bool = false) -> *Program {
    tc : Tacky_Ctx;
    tc.st = st;

    top_level_tac: [..]*Top_Level;
    for decl: pg.decls {
        if #complete decl.kind == {
            case .FN;
                fn_decl := cast(*Ast.Fn_Decl) decl;
                if fn_decl.body {
                    fn := gen_fn_tacky(*tc, fn_decl);
                    array_add(*top_level_tac, fn);
                }
            case .VAR; // noop - handled differently
        }
    }

    for value, key: st {
        if #complete value.kind == {
            case .VAR;
                var_symbol := cast(*Symbol_Var) value;
                if #complete var_symbol.attr.kind == {
                    case .STATIC;
                        if #complete var_symbol.attr.initial_value.kind == {
                            case .INITIAL;
                                static_var := Top_Level_Static_Var.new(clone(var_symbol.type), key, var_symbol.attr.global, var_symbol.attr.initial_value.value);
                                array_add(*top_level_tac, static_var);
                                // array_add(*top_level_tac, Top_Level_Static_Var.new(key, var_symbol.attr.global, var_symbol.attr.initial_value.value));
                            case .TENTATIVE;
                                init_value : Static_Init = ---;
                                if #complete var_symbol.type.kind == {
                                    case .INT; init_value = static_init_int(0);
                                    case .LONG; init_value = static_init_long(0);
                                    case .FN; unreachable("** compiler bug ** this is static var ast");
                                }
                                static_var := Top_Level_Static_Var.new(clone(var_symbol.type), key, var_symbol.attr.global, init_value);
                                array_add(*top_level_tac, static_var);
                                // array_add(*top_level_tac, Top_Level_Static_Var.new(key, var_symbol.attr.global, 0));
                            case .NO_INITIALIZER;
                        }
                    case .LOCAL;
                }
            case .FN; // noop
        }
    }

    program := Program.new(top_level_tac);

    if debug_log print_tacky(program, *stdout_writer_new());
    return program;
}

#scope_file

gen_fn_tacky :: (ctx: *Tacky_Ctx, fn_ast: *Ast.Fn_Decl) -> *Top_Level_Fn {
    instructions: [..]*Instruction;
    if fn_ast.body  {
        gen_instructions(ctx, *instructions, fn_ast.body);
        array_add(*instructions, ret(constant(Ast.Constant_Int.new(0))));
    }
    found_symbol, symbol := table_find(ctx.st, fn_ast.ident);
    assert(found_symbol);
    assert(symbol.kind == .FN);
    fn_symbol := cast(*Symbol_Fn) symbol;
    return Top_Level_Fn.new(fn_ast.ident, fn_symbol.global, instructions);
}

gen_instructions :: (using ctx: *Tacky_Ctx, instructions: *[..]*Instruction, block_ast: *Ast.Block) {
    gen_instructions(ctx, instructions, block_ast.items);
}

gen_instructions :: (using ctx: *Tacky_Ctx, instructions: *[..]*Instruction, block_item_ast: [..]*Ast.Block_Item) {
    for block_item_ast  {
        if #complete it.kind == {
            case .STMT;
                item_stmt := cast(*Ast.Block_Item_Stmt) it;
                gen_instructions(ctx, instructions, item_stmt.stmt);
            case .DECL;
                item_decl := cast(*Ast.Block_Item_Decl) it;
                gen_instructions_decl(ctx, instructions, item_decl.decl);
        }
    }
}

gen_instructions_decl :: (using ctx: *Tacky_Ctx, instructions: *[..]*Instruction, decl_ast: *Ast.Decl) {
    if #complete decl_ast.kind == {
        case .VAR;
            decl_var := cast(*Ast.Var_Decl) decl_ast;
            // if we only have declaration without any initializer, we can skip it as it has already fulfilled its purpose
            if (decl_var.init == null)  return;

            // Static variables are initialized in the data section, not in function body
            if (decl_var.storage_class == .STATIC)  return;

            result := gen_expr(ctx, instructions, decl_var.init);
            dst := variable(decl_var.ident);
            array_add(instructions, copy(result, dst));
        case .FN;
            decl_fn := cast(*Ast.Fn_Decl) decl_ast;
            if decl_fn.body != null assert(false, "Hmm.. this should not have happened - fn decl can't have body.");
    }
}

gen_instructions :: (using ctx: *Tacky_Ctx, instructions: *[..]*Instruction, stmt_ast: *Ast.Stmt) {
    if #complete stmt_ast.kind == {
        case .DEFAULT;
            stmt_default := cast(*Ast.Stmt_Default) stmt_ast;
            array_add(instructions, label(stmt_default.label));
        case .CASE;
            stmt_case := cast(*Ast.Stmt_Case) stmt_ast;
            array_add(instructions, label(stmt_case.label));
        case .RETURN;
            stmt_return := cast(*Ast.Stmt_Return) stmt_ast;
            src := gen_expr(ctx, instructions, stmt_return.expr);
            array_add(instructions, ret(src));
        case .SWITCH;
            stmt_switch := cast(*Ast.Stmt_Switch) stmt_ast;
            gen_stmt_switch(ctx, instructions, stmt_switch);
        case .EXPR;
            stmt_expr := cast(*Ast.Stmt_Expr) stmt_ast;
            if stmt_expr.expr.kind == .VAR  {
                expr_var := cast(*Ast.Expr_Var) stmt_expr.expr;
                success, ident := table_find(ctx.st, expr_var.ident);
                if success {
                    if ident.kind == .VAR {
                        var_symbol := cast(*Symbol_Var) ident;
                        if var_symbol.attr.kind == .STATIC {
                            return;
                        }
                    }
                }
            }
            gen_expr(ctx, instructions, stmt_expr.expr);
        case .IF;
            stmt_if := cast(*Ast.Stmt_If) stmt_ast;
            if stmt_if.else_block == null {
                if_end_label := make_label(ctx, "if_end");
                condition := gen_expr(ctx, instructions, stmt_if.condition);
                array_add(instructions, jump_if_zero(condition, if_end_label));
                gen_instructions(ctx, instructions, stmt_if.if_block);
                array_add(instructions, label(if_end_label));
            } else {
                if_end_label := make_label(ctx, "if_end");
                else_label := make_label(ctx, "else");

                condition := gen_expr(ctx, instructions, stmt_if.condition);

                array_add(instructions, jump_if_zero(condition, else_label));

                gen_instructions(ctx, instructions, stmt_if.if_block);
                array_add(instructions, jump(if_end_label));

                array_add(instructions, label(else_label));
                gen_instructions(ctx, instructions, stmt_if.else_block);

                array_add(instructions, label(if_end_label));
            }
        case .LABEL;
            stmt_label := cast(*Ast.Stmt_Label) stmt_ast;
            goto_label := label(stmt_label.label);
            array_add(instructions, goto_label);
            gen_instructions(ctx, instructions, stmt_label.stmt);
        case .GOTO;
            stmt_goto := cast(*Ast.Stmt_Goto) stmt_ast;
            array_add(instructions, jump(stmt_goto.label));
        case .COMPOUND;
            stmt_compound := cast(*Ast.Stmt_Compound) stmt_ast;
            gen_instructions(ctx, instructions, stmt_compound.block);
        case .FOR;
            stmt_for := cast(*Ast.Stmt_For) stmt_ast;
            loop_start_label     := sprint("%_start", stmt_for.label);
            loop_post_expr_label := sprint("%_post_expr", stmt_for.label);
            loop_end_label       := sprint("%_end", stmt_for.label);

            if #complete stmt_for.init.kind == {
                case .DECL;
                    init_decl := cast(*Ast.For_Init_Decl) stmt_for.init;
                    gen_instructions_decl(ctx, instructions, init_decl.decl);
                case .EXPR;
                    init_expr := cast(*Ast.For_Init_Expr) stmt_for.init;
                    if init_expr.expr != null gen_expr(ctx, instructions, init_expr.expr);
            }
            // jump to loop start - as first time you come into this phase, you don't want to run post expr
            array_add(instructions, jump(loop_start_label));

            array_add(instructions, label(loop_post_expr_label));
            if stmt_for.post != null  gen_expr(ctx, instructions, stmt_for.post);

            // Loop start - includes the condition and jump to body if needed
            array_add(instructions, label(loop_start_label));
            if stmt_for.condition != null {
                condition := gen_expr(ctx, instructions, stmt_for.condition);
                array_add(instructions, jump_if_zero(condition, loop_end_label));
            }

            gen_instructions(ctx, instructions, stmt_for.body);

            array_add(instructions, jump(loop_post_expr_label));
            array_add(instructions, label(loop_end_label));
        case .DO_WHILE;
            stmt_do_while := cast(*Ast.Stmt_Do_While) stmt_ast;
            loop_start_label := sprint("%_start", stmt_do_while.label);
            loop_end_label   := sprint("%_end", stmt_do_while.label);
            // TODO(seg4lt): Refactor
            // adding post expr just because I am handling continue to go to post expr
            // this makes it easier to model for loop
            // Maybe there is a better way to do this but..... this is what we have for now
            loop_post_expr_label := sprint("%_post_expr", stmt_do_while.label);

            array_add(instructions, label(loop_start_label));

            gen_instructions(ctx, instructions, stmt_do_while.body);

            array_add(instructions, label(loop_post_expr_label));
            condition := gen_expr(ctx, instructions, stmt_do_while.condition);
            array_add(instructions, jump_if_not_zero(condition, loop_start_label));

            array_add(instructions, label(loop_end_label));
        case .WHILE;
            stmt_while := cast(*Ast.Stmt_While) stmt_ast;
            loop_start_label := sprint("%_start", stmt_while.label);
            loop_end_label   := sprint("%_end", stmt_while.label);
            // TODO(seg4lt): Refactor
            // adding post expr just because I am handling continue to go to post expr
            // this makes it easier to model for loop
            // Maybe there is a better way to do this but..... this is what we have for now
            loop_post_expr_label := sprint("%_post_expr", stmt_while.label);

            array_add(instructions, label(loop_start_label));
            array_add(instructions, label(loop_post_expr_label));

            condition := gen_expr(ctx, instructions, stmt_while.condition);
            array_add(instructions, jump_if_zero(condition, loop_end_label));

            gen_instructions(ctx, instructions, stmt_while.body);

            array_add(instructions, jump(loop_start_label));
            array_add(instructions, label(loop_end_label));
        case .BREAK;
            stmt_break := cast(*Ast.Stmt_Break) stmt_ast;
            loop_end_label := sprint("%_end", stmt_break.label);
            array_add(instructions, jump(loop_end_label));
        case .CONTINUE;
            stmt_continue := cast(*Ast.Stmt_Continue) stmt_ast;
            loop_start_label := sprint("%_post_expr", stmt_continue.label);
            array_add(instructions, jump(loop_start_label));
        case .NULL;
            // pass through - nothing to do when null stmt is received
    }
}

gen_stmt_switch:: (using ctx: *Tacky_Ctx, instructions: *[..]*Instruction, switch_ast: *Ast.Stmt_Switch) {
    switch_condition := switch_ast.condition;
    switch_expr_val := gen_expr(ctx, instructions, switch_condition);

    // Add jump instruction for all cases first
    // We still don't emit the instruction for each case
    // handle non-default first
    for switch_ast.cases_label {
        if it.is_default continue;

        // we create an expression to check if matches case we have
        case_value := constant(Ast.Constant_Int.new(string_to_int(it.value)));
        condition := make_var(ctx, switch_condition.type);
        array_add(instructions, binary(.EQUAL_EQUAL, switch_expr_val, case_value, condition));

        // we gen the instruction for the expr we created
        // if it mathces, we jump the the case label
        // condition := gen_instructions(tc, instructions, condition_expr_ast);
        array_add(instructions, jump_if_not_zero(condition, it.label));
    }
    // handling default case separately as this is if nothing matches
    for switch_ast.cases_label {
        if !it.is_default continue;
        default_label := it.label;
        array_add(instructions, jump(default_label));
    }

    // by this point we have added required jump instructions to correct cases
    // if nothing maches we need to go to end to the switch
    switch_end_label := sprint("%_end", switch_ast.label);
    array_add(instructions, jump(switch_end_label));

    // now add instruction for all cases
    gen_instructions(ctx, instructions, switch_ast.body);

    // this is to mark end of switch to jump if nothing matches
    array_add(instructions, label(switch_end_label));
}

gen_expr :: (using ctx: *Tacky_Ctx, instructions: *[..]*Instruction, expr_ast: *Ast.Expr) -> dst: *Val {
    if #complete expr_ast.kind == {
        case .CAST; 
            using expr_cast := expr_ast.(*Ast.Expr_Cast);
            result := gen_expr(ctx, instructions, expr);
            if is_builtin_type_same(target_type, expr.type) return result;

            dst := make_var(ctx, expr_cast.target_type);
            // do I need to add to symbol
            if #complete target_type.kind == {
                case .INT;  array_add(instructions, signed_extend(result, dst));
                case .LONG; array_add(instructions, truncate(result, dst));
                case .FN; assert(false, "** compiler bug ** this is cast expr ast"); return null;
            }
            return dst;
        case .PREFIX;
            expr_prefix := cast(*Ast.Expr_Prefix) expr_ast;
            inner_expr_result := gen_expr(ctx, instructions, expr_prefix.expr);
            one := constant(Ast.Constant_Int.new(1));
            dst := make_var(ctx, expr_prefix.expr.type);
            if #complete expr_prefix.op == {
                case .ADD;
                    array_add(instructions, binary(.ADD, inner_expr_result, one, dst));
                    array_add(instructions, copy(dst, inner_expr_result));
                case .SUBTRACT;
                    array_add(instructions, binary(.SUB, inner_expr_result, one, dst));
                    array_add(instructions, copy(dst, inner_expr_result));
            }
            return inner_expr_result;
        case .POSTFIX;
            expr_postfix := cast(*Ast.Expr_Postfix) expr_ast;
            expr_val_tacky := gen_expr(ctx, instructions, expr_postfix.expr);

            old_value_dst := make_var(ctx, expr_postfix.expr.type);
            old_value     := copy(expr_val_tacky, old_value_dst);
            array_add(instructions, old_value);

            one := constant(Ast.Constant_Int.new(1));
            if #complete expr_postfix.op == {
                case .ADD;
                    dst := make_var(ctx, expr_postfix.expr.type);
                    array_add(instructions, binary(.ADD, expr_val_tacky, one, dst));
                    array_add(instructions, copy(dst, expr_val_tacky));
                case .SUBTRACT;
                    dst := make_var(ctx, expr_postfix.expr.type);
                    array_add(instructions, binary(.SUB, expr_val_tacky, one, dst));
                    array_add(instructions, copy(dst, expr_val_tacky));
            }
            return old_value_dst;
        case .FN_CALL;
            expr_fn_call := cast(*Ast.Expr_Fn_Call) expr_ast;
            args: [..]*Val;
            for expr_fn_call.args {
                arg_val := gen_expr(ctx, instructions, it);
                array_add(*args, arg_val);
            }
            dst := make_var(ctx, expr_fn_call.type);
            array_add(instructions, fn_call(expr_fn_call.ident, args, dst));
            return dst;
        case .UNARY;
            expr_unary := cast(*Ast.Expr_Unary) expr_ast;
            src := gen_expr(ctx, instructions, expr_unary.expr);
            dst := make_var(ctx, expr_unary.expr.type);
            op : Unary_Op = ---;
            if #complete expr_unary.op == {
                case .BITWISE_NOT; op = .BITWISE_NOT;
                case .NEGATE ;     op = .NEGATE;
                case .NOT;         op = .NOT;
            };
            array_add(instructions, unary(op, src, dst));
            return dst;
        case .BINARY;
            expr_binary := cast(*Ast.Expr_Binary) expr_ast;
            if expr_binary.op == {
                case .AND;
                    return gen_logical_and(ctx, instructions, expr_binary.*);
                case .OR;
                    return gen_logical_or(ctx, instructions, expr_binary.*);
                case;
                    src1 := gen_expr(ctx, instructions, expr_binary.left);
                    src2 := gen_expr(ctx, instructions, expr_binary.right);
                    dst  := make_var(ctx, expr_binary.type);
                    op   := to_tacky(expr_binary.op);
                    array_add(instructions, binary(op, src1, src2, dst));
                    return dst;
            }
        case .GROUP;
            expr_group := cast(*Ast.Expr_Group) expr_ast;
            return gen_expr(ctx, instructions, expr_group.expr);
        case .CONSTANT;
            expr_constant := cast(*Ast.Expr_Constant) expr_ast;
            return constant(clone(expr_constant.value));
        case .VAR;
            expr_var := cast(*Ast.Expr_Var) expr_ast;
            return variable(expr_var.ident);
        case .ASSIGNMENT;
            expr_assignment := cast(*Ast.Expr_Assignment) expr_ast;
            result := gen_expr(ctx, instructions, expr_assignment.src);

            if expr_assignment.dst.kind != .VAR
                assert(false, "What!! dst has to be variable. sema didn't catch this!!! : %", expr_assignment.dst);

            dst_var := cast(*Ast.Expr_Var) expr_assignment.dst;
            dst := variable(dst_var.ident);
            array_add(instructions, copy(result, dst));
            return dst;
        case .TERNARY;
            expr_ternary := cast(*Ast.Expr_Ternary) expr_ast;
            dst := make_var(ctx, expr_ternary.type);

            ternary_end  := make_label(ctx, "ternary_end");
            ternary_else := make_label(ctx, "ternary_else");

            condition := gen_expr(ctx, instructions, expr_ternary.condition);

            array_add(instructions, jump_if_zero(condition, ternary_else));

            { // true
                result := gen_expr(ctx, instructions, expr_ternary.true_expr);
                array_add(instructions, copy(result, dst));
                array_add(instructions, jump(ternary_end));
            }

            { // false
                array_add(instructions, label(ternary_else));
                result := gen_expr(ctx, instructions, expr_ternary.false_expr);
                array_add(instructions, copy(result, dst));
            }
            array_add(instructions, label(ternary_end));
            return dst;
    }
}



gen_logical_and :: (ctx: *Tacky_Ctx, instructions: *[..]*Instruction, bin_ast: Ast.Expr_Binary) -> *Val {
    label_false := make_label(ctx, "cond_false");

    src1 := gen_expr(ctx, instructions, bin_ast.left);
    array_add(instructions, jump_if_zero(src1, label_false));

    src2 := gen_expr(ctx, instructions, bin_ast.right);
    array_add(instructions, jump_if_zero(src2, label_false));

    result_var := make_var(ctx, bin_ast.type);
    one        := constant(Ast.Constant_Int.new(1));

    array_add(instructions, copy(one, result_var));

    label_end := make_label(ctx, "logical_cmp_end");

    array_add(instructions, jump(label_end));
    array_add(instructions, label(label_false));

    zero := constant(Ast.Constant_Int.new(0));
    array_add(instructions, copy(zero, result_var));

    array_add(instructions, label(label_end));
    return result_var;
}

gen_logical_or :: (ctx: *Tacky_Ctx, instructions: *[..]*Instruction, bin_ast: Ast.Expr_Binary) -> *Val {
    label_false := make_label(ctx, "cond_true");

    src1 := gen_expr(ctx, instructions, bin_ast.left);
    array_add(instructions, jump_if_not_zero(src1, label_false));

    src2 := gen_expr(ctx, instructions, bin_ast.right);
    array_add(instructions, jump_if_not_zero(src2, label_false));

    result_var := make_var(ctx, bin_ast.type);
    zero       := constant(Ast.Constant_Int.new(0));

    array_add(instructions, copy(zero, result_var));

    label_end := make_label(ctx, "logical_cmp_end");

    array_add(instructions, jump(label_end));
    array_add(instructions, label(label_false));

    one := constant(Ast.Constant_Int.new(1));
    array_add(instructions, copy(one, result_var));

    array_add(instructions, label(label_end));
    return result_var;
}

to_tacky :: (ast_op: Ast.Binary_Operator) -> Bin_Op {
    if #complete ast_op == {
        case .ADD;           return .ADD;
        case .BITWISE_AND;   return .BITWISE_AND;
        case .BITWISE_OR;    return .BITWISE_OR;
        case .BITWISE_XOR;   return .BITWISE_XOR;
        case .DIV;           return .DIV;
        case .EQUAL_EQUAL;   return .EQUAL_EQUAL;
        case .GREATER;       return .GREATER;
        case .GREATER_EQUAL; return .GREATER_EQUAL;
        case .LEFT_SHIFT;    return .LEFT_SHIFT;
        case .LESS;          return .LESS;
        case .LESS_EQUAL;    return .LESS_EQUAL;
        case .MOD;           return .MOD;
        case .MUL;           return .MUL;
        case .NOT_EQUAL;     return .NOT_EQUAL;
        case .RIGHT_SHIFT;   return .RIGHT_SHIFT;
        case .SUB;           return .SUB;
        case .AND;           #through;
        case .OR;            assert(false, "logical and/or operators are handled separately"); return .ADD;
    }
}

ret :: (val: *Val) -> *Instruction #expand {
    return Instruction_Return.new(val);
}

constant :: (value: *Ast.Constant) -> *Val #expand {
    return Val_Constant.new(value);
}

variable :: (ident: string) -> *Val #expand {
    return Val_Variable.new(ident);
}

copy :: (src: *Val, dst: *Val) -> *Instruction #expand {
    return Instruction_Copy.new(src, dst);
}

label :: (ident: string) -> *Instruction #expand {
    return Instruction_Label.new(ident);
}

jump :: (ident: string) -> *Instruction #expand {
    return Instruction_Jump.new(ident);
}

jump_if_zero :: (condition: *Val, ident: string) -> *Instruction #expand {
    return Instruction_Jump_If_Zero.new(condition, ident);
}

jump_if_not_zero :: (condition: *Val, ident: string) -> *Instruction #expand {
    return Instruction_Jump_If_Not_Zero.new(condition, ident);
}

fn_call :: (ident: string, args: [..]*Val, dst: *Val) -> *Instruction #expand {
    return Instruction_Fn_Call.new(ident, args, dst);
}

unary :: (op: Unary_Op, src: *Val, dst: *Val) -> *Instruction #expand {
    return Instruction_Unary.new(op, src, dst);
}

binary :: (op: Bin_Op, src1: *Val, src2: *Val, dst: *Val) -> *Instruction #expand {
    return Instruction_Binary.new(op, src1, src2, dst);
}

signed_extend :: (src: *Val, dst: *Val) -> *Instruction #expand {
    return Instruction_Signed_Extend.new(src, dst);
}

truncate :: (src: *Val, dst: *Val) -> *Instruction #expand {
    return Instruction_Truncate.new(src, dst);
}

make_var :: (using ctx: *Tacky_Ctx, type: *Ast.Builtin_Type) -> *Val {
    defer temp_var_index += 1;
    var := Val_Variable.new(sprint("tmp.%", temp_var_index));
    table_set(st, var.variable, Symbol_Var.new(var.variable, type, local_var()));
    return var;
}

make_label :: (tc : *Tacky_Ctx, label_prefix: string) -> string {
    defer tc.label_index += 1;
    return sprint("%.%", label_prefix, tc.label_index);
}

