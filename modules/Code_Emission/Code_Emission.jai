code_emm :: (src_path_no_ext: string, program: *Program_Asm) {
    file, success := file_open(tprint("%.s", src_path_no_ext), for_writing=true, keep_existing_content=false);
    if !success return;
    defer file_close(*file);

    writer := make_file_writer(*file);
    ce_program(*writer, program);
}

ce_program :: (writer: *Writer, using program: *Program_Asm) {
    if program == null return;
    defer {
        #if OS == .LINUX { 
            progbits := "\t.section .note.GNU-stack,\"\",@progbits\n";
            write(writer, progbits);
        }
    };
    ce_fn(writer, fn);
}
ce_fn :: (writer: *Writer, using fn: Fn_Asm) {
    write(writer, "\t.globl\t%\n", ident);
    write(writer, "%:\n", ident);

    { // save caller stack pointer: prologue
        write(writer, "\tpushq\t%\n", ce_fmt_reg(.RBP));
        write(writer, "\tmovq\t%, %\n", ce_fmt_reg(.RSP), ce_fmt_reg(.RBP));
    }
    for fn.instructions ce_inst(writer, *it); 
}

ce_inst :: (writer: *Writer, using inst: Instruction_Asm) {
    if #complete type == {
        case .MOV;
            write(writer, "\tmovl\t%, %\n", ce_fmt_operand(as.mov.src), ce_fmt_operand(as.mov.dst));
        case .RET;
            {   // epilogue
                write(writer, "\t# vv\tEpilogue\n");
                write(writer, "\tmovq\t%, %\n", ce_fmt_reg(.RBP), ce_fmt_reg(.RSP));
                write(writer, "\tpopq\t%\n", ce_fmt_reg(.RBP));
            }
            write(writer, "\tret\n");
        case .UNARY;
            write(writer, "\t%\t%\n",ce_fmt_unary_op(as.unary.op), ce_fmt_operand(as.unary.operand));
        case .BINARY;
            ins :=  ce_fmt_binary_op(as.binary.op);
            src1 := ce_fmt_operand(as.binary.src1);
            src2 := ce_fmt_operand(as.binary.src2);
            write(writer, "\t%\t%, %\n", ins, src1, src2);
        case .IDIV;
            ins := "idivl";
            divider := ce_fmt_operand(as.idiv);
            write(writer, "\t%\t%\n", ins, divider);
        case .CDQ;
            write(writer, "\tcdq\n");
        case .LABEL;
            write(writer,"%:\n", as.label);
        case .JMP;
            write(writer, "\tjmp\t%\n", as.jmp);
        case .JMP_CC;
            cmd : string = ---;
            if #complete as.jmp_cc.cond_code == {
                case .EE; cmd = "je";
                case .NE; cmd = "jne";
                case .G; cmd = "jg";
                case .GE; cmd = "jge";
                case .L; cmd = "jl";
                case .LE; cmd = "jle";
            }
            write(writer, "\t%\t%\n", cmd, as.jmp_cc.ident);
        case .CMP;
            write(writer, "\tcmpl\t%, %\n", ce_fmt_operand(as.cmp.op1), ce_fmt_operand(as.cmp.op2));
        case .SET_CC;
            cmd : string = ---;
            if #complete as.set_cc.cond_code == {
                case .EE; cmd = "sete";
                case .NE; cmd = "setne";
                case .G;  cmd = "setg";
                case .GE; cmd = "setge";
                case .L;  cmd = "setl";
                case .LE; cmd = "setle";
            }
            write(writer, "\t%\t%\n", cmd, ce_fmt_operand(as.set_cc.operand));
        case .ALLOCATE_STACK;
            if as.allocate_stack != 0 {
                write(writer, "\tsubq\t$%, %\n", as.allocate_stack, ce_fmt_reg(.RSP));
                write(writer, "\t# ^^^\tPrologue\n");
            } else {
                write(writer, "\t# ^^^\tPrologue (no stack allocation needed)\n");
            }

    }
}

ce_fmt_unary_op :: (op: Unary_Op_Asm) -> string {
    if #complete op == {
        case .NEG; return "negl";
        case .BITWISE_NOT; return "notl";
        case .NNOT; assert(false, "unreachable"); return "asdf";
    }
}
ce_fmt_binary_op :: (op : type_of(Instruction_Asm.as.binary.op)) -> string {
    if #complete op == {
        case .ADD; return "addl";
        case .SUB; return "subl";
        case .MUL; return "imull";
        case .BITWISE_AND; return "andl";
        case .BITWISE_OR; return "orl";
        case .BITWISE_XOR; return "xorl";
        case .LEFT_SHIFT; return "sall"; // doing arithmetic shift - shll for logical shift
        case .RIGHT_SHIFT; return "sarl"; // shrl
        case .LESS_EQUAL; #through;
        case .LESS; #through;
        case .GREATER_EQUAL; #through;
        case .NOT_EQUAL; #through;
        case .GREATER; #through;
        case .EQUAL_EQUAL; assert(false, "unreachable"); return "";
    }

}

ce_fmt_operand :: (operand: Operand_Asm) -> string {
    if #complete operand.type == {
        case .IMM; return tprint("$%", operand.as.imm);
        case .REG; return ce_fmt_reg(operand.as.reg);
        case .STACK; return tprint("%(%)", operand.as.stack, ce_fmt_reg(.RBP));
        case .PSEUDO; assert(false, "pseudo operand shouldn't exist anymore"); return "";
    }
}

ce_fmt_reg :: (r: Reg_Asm) -> string {
    // TODO: Figure out register size??
    if #complete r == {
        case .AX; return "%eax"; 
        case .DX; return "%edx"; 
        case .R10; return "%r10d"; 
        case .R11; return "%r11d"; 
        case .RSP; return "%rsp";
        case .RBP; return "%rbp";
    }
}

#scope_module
#import "File";
#import "Basic";
#import "Asm_Gen";
#import "Not_Basic";

#scope_export