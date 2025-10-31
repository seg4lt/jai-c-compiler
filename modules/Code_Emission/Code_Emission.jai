code_emm :: (src_path_no_ext: string, program: *Program, symbols: Symbol_Table, $debug_log: bool = false) {
    sb: String_Builder;
    sb_writer := sb_writer_new(*sb);

    emm_pg(*sb_writer, program, symbols);
    asm := builder_to_string(*sb);

    if debug_log print("\n\n-- Native Asm --\n%", asm);

    file, success := file_open(tprint("%.s", src_path_no_ext), for_writing=true, keep_existing_content=false);
    if !success return;
    defer file_close(*file);

    file_write(*file, asm);
}

#scope_file

emm_pg :: (writer: *Writer, program: *Program, symbols: Symbol_Table) {
    if program == null return;
    defer {
        #if OS == .LINUX {
            progbits := "\t.section .note.GNU-stack,\"\",@progbits\n";
            write(writer, progbits);
        }
    };
    for program.top_level {
        if #complete it.kind == {
            case .FN;
                fn := cast(*Top_Level_Fn) it;
                emm_fn(writer, fn, symbols);
            case .STATIC;
                sv := cast(*Top_Level_Static) it;
                symbol_name: string = ---;
                #if OS == .MACOS {
                    symbol_name = sprint("_%", sv.ident);
                } else {
                    symbol_name = sv.ident;
                }
                write(writer, "\n");
                if sv.global write(writer, "\t.global %\n", symbol_name);

                if sv.init != 0 write(writer, "\t.data\n");
                else              write(writer, "\t.bss\n");

                write(writer, "\t.balign 4\n");
                write(writer, "%:\n", symbol_name);
                if sv.init != 0  write(writer, "\t.long %\n", sv.init);
                else  write(writer, "\t.zero 4\n");
        }
    }
}

emm_fn :: (writer: *Writer, fn: *Top_Level_Fn, symbols: Symbol_Table) {
    write(writer, "\n");
    symbol_name : string = ---;

    #if OS == .MACOS  symbol_name = sprint("_%", fn.ident);
    else              symbol_name = fn.ident;

    if fn.global  write(writer, "\t.globl\t%\n", symbol_name);
    else          write(writer, "\t.local\t%\n", symbol_name);
    write(writer, "\t.text\n");
    write(writer, "%:\n", symbol_name);

    { // save caller stack pointer: prologue
        write(writer, "\tpushq\t%\n", fmt_reg(.{.RBP, .QWORD}));
        write(writer, "\tmovq\t%, %\n", fmt_reg(.{.RSP, .QWORD}), fmt_reg(.{.RBP, .QWORD}));
    }
    for fn.instructions emm_instructions(writer, it, symbols);
}

