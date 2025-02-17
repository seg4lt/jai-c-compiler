
Program_Tacky :: struct {
    fn: Fn_Tacky;
}

Fn_Tacky :: struct {
    ident: string;
    instructions: []Instruction_Tacky;
}

Instruction_Tacky :: struct {
    type: enum { RETURN; UNARY; BINARY;};
    as : union {
        ret: Val_Tacky;
        unary: struct { op: Unary_Op_Type_Tacky; src: Val_Tacky; dst: Val_Tacky;}
        binary: struct { op: enum {ADD;SUB;MUL;DIV;MOD;BITWISE_AND;BITWISE_OR;BITWISE_XOR;LEFT_SHIFT;RIGHT_SHIFT;}; src1: Val_Tacky; src2: Val_Tacky; dst: Val_Tacky; }
    };
}

Unary_Op_Type_Tacky :: enum {
  BITWISE_NOT; NEGATE;
}

Val_Tacky :: struct {
    type: enum { CONSTANT; VARIABLE; };
    as: union {
        constant: int;
        variable: string;
    };
}

Tacky_Ctx :: struct {
    temp_var_index : int = 0;
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
    gen_instructions(tc, *instructions, fn_ast.body);
    return .{ fn_ast.ident, instructions };
}

gen_instructions :: (tc: *Tacky_Ctx, instructions: *[..]Instruction_Tacky, stmt_ast: *Stmt_Ast_Node) {
    if #complete stmt_ast.type == {
        case .RETURN;
            src := gen_instructions(tc, instructions, stmt_ast.as.return_stmt.expr);
            array_add(instructions, .{.RETURN, .{ret = src}});
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
            }; 
            array_add(instructions, .{.UNARY, .{unary = .{op, src, dst}}});
            return dst;
        case .BINARY;
            bin_ast := expr_ast.as.binary;
            src1 := gen_instructions(tc, instructions, bin_ast.left);
            src2 := gen_instructions(tc, instructions, bin_ast.right);
            dst := make_var(tc);
            op := from_ast_binop_to_tacky(bin_ast.op);
            array_add(instructions, .{.BINARY, .{binary= .{op, src1, src2, dst}}});
            return dst;
        case .GROUP;
            return gen_instructions(tc, instructions, expr_ast.as.group);
        case .CONSTANT;
            return .{.CONSTANT, .{constant = expr_ast.as.constant}};
    }
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
    }
    assert(false, "There are not other binary operator. What is this %", ast_op);
    return .MOD; // unreachable
}

make_var :: (tc : *Tacky_Ctx) -> Val_Tacky {
    defer tc.temp_var_index += 1;
    return .{.VARIABLE, .{variable = tprint("tmp.%",tc.temp_var_index) }};
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
val                 = Constant(int) | Var(identifier)
unary_operator      = Complement | Negate
binary_operator     = Add | Subtract | Multiply | Divide | Remainder 

*/