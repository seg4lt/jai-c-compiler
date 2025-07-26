asm_gen :: (pgt: *Program_Tacky, st: Symbol_Table, do_print: bool = false) -> *Program_Asm {
    pasm_st_1 := asm_gen_state_1(pgt, st);
    if do_print {
        writer := make_stdout_writer();
        print_asm(*writer, pasm_st_1, 1);
    }
    asm_gen_stage_2(pasm_st_1);
    if do_print {
        writer := make_stdout_writer();
        print_asm(*writer, pasm_st_1, 2);
    }

    pg_stage_3 := asm_gen_stage_3(pasm_st_1);
    if do_print {
        writer := make_stdout_writer();
        print_asm(*writer, pg_stage_3, 3);
    }
    return  pg_stage_3;
}

#scope_file

asm_gen_state_1 :: (pgt: *Program_Tacky, st: Symbol_Table) -> *Program_Asm {
    pg := New(Program_Asm);
    fns : [..]Fn_Asm;
    for pgt.fns {
        fn := asm_gen_fn(*it, st);
        array_add(*fns, fn);
    }
    pg.* = .{fns};
    return pg;
}
asm_gen_fn :: (fnt: *Fn_Tacky, st: Symbol_Table) -> Fn_Asm {
    instructions : [..]Instruction_Asm;
    
    success, entry := table_find_new(*st, fnt.ident);
    if !success assert(false, "Function % not found in symbol table", fnt.ident);
    if entry.type != .FN assert(false, "Symbol % is not a function", fnt.ident);
    
    // fn args already has a name - but they don't have values
    // we need to move value as per System V calling convention to respective pseudo registers
    fn_symbol := entry.as.fn;
    fn_params := fn_symbol.params;
    args_registers : []Reg_Asm = .[.DI, .SI, .DX, .CX, .R8, .R9];
    register_args := array_view(fn_params, 0, min(fn_params.count, 6));
    stack_args := ifx fn_params.count > 6 array_view(fn_params, 6, fn_params.count - 6) else .[];
    
    for register_args {
        register_to_use := args_registers[it_index];
        assembly_arg := Operand_Asm.{ .PSEUDO, .{pseudo = it.ident }};
        array_add(*instructions, mov(reg(register_to_use), assembly_arg));
    }
    for stack_args {
        assembly_arg := Operand_Asm.{.PSEUDO, .{pseudo = it.ident }};
        src := Operand_Asm.{ .STACK, .{ stack = 16 + (it_index * 8 )}};
        array_add(*instructions, mov(src, assembly_arg));
    }
    
    for fnt.instructions asm_gen_inst(*instructions, *it);
    return .{fnt.ident, instructions, 0};
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
                    array_add(insts, .{.MOV, .{ mov = .{ src1, dst }}});

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

                    src2 := asm_gen_val_to_operand(*basm.src2);

                    if basm.src1.type == {
                        case .CONSTANT;
                            src1 := asm_gen_val_to_operand(*basm.src1);
                            ireg := Operand_Asm.{.REG,.{reg = .R11}};
                            array_add(insts, Instruction_Asm.{.MOV, .{mov = .{src = src1, dst = ireg }}});
                            array_add(insts, Instruction_Asm.{.CMP, .{cmp = .{src2, ireg}}});
                        case .VARIABLE;
                            src1 := asm_gen_val_to_operand(*basm.src1);
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
        case .FN_CALL;
            fn_call := instt.as.fn_call;
            args_registers : []Reg_Asm = .[.DI, .SI, .DX, .CX, .R8, .R9];
            
            register_args := array_view(fn_call.args, 0, min(fn_call.args.count, 6));
            stack_args := ifx fn_call.args.count > 6 array_view(fn_call.args, 6, fn_call.args.count - 6) else .[];
            
            stack_padding := ifx stack_args.count % 2 == 0 then 0 else 8;
            
            if stack_padding != 0 array_add(insts, .{.ALLOCATE_STACK, .{allocate_stack = stack_padding}});
            
            for * register_args {
                register_to_use := args_registers[it_index];
                assembly_arg := asm_gen_val_to_operand(it);
                array_add(insts, mov(assembly_arg, reg(register_to_use)));
            }
            
            for * < stack_args {
                assembly_arg := asm_gen_val_to_operand(it);
                if assembly_arg.type == .REG || assembly_arg.type == .IMM {
                    array_add(insts, .{.PUSH, .{push = assembly_arg}}); 
                } else {
                    array_add(insts, mov(assembly_arg, reg(.AX)));
                    array_add(insts, .{.PUSH, .{push = reg(.AX)}});
                }
            }
            
            array_add(insts, .{.CALL, .{call = fn_call.ident}});
            bytes_to_remove := (stack_args.count * 8) + stack_padding;
            if bytes_to_remove > 0 {
                array_add(insts, .{.DEALLOCATE_STACK, .{deallocate_stack = bytes_to_remove}});
            }
            
            assembly_dst := asm_gen_val_to_operand(*fn_call.dst);
            array_add(insts, mov(reg(.AX), assembly_dst));
    }
}

