#scope_module

// replace pseudo register, with offset relative to stack
fix_pseudo_register :: (pg: *Program_Asm, st: *Symbol_Table) {
    for *top_level_item: pg.top_level {
        if #complete top_level_item.kind == {
            case .FN;
                fn := *top_level_item.top_level_fn;
                fn.stack_size = fix_instructions(fn.instructions, st);
            case .STATIC; // noop, not a pseudo
        }
    }
}

#scope_file

STACK_SIZE := 4; // 4 bytes for 32-bit int - we only support 32-bit int at the moment

// replace pseudo register, with offset relative to stack
fix_instructions :: (insts: []Instruction_Asm, st: *Symbol_Table) -> stack_size: int {
    table : Table(string, int);
    init(*table);

    for * inst: insts {
        if #complete inst.type == {
            case .MOV;
                mov := *inst.as.mov;
                mov.src = pseudo_to_stack(*table, st, mov.src);
                mov.dst = pseudo_to_stack(*table, st, mov.dst);
            case .UNARY;
                unary := *inst.as.unary;
                unary.operand = pseudo_to_stack(*table, st, unary.operand);
            case .BINARY;
                binary := *inst.as.binary;
                binary.src1 = pseudo_to_stack(*table, st, binary.src1);
                binary.src2 = pseudo_to_stack(*table, st, binary.src2);
            case .CMP;
                cmp := *inst.as.cmp;
                cmp.op1 = pseudo_to_stack(*table, st, cmp.op1);
                cmp.op2 = pseudo_to_stack(*table, st, cmp.op2);
            case .IDIV;
                div := pseudo_to_stack(*table, st, inst.as.idiv);
                inst.as.idiv = div;
            case .SET_CC;
                set_cc := *inst.as.set_cc;
                set_cc.operand = pseudo_to_stack(*table, st, set_cc.operand);
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

pseudo_to_stack :: (table: *Table, st: *Symbol_Table, op: Operand_Asm) -> Operand_Asm {
    if op.type != .PSEUDO return op;
    
    pseudo := op.as.pseudo;
    
    found_symbol, symbol := table_find_new(st, pseudo);
    if symbol.attr.kind == .STATIC return data(pseudo); 
    
    success, saved_offset := table_find_new(table, pseudo);
    if success return stack(saved_offset);

    offset := (table.count + 1) * -STACK_SIZE;
    table_add(table, pseudo, offset);
    return stack(offset);
}
