start_code_emission :: (args: Cli_Args, asm_construct: *Asm_Construct) {
    file, success := file_open(tprint("%.s", args.source_file_path_without_ext), for_writing=true, keep_existing_content=false);
    if !success return;
    defer file_close(*file);

    code_emission(*file, asm_construct);
    // return file_write(*file, data, count);
}

code_emission :: (f: *File, using asm_construct: *Asm_Construct) {
    if asm_construct == null return;

    if #complete type == {
        case .PROGRAM;
            code_emission(f, as.program.fn);
            // #if OS == .LINUX { // we get os = MACOS inside docker as well
               progbits := "\t.section .note.GNU-stack,\"\",@progbits";
               file_write(f, progbits.data, progbits.count);
            // }
        case .FUNCTION;
            fn_name := as.fn.name;
            global_fn := tprint("\t.globl\t%\n", fn_name);
            file_write(f, global_fn.data, global_fn.count);
            fn_decl := tprint("%:\n", fn_name);
            file_write(f, fn_decl.data, fn_decl.count);
            code_emission(f, as.fn.instruction_list);
        case .INSTRUCTION_LIST;
            for as.instruction_list code_emission_inst(f, it);
        case .INSTRUCTION;
            code_emission_inst(f, as.instruction);
    }
}

code_emission_inst :: (f: *File, using inst: Instruction_Asm_Construct) {
    if #complete type == {
        case .MOV;
            to_print := tprint("\tmov\t% %\n", code_emission_format_operand(as.mov.src), code_emission_format_operand(as.mov.dst));
            file_write(f, to_print.data, to_print.count);
        case .RET;
            to_print := tprint("\tret\n");
            file_write(f, to_print.data, to_print.count);
    }
}
code_emission_format_operand :: (op: Asm_Operand) -> string {
    if #complete op.type == {
        case .IMM; return tprint("$%", op.as.imm.value);
        case .REGISTER; return code_emission_format_register(op.as.register);
    }
}

code_emission_format_register :: (r: Register) -> string {
    if #complete r == {
        case .EAX; return "%eax";
    }
}

#scope_file
#import "File";
#scope_export