emm_instructions :: (writer: *Writer, inst: *Instruction, symbols: Symbol_Table) {
    if #complete inst.kind == {
        case .CALL;
            call := cast(*Instruction_Call) inst;
            fn_name := call.ident;
            #if OS == .LINUX {
                success, entry := table_find(*symbols, fn_name);
                add_plt := false;
                if success && entry.kind == .FN {
                    fn_symbol := cast(*Symbol_Fn) entry;
                    if !fn_symbol.defined {
                        add_plt = true;
                    }
                }
                write(writer, "\tcall\t%", fn_name);
                write(writer, "%\n", ifx !add_plt "" else "@PLT");
            } else #if OS == .MACOS {
                write(writer, "\tcall\t_%\n", fn_name);
            }
        case .DEALLOCATE_STACK;
            dealloc := cast(*Instruction_Deallocate_Stack) inst;
            size := dealloc.size;
            write(writer, "\taddq\t$%, %\n", size, fmt_reg(.{.RSP,.QWORD}));
        case .PUSH;
            push := cast(*Instruction_Push) inst;
            write(writer, "\tpushq\t%\n", fmt_operand(push.operand));
        case .MOV;
            mov := cast(*Instruction_Mov) inst;
            write(writer, "\tmovl\t%, %\n", fmt_operand(mov.src), fmt_operand(mov.dst));
        case .RET;
            {   // epilogue
                write(writer, "\t# vv\tEpilogue\n");
                write(writer, "\tmovq\t%, %\n", fmt_reg(.{.RBP, .QWORD}), fmt_reg(.{.RSP, .QWORD}));
                write(writer, "\tpopq\t%\n", fmt_reg(.{.RBP, .QWORD}));
            }
            write(writer, "\tret\n");
        case .UNARY;
            unary := cast(*Instruction_Unary) inst;
            write(writer, "\t%\t%\n", fmt_operand(unary.op), fmt_operand(unary.operand));
        case .BINARY;
            binary := cast(*Instruction_Binary) inst;
            ins :=  fmt_operand(binary.op);
            src1 := fmt_operand(binary.src1);
            src2 := fmt_operand(binary.src2);
            write(writer, "\t%\t%, %\n", ins, src1, src2);
        case .IDIV;
            idiv := cast(*Instruction_Idiv) inst;
            ins := "idivl";
            divider := fmt_operand(idiv.operand);
            write(writer, "\t%\t%\n", ins, divider);
        case .CDQ;
            write(writer, "\tcdq\n");
        case .LABEL;
            lbl := cast(*Instruction_Label) inst;
            write(writer,"%:\n", lbl.ident);
        case .JMP;
            jmp := cast(*Instruction_Jmp) inst;
            write(writer, "\tjmp\t%\n", jmp.target);
        case .JMP_CC;
            jmp_cc := cast(*Instruction_Jmp_Cc) inst;
            cmd : string = ---;
            if #complete jmp_cc.cond_code == {
                case .EE; cmd = "je";
                case .NE; cmd = "jne";
                case .G;  cmd = "jg";
                case .GE; cmd = "jge";
                case .L;  cmd = "jl";
                case .LE; cmd = "jle";
            }
            write(writer, "\t%\t%\n", cmd, jmp_cc.target);
        case .CMP;
            cmp := cast(*Instruction_Cmp) inst;
            write(writer, "\tcmpl\t%, %\n", fmt_operand(cmp.op1), fmt_operand(cmp.op2));
        case .SET_CC;
            set_cc := cast(*Instruction_Set_Cc) inst;
            cmd : string = ---;
            if #complete set_cc.cond_code == {
                case .EE; cmd = "sete";
                case .NE; cmd = "setne";
                case .G;  cmd = "setg";
                case .GE; cmd = "setge";
                case .L;  cmd = "setl";
                case .LE; cmd = "setle";
            }
            write(writer, "\t%\t%\n", cmd, fmt_operand(set_cc.operand));
        case .ALLOCATE_STACK;
            alloc := cast(*Instruction_Allocate_Stack) inst;
            if alloc.size != 0 {
                write(writer, "\tsubq\t$%, %\n", alloc.size, fmt_reg(.{.RSP, .QWORD}));
                write(writer, "\t# ^^^\tPrologue\n");
            } else {
                write(writer, "\t# ^^^\tPrologue (no stack allocation needed)\n");
            }
    }
}

fmt_operand :: (op: Unary_Op) -> string {
    if #complete op == {
        case .BITWISE_NOT; return "notl";
        case .NEG;         return "negl";
        case .NNOT;        assert(false, "unreachable");  return "** compiler bug ** fmt_operand";
    }
}

fmt_operand :: (op: Bin_Op) -> string {
    if #complete op == {
        case .ADD;           return "addl";
        case .SUB;           return "subl";
        case .MUL;           return "imull";
        case .BITWISE_AND;   return "andl";
        case .BITWISE_OR;    return "orl";
        case .BITWISE_XOR;   return "xorl";
        case .LEFT_SHIFT;    return "sall"; // doing arithmetic shift - shll for logical shift
        case .RIGHT_SHIFT;   return "sarl"; // shrl
        case .LESS_EQUAL;    #through;
        case .LESS;          #through;
        case .GREATER_EQUAL; #through;
        case .NOT_EQUAL;     #through;
        case .GREATER;       #through;
        case .EQUAL_EQUAL;   unreachable("** compiler bug ** unexpected binary operator."); return "";
    }
}

