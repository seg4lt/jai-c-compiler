
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

gen_program_tacky :: (program_ast: *Program_Ast_Node) -> *Program_Tacky {
    tc : Tacky_Ctx;
    fn := gen_fn_tacky(*tc, program_ast.fn);
    program := New(Program_Tacky);
    program.* = .{ fn };
    print_tacky(program);
    return program;
}

gen_fn_tacky :: (tc: *Tacky_Ctx, fn_ast: *Fn_Ast_Node) -> Fn_Tacky {
    instructions: [..]Instruction_Tacky;
    for fn_ast.body {
        if #complete it.type == {
            case .STMT;
                gen_instructions(tc, *instructions, it.as.stmt);
            case .DECL;
                if (it.as.decl.init == null) {
                    // if we only have declaration without any initializer, we can skip it as it has already fulfilled its purpose
                    continue;
                }
                result := gen_instructions(tc, *instructions, it.as.decl.init);
                dst := Val_Tacky.{.VARIABLE, .{ variable = it.as.decl.ident}};
                array_add(*instructions, .{.COPY, .{copy = .{src = result, dst = dst}}});
        }
    }

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

gen_instructions :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, stmt_ast: *Stmt_Ast_Node) {
    if #complete stmt_ast.type == {
        case .RETURN;
            src := gen_instructions(tc, instructions, stmt_ast.as.return_stmt.expr);
            array_add(instructions, .{.RETURN, .{ret = src}});
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
        case .NULL;
                // pass through - nothing to do when null stmt is received
    }
}

gen_instructions :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, expr_ast: *Expr_Ast_Node) -> dst: Val_Tacky {
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
            return .{.VARIABLE, .{variable = expr_ast.as.var}};
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

gen_logical_and_instruction :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, bin_ast: type_of(Expr_Ast_Node.as.binary)) -> Val_Tacky {
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

gen_logical_or_instruction :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, bin_ast: type_of(Expr_Ast_Node.as.binary)) -> Val_Tacky {
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

from_ast_binop_to_tacky :: (ast_op: type_of(Expr_Ast_Node.as.binary.op)) -> type_of(Instruction_Tacky.as.binary.op) {
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

print_tacky :: (program: *Program_Tacky) {
    print("\n\n-- Tacky --\n");
    print("    .program\n");
    print_tacky_fn(*program.fn);
    print("\n");
}

print_tacky_fn :: (fn: *Fn_Tacky) {
    print(".%:", fn.ident);
    for fn.instructions print_tacky_inst(*it);
}

print_tacky_inst :: (inst: *Instruction_Tacky) {
    print("\n    ");
    if #complete inst.type == {
        case .RETURN;
            print("Return(");
            print_tacky_val(*inst.as.ret);
            print(")");
        case .UNARY;
            print("Unary(op: %", inst.as.unary.op);
            print(", src: ");
            print_tacky_val(*inst.as.unary.src);
            print(", dst: ");
            print_tacky_val(*inst.as.unary.dst);
            print(")");
        case .BINARY;
            print("Binary(op: %", inst.as.binary.op);
            print(", src1: ");
            print_tacky_val(*inst.as.binary.src1);
            print(", src2: ");
            print_tacky_val(*inst.as.binary.src2);
            print(", dst: ");
            print_tacky_val(*inst.as.binary.dst);
            print(")");
        case .LABEL;
            print("Label(%)", inst.as.label);
        case .JUMP_IF_NOT_ZERO; 
            print("JumpIfNotZero(condition: ");
            print_tacky_val(*inst.as.jump_if_zero.condition);
            print(", label: %", inst.as.jump_if_zero.ident);
            print(")");
        case .JUMP_IF_ZERO; 
            print("JumpIfZero(condition: ");
            print_tacky_val(*inst.as.jump_if_zero.condition);
            print(", label: %", inst.as.jump_if_zero.ident);
            print(")");
        case .COPY; 
            print("Copy(src: ");
            print_tacky_val(*inst.as.copy.src);
            print(", dst: ");
            print_tacky_val(*inst.as.copy.dst);
            print(")");
        case .JUMP;
            print("Jump(%)", inst.as.jump);
    }
}

print_tacky_val :: (val: *Val_Tacky) {
    if #complete val.type == {
        case .CONSTANT; print("Constant(%)", val.as.constant);
        case .VARIABLE; print("Var(%)", val.as.variable);
    }
}

/* -- ADSL for TACKY IR -- 

program             = Program(function_definition)
function_definition = Function(identifier, instruction* body)
instruction         = Return(val) 
                    | Unary(unary_operator, val src, val dst)
                    | Binary(binary_operator, val src1, val src2, val dst)
                    | Copy(val src, val dst)
                    | Jump(identifier target)
                    | JumpIfZero(val condition, identifier target)
                    | JumpIfNotZero(val condition, identifier target)
                    | Label(identifier)
val                 = Constant(int) | Var(identifier)
unary_operator      = Complement | Negate | Not
binary_operator     = Add | Subtract | Multiply | Divide | Remainder 
                    | And | Or
                    | Equal | Not Equal
                    | LessThan | LessOrEqual 
                    | GreaterThan | GreaterOrEqual 

*/