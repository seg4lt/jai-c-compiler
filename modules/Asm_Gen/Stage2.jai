#scope_module

// replace pseudo register, with offset relative to stack
fix_pseudo_register :: (pg: *Program_Asm) {
    for *fn: pg.fns fn.stack_size = fix_instructions(fn.instructions);
}

#scope_file

STACK_SIZE := 4; // 4 bytes for 32-bit int - we only support 32-bit int at the moment

// replace pseudo register, with offset relative to stack
fix_instructions :: (insts: []Instruction_Asm) -> stack_size: int {
    table : Table(string, int);
    init(*table);

    for * inst: insts {
        if #complete inst.type == {
            case .MOV;
                mov := *inst.as.mov;
                mov.src = pseudo_to_stack(*table, mov.src);
                mov.dst = pseudo_to_stack(*table, mov.dst);
            case .UNARY;
                unary := *inst.as.unary;
                unary.operand = pseudo_to_stack(*table, unary.operand);
            case .BINARY;
                binary := *inst.as.binary;
                binary.src1 = pseudo_to_stack(*table, binary.src1);
                binary.src2 = pseudo_to_stack(*table, binary.src2);
            case .CMP;
                cmp := *inst.as.cmp;
                cmp.op1 = pseudo_to_stack(*table, cmp.op1);
                cmp.op2 = pseudo_to_stack(*table, cmp.op2);
            case .IDIV;
                div := pseudo_to_stack(*table, inst.as.idiv);
                inst.as.idiv = div;
            case .SET_CC;
                set_cc := *inst.as.set_cc;
                set_cc.operand = pseudo_to_stack(*table, set_cc.operand);
            case .CDQ;              #through;
            case .RET;              #through;
            case .CALL;             #through;
            case .PUSH;             #through;
            case .DEALLOCATE_STACK; #through;
            case .ALLOCATE_STACK;   #through;
            case .LABEL;            #through;
            case .JMP_CC;           #through;
            case .JMP;              continue;
        }
    }
    return (table.count * STACK_SIZE);
}

pseudo_to_stack :: (table: *Table, op: Operand_Asm) -> Operand_Asm {
    if op.type != .PSEUDO return op;
    
    pseudo := op.as.pseudo;
    
    success, saved_offset := table_find_new(table, pseudo);
    if success return stack(saved_offset);

    offset := (table.count + 1) * -STACK_SIZE;
    table_add(table, pseudo, offset);
    return stack(offset);
}