fmt_operand :: (operand: *Operand) -> string {
    if #complete operand.kind == {
        case .IMM;
            imm := cast(*Operand_Imm) operand;
            return sprint("$%", imm.value);
        case .REG;
            reg := cast(*Operand_Reg) operand;
            return fmt_reg(reg.reg);
        case .STACK;
            stack := cast(*Operand_Stack) operand;
            return sprint("%(%)", stack.position, fmt_reg(.{.RBP, .QWORD}));
        case .DATA;
            data := cast(*Operand_Data) operand;
            #if OS == .MACOS {
                return sprint("_%(%)", data.ident, fmt_reg(.{.RIP, .QWORD}));
            }
            return sprint("%(%)", data.ident, fmt_reg(.{.RIP, .QWORD}));
        case .PSEUDO; unreachable("** compiler bug ** pseudo operand shouldn't exist anymore."); return "";
    }
}

fmt_reg :: (using r: Register_Asm) -> string {
    if #complete register == {
        case .AX;
            if #complete size == {
                case .QWORD; return "%rax";
                case .DWORD; return "%eax";
                case .WORD;  return "%ax";
                case .BYTE;  return "%al";
            };
        case .DX;
            if #complete size == {
                case .QWORD; return "%rdx";
                case .DWORD; return "%edx";
                case .WORD;  return "%dx";
                case .BYTE;  return "%dl";
            };
        case .R10;
            if #complete size  == {
                case .QWORD; return "%r10";
                case .DWORD; return "%r10d";
                case .WORD;  return "%r10w";
                case .BYTE;  return "%r10b";
            };
        case .R11;
            if #complete size  == {
                case .QWORD; return "%r11";
                case .DWORD; return "%r11d";
                case .WORD;  return "%r11w";
                case .BYTE;  return "%r11b";
            };
        case .RSP;
            if #complete size  == {
                case .QWORD; return "%rsp";
                case .DWORD; return "%esp";
                case .WORD;  return "%sp";
                case .BYTE;  return "%spl";
            };
        case .RBP;
            if #complete size == {
                case .QWORD; return "%rbp";
                case .DWORD; return "%ebp";
                case .WORD;  return "%bp";
                case .BYTE;  return "%bpl";
            };
        case .CX;
            if #complete size == {
                case .QWORD; return "%rcx";
                case .DWORD; return "%ecx";
                case .WORD;  return "%cx";
                case .BYTE;  return "%cl";
            };
        case .R8;
            if #complete size  == {
                case .QWORD; return "%r8";
                case .DWORD; return "%r8d";
                case .WORD;  return "%r8w";
                case .BYTE;  return "%r8b";
            };
        case .SI;
            if #complete size  == {
                case .QWORD; return "%rsi";
                case .DWORD; return "%esi";
                case .WORD;  return "%si";
                case .BYTE;  return "%sil";
            };
        case .R9;
            if #complete size == {
                case .QWORD; return "%r9";
                case .DWORD; return "%r9d";
                case .WORD;  return "%r9w";
                case .BYTE;  return "%r9b";
            };
        case .DI;
            if #complete size == {
                case .QWORD; return "%rdi";
                case .DWORD; return "%edi";
                case .WORD;  return "%di";
                case .BYTE;  return "%dil";
            };
        case .RIP;
            if #complete size == {
                case .QWORD; return "%rip";
                case .DWORD; unreachable("can't use rip like this");
                case .WORD;  unreachable("can't use rip like this");
                case .BYTE;  unreachable("can't use rip like this");
            };
    }
    unreachable("What!!!");
    return "";
}

#scope_module

#import "File";
#import "Basic";
#import "Asm_Gen";
#import "Not_Basic";

#scope_file
using Asm;
