
Program_Asm :: struct {
    fn: Fn_Asm;
}
Fn_Asm :: struct {
    ident: string;
    instructions: [..]Instruction_Asm;
}
Instruction_Asm :: struct {
    type : enum {MOV; UNARY; BINARY; IDIV; CDQ; ALLOCATE_STACK; RET;};
    as: union {
        mov: struct {src: Operand_Asm; dst: Operand_Asm; };
        unary: struct {op: Unary_Op_Asm; operand: Operand_Asm; }
        binary: struct {op: enum {ADD;SUB;MUL;}; src1: Operand_Asm; src2: Operand_Asm; } // src2 = src2 + src1 is what will happen
        idiv: Operand_Asm; // DIV and MOD handled here because it involves more work
        allocate_stack: int;
        // cdq: no value needed
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
Reg_Asm :: enum { AX; DX; R10; R11; RSP; RBP; }

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
    fn := asm_gen_fn(*pgt.fn);
    pg.* = .{fn};
    return pg;
}

// replace pseudo register, with offset relative to stack
asm_gen_stage_2 :: (insts: []Instruction_Asm) -> stack_size: int {
    table : Hash_Table.Table(string, int);
    Hash_Table.init(*table);
    defer Hash_Table.deinit(*table);

    for *inst: insts {
        if #complete inst.type == {
            case .MOV;
                mov := inst.as.mov;
                mov.src = asm_gen_stage_2_stack_offset(*table, mov.src);
                mov.dst = asm_gen_stage_2_stack_offset(*table, mov.dst);
                inst.* = .{.MOV,.{mov = mov}};
            case .UNARY;
                un := inst.as.unary;
                un.operand = asm_gen_stage_2_stack_offset(*table, un.operand);
                inst.* = .{.UNARY,.{unary=un}};
            case .BINARY;
                bin := inst.as.binary;
                bin.src1 = asm_gen_stage_2_stack_offset(*table, bin.src1);
                bin.src2 = asm_gen_stage_2_stack_offset(*table, bin.src2);
                inst.* = .{.BINARY, .{binary=bin}};
            case .IDIV;
                div := asm_gen_stage_2_stack_offset(*table, inst.as.idiv);
                inst.* = .{.IDIV, .{idiv=div}};
            case .CDQ; #through;
            case .RET; #through;
            case .ALLOCATE_STACK; continue;
        }
    }
    stack_size := (table.count * -4);
    // making it positive as this is size of stack
    return -1 * stack_size;
}

asm_gen_stage_2_stack_offset :: (table: *Hash_Table.Table, op: Operand_Asm) -> Operand_Asm {
    if op.type != .PSEUDO return op;

    saved_offset, success := Hash_Table.table_find(table, op.as.pseudo);
    if success return .{.STACK, .{ stack = saved_offset }};

    offset := (table.count + 1) * -4;
    Hash_Table.table_add(table, op.as.pseudo, offset);
    return .{.STACK,  .{stack=offset}};
}

// Fix assembly instruction
asm_gen_stage_3 :: (old_insts: []Instruction_Asm, stack_size: int) -> [..]Instruction_Asm {
    insts : [..]Instruction_Asm;
    array_add(*insts, .{.ALLOCATE_STACK, .{allocate_stack = stack_size}});

    for oi: old_insts {
        if #complete oi.type == {
            case .MOV;
                if oi.as.mov.src.type == .STACK && oi.as.mov.dst.type == .STACK {
                    // both src and dst can't be memory address
                    ireg := Operand_Asm.{.REG,.{reg = .R10}};
                    array_add(*insts, .{.MOV, .{mov = .{src = oi.as.mov.src, dst = ireg }}});
                    array_add(*insts, .{.MOV, .{mov = .{src= ireg, dst = oi.as.mov.dst}}});
                } else {
                    array_add(*insts, oi);
                }
            case .IDIV;
                if oi.as.idiv.type == .IMM {
                    // idivl  $3
                    // -- to --
                    // movl   $3, %r10d
                    // idivl  %r10d
                    // idiv divisor can't be constant
                    intermediate_reg := Operand_Asm.{.REG,.{reg = .R10}};
                    array_add(*insts, .{.MOV, .{mov = .{oi.as.idiv, intermediate_reg}}});
                    array_add(*insts, .{.IDIV, .{idiv = intermediate_reg}});
                } else {
                    array_add(*insts, oi);
                }
            case .BINARY;
                if #complete oi.as.binary.op == {
                    case .ADD; #through;
                    case .SUB;
                        // both src and dst can't be memory address
                        // addl   -4(%rbp), -8(%rbp)
                        // -- to -- 
                        // movl   -4(%rbp), %r10d
                        // addl   %r10d, -8(%rbp)
                        ireg := Operand_Asm.{.REG,.{reg = .R10}};
                        array_add(*insts, .{.MOV, .{mov = .{oi.as.binary.src1, ireg }}});
                        array_add(*insts, .{.BINARY, .{binary = .{ oi.as.binary.op, ireg, oi.as.binary.src2}}});
                    case .MUL;
                        // imull  $3, -4(%rbp) // imull can't use memory address as its destination
                        // -- to --
                        // movl   -4(%rbp), %r11d
                        // imull  $3, %r11d
                        // movl   %r11d, -4(%rbp)
                        ireg := Operand_Asm.{.REG,.{reg = .R11}};
                        array_add(*insts, .{.MOV, .{mov = .{oi.as.binary.src2, ireg }}});
                        array_add(*insts, .{.BINARY, .{binary = .{oi.as.binary.op, oi.as.binary.src1, ireg }}});
                        array_add(*insts, .{.MOV, .{mov = .{ ireg, oi.as.binary.src2 }}});
                }
            case .UNARY; #through;
            case .ALLOCATE_STACK; #through;
            case .CDQ; #through;
            case .RET;
                array_add(*insts, oi);
        }
    }
    return insts;
}


