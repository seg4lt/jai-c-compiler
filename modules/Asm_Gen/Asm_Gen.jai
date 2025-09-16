asm_gen :: (pgt: *Program_Tacky, st: *Symbol_Table, $debug_log: bool = false) -> *Program_Asm {
    program_asm := map_to_asm(pgt, st);
    if debug_log print_asm(*stdout_writer_new(), program_asm, 1);
    
    fix_pseudo_register(program_asm, st);
    if debug_log print_asm(*stdout_writer_new(), program_asm, 2);

    fixed_asm := fix_asm(program_asm);
    if debug_log print_asm(*stdout_writer_new(), fixed_asm, 3);
    
    return  fixed_asm;
}

#scope_file

#load "Stage1.jai";
#load "Stage2.jai";
#load "Stage3.jai";
