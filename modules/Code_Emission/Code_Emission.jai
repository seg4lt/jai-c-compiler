code_emm :: (src_path_no_ext: string, program: *Program_Asm, st: Symbol_Table) {
    file, success := file_open(tprint("%.s", src_path_no_ext), for_writing=true, keep_existing_content=false);
    if !success return;
    defer file_close(*file);

    writer := make_file_writer(*file);
    ce_program(*writer, program, st);
}

#scope_module

ce_program :: (writer: *Writer, using program: *Program_Asm, st: Symbol_Table) {
    if program == null return;
    defer {
        #if OS == .LINUX { 
            progbits := "\t.section .note.GNU-stack,\"\",@progbits\n";
            write(writer, progbits);
        }
    };
    for *fn: program.fns {
        ce_fn(writer, fn, st);
    }
}
ce_fn :: (writer: *Writer, using fn: Fn_Asm, st: Symbol_Table) {
    write(writer, "\t.globl\t%\n", ident);
    
    #if OS == .LINUX {
        write(writer, "%:\n", ident);
    } else #if OS == .MACOS {
        write(writer, "_%:\n", ident);
    }

    { // save caller stack pointer: prologue
        write(writer, "\tpushq\t%\n", ce_fmt_reg(.{.RBP, .QWORD}));
        write(writer, "\tmovq\t%, %\n", ce_fmt_reg(.{.RSP, .QWORD}), ce_fmt_reg(.{.RBP, .QWORD}));
    }
    for fn.instructions ce_inst(writer, *it, st); 
}

ce_inst :: (writer: *Writer, using inst: Instruction_Asm, st: Symbol_Table) {
    if #complete type == {
        case .CALL;
            fn_name := inst.as.call;
            #if OS == .LINUX {
                success := table_find_new(*st, fn_name);
                write(writer, "\tcall\t%", fn_name); 
                write(writer, "%\n", ifx success "" else "@PLT");
            } else #if OS == .MACOS {
                write(writer, "\tcall\t_%\n", fn_name);
            }
        case .DEALLOCATE_STACK;
            size := inst.as.deallocate_stack;
            write(writer, "\taddq\t$%, %\n", size, ce_fmt_reg(.{.RSP,.QWORD}));
        case .PUSH;
            size := inst.as.push;
            write(writer, "\tpushq\t%\n", ce_fmt_operand(size));
        case .MOV;
            write(writer, "\tmovl\t%, %\n", ce_fmt_operand(as.mov.src), ce_fmt_operand(as.mov.dst));
        case .RET;
            {   // epilogue
                write(writer, "\t# vv\tEpilogue\n");
                write(writer, "\tmovq\t%, %\n", ce_fmt_reg(.{.RBP, .QWORD}), ce_fmt_reg(.{.RSP, .QWORD}));
                write(writer, "\tpopq\t%\n", ce_fmt_reg(.{.RBP, .QWORD}));
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
                write(writer, "\tsubq\t$%, %\n", as.allocate_stack, ce_fmt_reg(.{.RSP, .QWORD}));
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
        case .STACK; return tprint("%(%)", operand.as.stack, ce_fmt_reg(.{.RBP, .QWORD}));
        case .PSEUDO; assert(false, "pseudo operand shouldn't exist anymore"); return "";
    }
}

ce_fmt_reg :: (using r: Register_Asm) -> string {
    // TODO: Figure out register size??
    if #complete register == {
        case .AX; 
            if #complete size == {
                case .QWORD; return "%rax"; 
                case .DWORD; return "%eax"; 
                case .WORD; return "%ax"; 
                case .BYTE; return "%al"; 
            };
        case .DX;  
            if #complete size == {
                case .QWORD; return "%rdx"; 
                case .DWORD; return "%edx"; 
                case .WORD; return "%dx"; 
                case .BYTE; return "%dl"; 
            };
        case .R10;
            if #complete size  == {
                case .QWORD; return "%r10"; 
                case .DWORD; return "%r10d"; 
                case .WORD; return "%r10w"; 
                case .BYTE; return "%r10b"; 
            };
        case .R11; 
            if #complete size  == {
                case .QWORD; return "%r11"; 
                case .DWORD; return "%r11d"; 
                case .WORD; return "%r11w"; 
                case .BYTE; return "%r11b"; 
            };
        case .RSP; 
            if #complete size  == {
                case .QWORD; return "%rsp"; 
                case .DWORD; return "%esp"; 
                case .WORD; return "%sp"; 
                case .BYTE; return "%spl"; 
            };
        case .RBP;
            if #complete size == {
                case .QWORD; return "%rbp"; 
                case .DWORD; return "%ebp"; 
                case .WORD; return "%bp"; 
                case .BYTE; return "%bpl"; 
            };
        case .CX; 
            if #complete size == {
                case .QWORD; return "%rcx"; 
                case .DWORD; return "%ecx"; 
                case .WORD; return "%cx"; 
                case .BYTE; return "%cl"; 
            };
        case .R8;
            if #complete size  == {
                case .QWORD; return "%r8"; 
                case .DWORD; return "%r8d"; 
                case .WORD; return "%r8w"; 
                case .BYTE; return "%r8b"; 
            };
        case .SI; 
            if #complete size  == {
                case .QWORD; return "%rsi"; 
                case .DWORD; return "%esi"; 
                case .WORD; return "%si"; 
                case .BYTE; return "%sil"; 
            };
        case .R9;
            if #complete size == {
                case .QWORD; return "%r9"; 
                case .DWORD; return "%r9d"; 
                case .WORD; return "%r9w"; 
                case .BYTE; return "%r9b"; 
            };
        case .DI;
            if #complete size == {
                case .QWORD; return "%rdi"; 
                case .DWORD; return "%edi"; 
                case .WORD; return "%di"; 
                case .BYTE; return "%dil"; 
            };
    }
}

#scope_module
#import "File";
#import "Basic";
#import "Asm_Gen";
#import "Not_Basic";

#scope_export