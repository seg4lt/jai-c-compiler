Store :: Table(string, Owing_Entry(string));

sema :: (ast: *Program_Ast, error_reporter: *Error_Reporter) {
    sema_var_resolution(ast, error_reporter);
    sema_label_resolution(ast);
    sema_loop_labeling(ast);
    print("\n-- AFTER SEMA --\n");
    print_program_ast(ast);
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

#import "Error_Reporter";

#scope_export
