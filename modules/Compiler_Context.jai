Compiler_Context :: struct {
    allocator:             Allocator;
    general_arena_state:   *Arena;
    general_arena:         Allocator;
    lexer_arena_state:     *Arena;
    lexer_arena:           Allocator;
    parser_arena_state:    *Arena;
    parser_arena:          Allocator;
    symbol_arena_state:    *Arena;
    symbol_arena:          Allocator;
    tacky_arena_state:     *Arena;
    tacky_arena:           Allocator;
    asm_ir_arena_state:    *Arena;
    asm_ir_arena:          Allocator;
    code_emm_arena_state:  *Arena;
    code_emm_arena:       Allocator;
}


init :: (using ctx: *Compiler_Context) {
    allocator = context.allocator;
    
    general_arena_state  = arena_init();
    general_arena = .{arena_allocator_proc, general_arena_state};
    
    lexer_arena_state = arena_init();
    lexer_arena = .{arena_allocator_proc, lexer_arena_state};
    
    parser_arena_state = arena_init();
    parser_arena = .{arena_allocator_proc, parser_arena_state};
    
    symbol_arena_state = arena_init();
    symbol_arena = .{arena_allocator_proc, symbol_arena_state};
    
    tacky_arena_state = arena_init();
    tacky_arena = .{arena_allocator_proc, tacky_arena_state};
    
    asm_ir_arena_state = arena_init();
    asm_ir_arena = .{arena_allocator_proc, asm_ir_arena_state};
    
    code_emm_arena_state = arena_init();
    code_emm_arena = .{arena_allocator_proc, code_emm_arena_state};
}

deinit :: (using ctx: *Compiler_Context, which: Arena_Type = .ALL) {
    push_allocator(allocator);
    if general_arena_state && (which & .GENERAL || which & .ALL) {
        arena_deinit(general_arena_state);
        general_arena_state = null;
    }
    if lexer_arena_state    && (which & .LEXER || which & .ALL) {
        arena_deinit(lexer_arena_state);
        lexer_arena_state = null;
    }
    if parser_arena_state   && (which & .PARSER || which & .ALL) {
        arena_deinit(parser_arena_state);
        parser_arena_state = null;
    }
    if symbol_arena_state   && (which & .SYMBOLS || which & .ALL) {
        arena_deinit(symbol_arena_state);
        symbol_arena_state = null;
    }
    if tacky_arena_state    && (which & .TACKY || which & .ALL) {
        arena_deinit(tacky_arena_state);
        tacky_arena_state = null;
    }
    if asm_ir_arena_state   && (which & .ASM_IR || which & .ALL) {
        arena_deinit(asm_ir_arena_state);
        asm_ir_arena_state = null;
    }
    if code_emm_arena_state && (which & .CODE_EMM || which & .ALL) {
        arena_deinit(code_emm_arena_state);
        code_emm_arena_state = null;
    }
}

#scope_file

Arena_Type :: enum_flags { GENERAL; LEXER; PARSER; SYMBOLS; TACKY; ASM_IR; CODE_EMM; ALL; };

#import "Basic";
#import "Not_Basic";