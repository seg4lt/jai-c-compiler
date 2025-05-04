
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

make_variable :: (name: string, n: int) -> string {
    return tprint("var_%.%", name, n);
}

make_goto_label :: (name: string, n: int) -> string {
    return tprint("goto_l_%.%", name, n);
}

#scope_module

Owing_Entry :: struct(T: Type) {
    owing_block: bool;
    processed: T;
}

table_clone_owing_entry :: (table: *Table(string, Owing_Entry(string))) -> Table(string, Owing_Entry(string)) {
    new_table : Table(string, Owing_Entry(string));
    init(*new_table);

    for table {
        value := it;
        value.owing_block = false;
        table_set(*new_table, it_index, value);
    }
    return new_table;
}

Store :: Table(string, Owing_Entry(string));

#import "Error_Reporter";
#import "Not_Basic";

#scope_export
