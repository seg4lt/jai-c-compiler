
Program_Asm :: struct {
    fn: Fn_Asm;
}
Fn_Asm :: struct {
    ident: string;
    instructions: [..]Instruction_Asm;
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
    print_asm(pasm_st_1, 1);
    stack_size := asm_gen_stage_2(pasm_st_1.fn.instructions);
    print("\n Stack Size: %\n", stack_size);
    print_asm(pasm_st_1, 2);

    new_insts := asm_gen_stage_3(pasm_st_1.fn.instructions, stack_size);
    pasm_st_1.fn.instructions = new_insts;
    print_asm(pasm_st_1, 3);
    return pasm_st_1;
}

asm_gen_state_1 :: (pgt: *Program_Tacky) -> *Program_Asm {
    pg := New(Program_Asm);
    fn := asm_gen_fn(pgt.fn);
    pg.* = .{fn};
    return pg;
}

// replace pseudo register, with offset relative to stack
asm_gen_stage_2 :: (insts: []Instruction_Asm) -> stack_size: int {
    table : Hash_Table.Table(string, int);
    Hash_Table.init(*table);
    defer Hash_Table.deinit(*table);

    for *inst: insts {
        if inst.type == {
        case .MOV;
           mov := inst.as.mov;
           mov.src = asm_gen_stage_2_stack_offset(*table, mov.src);
           mov.dst = asm_gen_stage_2_stack_offset(*table, mov.dst);
           inst.* = .{.MOV,.{mov = mov}};
        case .UNARY;
           un := inst.as.unary;
           un.operand = asm_gen_stage_2_stack_offset(*table, un.operand);
           inst.* = .{.UNARY,.{unary=un}};
        }
    }
    final_offset := (table.count * -4);
    return final_offset;
}

asm_gen_stage_2_stack_offset :: (table: *Hash_Table.Table, op: Operand_Asm) -> Operand_Asm {
    if op.type != .PSEUDO return op;

    saved_offset, success := Hash_Table.table_find(table, op.as.pseudo);
    if success return .{.STACK, .{ stack = saved_offset }};

    offset := (table.count + 1) * -4;
    Hash_Table.table_add(table, op.as.pseudo, offset);
    return .{.STACK,  .{stack=offset}};
}

// 1. Add number of bytes a stack needs to store all variable
// 2. If any instructions have two address pointer, dividing them in two to use R10 register.
asm_gen_stage_3 :: (old_insts: []Instruction_Asm, stack_size: int) -> [..]Instruction_Asm {
    insts : [..]Instruction_Asm;
    array_add(*insts, .{.ALLOCATE_STACK, .{allocate_stack = stack_size}});

    for oi: old_insts {
        if #complete oi.type == {
            case .MOV;
                if oi.as.mov.src.type == .STACK && oi.as.mov.dst.type == .STACK {
                    array_add(*insts, .{.MOV, .{mov = .{src = oi.as.mov.src, dst = .{.REG,.{reg = .R10}}}}});
                    array_add(*insts, .{.MOV, .{mov = .{src= .{.REG,.{reg = .R10}}, dst = oi.as.mov.dst}}});
                } else {
                    array_add(*insts, oi);
                }
            case .UNARY; #through;
            case .ALLOCATE_STACK; #through;
            case .RET;
                array_add(*insts, oi);
        }
    }
    return insts;
}


asm_gen_fn :: (fnt: *Fn_Tacky) -> Fn_Asm {
    instructions : [..]Instruction_Asm;
    for fnt.instructions asm_gen_inst(*instructions, it);
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
            print("ASTK %", inst.as.allocate_stack);
            print("\n");
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
            print("stack(%)", operand.as.stack);
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

#scope_file
Hash_Table :: #import "Hash_Table";
#scope_export