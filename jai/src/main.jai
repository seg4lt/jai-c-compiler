main :: () {
    // everything on temporary allocator, don't wanna manage memory for now
    push_allocator(temp);
    defer { reset_temporary_storage(); report_memory_leaks(); };

    args := get_cli_args();
    // print("Args % \n", args);

    print("WD: %\n", get_working_directory());

    lexer := ifx args.flags & .LEX {
        src, r_success := File.read_entire_file(args.source_file_path);
        if !r_success {
            log_error("Unable to read file -- '%'", args.source_file_path);
            exit(1);
        }
        lexer := Lexer.{src = src};
        success, msg := scan(*lexer);
        if !success {
            log_error("Failed to Lex: %", msg);
            exit(1);
        }
        lexer;
    };
    for lexer.tokens {
        print("%\n", it);
    }

    ast := ifx args.flags & .PARSE {
        parser := Parser.{tokens = lexer.tokens};
        success, program := parse_program(*parser);
        program;
    };
    print("----\n");
    ast_print(ast);
}


#import "Basic"()(MEMORY_DEBUGGER=true);
String :: #import "String";
Process :: #import "Process";
File :: #import "File";
#load "Lexer.jai";
#load "Cli_Args.jai";
#load "Ast.jai";




