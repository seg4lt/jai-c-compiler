
Program_Asm :: struct {
    fn: Fn_Asm;
}
Fn_Asm :: struct {
    ident: string;
    instructions: []Instruction_Asm;
}
Instruction_Asm :: struct {
    type : enum {MOV; UNARY; ALLOCATE_STACK; RET;};
    as: union {
        mov: struct {src: Operand_Asm; dst: Operand_Asm;};
        unary: struct {op: Unary_Op_Asm; operand: Operand_Asm;}
        allocate_stack: int;
        // ret : no value needed
    };
}
Operand_Asm :: struct {
    type: enum {IMM; REG; PSEUDO; STACK;};
    as: union {
        imm: int;
        reg: Reg_Asm;
        pseudo: string;
        stack: int;
    }; 
};
Unary_Op_Asm :: enum { NEG; NOT; }
Reg_Asm :: enum { AX; R10; }

asm_gen :: (pgt: *Program_Tacky) -> *Program_Asm {
    pasm_st_1 := asm_gen_state_1(pgt);
}

asm_gen_state_1 :: (pgt: *Program_Tacky) -> *Program_Asm {
    pg := New(Program_Asm);
    fn := asm_gen_fn(pgt.fn);
    pg.* = .{fn};
    print_asm(pg, 1);
    return pg;
}

asm_gen_fn :: (fnt: *Fn_Tacky) -> Fn_Asm {
    instructions : [..]Instruction_Asm;

    for fnt.instructions asm_gen_inst(*instructions, it);

    // fn := New(Fn_Asm);
    // fn.* = .{fnt.ident, instructions};
    // return fn;
    return .{fnt.ident, instructions};
}

asm_gen_inst :: (insts: *[..]Instruction_Asm, instt: *Instruction_Tacky) {
    if #complete instt.type == {
        case .RETURN;
            src := asm_gen_val_to_operand(instt.as.ret);
            dst := Operand_Asm.{.REG, .{ reg = .AX}};
            array_add(insts, .{.MOV,.{ mov = .{ src, dst }}});
            array_add(insts, .{ .RET, .{} }); 
        case .UNARY;
            src := asm_gen_val_to_operand(instt.as.unary.src);
            dst := asm_gen_val_to_operand(instt.as.unary.dst);
            array_add(insts, .{.MOV,.{ mov = .{ src, dst }}});
            op: Unary_Op_Asm = ---;
            if #complete instt.as.unary.op == {
                case .BITWISE_NOT; op = .NOT;
                case .NEGATE; op = .NEG;
            }
            array_add(insts, .{ .UNARY, .{unary = .{op, dst}}});  
    }
}

asm_gen_val_to_operand :: (using val: *Val_Tacky) -> Operand_Asm {
     if #complete type == {
        case .CONSTANT;
            return .{.IMM, .{ imm = as.constant }};
        case .VARIABLE;
            return .{.PSEUDO, .{ pseudo = as.variable }};
    }
}

print_asm :: (pg: *Program_Asm, stage: int) {
    print("\n\n---- ASM GEN % --- \n", stage);
    print(".program\n");
    print_asm_fn(pg.fn);
}

print_asm_fn :: (fn: Fn_Asm) {
    print(".%:\n", fn.ident);
    for fn.instructions print_asm_inst(it);
}

print_asm_inst :: (inst: Instruction_Asm) {
    print("    ");

    if #complete inst.type == {
        case .MOV;
            print("% ", inst.type);
            print_asm_operand(inst.as.mov.src);
            print(", ");
            print_asm_operand(inst.as.mov.dst);
            print("\n");
        case .UNARY;
            print("% ", inst.as.unary.op);
            print_asm_operand(inst.as.unary.operand);
            print("\n");
        case .RET;
            print("%",inst.type);
            print("\n");
        case .ALLOCATE_STACK;
            assert(false, "not implemented yet");
    }
}
print_asm_operand :: (operand: Operand_Asm) {
    if #complete operand.type == {
        case .IMM;
            print("imm(%)", operand.as.imm);
        case .REG;
            print("reg(%)", operand.as.reg);
        case .PSEUDO;
            print("pseudo(%)",operand.as.pseudo);
        case .STACK;
            assert(false, "not implemented");
    }
}

/*
program              = Program(function_definition)
function_definition  = Function(identifier name, instruction* instructions)
instruction          = Mov(operand src, operand dst)
                       | Unary(unary_operator, operand)
                       | AllocateStack(int)
                       | Ret
unary_operator       = Neg | Not
operand              = Imm(int) | Reg(reg) | Pseudo(identifier) | Stack(int)
reg                  = AX | R10

*/