mov :: (src: Operand_Asm, dst: Operand_Asm) -> Instruction_Asm {
    return .{ .MOV, .{ mov = .{ src, dst } } };
}

reg :: (r: Reg_Asm) -> Operand_Asm {
  return .{ type = .REG, as = .{ reg = r } };
}

from_relational_to_cond_code :: (op: Bin_Op_Type_Tacky) -> Cond_Code_Asm {
    if op == {
        case .EQUAL_EQUAL;   return .EE;
        case .GREATER;       return .G;
        case .GREATER_EQUAL; return .GE;
        case .LESS;          return .L;
        case .LESS_EQUAL;    return .LE;
        case .NOT_EQUAL;     return .NE;
    }
    assert(false, "not relational operator: %", op);
    return .EE; // unreachable
}

from_tacky_to_asm_binop :: (tacky_op: type_of(Instruction_Tacky.as.binary.op)) -> type_of(Instruction_Asm.as.binary.op) {
    if #complete tacky_op == {
        case .ADD;           return .ADD;
        case .SUB;           return .SUB;
        case .MUL;           return .MUL;
        case .BITWISE_OR;    return .BITWISE_OR;
        case .BITWISE_XOR;   return .BITWISE_XOR;
        case .BITWISE_AND;   return .BITWISE_AND;
        case .LEFT_SHIFT;    return .LEFT_SHIFT;
        case .RIGHT_SHIFT;   return .RIGHT_SHIFT;
        case .GREATER;       return .GREATER;
        case .GREATER_EQUAL; return .GREATER_EQUAL;
        case .LESS;          return .LESS;
        case .LESS_EQUAL;    return .LESS_EQUAL;
        case .EQUAL_EQUAL;   return .EQUAL_EQUAL;
        case .NOT_EQUAL;     return .NOT_EQUAL;

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
asm_gen_stage_2 :: (pg: *Program_Asm) {
    stack_size: int;
    
    for *fn: pg.fns {
        stack_size = asmgen_stage_2(fn.instructions);
        fn.stack_size = stack_size;
    }
}

// replace pseudo register, with offset relative to stack
asmgen_stage_2 :: (insts: []Instruction_Asm) -> stack_size: int {
    table : Table(string, int);
    init(*table);
    defer deinit(*table);

    for *inst: insts {
        if #complete inst.type == {
            case .CALL;
                continue;
            case .PUSH;
                continue;
            case .DEALLOCATE_STACK;
                continue;
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
    // -4 because we only support 32-bit int at the moment
    stack_size := (table.count * 4);
    if stack_size % 16 != 0 {
        // stack size should be multiple of 16
        stack_size += (16 - (stack_size % 16));
    }
    return stack_size;
}

asm_gen_stage_2_stack_offset :: (table: *Table, op: Operand_Asm) -> Operand_Asm {
    if op.type != .PSEUDO return op;

    success, saved_offset := table_find_new(table, op.as.pseudo);
    if success return .{.STACK, .{ stack = saved_offset }};

    offset := (table.count + 1) * -4;
    table_add(table, op.as.pseudo, offset);
    return .{.STACK,  .{stack=offset}};
}

// Fix assembly instruction
asm_gen_stage_3 :: (pg: *Program_Asm) -> *Program_Asm {
    new_pg := New(Program_Asm);
    fns : [..]Fn_Asm;
    
    for fn: pg.fns {
        stack_size := fn.stack_size;
        old_insts := fn.instructions;
        new_insts := asm_gen_stage_3(old_insts, stack_size);
        array_add(*fns, .{fn.ident, new_insts, stack_size});
    }
    new_pg.* = .{fns};
    return new_pg;
}

asm_gen_stage_3 :: (old_insts: []Instruction_Asm, stack_size: int) -> [..]Instruction_Asm {
    insts : [..]Instruction_Asm;
    array_add(*insts, .{.ALLOCATE_STACK, .{allocate_stack = stack_size}});

    for oi: old_insts {
        if #complete oi.type == {
            case .CALL; 
                array_add(*insts, oi);
            case .PUSH;
                array_add(*insts, oi);
            case .DEALLOCATE_STACK;
                array_add(*insts, oi);
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
                    case .LEFT_SHIFT; #through;
                    case .RIGHT_SHIFT;
                        ireg := Operand_Asm.{.REG,.{reg = .CX }};
                        array_add(*insts, .{.MOV, .{mov = .{oi.as.binary.src1, ireg }}});
                        array_add(*insts, .{.BINARY, .{binary = .{ oi.as.binary.op, ireg, oi.as.binary.src2}}});
                    case .BITWISE_AND; #through;
                    case .BITWISE_OR; #through;
                    case .BITWISE_XOR; #through;
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
