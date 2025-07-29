asm_gen :: (pgt: *Program_Tacky, st: Symbol_Table, do_print: bool = false) -> *Program_Asm {
    program_asm := map_to_asm(pgt, st);
    if do_print {
        writer := stdout_writer_new();
        print_asm(*writer, program_asm, 1);
    }
    fix_pseudo_register(program_asm);
    if do_print {
        writer := stdout_writer_new();
        print_asm(*writer, program_asm, 2);
    }

    fixed_asm := fix_asm(program_asm);
    if do_print {
        writer := stdout_writer_new();
        print_asm(*writer, fixed_asm, 3);
    }
    return  fixed_asm;
}

#scope_file

#load "Stage1.jai";
#load "Stage2.jai";
#load "Stage3.jai";


/* ADSL ASM_GEN
program              = Program(function_definition)
function_definition  = Function(identifier name, instruction* instructions)
instruction          = Mov(operand src, operand dst)
                       | Unary(unary_operator, operand)
                       | Binary(binary_operator, operand, operand)
                       | Cmp(operand, operand)
                       | Idiv(operand)
                       | Cdq
                       | Jmp(identifier)
                       | JmpCC(cond_code, identifier)
                       | SetCC(cond_code, identifier)
                       | Label(identifier)
                       | AllocateStack(int)
                       | Ret
unary_operator       = Neg | Not
operand              = Imm(int) | Reg(reg) | Pseudo(identifier) | Stack(int)
reg                  = AX | DX | R10 | R11 | RSP | RBP
cond_code            = EE | NE | G | GE | L | LE

*/
