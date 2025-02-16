main :: () {
    // everything on temporary allocator, don't wanna manage memory for now
    push_allocator(temp);
    defer { report_memory_leaks(); };

    args := get_cli_args();
    print("%\n", args);

    lexer := ifx args.flags & .LEX lex(args);
    ast := ifx args.flags & .PARSE ast_parse(*lexer);
    tacky := ifx args.flags & .TACKY gen_program_tacky(ast);
    asm_construct := ifx args.flags & .CODE_GEN asm_gen(tacky);
    // if args.flags & .CODE_GEN code_emm(args, asm_construct); 
    // if args.flags & .ALL assember_and_linker(args);
}


#import "Basic"()(MEMORY_DEBUGGER=true);
String :: #import "String";
Process :: #import "Process";
#import "File";
#load "Lexer.jai";
#load "Cli_Args.jai";
#load "Ast.jai";
#load "Tacky_IR.jai";
#load "Asm_Gen.jai";
// #load "Code_Emission.jai";
// #load "Compiler_Util.jai";




