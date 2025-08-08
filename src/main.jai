main :: () {
    defer report_memory_leaks();
    
    cc: Compiler_Context;
    init(*cc);
    defer deinit(*cc);
    
    run_compiler(*cc,, cc.general_arena);
    
    print("\n================= COMPILER EXITED ===================\n");
}

run_compiler :: (cc: *Compiler_Context) {
    args := get_compiler_args();
    preprocessed_src := run_preprocessor(args.src_path);
    error_reporter := Error_Reporter.{src_path = args.src_path, src = preprocessed_src};
    
    symbols: Symbol_Table = ---;
    init(*symbols,, cc.symbol_arena);
    
    tokens := ifx args.flags & .LEX scan_tokens(preprocessed_src, *error_reporter,, cc.lexer_arena) else .[];
    
    ast := ifx args.flags & .PARSE parse_ast(tokens, *error_reporter, debug_log = SUPER_DEBUG,, cc.parser_arena) else null;
    deinit(cc, .LEXER);
    
    if args.flags & .SEMA sema(ast, *symbols, *error_reporter, debug_log = SUPER_DEBUG,, cc.parser_arena);
    
    tacky :=  ifx args.flags & .TACKY gen_tacky(ast, debug_log = SUPER_DEBUG,, cc.tacky_arena) else null;
    deinit(cc, .PARSER);
    
    asm_ir := ifx args.flags & .CODE_GEN asm_gen(tacky, symbols, debug_log = SUPER_DEBUG,, cc.asm_ir_arena) else null;
    deinit(cc, .TACKY);
    
    if args.flags & .ALL code_emm(args.src_path_without_ext, asm_ir, symbols, debug_log = SUPER_DEBUG,, cc.code_emm_arena);
    deinit(cc, .ASM_IR);
    
    if args.flags & .ALL assember_and_linker(args.src_path_without_ext, args.output_type);
}

SUPER_DEBUG :: true;


#import "Basic"()(MEMORY_DEBUGGER=true, REPLACEMENT_INTERFACE=ARENA_AWARE_MEMORY_DEBUGGER);
#import "Not_Basic"()(MEMORY_DEBUGGER=true);
String :: #import "String";
Process :: #import "Process";
#import "Lexer";
#import "Parser";
#import "File";
#import "Error_Reporter";
#import "Compiler_Util";
#import "Sema";
#import "Tacky_IR";
#import "Asm_Gen";
#import "Code_Emission";
#import "Compiler_Args";
#import "Symbol_Table";
#import "Hash_Table";
#import "Compiler_Context";
