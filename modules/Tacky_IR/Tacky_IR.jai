gen_tacky :: (pg: *Program_Ast, st: *Symbol_Table, debug_log: bool = false) -> *Program_Tacky {
    tc : Tacky_Ctx;
    
    top_level_tac: [..]Top_Level_Tacky;
    for *decl: pg.decls {
        using decl.*;
        if #complete type == {
            case .FN; if decl_fn.block {
                fn := gen_fn_tacky(*tc, decl_fn, st);
                array_add(*top_level_tac, top_level_fn_tac(fn));
            }
            case .VAR; // noop - handled differently
        }
    }
    
    for value, key: st {
        if #complete value.attr.kind == {
            case .STATIC;
                sv := value.attr.static;
                if #complete sv.initial_value.kind == {
                    case .INITIAL; 
                        array_add(*top_level_tac, top_level_static_var_tac(.{key, sv.global, sv.initial_value.initial}));
                    case .TENTATIVE; 
                        array_add(*top_level_tac, top_level_static_var_tac(.{key, sv.global, 0}));
                    case .NO_INITIALIZER; // noop
                }
            case .FN;    #through;
            case .LOCAL; // noop
        }
    }
    
    program := New(Program_Tacky, .{ top_level_tac });

    if debug_log print_tacky(program, *stdout_writer_new());
    return program;
}

#scope_file

gen_fn_tacky :: (tc: *Tacky_Ctx, fn_ast: *Fn_Decl_Ast, st: *Symbol_Table) -> Fn_Tacky {
    instructions: [..]Instruction_Tacky;
    if fn_ast.block  {
        gen_instructions(tc, *instructions, fn_ast.block, st);
        // Always add return 0 as there might be case where we don't have one
        // Potentially we can optimize this away later.
        array_add(*instructions, ret(constant(0)));
    }
    found_symbol, symbol := table_find_new(st, fn_ast.ident);
    assert(found_symbol, "Something went wrong.. fn symbol not found on table");
    assert(symbol.attr.kind == .FN, "Symbol should be fn kind");
    return .{ copy_string(fn_ast.ident), symbol.attr.fn.global, instructions };
}

gen_instructions :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, block_ast: *Block_Ast, st: *Symbol_Table) {
    gen_instructions(tc, instructions, block_ast.items, st);
}

gen_instructions :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, block_item_ast: [..]*Block_Item_Ast, st: *Symbol_Table) {
    for block_item_ast  {
        using it;
        if #complete type == {
            case .STMT; gen_instructions(tc, instructions, block_item_stmt, st);
            case .DECL; gen_instructions_decl(tc, instructions, block_item_decl);
        }
    }
}

gen_instructions_decl :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, using decl_ast: *Decl_Ast) {
    if #complete type == {
        case .VAR;
            // if we only have declaration without any initializer, we can skip it as it has already fulfilled its purpose
            if (decl_var.init == null)  return;
            
            // Static variables are initialized in the data section, not in function body
            if (decl_var.storage_class == .STATIC)  return;
            
            result := gen_expr(tc, instructions, decl_var.init);
            dst := variable(decl_var.ident);
            array_add(instructions, copy(result, dst));
        case .FN;
            if decl_fn.block != null assert(false, "Hmm.. this should not have happened - fn decl can't have body.");
    }
}

