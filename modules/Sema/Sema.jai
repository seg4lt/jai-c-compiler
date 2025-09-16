sema :: (ast: *Program_Ast, st: *Symbol_Table, erp: *Error_Reporter, debug_log: bool = false) {
    sema_ident_resolution(ast, erp);
    sema_label_resolution(ast, erp);
    sema_loop_labeling(ast, erp);
    sema_typecheck(ast, st, erp);

    if debug_log {
        print("\n-- AFTER SEMA --\n");
        print_program_ast(*stdout_writer_new(), ast);
        // TODO(seg4lt): add proper symbol printer for debugging
    }
}

#scope_module

get_4_digit_random :: () -> u64 {
    return random_get() % 10000;
}

make_variable :: (name: string) -> string {
    return sprint("var_%.r%", name, get_4_digit_random());
}

make_goto_label :: (name: string) -> string {
    return sprint("goto_l_%.r%", name, get_4_digit_random());
}

#import "Error_Reporter";
#import "Not_Basic";
#import "Symbol_Table";
#import "Print_Vars";

#scope_export
