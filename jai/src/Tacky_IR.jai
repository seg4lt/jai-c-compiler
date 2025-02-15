
Program_Tacky :: struct {
    fn: *Fn_Tacky;
}

Fn_Tacky :: struct {
    ident: string;
    instructions: []*Instruction_Tacky;
}

Instruction_Tacky :: struct {
    type: enum { RETURN; UNARY;};
    as : union {
        ret: *Val_Tacky;
        unary: struct { op: Unary_Op_Type_Tacky; src: *Val_Tacky; dst: *Val_Tacky;}
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

gen_fn_tacky :: (tc: *Tacky_Ctx, fn_ast: *Fn_Ast_Node) -> *Fn_Tacky {
    instructions: [..]*Instruction_Tacky;
    gen_instructions(tc, *instructions, fn_ast.body);
    fn := New(Fn_Tacky);
    fn.* = .{ fn_ast.ident, instructions };
    return fn;
}

gen_instructions :: (tc: *Tacky_Ctx, instructions: *[..]*Instruction_Tacky, stmt_ast: *Stmt_Ast_Node) {
    if #complete stmt_ast.type == {
        case .RETURN;
            src := gen_instructions(tc, instructions, stmt_ast.as.return_stmt.expr);
            ret := New(Instruction_Tacky);
            ret .* = .{.RETURN, .{ret = src}};
            array_add(instructions, ret);
    }
}

gen_instructions :: (tc: *Tacky_Ctx, instructions: *[..]*Instruction_Tacky, expr_ast: *Expr_Ast_Node) -> dst: *Val_Tacky {
    if #complete expr_ast.type == {
        case .UNARY;
            src := gen_instructions(tc, instructions, expr_ast.as.unary.expr);
            dst := make_var(tc);
            op : Unary_Op_Type_Tacky = ---;
            if #complete expr_ast.as.unary.op == {
                case .BITWISE_NOT; op = .BITWISE_NOT;
                case .NEGATE ; op = .NEGATE;
            }; 
            unary := New(Instruction_Tacky);
            unary.* = .{.UNARY, .{unary = .{op, src, dst}}};
            array_add(instructions, unary);
            return dst;
        case .GROUP;
            return gen_instructions(tc, instructions, expr_ast.as.group);
        case .CONSTANT;
            var := New(Val_Tacky);
            var.* = .{.CONSTANT, .{constant = expr_ast.as.constant}};
            return var; 
    }
}

make_var :: (tc : *Tacky_Ctx) -> *Val_Tacky {
    var := New(Val_Tacky);
    defer tc.temp_var_index += 1;
    var.* = .{.VARIABLE, .{variable = tprint("tmp.%",tc.temp_var_index) }};
    return var;
}

print_tacky :: (program: *Program_Tacky) {
    print("\n\n-- Tacky --\n");
    print("    .program\n");
    print_tacky_fn(program.fn);
}

print_tacky_fn :: (fn: *Fn_Tacky) {
    print(".%:", fn.ident);
    for fn.instructions print_tacky_inst(it);
}

print_tacky_inst :: (inst: *Instruction_Tacky) {
    print("\n    ");
    if #complete inst.type == {
        case .RETURN;
            print("Return(");
            print_tacky_val(inst.as.ret);
            print(")");
        case .UNARY;
            print("Unary(op: %", inst.as.unary.op);
            print(", src: ");
            print_tacky_val(inst.as.unary.src);
            print(", dst: ");
            print_tacky_val(inst.as.unary.dst);
            print(")");
    }
}

print_tacky_val :: (val: *Val_Tacky) {
    if #complete val.type == {
        case .CONSTANT; print("Constant(%)", val.as.constant);
        case .VARIABLE; print("Var(%)", val.as.variable);
    }
}

// Unary(Complement, Constant(2), Var("tmp.0")) 
// Return(Var("tmp.0"))

// Unary(Negate, Constant(8), Var("tmp.0")) 
// Unary(Complement, Var("tmp.0"), Var("tmp.1")) 
// Unary(Negate, Var("tmp.1"), Var("tmp.2")) 
// Return(Var("tmp.2"))


/* -- ADSL for TACKY IR -- 

program             = Program(function_definition)
function_definition = Function(identifier, instruction* body)
instruction         = Return(val) | Unary(unary_operator, val src, val dst)
val                 = Constant(int) | Var(identifier)
unary_operator      = Complement | Negate

*/