gen_instructions :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, using stmt_ast: *Stmt_Ast, st: *Symbol_Table) {
    if #complete type == {
        case .DEFAULT; 
            array_add(instructions, label(stmt_default));
        case .CASE;
            array_add(instructions, label(stmt_case.label));
        case .RETURN;
            src := gen_expr(tc, instructions, stmt_return.expr);
            array_add(instructions, ret(src));
        case .SWITCH; 
            gen_stmt_switch(tc, instructions, stmt_switch, st);
        case .EXPR; 
            if stmt_expr.type == .VAR  {
                success, ident := table_find_new(st, stmt_expr.expr_var);
                if success {
                    if ident.attr.kind == .STATIC {
                        return;
                    }
                }
            }
            gen_expr(tc, instructions, stmt_expr);
        case .IF;
            if stmt_if.else_block == null {
                if_end_label := make_label(tc, "if_end");
                condition := gen_expr(tc, instructions, stmt_if.condition);
                array_add(instructions, jump_if_zero(condition, if_end_label.as.label));
                gen_instructions(tc, instructions, stmt_if.if_block, st);
                array_add(instructions, if_end_label);
            } else {
                if_end_label := make_label(tc, "if_end");
                else_label := make_label(tc, "else");

                condition := gen_expr(tc, instructions, stmt_if.condition);

                array_add(instructions, jump_if_zero(condition, else_label.as.label));

                gen_instructions(tc, instructions, stmt_if.if_block, st);
                array_add(instructions, jump(if_end_label.as.label));

                array_add(instructions, else_label);
                gen_instructions(tc, instructions, stmt_if.else_block, st);

                array_add(instructions, if_end_label);
            }
        case .LABEL;
            goto_label := label(stmt_label.label);
            array_add(instructions, goto_label);
            gen_instructions(tc, instructions, stmt_label.stmt, st);
        case .GOTO;
            array_add(instructions, jump(stmt_goto));
        case .COMPOUND;
            gen_instructions(tc, instructions, stmt_compound, st);
        case .FOR;
            loop_start_label     := sprint("%_start", stmt_for.label);
            loop_post_expr_label := sprint("%_post_expr", stmt_for.label);
            loop_end_label       := sprint("%_end", stmt_for.label);

            using stmt_for.init;
            if #complete stmt_for.init.type == {
                case .DECL; gen_instructions_decl(tc, instructions, for_init_decl);
                case .EXPR; if for_init_expr != null gen_expr(tc, instructions, for_init_expr);
            }
            // jump to loop start - as first time you come into this phase, you don't want to run post expr
            array_add(instructions, jump(loop_start_label));

            array_add(instructions, label(loop_post_expr_label));
            if stmt_for.post != null  gen_expr(tc, instructions, stmt_for.post);

            // Loop start - includes the condition and jump to body if needed
            array_add(instructions, label(loop_start_label));
            if stmt_for.condition != null {
                condition := gen_expr(tc, instructions, stmt_for.condition);
                array_add(instructions, jump_if_zero(condition, loop_end_label));
            }

            gen_instructions(tc, instructions, stmt_for.body, st);

            array_add(instructions, jump(loop_post_expr_label));
            array_add(instructions, label(loop_end_label));
        case .DO_WHILE;
            loop_start_label := sprint("%_start", stmt_do_while.label);
            loop_end_label := sprint("%_end", stmt_do_while.label);
            // TODO(seg4lt): Refactor  
            // adding post expr just because I am handling continue to go to post expr
            // this makes it easier to model for loop
            // Maybe there is a better way to do this but..... this is what we have for now
            loop_post_expr_label := sprint("%_post_expr", stmt_do_while.label);

            array_add(instructions, label(loop_start_label));

            gen_instructions(tc, instructions, stmt_do_while.body, st);

            array_add(instructions, label(loop_post_expr_label));
            condition := gen_expr(tc, instructions, stmt_do_while.condition);
            array_add(instructions, jump_if_not_zero(condition, loop_start_label));

            array_add(instructions, label(loop_end_label));
        case .WHILE;
            loop_start_label := sprint("%_start", stmt_while.label);
            loop_end_label := sprint("%_end", stmt_while.label);
            // TODO(seg4lt): Refactor
            // adding post expr just because I am handling continue to go to post expr
            // this makes it easier to model for loop
            // Maybe there is a better way to do this but..... this is what we have for now
            loop_post_expr_label := sprint("%_post_expr", stmt_while.label);

            array_add(instructions, label(loop_start_label));
            array_add(instructions, label(loop_post_expr_label));

            condition := gen_expr(tc, instructions, stmt_while.condition);
            array_add(instructions, jump_if_zero(condition, loop_end_label));

            gen_instructions(tc, instructions, stmt_while.body, st);

            array_add(instructions, jump(loop_start_label));
            array_add(instructions, label(loop_end_label));
        case .BREAK;
            loop_end_label := sprint("%_end", stmt_break);
            array_add(instructions, jump(loop_end_label));
        case .CONTINUE;
            loop_start_label := sprint("%_post_expr", stmt_continue);
            array_add(instructions, jump(loop_start_label));
        case .NULL; 
            // pass through - nothing to do when null stmt is received
    }
}

