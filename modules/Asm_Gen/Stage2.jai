#scope_module

// replace pseudo register, with offset relative to stack
fix_pseudo_register :: (pg: *Program, st: *Symbol_Table) {
    for top_level_item: pg.top_level {
        if #complete top_level_item.kind == {
            case .FN;
                fn := cast(*Top_Level_Fn) top_level_item;
                fn.stack_size = fix_instructions(fn.instructions, st);
            case .STATIC; // noop, not a pseudo
        }
    }
}

#scope_file

STACK_SIZE := 4; // 4 bytes for 32-bit int - we only support 32-bit int at the moment

// replace pseudo register, with offset relative to stack
fix_instructions :: (insts: []*Instruction, st: *Symbol_Table) -> stack_size: int {
    table : Table(string, int);
    init(*table);

    for inst: insts {
        if #complete inst.kind == {
            case .MOVSX; assert(false, "MOVSX not implemented");
            case .MOV;
                mov := cast(*Instruction_Mov) inst;
                mov.src = pseudo_to_stack(*table, st, mov.src);
                mov.dst = pseudo_to_stack(*table, st, mov.dst);
            case .UNARY;
                unary := cast(*Instruction_Unary) inst;
                unary.operand = pseudo_to_stack(*table, st, unary.operand);
            case .BINARY;
                binary := cast(*Instruction_Binary) inst;
                binary.src1 = pseudo_to_stack(*table, st, binary.src1);
                binary.src2 = pseudo_to_stack(*table, st, binary.src2);
            case .CMP;
                cmp := cast(*Instruction_Cmp) inst;
                cmp.op1 = pseudo_to_stack(*table, st, cmp.op1);
                cmp.op2 = pseudo_to_stack(*table, st, cmp.op2);
            case .IDIV;
                idiv := cast(*Instruction_Idiv) inst;
                idiv.operand = pseudo_to_stack(*table, st, idiv.operand);
            case .SET_CC;
                set_cc := cast(*Instruction_Set_Cc) inst;
                set_cc.operand = pseudo_to_stack(*table, st, set_cc.operand);
            case .PUSH;
                push := cast(*Instruction_Push) inst;
                push.operand = pseudo_to_stack(*table, st, push.operand);
            case .CDQ;              #through;
            case .RET;              #through;
            case .CALL;             #through;
            case .LABEL;            #through;
            case .JMP_CC;           #through;
            case .JMP;              continue;
        }
    }
    return (table.count * STACK_SIZE);
}

pseudo_to_stack :: (table: *Table, st: *Symbol_Table, op: *Operand) -> *Operand {
    if op.kind != .PSEUDO return op;

    pseudo_op := cast(*Operand_Pseudo) op;
    pseudo := pseudo_op.ident;

    found_symbol, symbol := table_find(st, pseudo);
    if found_symbol && symbol.kind == .VAR {
        var_symbol := cast(*Symbol_Var) symbol;
        if var_symbol.attr.kind == .STATIC return data(pseudo);
    }

    success, saved_offset := table_find(table, pseudo);
    if success return stack(saved_offset);

    offset := (table.count + 1) * -STACK_SIZE;
    table_add(table, pseudo, offset);
    return stack(offset);
}