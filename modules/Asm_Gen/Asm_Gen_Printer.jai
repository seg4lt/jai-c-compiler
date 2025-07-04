print_asm :: (writer: *Writer, pg: *Program_Asm, stage: int) {
    write(writer, "\n\n---- ASM GEN % --- \n", stage);
    write(writer, ".program\n");
    for pg.fns print_asm_fn(writer, it);
}

print_asm_fn :: (writer: *Writer, fn: Fn_Asm) {
    write(writer, ".%:\n", fn.ident);
    for fn.instructions print_asm_inst(writer, it);
}

print_asm_inst :: (writer: *Writer, inst: Instruction_Asm) {
    if inst.type != .LABEL {
        write(writer, "    ");
    }

    if #complete inst.type == {
        case .MOV;
            write(writer, "% ", inst.type);
            print_asm_operand(writer, inst.as.mov.src);
            write(writer, ", ");
            print_asm_operand(writer, inst.as.mov.dst);
            write(writer, "\n");
        case .UNARY;
            write(writer, "% ", inst.as.unary.op);
            print_asm_operand(writer, inst.as.unary.operand);
            write(writer, "\n");
        case .RET;
            write(writer, "% ",inst.type);
            write(writer, "\n");
        case .ALLOCATE_STACK;
            write(writer, "ASTK %", inst.as.allocate_stack);
            write(writer, "\n");
        case .CDQ;
            write(writer, "CDQ ");
            write(writer, "\n");
        case .BINARY;
            write(writer, "% ", inst.as.binary.op);
            print_asm_operand(writer, inst.as.binary.src1);
            write(writer, ", ");
            print_asm_operand(writer, inst.as.binary.src2);
            write(writer, "\n");
        case .IDIV;
            write(writer, "IDIV ");
            print_asm_operand(writer, inst.as.idiv);
            write(writer, "\n");
        case .LABEL;
            write(writer, "%\n", inst.as.label);
        case .SET_CC;
            write(writer, "SETCC ");
            write(writer, "%", inst.as.set_cc.cond_code);
            write(writer, ", ");
            print_asm_operand(writer, inst.as.set_cc.operand);
            write(writer, "\n");
        case .JMP_CC;
            write(writer, "JMPCC ");
            write(writer, "%", inst.as.jmp_cc.cond_code);
            write(writer, ", ");
            write(writer, inst.as.jmp_cc.ident);
            write(writer, "\n");
        case .JMP; 
            write(writer, "JMP ");
            write(writer, inst.as.jmp);
            write(writer, "\n");
        case .CMP; 
            write(writer, "CMP ");
            print_asm_operand(writer, inst.as.cmp.op1);
            write(writer, ", ");
            print_asm_operand(writer, inst.as.cmp.op2);
            write(writer, "\n");
        case .CALL;
            write(writer, "CALL ");
            write(writer, inst.as.call);
            write(writer, "\n");
        case .PUSH;
            write(writer, "PUSH ");
            print_asm_operand(writer, inst.as.push);
            write(writer, "\n");
        case .DEALLOCATE_STACK;
            write(writer, "DSTK %", inst.as.deallocate_stack);
            write(writer, "\n");
    }
}
print_asm_operand :: (writer: *Writer, operand: Operand_Asm) {
    if #complete operand.type == {
        case .IMM;
            write(writer, "imm(%)", operand.as.imm);
        case .REG;
            write(writer, "reg(%)", operand.as.reg);
        case .PSEUDO;
            write(writer, "pseudo(%)",operand.as.pseudo);
        case .STACK;
            write(writer, "stack(%)", operand.as.stack);
    }
}