gen_stmt_switch:: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, switch_ast: Switch_Stmt_Ast, st: *Symbol_Table) {
    switch_condition := switch_ast.condition;
    switch_expr_val := gen_expr(tc, instructions, switch_condition);

    // Add jump instruction for all cases first
    // We still don't emit the instruction for each case
    // handle non-default first
    for switch_ast.cases_label {
        if it.is_default continue;

        // we create an expression to check if matches case we have
        case_value := constant(string_to_int(it.value));
        condition := make_var(tc);
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
    gen_instructions(tc, instructions, switch_ast.body, st);

    // this is to mark end of switch to jump if nothing matches
    array_add(instructions, label(switch_end_label));
}

gen_expr :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, using expr_ast: *Expr_Ast) -> dst: Val_Tacky {
    if #complete type == {
        case .PREFIX;
            inner_expr_result := gen_expr(tc, instructions, expr_prefix.expr);
            one := constant(1);
            dst := make_var(tc);
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
            expr_val_tacky := gen_expr(tc, instructions, expr_postfix.expr);
            
            old_value_dst := make_var(tc);
            old_value     := copy(expr_val_tacky, old_value_dst);
            array_add(instructions, old_value);
        
            one := constant(1);
            if #complete expr_postfix.op == {
                case .ADD; 
                    dst := make_var(tc);
                    array_add(instructions, binary(.ADD, expr_val_tacky, one, dst));
                    array_add(instructions, copy(dst, expr_val_tacky));
                case .SUBTRACT; 
                    dst := make_var(tc);
                    array_add(instructions, binary(.SUB, expr_val_tacky, one, dst));
                    array_add(instructions, copy(dst, expr_val_tacky));
            }
            return old_value_dst;
        case .FN_CALL;
            args: [..]Val_Tacky;
            for expr_fn_call.args {
                arg_val := gen_expr(tc, instructions, it);
                array_add(*args, arg_val);
            }
            dst := make_var(tc);
            array_add(instructions, fn_call(expr_fn_call.ident, args, dst));
            return dst;
        case .UNARY;
            src := gen_expr(tc, instructions, expr_unary.expr);
            dst := make_var(tc);
            op : Unary_Op_Type_Tacky = ---;
            if #complete expr_unary.op == {
                case .BITWISE_NOT; op = .BITWISE_NOT;
                case .NEGATE ;     op = .NEGATE;
                case .NOT;         op = .NOT; 
            }; 
            array_add(instructions, unary(op, src, dst));
            return dst;
        case .BINARY;
            if expr_binary.op == {
                case .AND; 
                    return gen_logical_and(tc, instructions, expr_binary);
                case .OR;
                    return gen_logical_or(tc, instructions, expr_binary);
                case;
                    src1 := gen_expr(tc, instructions, expr_binary.left);
                    src2 := gen_expr(tc, instructions, expr_binary.right);
                    dst  := make_var(tc);
                    op   := to_tacky(expr_binary.op);
                    array_add(instructions, binary(op, src1, src2, dst));
                    return dst;
            }
        case .GROUP;
            return gen_expr(tc, instructions, expr_group);
        case .CONSTANT;
            return constant(expr_constant);
        case .VAR;
            return variable(expr_var);
        case .ASSIGNMENT; 
            result := gen_expr(tc, instructions, expr_assignment.src);
            
            if expr_assignment.dst.type != .VAR
                assert(false, "What!! dst has to be variable. sema didn't catch this!!! : %", expr_assignment.dst);
                
            dst := variable(expr_assignment.dst.expr_var);
            array_add(instructions, copy(result, dst));
            return dst;
        case .TERNARY;
            dst     := make_var(tc);
            result  : Val_Tacky = ---;

            ternary_end  := make_label(tc, "ternary_end");
            ternary_else := make_label(tc, "ternary_else");

            condition := gen_expr(tc, instructions, expr_ternary.condition);

            array_add(instructions, jump_if_zero(condition, ternary_else.as.label));

            { // true
                result = gen_expr(tc, instructions, expr_ternary.true_expr);
                array_add(instructions, copy(result, dst));
                array_add(instructions, jump(ternary_end.as.label));
            }

            { // false
                array_add(instructions, ternary_else);
                result = gen_expr(tc, instructions, expr_ternary.false_expr);
                array_add(instructions, copy(result, dst));
            }
            array_add(instructions, ternary_end); 
            return dst;
    }
}

gen_postfix :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, expr_ast: *Expr_Ast, expr_val_tacky: Val_Tacky) -> Val_Tacky {
    if expr_ast.postfix == .NONE return expr_val_tacky;

    old_value_dst := make_var(tc);
    old_value     := copy(expr_val_tacky, old_value_dst);
    array_add(instructions, old_value);

    one := constant(1);
    if #complete expr_ast.postfix == {
        case .INCR; 
            dst := make_var(tc);
            array_add(instructions, binary(.ADD, expr_val_tacky, one, dst));
            array_add(instructions, copy(dst, expr_val_tacky));
        case .DECR; 
            dst := make_var(tc);
            array_add(instructions, binary(.SUB, expr_val_tacky, one, dst));
            array_add(instructions, copy(dst, expr_val_tacky));
        case .NONE; 
            assert(false, "unreachable");
    }
    return old_value_dst;
}

