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
    // 4 because we only support 32-bit int at the moment
    stack_size := (table.count * 4);
   
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
