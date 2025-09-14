main :: () {
    success := ifx 1 {
        defer report_memory_leaks();
        ctx: Compiler_Context;
        init(*ctx);
        defer deinit(*ctx);
        
        run_compiler(*ctx);
    }
    print("\n================= COMPILER EXITED ===================\n");
    if !success {
        log_error("Compiler failed with errors. Exiting.");
        exit(1);
    }
}

run_compiler :: (ctx: *Compiler_Context) -> success: bool = true {
    args := get_compiler_args(,, ctx.general_arena);
    src := run_preprocessor(args.src_path,, ctx.general_arena);
    erp := Error_Reporter.{src_path = args.src_path, src = src};
    
    symbols: Symbol_Table = ---;
    init(*symbols,, ctx.symbol_arena);
    
    tokens: []Token = .[]; 
    if args.flags & .LEX {
        tokens = scan_tokens(src, *erp, DEBUG_LOG,, ctx.lexer_arena);
        fail_fast();
    }
    
    ast: *Program_Ast = null;
    if args.flags & .PARSE && tokens.count > 0 {
        defer deinit(ctx, .LEXER);
        ast = parse_ast(tokens, *erp, DEBUG_LOG,, ctx.parser_arena);
        fail_fast();
    }
    
    if args.flags & .SEMA && ast != null {
        sema(ast, *symbols, *erp, DEBUG_LOG,, ctx.parser_arena);
        fail_fast();
    }
    
    tacky: *Program_Tacky = null;
    if args.flags & .TACKY && ast != null {
        defer deinit(ctx, .PARSER);
        tacky = gen_tacky(ast, DEBUG_LOG,, ctx.tacky_arena);
        fail_fast();
    }
    
    asm_ir: *Program_Asm = null; 
    if args.flags & .CODE_GEN && tacky != null {
        defer deinit(ctx, .TACKY);
        asm_ir = asm_gen(tacky, symbols, DEBUG_LOG,, ctx.asm_ir_arena);
    }
    
    if args.flags & .ALL && asm_ir != null {
        code_emm(args.src_path_without_ext, asm_ir, symbols, DEBUG_LOG,, ctx.code_emm_arena);
        deinit(ctx, .ASM_IR);
    }
    
    if args.flags & .ALL {
        assember_and_linker(args.src_path_without_ext, args.output_type);
    }
    return;
}

fail_fast :: () #expand {
    if `erp.error_items.count <= 0 return;
    
    print_errors(*`erp, panic = true);
    `return success = false;
}

DEBUG_LOG :: true;

#import "Basic"()(MEMORY_DEBUGGER=true, REPLACEMENT_INTERFACE=ARENA_AWARE_MEMORY_DEBUGGER);
#import "Not_Basic"()(MEMORY_DEBUGGER=true);
Posix :: #import "POSIX";
#import "Lexer";
#import "Parser";
#import "Error_Reporter";
#import "Compiler_Util";
#import "Sema";
#import "Tacky_IR";
#import "Asm_Gen";
#import "Code_Emission";
#import "Compiler_Args";
#import "Symbol_Table";
#import "Compiler_Context";
