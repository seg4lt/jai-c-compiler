sema :: (ast: *Program_Ast, error_reporter: *Error_Reporter, do_print: bool = false) {
    sema_var_resolution(ast, error_reporter);
    sema_label_resolution(ast, error_reporter);
    sema_loop_labeling(ast, error_reporter);

    if do_print {
        print("\n-- AFTER SEMA --\n");
        writer := make_stdout_writer();
        print_program_ast(*writer, ast);
    }
}

#scope_module

get_4_digit_random :: () -> u64 {
    return random_get() % 10000;
}

make_variable :: (name: string) -> string {
    return tprint("var_%.r%", name, get_4_digit_random());
}

make_goto_label :: (name: string) -> string {
    return tprint("goto_l_%.r%", name, get_4_digit_random());
}

#import "Error_Reporter";
#import "Not_Basic";

#scope_export