gen_logical_and :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, bin_ast: type_of(Expr_Ast.expr_binary)) -> Val_Tacky {
    label_false := make_label(tc, "cond_false");

    src1 := gen_expr(tc, instructions, bin_ast.left);
    array_add(instructions, jump_if_zero(src1, label_false.as.label));

    src2 := gen_expr(tc, instructions, bin_ast.right);
    array_add(instructions, jump_if_zero(src2, label_false.as.label));

    result_var := make_var(tc);
    one        := constant(1);
    array_add(instructions, copy(one, result_var));

    label_end := make_label(tc, "logical_cmp_end");

    array_add(instructions, jump(label_end.as.label));
    array_add(instructions, label_false);

    zero := constant(0);
    array_add(instructions, copy(zero, result_var));

    array_add(instructions, label_end);

    return result_var;
}

gen_logical_or :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, bin_ast: type_of(Expr_Ast.expr_binary)) -> Val_Tacky {
    label_false := make_label(tc, "cond_true");

    src1 := gen_expr(tc, instructions, bin_ast.left);
    array_add(instructions, jump_if_not_zero(src1, label_false.as.label));

    src2 := gen_expr(tc, instructions, bin_ast.right);
    array_add(instructions, jump_if_not_zero(src2, label_false.as.label));

    result_var := make_var(tc);
    zero       := constant(0);
    array_add(instructions, copy(zero, result_var));

    label_end := make_label(tc, "logical_cmp_end");

    array_add(instructions, jump(label_end.as.label));
    array_add(instructions, label_false);
    
    one := constant(1);
    array_add(instructions, copy(one, result_var));
    array_add(instructions, label_end);

    return result_var;
}

to_tacky :: (ast_op: type_of(Expr_Ast.expr_binary.op)) -> type_of(Instruction_Tacky.as.binary.op) {
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
        case .OR;            assert(false, "And and OR are not handled this way");
    }
    assert(false, "There are not other binary operator. What is this %", ast_op);
    return .MOD; // unreachable
}

ret :: (val: Val_Tacky) -> Instruction_Tacky #expand {
    return .{.RETURN, .{ ret = val }};
}

constant :: (value: int) -> Val_Tacky #expand {
    return .{.CONSTANT, .{constant = value }};
}

variable :: (ident: string) -> Val_Tacky #expand {
    return .{.VARIABLE, .{variable = copy_string(ident) }};
}

copy :: (src: Val_Tacky, dst: Val_Tacky) -> Instruction_Tacky #expand {
    return .{.COPY, .{ copy = .{ src, dst }}};
}

label :: (ident: string) -> Instruction_Tacky #expand {
    return .{.LABEL, .{label = copy_string(ident) }};
}

jump :: (ident: string) -> Instruction_Tacky #expand {
    return .{.JUMP, .{ jump = copy_string(ident) }};
}

jump_if_zero :: (condition: Val_Tacky, ident: string) -> Instruction_Tacky #expand {
    return .{ .JUMP_IF_ZERO, .{ jump_if_zero = .{ condition, copy_string(ident) } }};
}

jump_if_not_zero :: (condition: Val_Tacky, ident: string) -> Instruction_Tacky #expand {
    return .{ .JUMP_IF_NOT_ZERO, .{ jump_if_not_zero = .{condition, copy_string(ident) } }};
}

fn_call :: (ident: string, args: [..]Val_Tacky, dst: Val_Tacky) -> Instruction_Tacky #expand {
    return .{ .FN_CALL, .{ fn_call = .{ copy_string(ident), args, dst } }};
}

unary :: (op: Unary_Op_Type_Tacky, src: Val_Tacky, dst: Val_Tacky) -> Instruction_Tacky #expand {
    return .{.UNARY, .{unary = .{op, src, dst}}};
}

binary :: (op: Bin_Op_Type_Tacky, src1: Val_Tacky, src2: Val_Tacky, dst: Val_Tacky) -> Instruction_Tacky #expand {
    return .{.BINARY, .{binary= .{ op, src1, src2, dst}}};
}

make_var :: (tc : *Tacky_Ctx) -> Val_Tacky {
    defer tc.temp_var_index += 1;
    return .{.VARIABLE, .{variable = sprint("tmp.%",tc.temp_var_index) }};
}

make_label :: (tc : *Tacky_Ctx, label: string) -> Instruction_Tacky {
    defer tc.label_index += 1;
    return .{.LABEL, .{label = sprint("L_%.%", copy_string(label), tc.label_index) }};
}