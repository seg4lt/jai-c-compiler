#scope_file

#import "Compiler";
#import "Parser";
#import "Lexer";

// #run _run_tests();

_run_tests :: () {
    log("Running test for file: %", #file);
    if !run_tests() return;
    multi_digit_number_test();
}

run_tests:: () -> bool {
    options := get_build_options();
    args := options.compile_time_command_line;
    for args if it == "tests" return true;
    return false;
}

multi_digit_number_test :: () {
    src := #string DONE
    int main(void) {
        int x = 123;
        return x;
    }
    DONE;

    error_reporter := Error_Reporter.{src = src, src_path = ""};
    lexer          := parse_lex_tokens(src, *error_reporter);
    program_ast    := parse_ast(*lexer, *error_reporter);

    sb: String_Builder;
    sb_writer := sb_writer_new(*sb);
    print_program_ast(*sb_writer, program_ast);

    ast_string := builder_to_string(*sb);
    expected_ast_string := #string DONE
-- AST --
[PROGRAM]・
┊﹣[FN]・main
┊﹣┊﹣[BLOCK]
┊﹣┊﹣┊﹣[DECL]・x・=・123
┊﹣┊﹣┊﹣[RETURN]・
┊﹣┊﹣┊﹣┊﹣[VAR]・x・
DONE;
    actual_ast_split := split(ast_string, "\n"); 
    expected_ast_split := split(expected_ast_string, "\n");
    for 0..actual_ast_split.count-1 {
        if actual_ast_split[it] != expected_ast_split[it] {
            log_error("Expected: %\nActual: %\n", expected_ast_string, ast_string);
            assert(false, "Line % doesn't match. \nExpected: %\nActual  : %\n", it, expected_ast_split[it], actual_ast_split[it]);
            return;
        }
    }
};