asm_gen_fn :: (fnt: *Fn_Tacky) -> Fn_Asm {
    instructions : [..]Instruction_Asm;
    for fnt.instructions asm_gen_inst(*instructions, *it);
    return .{fnt.ident, instructions};
}

asm_gen_inst :: (insts: *[..]Instruction_Asm, instt: *Instruction_Tacky) {
    if #complete instt.type == {
        case .RETURN;
            src := asm_gen_val_to_operand(*instt.as.ret);
            dst := Operand_Asm.{.REG, .{ reg = .AX}};
            array_add(insts, .{.MOV,.{ mov = .{ src, dst }}});
            array_add(insts, .{ .RET, .{} }); 
        case .UNARY;
            src := asm_gen_val_to_operand(*instt.as.unary.src);
            dst := asm_gen_val_to_operand(*instt.as.unary.dst);
            array_add(insts, .{.MOV,.{ mov = .{ src, dst }}});
            op: Unary_Op_Asm = ---;
            if #complete instt.as.unary.op == {
                case .BITWISE_NOT; op = .NOT;
                case .NEGATE; op = .NEG;
            }
            array_add(insts, .{ .UNARY, .{unary = .{op, dst}}});  
        case .BINARY;
            basm := instt.as.binary;
            if #complete basm.op == {
                case .ADD; #through;
                case .SUB; #through;
                case .MUL;
                    src1 := asm_gen_val_to_operand(*basm.src1);
                    dst := asm_gen_val_to_operand(*basm.dst);
                    array_add(insts, .{.MOV,.{ mov = .{ src1, dst }}});

                    op := from_tacky_to_asm_binop(basm.op);
                    src2 := asm_gen_val_to_operand(*basm.src2);
                    array_add(insts, .{.BINARY, .{binary=.{op, src2, dst}}});
                case .DIV; #through;
                case .MOD;
                    // load divident to AX register
                    src1 := asm_gen_val_to_operand(*basm.src1);
                    fst_move_dst := Operand_Asm.{.REG, .{ reg = .AX}};
                    array_add(insts, .{.MOV,.{ mov = .{ src1, fst_move_dst }}});

                    // Sign-extend EAX into RDX;RAX
                    array_add(insts, .{.CDQ, .{}});

                    // perform IDIV with divident src2
                    src2 := asm_gen_val_to_operand(*basm.src2);
                    array_add(insts, .{.IDIV, .{idiv = src2}});

                    // move the result from specified register to dst
                    fin_mov_src : Operand_Asm = ---;
                    if basm.op == {
                        case .DIV; fin_mov_src = .{.REG, .{reg = .AX}};
                        case .MOD; fin_mov_src = .{.REG, .{reg = .DX}};
                        case; assert(false, "Div shouldn't get any other operator: %", basm.op);
                    }
                    fin_mov_dst := asm_gen_val_to_operand(*basm.dst);
                    array_add(insts, .{.MOV,.{ mov = .{ fin_mov_src, fin_mov_dst}}});
            }
    }
}

from_tacky_to_asm_binop :: (tacky_op: type_of(Instruction_Tacky.as.binary.op)) -> type_of(Instruction_Asm.as.binary.op) {
    if #complete tacky_op == {
        case .ADD; return .ADD;
        case .SUB; return .SUB;
        case .MUL; return .MUL;
        case .DIV; #through;
        case .MOD; 
            assert(false, "Other binary operator are either handled differently, or not supported: %", tacky_op);
            return .MUL; // unreachable;
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
            print("% ",inst.type);
            print("\n");
        case .ALLOCATE_STACK;
            print("ASTK %", inst.as.allocate_stack);
            print("\n");
        case .CDQ;
            print("CDQ ");
            print("\n");
        case .BINARY;
            print("% ", inst.as.binary.op);
            print_asm_operand(inst.as.binary.src1);
            print(", ");
            print_asm_operand(inst.as.binary.src2);
            print("\n");
        case .IDIV;
            print("IDIV ");
            print_asm_operand(inst.as.idiv);
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

/* ADSL ASM_GEN
program              = Program(function_definition)
function_definition  = Function(identifier name, instruction* instructions)
instruction          = Mov(operand src, operand dst)
                       | Unary(unary_operator, operand)
                       | Binary(binary_operator, operand, operand)
                       | Idiv(operand)
                       | Cdq
                       | AllocateStack(int)
                       | Ret
unary_operator       = Neg | Not
operand              = Imm(int) | Reg(reg) | Pseudo(identifier) | Stack(int)
reg                  = AX | DX | R10 | R11 | RSP | RBP

*/

#scope_file
Hash_Table :: #import "Hash_Table";
#scope_export