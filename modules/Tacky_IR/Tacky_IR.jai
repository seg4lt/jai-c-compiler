Program_Tacky :: struct {
    fn: Fn_Tacky;
}

Fn_Tacky :: struct {
    ident: string;
    instructions: []Instruction_Tacky;
}

Instruction_Type_Tacky :: enum {
    RETURN; 
    UNARY; 
    BINARY;
    COPY;
    JUMP;
    JUMP_IF_ZERO;
    JUMP_IF_NOT_ZERO;
    LABEL;
}

Instruction_Tacky :: struct {
    type: Instruction_Type_Tacky;
    as : union {
        ret: Val_Tacky;
        unary: struct { op: Unary_Op_Type_Tacky; src: Val_Tacky; dst: Val_Tacky;};
        binary: struct { op: Bin_Op_Type_Tacky; src1: Val_Tacky; src2: Val_Tacky; dst: Val_Tacky; };
        copy: struct {src: Val_Tacky; dst: Val_Tacky;};
        jump: string;
        jump_if_zero: struct {condition: Val_Tacky; ident: string;};
        jump_if_not_zero: struct {condition: Val_Tacky; ident: string;};
        label: string;
    };
}

Unary_Op_Type_Tacky :: enum {
  BITWISE_NOT; NEGATE; NOT;
}

Bin_Op_Type_Tacky ::enum {
    ADD;
    SUB;
    MUL;
    DIV;
    MOD;
    BITWISE_AND;
    BITWISE_OR;
    BITWISE_XOR;
    LEFT_SHIFT;
    RIGHT_SHIFT;

    EQUAL_EQUAL; NOT_EQUAL;
    LESS; LESS_EQUAL;
    GREATER; GREATER_EQUAL;
}

Val_Tacky :: struct {
    type: enum { CONSTANT; VARIABLE; };
    as: union {
        constant: int;
        variable: string;
    };
}

Tacky_Ctx :: struct {
    temp_var_index: int = 0;
    label_index: int = 0;
}

gen_program_tacky :: (program_ast: *Program_Ast, do_print: bool = false) -> *Program_Tacky {
    tc : Tacky_Ctx;
    fn := gen_fn_tacky(*tc, program_ast.fn);
    program := New(Program_Tacky);
    program.* = .{ fn };

    if do_print {
        writer := make_stdout_writer();
        print_tacky(program, *writer);
    }

    return program;
}

gen_fn_tacky :: (tc: *Tacky_Ctx, fn_ast: *Fn_Ast) -> Fn_Tacky {
    instructions: [..]Instruction_Tacky;
    gen_instructions(tc, *instructions, fn_ast.block);

    has_return := false;
    for instructions  {
        if (it.type == .RETURN) { 
            has_return = true; 
            break;
        }
    }
    if !has_return array_add(*instructions, .{.RETURN, .{ret = .{.CONSTANT, .{constant = 0}}}});

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
    if (decl_ast.init == null) {
        // if we only have declaration without any initializer, we can skip it as it has already fulfilled its purpose
        return;
    }
    result := gen_instructions(tc, instructions, decl_ast.init);
    dst := Val_Tacky.{.VARIABLE, .{ variable = decl_ast.ident}};
    array_add(instructions, .{.COPY, .{copy = .{src = result, dst = dst}}});
}

