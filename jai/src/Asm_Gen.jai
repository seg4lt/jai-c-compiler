
Program_Asm :: struct {
    fn: Fn_Asm;
}
Fn_Asm :: struct {
    ident: string;
    instructions: [..]Instruction_Asm;
}
Instruction_Asm :: struct {
    type : Instruction_Asm_Type;
    as: union {
        mov: struct {src: Operand_Asm; dst: Operand_Asm;};
        unary: struct {op: Unary_Op_Asm; operand: Operand_Asm;}
        binary: struct {op: Bin_Op_Asm; src1: Operand_Asm; src2: Operand_Asm;} 
        idiv: Operand_Asm;
        cmp: struct {op1: Operand_Asm; op2: Operand_Asm;};
        jmp: string;
        jmp_cc: struct {cond_code: Cond_Code_Asm; ident: string;};
        set_cc: struct {cond_code: Cond_Code_Asm; operand: Operand_Asm;};
        label: string;
        allocate_stack: int;
        // cdq: no value needed
        // ret : no value needed
    };
}
Instruction_Asm_Type :: enum {MOV; UNARY; BINARY; IDIV; CDQ; ALLOCATE_STACK; RET; CMP; JMP; JMP_CC;SET_CC;LABEL; };
Cond_Code_Asm :: enum {EE; NE; G; GE; L; LE;}; 
Operand_Asm :: struct {
    type: enum {IMM; REG; PSEUDO; STACK;};
    as: union { imm: int; reg: Reg_Asm; pseudo: string; stack: int; }; 
};
Unary_Op_Asm :: enum { NEG; BITWISE_NOT; NNOT; }
Bin_Op_Asm :: enum {
    ADD;
    SUB;
    MUL;
    BITWISE_OR;
    BITWISE_AND;
    BITWISE_XOR;
    LEFT_SHIFT;
    RIGHT_SHIFT;
    EQUAL_EQUAL;
    NOT_EQUAL;
    GREATER;
    GREATER_EQUAL;
    LESS;
    LESS_EQUAL;
}; 
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
            if instt.as.unary.op == .NOT {
                zero := Operand_Asm.{.IMM, .{imm = 0}};
                src := asm_gen_val_to_operand(*instt.as.unary.src);
                dst := asm_gen_val_to_operand(*instt.as.unary.dst);
                array_add(insts, .{.MOV, .{mov = .{zero, dst}}});
                array_add(insts, .{.CMP, .{cmp = .{  zero, src }}});
                array_add(insts, .{.SET_CC, .{set_cc = .{.EE, dst}}});
            } else {
                src := asm_gen_val_to_operand(*instt.as.unary.src);
                dst := asm_gen_val_to_operand(*instt.as.unary.dst);
                array_add(insts, .{.MOV,.{ mov = .{ src, dst }}});
                op: Unary_Op_Asm = ---;
                if #complete instt.as.unary.op == {
                    case .BITWISE_NOT; op = .BITWISE_NOT;
                    case .NEGATE; op = .NEG;
                    case .NOT; assert(false, "unreachable");
                }
                array_add(insts, .{ .UNARY, .{unary = .{op, dst}}});  
            }

        case .BINARY;
            basm := instt.as.binary;
            if #complete basm.op == {
                case .ADD; #through;
                case .SUB; #through;
                case .MUL; #through;
                case .BITWISE_AND; #through;
                case .BITWISE_OR; #through;
                case .BITWISE_XOR; #through;
                case .LEFT_SHIFT; #through;
                case .RIGHT_SHIFT; 
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
                case .GREATER; #through;
                case .GREATER_EQUAL; #through;
                case .LESS; #through;
                case .LESS_EQUAL; #through;
                case .NOT_EQUAL; #through;
                case .EQUAL_EQUAL;
                    dst := asm_gen_val_to_operand(*basm.dst);
                    array_add(insts, .{.MOV, .{mov = .{.{.IMM, .{imm = 0}}, dst}}});

                    src1 := asm_gen_val_to_operand(*basm.src1);

                    if basm.src2.type == {
                        case .CONSTANT; 
                            src2 := asm_gen_val_to_operand(*basm.src2);
                            ireg := Operand_Asm.{.REG,.{reg = .R11}};
                            array_add(insts, Instruction_Asm.{.MOV, .{mov = .{src = src2, dst = ireg }}});
                            array_add(insts, Instruction_Asm.{.CMP, .{cmp = .{src1, ireg}}});
                        case .VARIABLE; 
                            src2 := asm_gen_val_to_operand(*basm.src2);
                            array_add(insts, .{.CMP, .{cmp = .{src2, src1}}});
                    }

                    cc := from_relational_to_cond_code(basm.op);
                    array_add(insts, .{.SET_CC, .{set_cc = .{cc, dst}}});
            }
        case .LABEL;
            array_add(insts, .{.LABEL, .{label = instt.as.label}});
        case .JUMP_IF_NOT_ZERO; 
            cond_var := asm_gen_val_to_operand(*instt.as.jump_if_zero.condition);
            zero := Operand_Asm.{.IMM, .{imm = 0}};
            array_add(insts, .{.CMP, .{cmp = .{zero, cond_var}}});
            array_add(insts, .{.JMP_CC, .{jmp_cc = .{.NE, instt.as.jump_if_zero.ident}}});
        case .JUMP_IF_ZERO;
            cond_var := asm_gen_val_to_operand(*instt.as.jump_if_zero.condition);
            zero := Operand_Asm.{.IMM, .{imm = 0}};
            array_add(insts, .{.CMP, .{cmp = .{zero, cond_var}}});
            array_add(insts, .{.JMP_CC, .{jmp_cc = .{.EE, instt.as.jump_if_zero.ident}}});
        case .COPY;
            src := asm_gen_val_to_operand(*instt.as.copy.src);
            dst := asm_gen_val_to_operand(*instt.as.copy.dst);
            array_add(insts, .{.MOV, .{mov = .{src, dst}}});
        case .JUMP;
            array_add(insts, .{.JMP, .{jmp = instt.as.jump}});
    }
}

