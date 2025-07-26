main :: () {
    push_allocator(temp);
    defer { reset_temporary_storage(); report_memory_leaks(); };

    args := get_cli_args();
    src_content := run_preprocessor(args.src_path);

    erp := Error_Reporter.{src_path = args.src_path, src = src_content};
    st: Symbol_Table;
    init(*st);

    lexer         := ifx args.flags & .LEX          parse_lex_tokens(src_content, *erp, do_print=true);
    ast           := ifx args.flags & .PARSE        parse_ast(*lexer, *erp, do_print=true);
    if args.flags                   & .SEMA         sema(ast, *st, *erp, do_print=true);
    tacky         := ifx args.flags & .TACKY        gen_program_tacky(ast, do_print=true);
    asm_construct := ifx args.flags & .CODE_GEN     asm_gen(tacky, st, do_print=true);
    // if args.flags                   & .ALL          code_emm(args.src_path_without_ext, asm_construct);
    // if args.flags                   & .ALL          assember_and_linker(args.src_path_without_ext, args.output_type);
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
#import "Tacky_IR";
#import "Asm_Gen";
#import "Code_Emission";
#import "Cli_Args";
#import "Symbol_Table";
#import "Hash_Table";

