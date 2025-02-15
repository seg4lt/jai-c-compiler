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
            { // epilogue
                file_write(f, tprint("\tmovq\t%, %\n", ce_fmt_reg(.RBP), ce_fmt_reg(.RSP)));
                file_write(f, tprint("\tpopq\t%\n", ce_fmt_reg(.RBP)));
            }
            file_write(f, tprint("\tret\n"));
        case .UNARY;
            file_write(f, tprint("\t%\t%\n",ce_fmt_unary_op(as.unary.op), ce_fmt_operand(as.unary.operand)));
        case .ALLOCATE_STACK;
           file_write(f, tprint("\tsubq\t%, %\n", as.allocate_stack, ce_fmt_reg(.RSP)));
    }
}

ce_fmt_unary_op :: (op: Unary_Op_Asm) -> string {
    if #complete op == {
        case .NEG; return "negl";
        case .NOT; return "notl";
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
        case .R10; return "%r10d"; 
        case .RSP; return "%rsp";
        case .RBP; return "%rbp";
    }
}

#scope_file
#import "File";
#scope_export