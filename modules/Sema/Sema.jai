sema :: (ast: *Program_Ast, st: *Symbol_Table, erp: *Error_Reporter, do_print: bool = false) {
    sema_ident_resolution(ast, erp);
    sema_label_resolution(ast, erp);
    sema_loop_labeling(ast, erp);
    sema_typecheck(ast, st, erp);

    if do_print {
        print("\n-- AFTER SEMA --\n");
        writer := stdout_writer_new();
        print_program_ast(*writer, ast);
        
        
        print("\n-- SYMBOL TABLE --\n"); 
        for st {
            print("%: %\n", it_index, it);
        }
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
#import "Symbol_Table";

#scope_export
