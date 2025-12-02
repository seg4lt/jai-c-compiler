print_asm :: (writer: *Writer, pg: *Asm.Program, stage: int) {
    write(writer, "\n\n---- ASM GEN % --- \n", stage);
    write(writer, ".program\n");
    for pg.top_level {
        if #complete it.kind == {
            case .FN;
                fn := cast(*Asm.Top_Level_Fn) it;
                print_asm_fn(writer, fn);
            case .STATIC;
                sv := cast(*Asm.Top_Level_Static) it;
                write(writer, ".data ");
                write(writer, ".%: .long %\n", sv.ident, sv.init);
        } 
    }
}

print_asm_fn :: (writer: *Writer, fn: *Asm.Top_Level_Fn) {
    write(writer, ".%:\n", fn.ident);
    for fn.instructions print_asm_inst(writer, it);
}

print_asm_inst :: (writer: *Writer, inst: *Asm.Instruction) {
    if inst.kind != .LABEL {
        write(writer, "    ");
    }

    if #complete inst.kind == {
        case .MOVSX; assert(false, "MOVSX not implemented");
        case .MOV;
            mov := cast(*Asm.Instruction_Mov) inst;
            write(writer, "% ", inst.kind);
            print_asm_operand(writer, mov.src);
            write(writer, ", ");
            print_asm_operand(writer, mov.dst);
            write(writer, "\n");
        case .UNARY;
            unary := cast(*Asm.Instruction_Unary) inst;
            write(writer, "% ", unary.op);
            print_asm_operand(writer, unary.operand);
            write(writer, "\n");
        case .RET;
            write(writer, "% ", inst.kind);
            write(writer, "\n");
        case .CDQ;
            write(writer, "CDQ ");
            write(writer, "\n");
        case .BINARY;
            binary := cast(*Asm.Instruction_Binary) inst;
            write(writer, "% ", binary.op);
            print_asm_operand(writer, binary.src1);
            write(writer, ", ");
            print_asm_operand(writer, binary.src2);
            write(writer, "\n");
        case .IDIV;
            idiv := cast(*Asm.Instruction_Idiv) inst;
            write(writer, "IDIV ");
            print_asm_operand(writer, idiv.operand);
            write(writer, "\n");
        case .LABEL;
            lbl := cast(*Asm.Instruction_Label) inst;
            write(writer, "%\n", lbl.ident);
        case .SET_CC;
            set_cc := cast(*Asm.Instruction_Set_Cc) inst;
            write(writer, "SETCC ");
            write(writer, "%", set_cc.cond_code);
            write(writer, ", ");
            print_asm_operand(writer, set_cc.operand);
            write(writer, "\n");
        case .JMP_CC;
            jmp_cc := cast(*Asm.Instruction_Jmp_Cc) inst;
            write(writer, "JMPCC ");
            write(writer, "%", jmp_cc.cond_code);
            write(writer, ", ");
            write(writer, jmp_cc.target);
            write(writer, "\n");
        case .JMP; 
            jmp := cast(*Asm.Instruction_Jmp) inst;
            write(writer, "JMP ");
            write(writer, jmp.target);
            write(writer, "\n");
        case .CMP; 
            cmp := cast(*Asm.Instruction_Cmp) inst;
            write(writer, "CMP ");
            print_asm_operand(writer, cmp.op1);
            write(writer, ", ");
            print_asm_operand(writer, cmp.op2);
            write(writer, "\n");
        case .CALL;
            call := cast(*Asm.Instruction_Call) inst;
            write(writer, "CALL ");
            write(writer, call.ident);
            write(writer, "\n");
        case .PUSH;
            push := cast(*Asm.Instruction_Push) inst;
            write(writer, "PUSH ");
            print_asm_operand(writer, push.operand);
            write(writer, "\n");
    }
}

print_asm_operand :: (writer: *Writer, operand: *Asm.Operand) {
    if #complete operand.kind == {
        case .IMM;
            imm := cast(*Asm.Operand_Imm) operand;
            write(writer, "imm(%)", imm.value);
        case .REG;
            reg := cast(*Asm.Operand_Reg) operand;
            write(writer, "reg(%)", reg.reg);
        case .PSEUDO;
            pseudo := cast(*Asm.Operand_Pseudo) operand;
            write(writer, "pseudo(%)", pseudo.ident);
        case .STACK;
            stack := cast(*Asm.Operand_Stack) operand;
            write(writer, "stack(%)", stack.position);
        case .DATA;
            data := cast(*Asm.Operand_Data) operand;
            write(writer, "data(%)", data.ident);
    }
}