main :: () {
    success := run_compiler();

    log("\n================= COMPILER EXITED ===================\n");
    if !success { 
        log("Compiler failed with errors. Exiting."); 
        exit(1); 
    }
}

run_compiler :: () -> success: bool = true {
    // defer report_memory_leaks();
    
    ctx: Compiler_Context;
    init(*ctx); 
    defer deinit(*ctx);

    args := get_compiler_args(,, ctx.general_arena);
    src := run_preprocessor(args.src_path,, ctx.general_arena);
    erp := Error_Reporter.{src_path = args.src_path, src = src};

    symbols: Symbol_Table = ---;
    init(*symbols);

    tokens := ifx args.flags & .LEX scan_tokens(src, *erp, DEBUG_LOG,, ctx.lexer_arena);

    ast := ifx args.flags & .PARSE && tokens.count > 0 && !has_error(*erp) {
        defer deinit(*ctx, .LEXER);
        parse_ast(tokens, *erp, DEBUG_LOG,, ctx.parser_arena);
    }

    if args.flags & .SEMA && ast && !has_error(*erp) {
        sema(ast, *symbols, *erp, DEBUG_LOG,, ctx.parser_arena);
    }

    tacky := ifx args.flags & .TACKY && ast && !has_error(*erp) {
        defer deinit(*ctx, .PARSER);
        gen_tacky(ast, *symbols, DEBUG_LOG,, ctx.tacky_arena);
    }

    asm_ir := ifx args.flags & .CODE_GEN && tacky && !has_error(*erp) {
        defer deinit(*ctx, .TACKY);
        asm_gen(tacky, *symbols, DEBUG_LOG,, ctx.asm_ir_arena);
    }

    // if args.flags & .ALL && asm_ir && !has_error(*erp) {
    //     defer deinit(*ctx, .ASM_IR);
    //     code_emm(args.src_path_without_ext, asm_ir, symbols, DEBUG_LOG,, ctx.code_emm_arena);
    // }

    // if args.flags & .ALL && !has_error(*erp) {
    //     assember_and_linker(args.src_path_without_ext, args.output_type);
    // }
    if has_error(*erp) {
        print_errors(*erp);
        return false;
    }
    return true;
}

has_error :: (erp: *Error_Reporter) -> bool {
    return erp.error_items.count > 0;
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
