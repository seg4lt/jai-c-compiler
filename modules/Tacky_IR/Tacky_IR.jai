gen_tacky :: (pg: *Program_Ast, do_print: bool = false) -> *Program_Tacky {
    tc : Tacky_Ctx;
    
    fns: [..]Fn_Tacky;
    for fn_ast: pg.fns {
        if fn_ast.block {
            fn := gen_fn_tacky(*tc, fn_ast);
            array_add(*fns, fn);
        }
    }
    program := New(Program_Tacky, .{ fns });

    if do_print {
        writer := stdout_writer_new();
        print_tacky(program, *writer);
    }

    return program;
}

#scope_file

gen_fn_tacky :: (tc: *Tacky_Ctx, fn_ast: *Fn_Decl_Ast) -> Fn_Tacky {
    instructions: [..]Instruction_Tacky;
    if fn_ast.block  {
        gen_instructions(tc, *instructions, fn_ast.block);
        // Always add return 0 as there might be case where we don't have one
        // Potentially we can optimize this away later.
        array_add(*instructions, ret(constant(0)));
    }
    return .{ fn_ast.ident, instructions };
}

gen_instructions :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, block_ast: *Block_Ast) {
    gen_instructions(tc, instructions, block_ast.items);
}

gen_instructions :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, block_item_ast: [..]*Block_Item_Ast) {
    for block_item_ast {
        if #complete it.type == {
            case .STMT;
                gen_instructions(tc, instructions, it.as.stmt);
            case .DECL;
                gen_instructions_decl(tc, instructions, it.as.decl);
        }
    }
}

gen_instructions_decl :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, decl_ast: *Decl_Ast) {
    if #complete decl_ast.type == {
        case .VAR;
            var_decl := decl_ast.as.var;
            if (var_decl.init == null) {
                // if we only have declaration without any initializer, we can skip it as it has already fulfilled its purpose
                return;
            }
            result := gen_expr(tc, instructions, var_decl.init);
            dst := variable(var_decl.ident);
            array_add(instructions, copy(result, dst));
        case .FN;
            fn_decl := decl_ast.as.fn;
            if fn_decl.block != null {
                assert(false, "Hmm.. this should not have happened - fn decl can't have body.");
            }
    }

}

