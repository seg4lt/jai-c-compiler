code_emm :: (args: Cli_Args, program: *Program_Asm) {
    file, success := file_open(tprint("%.s", args.source_file_path_without_ext), for_writing=true, keep_existing_content=false);
    if !success return;
    defer file_close(*file);

    ce_program(*file, program);
}

ce_program :: (f: *File, using program: *Program_Asm) {
    if program == null return;
    defer {
        #if OS == .LINUX { 
            progbits := "\t.section .note.GNU-stack,\"\",@progbits";
            file_write(f, progbits.data, progbits.count);
        }
    };
    ce_fn(f, fn);
}
ce_fn :: (f: *File, using fn: Fn_Asm) {
    file_write(f, tprint("\t.globl\t%\n", ident));
    file_write(f, tprint("%:\n", ident));

    { // save caller stack pointer: prologue
        file_write(f, tprint("\tpushq\t%\n", ce_fmt_reg(.RBP)));
        file_write(f, tprint("\tmovq\t%, %\n", ce_fmt_reg(.RSP), ce_fmt_reg(.RBP)));
    }
    for fn.instructions ce_inst(f, *it); 
}

ce_inst :: (f: *File, using inst: Instruction_Asm) {
    if #complete type == {
        case .MOV;
            file_write(f, tprint("\tmovl\t%, %\n", ce_fmt_operand(as.mov.src), ce_fmt_operand(as.mov.dst)));
        case .RET;
            {   // epilogue
                file_write(f, "\t;˯˯˯\tEpilogue\n");
                file_write(f, tprint("\tmovq\t%, %\n", ce_fmt_reg(.RBP), ce_fmt_reg(.RSP)));
                file_write(f, tprint("\tpopq\t%\n", ce_fmt_reg(.RBP)));
            }
            file_write(f, tprint("\tret\n"));
        case .UNARY;
            file_write(f, tprint("\t%\t%\n",ce_fmt_unary_op(as.unary.op), ce_fmt_operand(as.unary.operand)));
        case .BINARY;
            ins :=  ce_fmt_binary_op(as.binary.op);
            src1 := ce_fmt_operand(as.binary.src1);
            src2 := ce_fmt_operand(as.binary.src2);
            file_write(f, tprint("\t%\t%, %\n", ins, src1, src2));
        case .IDIV;
            ins := "idivl";
            divider := ce_fmt_operand(as.idiv);
            file_write(f, tprint("\t%\t%\n", ins, divider));
        case .CDQ;
            file_write(f, "\tcdq\n");
        case .LABEL;
            file_write(f, tprint("%:\n", as.label));
        case .JMP;
            file_write(f, tprint("\tjmp\t%\n", as.jmp));
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
            file_write(f, tprint("\t%\t%\n", cmd, as.jmp_cc.ident));
        case .CMP;
            file_write(f, tprint("\tcmpl\t%, %\n", ce_fmt_operand(as.cmp.op1), ce_fmt_operand(as.cmp.op2)));
        case .SET_CC;
            cmd : string = ---;
            if #complete as.set_cc.cond_code == {
                case .EE; cmd = "sete";
                case .NE; cmd = "setne";
                case .G; cmd = "setg";
                case .GE; cmd = "setge";
                case .L; cmd = "setl";
                case .LE; cmd = "setle";
            }
            file_write(f, tprint("\t%\t%\n", cmd, ce_fmt_operand(as.set_cc.operand)));
        case .ALLOCATE_STACK;
            file_write(f, tprint("\tsubq\t%, %\n", as.allocate_stack, ce_fmt_reg(.RSP)));
            file_write(f, "\t;˄˄˄\tPrologue\n");

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

#scope_file
#import "File";
#scope_export