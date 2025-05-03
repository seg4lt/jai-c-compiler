main :: () {
    // everything on temporary allocator, don't wanna manage memory for now
    push_allocator(temp);
    defer { report_memory_leaks(); };

    args := get_cli_args();
    src_content := run_preprocessor(args.src_path);

    error_reporter: Error_Reporter;
    error_reporter.src_path = args.src_path;
    error_reporter.src = src_content;

    lexer         := ifx args.flags & .LEX          lex(src_content, *error_reporter);
    ast           := ifx args.flags & .PARSE        ast_parse(*lexer, *error_reporter);
    if args.flags                   & .SEMA         sema(ast);
    tacky         := ifx args.flags & .TACKY        gen_program_tacky(ast);
    asm_construct := ifx args.flags & .CODE_GEN     asm_gen(tacky);
    if args.flags                   & .CODE_GEN     code_emm(args, asm_construct); 
    if args.flags                   & .ALL          assember_and_linker(args.src_path_without_ext);
}


#import "Basic"()(MEMORY_DEBUGGER=true);
String :: #import "String";
Process :: #import "Process";
#import "Lexer";
#import "Parser";
#import "File";
#import "Not_Basic";
#import "Error_Reporter";
#import "Compiler_Util";
#import "Sema";

#load "Cli_Args.jai";
#load "Tacky_IR.jai";
#load "Asm_Gen.jai";
#load "Code_Emission.jai";
#load "Utils.jai";

