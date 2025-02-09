main :: () {
    // everything on temporary allocator, don't wanna manage memory for now
    push_allocator(temp);
    defer { reset_temporary_storage(); report_memory_leaks(); };

    args := get_cli_args();
    // print("Args % \n", args);

    if args.flags & .LEX {
        src := File.read_entire_file(args.source_file_path);
        lexer := Lexer.{src = src};
        success, msg := scan(*lexer);
        // for lexer.tokens {
        //     print("%\n", it);
        // }
        if !success {
            log_error("Failed to Lex: %", msg);
            exit(1);
        }
    }
}


#import "Basic"()(MEMORY_DEBUGGER=true);
String :: #import "String";
Process :: #import "Process";
File :: #import "File";
#load "Lexer.jai";
#load "Cli_Args.jai";