gen_instructions :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, stmt_ast: *Stmt_Ast) {
    if #complete stmt_ast.type == {
        case .DEFAULT;
            label := stmt_ast.as.default;
            default_label := Instruction_Tacky.{.LABEL, .{label = label }};
            array_add(instructions, default_label);
        case .CASE;
            label := stmt_ast.as.case_stmt.label;
            case_label := Instruction_Tacky.{.LABEL, .{label = label }};
            array_add(instructions, case_label);
        case .RETURN;
            src := gen_instructions(tc, instructions, stmt_ast.as.return_stmt.expr);
            array_add(instructions, .{.RETURN, .{ret = src}});
        case .SWITCH;
            gen_instructions_for_switch(tc, instructions, stmt_ast.as.switch);
        case .EXPR;
            gen_instructions(tc, instructions, stmt_ast.as.expr);
        case .IF;
            if_stmt := stmt_ast.as.if_stmt;

            if if_stmt.else_block == null {
                if_end_label := make_label(tc, "if_end");
                condition := gen_instructions(tc, instructions, if_stmt.condition);

                array_add(instructions, .{ .JUMP_IF_ZERO, .{ jump_if_zero = .{ condition, if_end_label.as.label } } });

                gen_instructions(tc, instructions, if_stmt.if_block);

                array_add(instructions, if_end_label);
            } else {
                if_end_label := make_label(tc, "if_end");
                else_label := make_label(tc, "else");

                condition := gen_instructions(tc, instructions, if_stmt.condition);

                array_add(instructions, .{ .JUMP_IF_ZERO, .{ jump_if_zero = .{ condition, else_label.as.label } } });

                gen_instructions(tc, instructions, if_stmt.if_block);
                array_add(instructions, .{.JUMP, .{jump = if_end_label.as.label}});

                array_add(instructions, else_label);
                gen_instructions(tc, instructions, if_stmt.else_block);

                array_add(instructions, if_end_label);
            }
        case .LABEL;
            label := stmt_ast.as.label;
            goto_label := Instruction_Tacky.{.LABEL, .{label = label }};
            array_add(instructions, goto_label);
        case .GOTO;
            goto := stmt_ast.as.goto;
            array_add(instructions, .{.JUMP, .{ jump = goto }});
        case .COMPOUND;
            gen_instructions(tc, instructions, stmt_ast.as.compound);
        case .FOR;
            for_stmt := stmt_ast.as.for_stmt;
            loop_start_label := tprint("%_start", for_stmt.label);
            loop_end_label := tprint("%_end", for_stmt.label);

            if #complete for_stmt.init.type == {
                case .INIT_DECL;
                    gen_instructions_decl(tc, instructions, for_stmt.init.as.decl);
                case .INIT_EXPR;
                    if for_stmt.init.as.expr != null {
                        gen_instructions(tc, instructions, for_stmt.init.as.expr);
                    }
            }
            array_add(instructions, .{.LABEL, .{label = loop_start_label}});

            if for_stmt.condition != null {
                condition := gen_instructions(tc, instructions, for_stmt.condition);
                array_add(instructions, .{ .JUMP_IF_ZERO, .{ jump_if_zero = .{ condition, loop_end_label } } });
            }

            gen_instructions(tc, instructions, for_stmt.body);

            if for_stmt.post != null gen_instructions(tc, instructions, for_stmt.post);

            array_add(instructions, .{.JUMP, .{ jump = loop_start_label}});
            array_add(instructions, .{.LABEL, .{label = loop_end_label}});
        case .DO_WHILE;
            do_while_stmt := stmt_ast.as.do_while;
            loop_start_label := tprint("%_start", do_while_stmt.label);
            loop_end_label := tprint("%_end", do_while_stmt.label);

            array_add(instructions, .{.LABEL, .{label = loop_start_label}});

            gen_instructions(tc, instructions, do_while_stmt.body);

            condition := gen_instructions(tc, instructions, do_while_stmt.condition);
            array_add(instructions, .{ .JUMP_IF_NOT_ZERO, .{ jump_if_not_zero = .{ condition, loop_start_label } } });

            array_add(instructions, .{.LABEL, .{label = loop_end_label}});
        case .WHILE;
            while_stmt := stmt_ast.as.while_stmt;
            loop_start_label := tprint("%_start", while_stmt.label);
            loop_end_label := tprint("%_end", while_stmt.label);

            array_add(instructions, .{.LABEL, .{label = loop_start_label}});

            condition := gen_instructions(tc, instructions, while_stmt.condition);
            array_add(instructions, .{ .JUMP_IF_ZERO, .{ jump_if_zero = .{ condition, loop_end_label } } });

            gen_instructions(tc, instructions, while_stmt.body);

            array_add(instructions, .{.JUMP, .{ jump = loop_start_label}});

            array_add(instructions, .{.LABEL, .{label = loop_end_label}});
        case .BREAK;
            break_stmt := stmt_ast.as.break_stmt;
            loop_end_label := tprint("%_end",break_stmt);
            array_add(instructions, .{.JUMP, .{ jump = loop_end_label }});
        case .CONTINUE;
            continue_stmt := stmt_ast.as.continue_stmt;
            loop_start_label := tprint("%_start", continue_stmt);
            array_add(instructions, .{.JUMP, .{ jump = loop_start_label }});
        case .NULL;
                // pass through - nothing to do when null stmt is received
    }
}

gen_instructions :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, expr_ast: *Expr_Ast) -> dst: Val_Tacky {
    val := gen_instructions_expr(tc, instructions, expr_ast);
    return gen_inst_for_possible_postfix(tc, instructions, expr_ast, val);
}

