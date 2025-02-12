asm_gen :: (ast: *Ast_Node) -> *Asm_Construct {
    if #complete ast.type == {
        case .PROGRAM; 
            fn := asm_gen(ast.as.program.fn);
            ac := New(Asm_Construct);
            ac.* = .{ type = .PROGRAM, as = .{ program = .{ fn = fn} }};
            print("--- AsmGen --- \n");
            gen_asm_print(ac);
            return ac;
        case .FN;  return asm_gen_fn(ast.as.fn);
        case .STMT; return asm_gen_stmt(ast.as.stmt);
        case .EXPR; #through;
        case; assert(false, "generate asm %", ast.type);
    }
    assert(false, "when case program hit all things should be consumed");
    return null;
}

asm_gen_fn :: (fn: Fn_Ast_Node) -> *Asm_Construct {
    fc: Fn_Asm_Construct;
    fc.name = fn.name;

    instructions: [..]Instruction_Asm_Construct;
    for body: fn.body {
        ret_ac := asm_gen(body);
        if ret_ac.type == {
            case .INSTRUCTION_LIST;
                for ret_ac.as.instruction_list  {
                    array_add(*instructions, it);
                }
            case .INSTRUCTION;
                    array_add(*instructions, ret_ac.as.instruction);
            case; 
                assert(false, "Function generate_asm should only return instruction or instruction list. Found %", ret_ac.*);
        }
    }

    ilist := New(Asm_Construct);
    ilist.* = .{type = .INSTRUCTION_LIST, as = .{ instruction_list = instructions}};
    fc.instruction_list = ilist;
    ac := New(Asm_Construct);
    ac.* = .{type = .FUNCTION, as = .{ fn = fc}};
    return ac;
}

asm_gen_stmt :: (using stmt_ast: Stmt_Ast_Node) -> *Asm_Construct {
    if #complete type == {
        case .RETURN;
            return asm_gen_return_stmt(as.return_stmt);
        case;
            assert(false, "Uknonw statement: %", type);
            return null;
    }
}

asm_gen_return_stmt :: (return_stmt: Return_Stmt) -> *Asm_Construct {
    if type != .INT_VALUE {
        assert(false, "return value must be integer. Found %", value);
    }
    ret_value := value.as.int_value;
    src := Asm_Operand.{type = .IMM, as = .{ imm = .{ value = ret_value }}};
    dest := Asm_Operand.{type = .REGISTER, as = .{ register = .EAX }};

    insts: [..]Instruction_Asm_Construct;
    array_add(*insts, .{type = .MOV, as = .{ mov = .{src, dest}}});
    array_add(*insts,.{ type = .RET });

    rt := New(Asm_Construct);
    rt.type = .INSTRUCTION_LIST;
    rt.as.instruction_list = insts; 
    // ins_list : [..]*Asm_Construct;
    return rt;
}

Asm_Construct_Type :: enum {
    PROGRAM;
    FUNCTION;
    INSTRUCTION_LIST;
    INSTRUCTION;
}

Asm_Construct :: struct {
    type: Asm_Construct_Type;
    as: union {
        program: Program_Asm_Construct;
        fn: Fn_Asm_Construct;
        instruction_list: []Instruction_Asm_Construct;
        instruction: Instruction_Asm_Construct;
    };
}

Program_Asm_Construct :: struct {
    fn: *Asm_Construct;
}

Fn_Asm_Construct :: struct {
    name: string;
    instruction_list: *Asm_Construct;
}

Asm_Instruction_Type :: enum {
    MOV; RET;
}

Instruction_Asm_Construct :: struct {
    type: Asm_Instruction_Type;
    as: union {
        mov: Mov_Instruction;
        // ret # no need to store value for ret
    };
}

Mov_Instruction :: struct {
    src: Asm_Operand;
    dst: Asm_Operand;
}
Asm_Operand_Type :: enum {
    IMM; REGISTER;
}

Asm_Operand :: struct {
    type: Asm_Operand_Type;
    as: union {
        imm: Imm_Operand;
        register: Register;
    };
}

Imm_Operand :: struct {
    value: int;
}

Register :: enum {
    EAX;
}

#scope_file
gen_asm_print :: (node: *Asm_Construct, depth: int = 0) {
    if node == null return;
    if #complete node.type == {
        case .PROGRAM;
            print("program: \n");
            gen_asm_print(node.as.program.fn, depth + 1);
        case .FUNCTION;
            print("%:\n", node.as.fn.name);
            gen_asm_print(node.as.fn.instruction_list, depth + 1);
        case .INSTRUCTION_LIST;
            for node.as.instruction_list  {
                print("\t");
                asm_print_inst(it, depth + 1);
                print("\n");
            }
        case .INSTRUCTION;
            print("\t");
            asm_print_inst(node.as.instruction, depth + 1);
            print("\n");
    }
}
asm_print_inst :: (node: Instruction_Asm_Construct, depth: int = 0) {
    if #complete node.type == {
        case .MOV; 
            print ("mov        %, %", asm_format_operand(node.as.mov.src), asm_format_operand(node.as.mov.dst));
        case .RET; print("ret");
    }
}
asm_format_operand :: (op: Asm_Operand) -> string {
    if #complete op.type == {
        case .IMM; return tprint("$%", op.as.imm.value);
        case .REGISTER; return asm_format_register(op.as.register);
    }
}
asm_format_register :: (r: Register) -> string {
    if #complete r == {
        case .EAX; return "%eax";
    }
}
#scope_export