from_relational_to_cond_code :: (op: Bin_Op_Type_Tacky) -> Cond_Code_Asm {
    if op == {
        case .EQUAL_EQUAL; return .EE;
        case .GREATER; return .G;
        case .GREATER_EQUAL; return .GE;
        case .LESS; return .L;
        case .LESS_EQUAL; return .LE;
        case .NOT_EQUAL; return .NE;
    }
    assert(false, "not relational operator: %", op);
    return .EE; // unreachable
}

from_tacky_to_asm_binop :: (tacky_op: type_of(Instruction_Tacky.as.binary.op)) -> type_of(Instruction_Asm.as.binary.op) {
    if #complete tacky_op == {
        case .ADD; return .ADD;
        case .SUB; return .SUB;
        case .MUL; return .MUL;
        case .BITWISE_OR; return .BITWISE_OR;
        case .BITWISE_XOR; return .BITWISE_XOR;
        case .BITWISE_AND; return .BITWISE_AND;
        case .LEFT_SHIFT; return .LEFT_SHIFT;
        case .RIGHT_SHIFT; return .RIGHT_SHIFT;

        case .GREATER; return .GREATER;
        case .GREATER_EQUAL; return .GREATER_EQUAL;
        case .LESS; return .LESS;
        case .LESS_EQUAL; return .LESS_EQUAL;
        case .EQUAL_EQUAL; return .EQUAL_EQUAL;
        case .NOT_EQUAL; return .NOT_EQUAL;

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
            case .CMP;
                cmp := inst.as.cmp;
                cmp.op1 = asm_gen_stage_2_stack_offset(*table, cmp.op1);
                cmp.op2 = asm_gen_stage_2_stack_offset(*table, cmp.op2);
                inst.* = .{.CMP, .{cmp=cmp}};
            case .IDIV;
                div := asm_gen_stage_2_stack_offset(*table, inst.as.idiv);
                inst.* = .{.IDIV, .{idiv=div}};
            case .SET_CC; 
                set_cc := inst.as.set_cc;
                set_cc.operand = asm_gen_stage_2_stack_offset(*table, set_cc.operand);
                inst.* = .{.SET_CC, .{set_cc=set_cc}}; 
            case .CDQ; #through;
            case .RET; #through;
            case .ALLOCATE_STACK; continue;
            case .LABEL; continue;
            case .JMP_CC; continue;
            case .JMP; continue;
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
                    array_add(*insts, .{.MOV, .{mov = .{src = ireg, dst = oi.as.mov.dst}}});
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
                    case .BITWISE_AND; #through;
                    case .BITWISE_OR; #through;
                    case .BITWISE_XOR; #through;
                    case .LEFT_SHIFT; #through;
                    case .RIGHT_SHIFT; #through;
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
                    case .EQUAL_EQUAL; assert(false, "unreachable");
                    case .NOT_EQUAL; assert(false, "unreachable");
                    case .GREATER; assert(false, "unreachable");
                    case .LESS; assert(false, "unreachable");
                    case .LESS_EQUAL; assert(false, "unreachable");
                    case .GREATER_EQUAL; assert(false, "unreachable");
                }
            case .UNARY; #through;
            case .ALLOCATE_STACK; #through;
            case .CDQ; #through;
            case .RET;
                array_add(*insts, oi);
            case .LABEL; array_add(*insts, oi);
            case .JMP; array_add(*insts, oi);
            case .JMP_CC; array_add(*insts, oi);
            case .SET_CC;
                array_add(*insts, oi);
            case .CMP; 
                if oi.as.cmp.op1.type == .STACK && oi.as.cmp.op2.type == .STACK {
                    ireg := Operand_Asm.{.REG,.{reg = .R10}};
                    array_add(*insts, .{.MOV, .{mov = .{oi.as.cmp.op1, ireg }}});
                    array_add(*insts, .{.CMP, .{cmp = .{ ireg, oi.as.cmp.op2}}});
                }
                else if oi.as.cmp.op2.type == .IMM {
                    ireg := Operand_Asm.{.REG,.{reg = .R11}};
                    array_add(*insts, .{.MOV, .{mov = .{oi.as.cmp.op2, ireg }}});
                    array_add(*insts, .{.CMP, .{cmp = .{ oi.as.cmp.op1, ireg}}});
                } 
                else {
                    array_add(*insts, oi);
                }
        }
    }
    return insts;
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
    if inst.type != .LABEL {
        print("    ");
    }

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
        case .LABEL;
            print("%\n", inst.as.label);
        case .SET_CC;
            print("SETCC ");
            print("%", inst.as.set_cc.cond_code);
            print(", ");
            print_asm_operand(inst.as.set_cc.operand);
            print("\n");
        case .JMP_CC;
            print("JMPCC ");
            print("%", inst.as.jmp_cc.cond_code);
            print(", ");
            print(inst.as.jmp_cc.ident);
            print("\n");
        case .JMP; 
            print("JMP ");
            print(inst.as.jmp);
            print("\n");
        case .CMP; 
            print("CMP ");
            print_asm_operand(inst.as.cmp.op1);
            print(", ");
            print_asm_operand(inst.as.cmp.op2);
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


#scope_file
Hash_Table :: #import "Hash_Table";
#scope_export

/* ADSL ASM_GEN
program              = Program(function_definition)
function_definition  = Function(identifier name, instruction* instructions)
instruction          = Mov(operand src, operand dst)
                       | Unary(unary_operator, operand)
                       | Binary(binary_operator, operand, operand)
                       | Cmp(operand, operand)
                       | Idiv(operand)
                       | Cdq
                       | Jmp(identifier)
                       | JmpCC(cond_code, identifier)
                       | SetCC(cond_code, identifier)
                       | Label(identifier)
                       | AllocateStack(int)
                       | Ret
unary_operator       = Neg | Not
operand              = Imm(int) | Reg(reg) | Pseudo(identifier) | Stack(int)
reg                  = AX | DX | R10 | R11 | RSP | RBP
cond_code            = EE | NE | G | GE | L | LE

*/