gen_instructions_for_switch:: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, switch_ast: Switch_Stmt_Ast) {
    s_expr := switch_ast.condition;

    // @note
    // Add jump instruction for all cases first
    // We still don't emit the instruction for each case

    // handle non-default first
    for switch_ast.cases_label {
        if it.is_default continue;

        // we create an expression to check if matches case we have
        constant_expr := create_constant_expr(string_to_int(it.value), 0, 0);
        condition_expr_ast := create_binary_expr(.EQUAL_EQUAL, s_expr, constant_expr, 0, 0);
        defer free(condition_expr_ast);

        // we gen the instruction for the expr we created
        // if it mathces, we jump the the case label
        condition := gen_instructions(tc, instructions, condition_expr_ast);
        array_add(instructions, .{ .JUMP_IF_ZERO, .{ jump_if_zero = .{ condition, it.label } } });
    }
    // handling default case separately as this is if nothing matches
    for switch_ast.cases_label {
        if !it.is_default continue;
        default_label := it.label;
        array_add(instructions, .{.JUMP, .{ jump = default_label }});
    }

    // by this point we have added required jump instructions to correct cases
    // if nothing maches we need to go to end to the switch
    switch_end_label := make_label(tc, "switch_end");
    array_add(instructions, .{.JUMP, .{  jump = switch_end_label.as.label }});

    // now add instruction for all cases
    gen_instructions(tc, instructions, switch_ast.body);

    // this is to mark end of switch to jump if nothing matches
    array_add(instructions, switch_end_label);
}

gen_instructions_expr :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, expr_ast: *Expr_Ast) -> dst: Val_Tacky {
    if #complete expr_ast.type == {
        case .UNARY;
            src := gen_instructions(tc, instructions, expr_ast.as.unary.expr);
            dst := make_var(tc);
            op : Unary_Op_Type_Tacky = ---;
            if #complete expr_ast.as.unary.op == {
                case .BITWISE_NOT; op = .BITWISE_NOT;
                case .NEGATE ; op = .NEGATE;
                case .NOT; op = .NOT; 
            }; 
            array_add(instructions, .{.UNARY, .{unary = .{op, src, dst}}});
            return dst;
        case .BINARY;
            bin_ast := expr_ast.as.binary;
            if bin_ast.op == {
                case .AND; 
                    return gen_logical_and_instruction(tc, instructions, bin_ast);
                case .OR;
                    return gen_logical_or_instruction(tc, instructions, bin_ast);
                case;
                    src1 := gen_instructions(tc, instructions, bin_ast.left);
                    src2 := gen_instructions(tc, instructions, bin_ast.right);
                    dst := make_var(tc);
                    op := from_ast_binop_to_tacky(bin_ast.op);
                    array_add(instructions, .{.BINARY, .{binary= .{op, src1, src2, dst}}});
                    return dst;
            }
        case .GROUP;
            return gen_instructions(tc, instructions, expr_ast.as.group);
        case .CONSTANT;
            return .{.CONSTANT, .{constant = expr_ast.as.constant}};
        case .VAR;
            expr_value := Val_Tacky.{.VARIABLE, .{variable = expr_ast.as.var}};
            // return gen_inst_for_possible_postfix(tc, instructions, expr_ast, expr_value);
            return expr_value;
        case .ASSIGNMENT; 
            result := gen_instructions(tc, instructions, expr_ast.as.assignment.src);

            if expr_ast.as.assignment.dst.type != .VAR assert(false, "What!! dst has to be variable. sema didn't catch this!!! : %", expr_ast.as.assignment.dst);

            dst := Val_Tacky.{.VARIABLE, .{ variable = expr_ast.as.assignment.dst.as.var}};
            array_add(instructions, .{.COPY, .{copy = .{src = result, dst = dst}}});
            return dst;
        case .CONDITIONAL;
            ternary := expr_ast.as.conditional;
            result : Val_Tacky = ---;

            ternary_end := make_label(tc, "ternary_end");
            ternary_else := make_label(tc, "ternary_else");

            condition := gen_instructions(tc, instructions, ternary.condition);

            array_add(instructions, .{ .JUMP_IF_ZERO, .{ jump_if_zero = .{ condition, ternary_else.as.label } } });

            { // true
                result = gen_instructions(tc, instructions, ternary.true_block);
                array_add(instructions, .{.JUMP, .{jump = ternary_end.as.label}});
            }

            { // false
                array_add(instructions, ternary_else);
                result = gen_instructions(tc, instructions, ternary.false_block);
            }
            //  array_add(instructions, .{.COPY, .{copy = .{src = result, dst = dst}}});
            array_add(instructions, ternary_end); 
            return result;
    }
}

