#scope_file

#import "Compiler";
#import "Parser";
#import "Lexer";

#run _run_tests();

_run_tests :: () {
    log("Running test for file: %", #file);
    run_tests:: () -> bool {
        options := get_build_options();
        args := options.compile_time_command_line;
        for args if it == "tests" return true;
        return false;
    }

    if !run_tests() return;

    multi_digit_number_test :: () {
        src := "12345";

        error_reporter := Error_Reporter.{src = src, src_path = ""};
        lexer          := parse_lex_tokens(src, *error_reporter);
        program_ast    := parse_ast(*lexer, *error_reporter);

        sb: String_Builder;
        sb_writer := make_sb_writer(*sb);
        print_program_ast(*sb_writer, program_ast);
    }
}