gen_instructions :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, stmt_ast: *Stmt_Ast) {
    if #complete stmt_ast.type == {
        case .DEFAULT;
            default_stmt := stmt_ast.as.default;
            array_add(instructions, label(default_stmt));
        case .CASE;
            case_label := stmt_ast.as.case_stmt.label;
            array_add(instructions, label(case_label));
        case .RETURN;
            src := gen_expr(tc, instructions, stmt_ast.as.return_stmt.expr);
            array_add(instructions, ret(src));
        case .SWITCH;
            gen_stmt_switch(tc, instructions, stmt_ast.as.switch);
        case .EXPR;
            gen_expr(tc, instructions, stmt_ast.as.expr);
        case .IF;
            if_stmt := stmt_ast.as.if_stmt;

            if if_stmt.else_block == null {
                if_end_label := make_label(tc, "if_end");
                condition := gen_expr(tc, instructions, if_stmt.condition);
                array_add(instructions, jump_if_zero(condition, if_end_label.as.label));
                gen_instructions(tc, instructions, if_stmt.if_block);
                array_add(instructions, if_end_label);
            } else {
                if_end_label := make_label(tc, "if_end");
                else_label := make_label(tc, "else");

                condition := gen_expr(tc, instructions, if_stmt.condition);

                array_add(instructions, jump_if_zero(condition, else_label.as.label));

                gen_instructions(tc, instructions, if_stmt.if_block);
                array_add(instructions, jump(if_end_label.as.label));

                array_add(instructions, else_label);
                gen_instructions(tc, instructions, if_stmt.else_block);

                array_add(instructions, if_end_label);
            }
        case .LABEL;
            label_stmt := stmt_ast.as.label;
            goto_label := label(label_stmt.label);
            array_add(instructions, goto_label);
            gen_instructions(tc, instructions, label_stmt.stmt);
        case .GOTO;
            goto := stmt_ast.as.goto;
            array_add(instructions, jump(goto));
        case .COMPOUND;
            gen_instructions(tc, instructions, stmt_ast.as.compound);
        case .FOR;
            for_stmt := stmt_ast.as.for_stmt;
            loop_start_label := tprint("%_start", for_stmt.label);
            loop_post_expr_label := tprint("%_post_expr", for_stmt.label);
            loop_end_label := tprint("%_end", for_stmt.label);

            if #complete for_stmt.init.type == {
                case .INIT_DECL;
                    gen_instructions_decl(tc, instructions, for_stmt.init.as.decl);
                case .INIT_EXPR;
                    if for_stmt.init.as.expr != null {
                        gen_expr(tc, instructions, for_stmt.init.as.expr);
                    }
            }
            // jump to loop start - as first time you come into this phase, you don't want to run post expr
            array_add(instructions, jump(loop_start_label));

            array_add(instructions, label(loop_post_expr_label));
            if for_stmt.post != null  gen_expr(tc, instructions, for_stmt.post);

            // Loop start - includes the condition and jump to body if needed
            array_add(instructions, label(loop_start_label));
            if for_stmt.condition != null {
                condition := gen_expr(tc, instructions, for_stmt.condition);
                array_add(instructions, jump_if_zero(condition, loop_end_label));
            }

            gen_instructions(tc, instructions, for_stmt.body);

            array_add(instructions, jump(loop_post_expr_label));
            array_add(instructions, label(loop_end_label));
        case .DO_WHILE;
            do_while_stmt := stmt_ast.as.do_while;
            loop_start_label := tprint("%_start", do_while_stmt.label);
            loop_end_label := tprint("%_end", do_while_stmt.label);
            // @refactor adding post expr just because I am handling continue to go to post expr
            // this makes it easier to model for loop
            // Maybe there is a better way to do this but..... this is what we have for now
            loop_post_expr_label := tprint("%_post_expr", do_while_stmt.label);

            array_add(instructions, label(loop_start_label));

            gen_instructions(tc, instructions, do_while_stmt.body);

            array_add(instructions, label(loop_post_expr_label));
            condition := gen_expr(tc, instructions, do_while_stmt.condition);
            array_add(instructions, jump_if_not_zero(condition, loop_start_label));

            array_add(instructions, label(loop_end_label));
        case .WHILE;
            while_stmt := stmt_ast.as.while_stmt;
            loop_start_label := tprint("%_start", while_stmt.label);
            loop_end_label := tprint("%_end", while_stmt.label);
            // @refactor
            // adding post expr just because I am handling continue to go to post expr
            // this makes it easier to model for loop
            // Maybe there is a better way to do this but..... this is what we have for now
            loop_post_expr_label := tprint("%_post_expr", while_stmt.label);

            array_add(instructions, label(loop_start_label));
            array_add(instructions, label(loop_post_expr_label));

            condition := gen_expr(tc, instructions, while_stmt.condition);
            array_add(instructions, jump_if_zero(condition, loop_end_label));

            gen_instructions(tc, instructions, while_stmt.body);

            array_add(instructions, jump(loop_start_label));
            array_add(instructions, label(loop_end_label));
        case .BREAK;
            break_stmt := stmt_ast.as.break_stmt;
            loop_end_label := tprint("%_end", break_stmt);
            array_add(instructions, jump(loop_end_label));
        case .CONTINUE;
            continue_stmt := stmt_ast.as.continue_stmt;
            loop_start_label := tprint("%_post_expr", continue_stmt);
            array_add(instructions, jump(loop_start_label));
        case .NULL; // pass through - nothing to do when null stmt is received
    }
}

gen_expr :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, expr_ast: *Expr_Ast) -> dst: Val_Tacky {
    val := gen_expr_raw(tc, instructions, expr_ast);
    return gen_postfix(tc, instructions, expr_ast, val);
}

gen_stmt_switch:: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, switch_ast: Switch_Stmt_Ast) {
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
    switch_end_label := tprint("%_end", switch_ast.label);
    array_add(instructions, jump(switch_end_label));

    // now add instruction for all cases
    gen_instructions(tc, instructions, switch_ast.body);

    // this is to mark end of switch to jump if nothing matches
    array_add(instructions, label(switch_end_label));
}

