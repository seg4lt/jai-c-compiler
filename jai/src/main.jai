main :: () {
    // everything on temporary allocator, don't wanna manage memory for now
    push_allocator(temp);
    defer { reset_temporary_storage(); report_memory_leaks(); };

    args := get_cli_args();

    lexer := ifx args.flags & .LEX lex(args);
    ast := ifx args.flags & .PARSE ast_parse(*lexer);
    asm_construct := ifx args.flags & .PARSE  generate_asm(ast);
    if args.flags & .CODE_GEN start_code_emission(args, asm_construct); 
    if args.flags & .ALL assember_and_linker(args);
}

#import "Basic"()(MEMORY_DEBUGGER=true);
String :: #import "String";
Process :: #import "Process";
#import "File";
#load "Lexer.jai";
#load "Cli_Args.jai";
#load "Ast.jai";
#load "Asm_Gen.jai";
#load "Write_Asm.jai";
#load "Compiler_Util.jai";




