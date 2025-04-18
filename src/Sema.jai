Store :: Table(string, Owing_Entry(string));

sema :: (ast: *Program_Ast) {
    sema_var_resolution(ast);
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

#scope_file

#import "Hash_Table";

#load "Sema_Goto_Label_Resolution.jai";
#load "Sema_Var_Resolution.jai";
#load "Sema_Loop_Labeling.jai";

#scope_export