gen_inst_for_possible_postfix :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, expr_ast: *Expr_Ast, expr_val_tacky: Val_Tacky) -> Val_Tacky {
    if (expr_ast.postfix == .NONE) return expr_val_tacky;
    old_value_dst := make_var(tc);
    old_value := Instruction_Tacky.{.COPY, .{copy = .{src = expr_val_tacky, dst = old_value_dst }}};
    array_add(instructions, old_value);

    one := Val_Tacky.{.CONSTANT, .{constant = 1 }};
    if #complete expr_ast.postfix == {
        case .INCR; 
            dst := make_var(tc);
            array_add(instructions, .{.BINARY, .{binary= .{ .ADD, expr_val_tacky, one, dst}}});
            array_add(instructions, .{.COPY, .{copy = .{src = dst, dst = expr_val_tacky}}});
        case .DECR; 
            dst := make_var(tc);
            array_add(instructions, .{.BINARY, .{binary= .{ .SUB, expr_val_tacky, one, dst}}});
            array_add(instructions, .{.COPY, .{copy = .{src = dst, dst = expr_val_tacky}}});
        case .NONE; assert(false, "unreachable");
    }
    return old_value_dst;
}

gen_logical_and_instruction :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, bin_ast: type_of(Expr_Ast.as.binary)) -> Val_Tacky {
    label_false := make_label(tc, tprint("cond_%", "false"));

    src1 := gen_instructions(tc, instructions, bin_ast.left);
    array_add(instructions, .{.JUMP_IF_ZERO, .{jump_if_zero = .{src1, label_false.as.label}}});

    src2 := gen_instructions(tc, instructions, bin_ast.right);
    array_add(instructions, .{.JUMP_IF_ZERO, .{jump_if_zero = .{src2,label_false.as.label}}});

    result_var := make_var(tc);
    one := Val_Tacky.{.CONSTANT, .{constant = 1 }};
    array_add(instructions, .{.COPY, .{copy = .{one, result_var}}});

    label_end := make_label(tc, "logical_cmp_end");

    array_add(instructions,.{.JUMP, .{jump = label_end.as.label}});
    array_add(instructions, label_false);

    zero := Val_Tacky.{.CONSTANT, .{constant = 0 }};
    array_add(instructions, .{.COPY, .{copy = .{zero, result_var}}});

    array_add(instructions, label_end);

    return result_var;
}

gen_logical_or_instruction :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, bin_ast: type_of(Expr_Ast.as.binary)) -> Val_Tacky {
    label_false := make_label(tc, tprint("cond_%", "true"));

    src1 := gen_instructions(tc, instructions, bin_ast.left);
    array_add(instructions, .{.JUMP_IF_NOT_ZERO, .{jump_if_not_zero = .{src1, label_false.as.label}}});

    src2 := gen_instructions(tc, instructions, bin_ast.right);
    array_add(instructions, .{.JUMP_IF_NOT_ZERO, .{jump_if_not_zero = .{src2,label_false.as.label}}});

    result_var := make_var(tc);
    one := Val_Tacky.{.CONSTANT, .{constant = 1 }};
    zero := Val_Tacky.{.CONSTANT, .{constant = 0 }};
    array_add(instructions, .{.COPY, .{copy = .{zero, result_var}}});

    label_end := make_label(tc, "logical_cmp_end");

    array_add(instructions,.{.JUMP, .{jump = label_end.as.label}});

    array_add(instructions, label_false);

    array_add(instructions, .{.COPY, .{copy = .{one, result_var}}});

    array_add(instructions, label_end);

    return result_var;
}

from_ast_binop_to_tacky :: (ast_op: type_of(Expr_Ast.as.binary.op)) -> type_of(Instruction_Tacky.as.binary.op) {
    if #complete ast_op == {
        case .ADD; return .ADD;
        case .SUB; return .SUB; 
        case .MUL; return .MUL;
        case .DIV; return .DIV;
        case .MOD; return .MOD;
        case .BITWISE_AND; return .BITWISE_AND;
        case .BITWISE_OR; return .BITWISE_OR;
        case .BITWISE_XOR; return .BITWISE_XOR;
        case .LEFT_SHIFT; return .LEFT_SHIFT;
        case .RIGHT_SHIFT; return .RIGHT_SHIFT;
        case .LESS_EQUAL; return .LESS_EQUAL;
        case .LESS; return .LESS;
        case .GREATER_EQUAL; return .GREATER_EQUAL;
        case .GREATER; return .GREATER;
        case .EQUAL_EQUAL; return .EQUAL_EQUAL;
        case .NOT_EQUAL; return .NOT_EQUAL;
        case .AND; #through;
        case .OR; 
            assert(false, "And and OR are not handled this way");
    }
    assert(false, "There are not other binary operator. What is this %", ast_op);
    return .MOD; // unreachable
}

make_var :: (tc : *Tacky_Ctx) -> Val_Tacky {
    defer tc.temp_var_index += 1;
    return .{.VARIABLE, .{variable = tprint("tmp.%",tc.temp_var_index) }};
}

make_label :: (tc : *Tacky_Ctx, label: string) -> Instruction_Tacky {
    defer tc.label_index += 1;
    return .{.LABEL, .{label = tprint("L_%.%",label, tc.label_index) }};
}