// This doesn't process postfix
gen_expr_raw :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, expr_ast: *Expr_Ast) -> dst: Val_Tacky {
    if #complete expr_ast.type == {
        case .FN_CALL;
            fn_call_expr := expr_ast.as.fn_call;
            args: [..]Val_Tacky;
            
            for fn_call_expr.args {
                arg_val := gen_expr(tc, instructions, it);
                array_add(*args, arg_val);
            }
            dst := make_var(tc);
            array_add(instructions, fn_call(fn_call_expr.ident, args, dst));
            return dst;
        case .UNARY;
            src := gen_expr(tc, instructions, expr_ast.as.unary.expr);
            dst := make_var(tc);
            op : Unary_Op_Type_Tacky = ---;
            if #complete expr_ast.as.unary.op == {
                case .BITWISE_NOT; op = .BITWISE_NOT;
                case .NEGATE ;     op = .NEGATE;
                case .NOT;         op = .NOT; 
            }; 
            array_add(instructions, unary(op, src, dst));
            return dst;
        case .BINARY;
            bin_ast := expr_ast.as.binary;
            if bin_ast.op == {
                case .AND; 
                    return gen_logical_and(tc, instructions, bin_ast);
                case .OR;
                    return gen_logical_or(tc, instructions, bin_ast);
                case;
                    src1 := gen_expr(tc, instructions, bin_ast.left);
                    src2 := gen_expr(tc, instructions, bin_ast.right);
                    dst  := make_var(tc);
                    op   := to_tacky(bin_ast.op);
                    array_add(instructions, binary(op, src1, src2, dst));
                    return dst;
            }
        case .GROUP;
            return gen_expr(tc, instructions, expr_ast.as.group);
        case .CONSTANT;
            return constant(expr_ast.as.constant);
        case .VAR;
            return variable(expr_ast.as.var);
        case .ASSIGNMENT; 
            assignment := expr_ast.as.assignment;
            result := gen_expr(tc, instructions, assignment.src);
            
            if assignment.dst.type != .VAR
                assert(false, "What!! dst has to be variable. sema didn't catch this!!! : %", assignment.dst);
                
            dst := variable(assignment.dst.as.var);
            array_add(instructions, copy(result, dst));
            return dst;
        case .TERNARY;
            ternary := expr_ast.as.ternary;
            dst     := make_var(tc);
            result  : Val_Tacky = ---;

            ternary_end  := make_label(tc, "ternary_end");
            ternary_else := make_label(tc, "ternary_else");

            condition := gen_expr(tc, instructions, ternary.condition);

            array_add(instructions, jump_if_zero(condition, ternary_else.as.label));

            { // true
                result = gen_expr(tc, instructions, ternary.true_expr);
                array_add(instructions, copy(result, dst));
                array_add(instructions, jump(ternary_end.as.label));
            }

            { // false
                array_add(instructions, ternary_else);
                result = gen_expr(tc, instructions, ternary.false_expr);
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

gen_logical_and :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, bin_ast: type_of(Expr_Ast.as.binary)) -> Val_Tacky {
    label_false := make_label(tc, tprint("cond_%", "false"));

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

gen_logical_or :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, bin_ast: type_of(Expr_Ast.as.binary)) -> Val_Tacky {
    label_false := make_label(tc, tprint("cond_%", "true"));

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

to_tacky :: (ast_op: type_of(Expr_Ast.as.binary.op)) -> type_of(Instruction_Tacky.as.binary.op) {
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
    return .{.VARIABLE, .{variable = ident }};
}

copy :: (src: Val_Tacky, dst: Val_Tacky) -> Instruction_Tacky #expand {
    return .{.COPY, .{ copy = .{ src, dst }}};
}

label :: (ident: string) -> Instruction_Tacky #expand {
    return .{.LABEL, .{label = ident }};
}

jump :: (ident: string) -> Instruction_Tacky #expand {
    return .{.JUMP, .{ jump = ident }};
}

jump_if_zero :: (condition: Val_Tacky, ident: string) -> Instruction_Tacky #expand {
    return .{ .JUMP_IF_ZERO, .{ jump_if_zero = .{ condition, ident } }};
}

jump_if_not_zero :: (condition: Val_Tacky, ident: string) -> Instruction_Tacky #expand {
    return .{ .JUMP_IF_NOT_ZERO, .{ jump_if_not_zero = .{condition, ident } }};
}

fn_call :: (ident: string, args: [..]Val_Tacky, dst: Val_Tacky) -> Instruction_Tacky #expand {
    return .{ .FN_CALL, .{ fn_call = .{ ident, args, dst } }};
}

unary :: (op: Unary_Op_Type_Tacky, src: Val_Tacky, dst: Val_Tacky) -> Instruction_Tacky #expand {
    return .{.UNARY, .{unary = .{op, src, dst}}};
}

binary :: (op: Bin_Op_Type_Tacky, src1: Val_Tacky, src2: Val_Tacky, dst: Val_Tacky) -> Instruction_Tacky #expand {
    return .{.BINARY, .{binary= .{ op, src1, src2, dst}}};
}

make_var :: (tc : *Tacky_Ctx) -> Val_Tacky {
    defer tc.temp_var_index += 1;
    return .{.VARIABLE, .{variable = tprint("tmp.%",tc.temp_var_index) }};
}

make_label :: (tc : *Tacky_Ctx, label: string) -> Instruction_Tacky {
    defer tc.label_index += 1;
    return .{.LABEL, .{label = tprint("L_%.%",label, tc.label_index) }};
}