#scope_file

#import "Compiler";
#import "Parser";

#run _run_tests();

_run_tests :: () {
    log("Running test for file: %", #file);
    run_tests:: () -> bool {
        options := get_build_options();
        args := options.compile_time_command_line;
        for args if it == "tests" return true;
        return false;
    }

    get_lexer :: (src: string, error_reporter: *Error_Reporter) -> Lexer {
        lexer := parse_lex_tokens(src, error_reporter);
        return lexer;
    }

    verify_tokens :: (test_name: string, src: string, expected_tokens: [..]Token) {
        error_reporter: Error_Reporter;
        lexer := get_lexer(src, *error_reporter);
        assert(expected_tokens.count == lexer.tokens.count, "Lexer token count doesn't match");

        for 0..lexer.tokens.count-1 {
            a_token := lexer.tokens.data[it];
            e_token := expected_tokens[it];
            assert(a_token.type == e_token.type, "idx: % - Lexer token type doesn't match. Expected % found %", it, e_token.type, a_token.type);
        }
       log("PASS - %", test_name);
    }

    test__return_stmt :: () {
        src := #string DONE
        int main(void) {
            return 0;
        }
        DONE
        expected_tokens: [..]Token;
        array_add(*expected_tokens,
            // int main(void) {
            .{.INT, "int", 1, 1}, 
            .{.IDENT, "main", 1, 1}, 
            .{.LPAREN, "(", 1, 1}, 
            .{.VOID, "void", 1, 1}, 
            .{.RPAREN, ")", 1, 1}, 
            .{.LCURLY, "{", 1, 1},
            // return 0;
            .{.RETURN, "return", 2, 2}, 
            .{.INT_LITERAL, "0", 2, 2}, 
            .{.SEMICOLON, ";", 2, 2},
            // }
            .{.RCURLY, "}", 3, 2}
        );
        verify_tokens(#procedure_name(), src, expected_tokens);
    } 

    test__variable :: () {
        src := #string DONE
        var x = 10;
        x = 20;
        DONE
        expected_tokens: [..]Token;
        array_add(*expected_tokens, 
            // var x = 10;
            .{.IDENT, "var", 1, 1}, 
            .{.IDENT, "x", 1, 1}, 
            .{.ASSIGN, "=", 1, 1}, 
            .{.INT_LITERAL, "10", 1, 1}, 
            .{.SEMICOLON, ";", 1, 1}, 
            // x = 20;
            .{.IDENT, "x", 2, 1}, 
            .{.ASSIGN, "=", 2, 1}, 
            .{.INT_LITERAL, "20", 2, 1}, 
            .{.SEMICOLON, ";", 2, 1}
        );
        verify_tokens(#procedure_name(), src, expected_tokens);
    }

    test__relational_operators :: () {
        src := #string DONE
        a < b;
        a <= b;
        a > b;
        a >= b;
        a == b;
        a != b;
        DONE
        expected_tokens: [..]Token;
        array_add(*expected_tokens, 
            // a < b;
            .{.IDENT, "a", 1, 1},
            .{.LESS, "<", 1, 1},
            .{.IDENT, "b", 1, 1},
            .{.SEMICOLON, ";", 1, 1},
            // a <= b;
            .{.IDENT, "a", 2, 1},
            .{.LESS_EQUAL, "<=", 2, 1},
            .{.IDENT, "b", 2, 1},
            .{.SEMICOLON, ";", 2, 1},
            // a > b;
            .{.IDENT, "a", 3, 1},
            .{.GREATER, ">", 3, 1},
            .{.IDENT, "b", 3, 1},
            .{.SEMICOLON, ";", 3, 1},
            // a >= b;
            .{.IDENT, "a", 4, 1},
            .{.GREATER_EQUAL, ">=", 4, 1},
            .{.IDENT, "b", 4, 1},
            .{.SEMICOLON, ";", 4, 1},
            // a == b;
            .{.IDENT, "a", 5, 1},
            .{.EQUAL_EQUAL, "==", 5, 1},
            .{.IDENT, "b", 5, 1},
            .{.SEMICOLON, ";", 5, 1},
            // a != b;
            .{.IDENT, "a", 6, 1},
            .{.NOT_EQUAL, "!=", 6, 1},
            .{.IDENT, "b", 6, 1},
            .{.SEMICOLON, ";", 6, 1}
        );
        verify_tokens(#procedure_name(), src, expected_tokens);
    }

    test__compound_assignment_operators :: () {
        src := #string DONE
        a += b;
        a -= b;
        a *= b;
        a /= b;
        a %= b;
        a <<= b;
        a >>= b;
        a &= b;
        a |= b;
        a ^= b;
        DONE
        expected_tokens: [..]Token;

        // a += b;
        array_add(*expected_tokens, .{.IDENT, "a", 1, 1});
        array_add(*expected_tokens, .{.PLUS_EQUAL, "+=", 1, 1});
        array_add(*expected_tokens, .{.IDENT, "b", 1, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 1, 1});

        // a -= b;
        array_add(*expected_tokens, .{.IDENT, "a", 2, 1});
        array_add(*expected_tokens, .{.MINUS_EQUAL, "-=", 2, 1});
        array_add(*expected_tokens, .{.IDENT, "b", 2, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 2, 1});

        // a *= b;
        array_add(*expected_tokens, .{.IDENT, "a", 3, 1});
        array_add(*expected_tokens, .{.MULTIPLY_EQUAL, "*=", 3, 1});
        array_add(*expected_tokens, .{.IDENT, "b", 3, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 3, 1});

        // a /= b;
        array_add(*expected_tokens, .{.IDENT, "a", 4, 1});
        array_add(*expected_tokens, .{.DIVIDE_EQUAL, "/=", 4, 1});
        array_add(*expected_tokens, .{.IDENT, "b", 4, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 4, 1});

        // a %= b;
        array_add(*expected_tokens, .{.IDENT, "a", 5, 1});
        array_add(*expected_tokens, .{.MOD_EQUAL, "%=", 5, 1});
        array_add(*expected_tokens, .{.IDENT, "b", 5, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 5, 1});

        // a <<= b;
        array_add(*expected_tokens, .{.IDENT, "a", 6, 1});
        array_add(*expected_tokens, .{.LEFT_SHIFT_EQUAL, "<<=", 6, 1});
        array_add(*expected_tokens, .{.IDENT, "b", 6, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 6, 1});

        // a >>= b;
        array_add(*expected_tokens, .{.IDENT, "a", 7, 1});
        array_add(*expected_tokens, .{.RIGHT_SHIFT_EQUAL, ">>=", 7, 1});
        array_add(*expected_tokens, .{.IDENT, "b", 7, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 7, 1});

        // a &= b;
        array_add(*expected_tokens, .{.IDENT, "a", 8, 1});
        array_add(*expected_tokens, .{.BITWISE_AND_EQUAL, "&=", 8, 1});
        array_add(*expected_tokens, .{.IDENT, "b", 8, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 8, 1});

        // a |= b;
        array_add(*expected_tokens, .{.IDENT, "a", 9, 1});
        array_add(*expected_tokens, .{.BITWISE_OR_EQUAL, "|=", 9, 1});
        array_add(*expected_tokens, .{.IDENT, "b", 9, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 9, 1});

        // a ^= b;
        array_add(*expected_tokens, .{.IDENT, "a", 10, 1});
        array_add(*expected_tokens, .{.BITWISE_XOR_EQUAL, "^=", 10, 1});
        array_add(*expected_tokens, .{.IDENT, "b", 10, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 10, 1});
        verify_tokens(#procedure_name(), src, expected_tokens);
    }

    test__unary_operators :: () {
        src := #string DONE
        !a;
        ~b;
        ++c;
        --d;
        c++;
        d--;
        DONE
        expected_tokens: [..]Token;
        array_add(*expected_tokens, 
            // !a;
            .{.NOT, "!", 1, 1},
            .{.IDENT, "a", 1, 1},
            .{.SEMICOLON, ";", 1, 1},
            // ~b;
            .{.BITWISE_NOT, "~", 2, 1},
            .{.IDENT, "b", 2, 1},
            .{.SEMICOLON, ";", 2, 1},
            // ++c;
            .{.PLUS_PLUS, "++", 3, 1},
            .{.IDENT, "c", 3, 1},
            .{.SEMICOLON, ";", 3, 1},
            // --d;
            .{.MINUS_MINUS, "--", 4, 1},
            .{.IDENT, "d", 4, 1},
            .{.SEMICOLON, ";", 4, 1},
            // c++;
            .{.IDENT, "c", 5, 1},
            .{.PLUS_PLUS, "++", 5, 1},
            .{.SEMICOLON, ";", 5, 1},
            // d--;
            .{.IDENT, "d", 6, 1},
            .{.MINUS_MINUS, "--", 6, 1},
            .{.SEMICOLON, ";", 6, 1}
        );
        verify_tokens(#procedure_name(), src, expected_tokens);
    }

    test__ternary_operator :: () {
        src := #string DONE
        x = a ? b : c;
        DONE
        expected_tokens: [..]Token;

        // x = a ? b : c;
        array_add(*expected_tokens, .{.IDENT, "x", 1, 1});
        array_add(*expected_tokens, .{.ASSIGN, "=", 1, 1});
        array_add(*expected_tokens, .{.IDENT, "a", 1, 1});
        array_add(*expected_tokens, .{.QUESTION_MARK, "?", 1, 1});
        array_add(*expected_tokens, .{.IDENT, "b", 1, 1});
        array_add(*expected_tokens, .{.COLON, ":", 1, 1});
        array_add(*expected_tokens, .{.IDENT, "c", 1, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 1, 1});
        verify_tokens(#procedure_name(), src, expected_tokens);
    }

    test__bitwise_operators :: () {
        src := #string DONE
        a & b;
        c | d;
        e ^ f;
        ~g;
        h << i;
        j >> k;
        DONE
        expected_tokens: [..]Token;
        array_add(*expected_tokens, 
            // a & b;
            .{.IDENT, "a", 1,1},
            .{.BITWISE_AND, "&", 1,1},
            .{.IDENT, "b", 1,1},
            .{.SEMICOLON, ";", 1,1},
            // c | d;
            .{.IDENT, "c", 2,1},
            .{.BITWISE_OR, "|", 2,1},
            .{.IDENT, "d", 2,1},
            .{.SEMICOLON, ";", 2,1},
            // e ^ f;
            .{.IDENT, "e", 3,1},
            .{.BITWISE_XOR, "^", 3,1},
            .{.IDENT, "f", 3,1},
            .{.SEMICOLON, ";", 3,1},
            // ~g;
            .{.BITWISE_NOT, "~", 4,1},
            .{.IDENT, "g", 4,1},
            .{.SEMICOLON, ";", 4,1},
            // h << i;
            .{.IDENT, "h", 5,1},
            .{.LEFT_SHIFT, "<<", 5,1},
            .{.IDENT, "i", 5,1},
            .{.SEMICOLON, ";", 5,1},
            // j >> k;
            .{.IDENT, "j", 6,1},
            .{.RIGHT_SHIFT, ">>", 6,1},
            .{.IDENT, "k", 6,1},
            .{.SEMICOLON, ";", 6,1}
        );
        verify_tokens(#procedure_name(), src, expected_tokens);
    }

    test__logical_operators :: () {
        src := #string DONE
        a && b;
        c || d;
        !e;
        DONE
        expected_tokens: [..]Token;
        array_add(*expected_tokens, 
            // a && b;
            .{.IDENT, "a", 1, 1},
            .{.AND, "&&", 1, 1},
            .{.IDENT, "b", 1, 1},
            .{.SEMICOLON, ";", 1, 1},
            // c || d;
            .{.IDENT, "c", 2, 1},
            .{.OR, "||", 2, 1},
            .{.IDENT, "d", 2, 1},
            .{.SEMICOLON, ";", 2, 1},
            // !e;
            .{.NOT, "!", 3, 1},
            .{.IDENT, "e", 3, 1},
            .{.SEMICOLON, ";", 3, 1}
        );
        verify_tokens(#procedure_name(), src, expected_tokens);
    }

    test__keywords :: () {
        src := #string DONE
        int x;
        void func(void);
        return value;
        if (condition) { body; }
        else { alternative; }
        label:
        goto label;
        for (int i = 0; i < 10; i++ ) { int x = i; }
        do { int x = 1; } while ( i < 10 );
        while (i < 10) { ++i; }
        break;
        continue;
        switch (value) {
            case 1: stmt1;
            default: stmt_default;
        }
        DONE
        expected_tokens: [..]Token;
        // int x;
        array_add(*expected_tokens, .{.INT, "int", 1, 1});
        array_add(*expected_tokens, .{.IDENT, "x", 1, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 1, 1});

        // void func(void);
        array_add(*expected_tokens, .{.VOID, "void", 2, 1});
        array_add(*expected_tokens, .{.IDENT, "func", 2, 1});
        array_add(*expected_tokens, .{.LPAREN, "(", 2, 1});
        array_add(*expected_tokens, .{.VOID, "void", 2, 1});
        array_add(*expected_tokens, .{.RPAREN, ")", 2, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 2, 1});

        // return value;
        array_add(*expected_tokens, .{.RETURN, "return", 3, 1});
        array_add(*expected_tokens, .{.IDENT, "value", 3, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 3, 1});

        // if (condition) { body; }
        array_add(*expected_tokens, .{.IF, "if", 4, 1});
        array_add(*expected_tokens, .{.LPAREN, "(", 4, 1});
        array_add(*expected_tokens, .{.IDENT, "condition", 4, 1});
        array_add(*expected_tokens, .{.RPAREN, ")", 4, 1});
        array_add(*expected_tokens, .{.LCURLY, "{", 4, 1});
        array_add(*expected_tokens, .{.IDENT, "body", 4, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 4, 1});
        array_add(*expected_tokens, .{.RCURLY, "}", 4, 1});

        // else { alternative; }
        array_add(*expected_tokens, .{.ELSE, "else", 5, 1});
        array_add(*expected_tokens, .{.LCURLY, "{", 5, 1});
        array_add(*expected_tokens, .{.IDENT, "alternative", 5, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 5, 1});
        array_add(*expected_tokens, .{.RCURLY, "}", 5, 1});

        // label:
        array_add(*expected_tokens, .{.IDENT, "label", 6, 1});
        array_add(*expected_tokens, .{.COLON, ":", 6, 1});

        // goto label;
        array_add(*expected_tokens, .{.GOTO, "goto", 7, 1});
        array_add(*expected_tokens, .{.IDENT, "label", 7, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 7, 1});

        // for (int i = 0; i < 10; i++ ) { int x = i; }
        array_add(*expected_tokens, .{.FOR, "for", 8, 1});
        array_add(*expected_tokens, .{.LPAREN, "(", 8, 1});
        array_add(*expected_tokens, .{.INT, "int", 8, 1});
        array_add(*expected_tokens, .{.IDENT, "i", 8, 1});
        array_add(*expected_tokens, .{.ASSIGN, "=", 8, 1});
        array_add(*expected_tokens, .{.INT_LITERAL, "0", 8, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 8, 1});
        array_add(*expected_tokens, .{.IDENT, "i", 8, 1});
        array_add(*expected_tokens, .{.LESS, "<", 8, 1});
        array_add(*expected_tokens, .{.INT_LITERAL, "10", 8, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 8, 1});
        array_add(*expected_tokens, .{.IDENT, "i", 8, 1});
        array_add(*expected_tokens, .{.PLUS_PLUS, "++", 8, 1});
        array_add(*expected_tokens, .{.RPAREN, ")", 8, 1});
        array_add(*expected_tokens, .{.LCURLY, "{", 8, 1});
        array_add(*expected_tokens, .{.INT, "int", 8, 1});
        array_add(*expected_tokens, .{.IDENT, "x", 8, 1});
        array_add(*expected_tokens, .{.ASSIGN, "=", 8, 1});
        array_add(*expected_tokens, .{.IDENT, "i", 8, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 8, 1});
        array_add(*expected_tokens, .{.RCURLY, "}", 8, 1});

        // do { int x = 1; } while ( i < 10 );
        array_add(*expected_tokens, .{.DO, "do", 9, 1});
        array_add(*expected_tokens, .{.LCURLY, "{", 9, 1});
        array_add(*expected_tokens, .{.INT, "int", 9, 1});
        array_add(*expected_tokens, .{.IDENT, "x", 9, 1});
        array_add(*expected_tokens, .{.ASSIGN, "=", 9, 1});
        array_add(*expected_tokens, .{.INT_LITERAL, "1", 9, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 9, 1});
        array_add(*expected_tokens, .{.RCURLY, "}", 9, 1});
        array_add(*expected_tokens, .{.WHILE, "while", 9, 1});
        array_add(*expected_tokens, .{.LPAREN, "(", 9, 1});
        array_add(*expected_tokens, .{.IDENT, "i", 9, 1});
        array_add(*expected_tokens, .{.LESS, "<", 9, 1});
        array_add(*expected_tokens, .{.INT_LITERAL, "10", 9, 1});
        array_add(*expected_tokens, .{.RPAREN, ")", 9, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 9, 1});

        // while (i < 10) { ++i; }
        array_add(*expected_tokens, .{.WHILE, "while", 10, 1});
        array_add(*expected_tokens, .{.LPAREN, "(", 10, 1});
        array_add(*expected_tokens, .{.IDENT, "i", 10, 1});
        array_add(*expected_tokens, .{.LESS, "<", 10, 1});
        array_add(*expected_tokens, .{.INT_LITERAL, "10", 10, 1});
        array_add(*expected_tokens, .{.RPAREN, ")", 10, 1});
        array_add(*expected_tokens, .{.LCURLY, "{", 10, 1});
        array_add(*expected_tokens, .{.PLUS_PLUS, "++", 10, 1});
        array_add(*expected_tokens, .{.IDENT, "i", 10, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 10, 1});
        array_add(*expected_tokens, .{.RCURLY, "}", 10, 1});

        // break;
        array_add(*expected_tokens, .{.BREAK, "break", 11, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 11, 1});

        // continue;
        array_add(*expected_tokens, .{.CONTINUE, "continue", 12, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 12, 1});

        // switch (value) {
        array_add(*expected_tokens, .{.SWITCH, "switch", 13, 1});
        array_add(*expected_tokens, .{.LPAREN, "(", 13, 1});
        array_add(*expected_tokens, .{.IDENT, "value", 13, 1});
        array_add(*expected_tokens, .{.RPAREN, ")", 13, 1});
        array_add(*expected_tokens, .{.LCURLY, "{", 13, 1});

        // case 1: stmt1;
        array_add(*expected_tokens, .{.CASE, "case", 14, 1});
        array_add(*expected_tokens, .{.INT_LITERAL, "1", 14, 1});
        array_add(*expected_tokens, .{.COLON, ":", 14, 1});
        array_add(*expected_tokens, .{.IDENT, "stmt1", 14, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 14, 1});

        // default: stmt_default;
        array_add(*expected_tokens, .{.DEFAULT, "default", 15, 1});
        array_add(*expected_tokens, .{.COLON, ":", 15, 1});
        array_add(*expected_tokens, .{.IDENT, "stmt_default", 15, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 15, 1});

        // }
        array_add(*expected_tokens, .{.RCURLY, "}", 16, 1});
        verify_tokens(#procedure_name(), src, expected_tokens);
    }

    test__conditional_statements :: () {
        src := #string DONE
        if (a > b) {
            c = 1;
        } else if (a < b) {
            c = 2;
        } else {
            c = 3;
        }

        result = (x > y) ? x : y;
        DONE
        expected_tokens: [..]Token;
        // if (a > b) {
        array_add(*expected_tokens, .{.IF, "if", 1, 1});
        array_add(*expected_tokens, .{.LPAREN, "(", 1, 1});
        array_add(*expected_tokens, .{.IDENT, "a", 1, 1});
        array_add(*expected_tokens, .{.GREATER, ">", 1, 1});
        array_add(*expected_tokens, .{.IDENT, "b", 1, 1});
        array_add(*expected_tokens, .{.RPAREN, ")", 1, 1});
        array_add(*expected_tokens, .{.LCURLY, "{", 1, 1});

        // c = 1;
        array_add(*expected_tokens, .{.IDENT, "c", 2, 1});
        array_add(*expected_tokens, .{.ASSIGN, "=", 2, 1});
        array_add(*expected_tokens, .{.INT_LITERAL, "1", 2, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 2, 1});

        // }
        array_add(*expected_tokens, .{.RCURLY, "}", 3, 1});

        // else if (a < b) {
        array_add(*expected_tokens, .{.ELSE, "else", 3, 1});
        array_add(*expected_tokens, .{.IF, "if", 3, 1});
        array_add(*expected_tokens, .{.LPAREN, "(", 3, 1});
        array_add(*expected_tokens, .{.IDENT, "a", 3, 1});
        array_add(*expected_tokens, .{.LESS, "<", 3, 1});
        array_add(*expected_tokens, .{.IDENT, "b", 3, 1});
        array_add(*expected_tokens, .{.RPAREN, ")", 3, 1});
        array_add(*expected_tokens, .{.LCURLY, "{", 3, 1});

        // c = 2;
        array_add(*expected_tokens, .{.IDENT, "c", 4, 1});
        array_add(*expected_tokens, .{.ASSIGN, "=", 4, 1});
        array_add(*expected_tokens, .{.INT_LITERAL, "2", 4, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 4, 1});

        // }
        array_add(*expected_tokens, .{.RCURLY, "}", 5, 1});

        // else {
        array_add(*expected_tokens, .{.ELSE, "else", 5, 1});
        array_add(*expected_tokens, .{.LCURLY, "{", 5, 1});

        // c = 3;
        array_add(*expected_tokens, .{.IDENT, "c", 6, 1});
        array_add(*expected_tokens, .{.ASSIGN, "=", 6, 1});
        array_add(*expected_tokens, .{.INT_LITERAL, "3", 6, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 6, 1});

        // }
        array_add(*expected_tokens, .{.RCURLY, "}", 7, 1});

        // result = (x > y) ? x : y;
        array_add(*expected_tokens, .{.IDENT, "result", 9, 1});
        array_add(*expected_tokens, .{.ASSIGN, "=", 9, 1});
        array_add(*expected_tokens, .{.LPAREN, "(", 9, 1});
        array_add(*expected_tokens, .{.IDENT, "x", 9, 1});
        array_add(*expected_tokens, .{.GREATER, ">", 9, 1});
        array_add(*expected_tokens, .{.IDENT, "y", 9, 1});
        array_add(*expected_tokens, .{.RPAREN, ")", 9, 1});
        array_add(*expected_tokens, .{.QUESTION_MARK, "?", 9, 1});
        array_add(*expected_tokens, .{.IDENT, "x", 9, 1});
        array_add(*expected_tokens, .{.COLON, ":", 9, 1});
        array_add(*expected_tokens, .{.IDENT, "y", 9, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 9, 1});
        verify_tokens(#procedure_name(), src, expected_tokens);
    }

    test__switch_statement :: () {
        src := #string DONE
        switch (value) {
            case 1:
                result = one;
                break;
            case 2:
                result = two;
                break;
            default:
                result = other;
        }
        DONE
        expected_tokens: [..]Token;
        // switch (value) {
        array_add(*expected_tokens, .{.SWITCH, "switch", 1, 1});
        array_add(*expected_tokens, .{.LPAREN, "(", 1, 1});
        array_add(*expected_tokens, .{.IDENT, "value", 1, 1});
        array_add(*expected_tokens, .{.RPAREN, ")", 1, 1});
        array_add(*expected_tokens, .{.LCURLY, "{", 1, 1});

        // case 1:
        array_add(*expected_tokens, .{.CASE, "case", 2, 1});
        array_add(*expected_tokens, .{.INT_LITERAL, "1", 2, 1});
        array_add(*expected_tokens, .{.COLON, ":", 2, 1});

        // result = one;
        array_add(*expected_tokens, .{.IDENT, "result", 3, 1});
        array_add(*expected_tokens, .{.ASSIGN, "=", 3, 1});
        array_add(*expected_tokens, .{.IDENT, "one", 3, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 3, 1});

        // break;
        array_add(*expected_tokens, .{.BREAK, "break", 4, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 4, 1});

        // case 2:
        array_add(*expected_tokens, .{.CASE, "case", 5, 1});
        array_add(*expected_tokens, .{.INT_LITERAL, "2", 5, 1});
        array_add(*expected_tokens, .{.COLON, ":", 5, 1});

        // result = two;
        array_add(*expected_tokens, .{.IDENT, "result", 6, 1});
        array_add(*expected_tokens, .{.ASSIGN, "=", 6, 1});
        array_add(*expected_tokens, .{.IDENT, "two", 6, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 6, 1});

        // break;
        array_add(*expected_tokens, .{.BREAK, "break", 7, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 7, 1});

        // default:
        array_add(*expected_tokens, .{.DEFAULT, "default", 8, 1});
        array_add(*expected_tokens, .{.COLON, ":", 8, 1});

        // result = other;
        array_add(*expected_tokens, .{.IDENT, "result", 9, 1});
        array_add(*expected_tokens, .{.ASSIGN, "=", 9, 1});
        array_add(*expected_tokens, .{.IDENT, "other", 9, 1});
        array_add(*expected_tokens, .{.SEMICOLON, ";", 9, 1});

        // }
        array_add(*expected_tokens, .{.RCURLY, "}", 10, 1});
        verify_tokens(#procedure_name(), src, expected_tokens);
    }

    if !run_tests() return;

    test__return_stmt();
    test__variable();
    test__relational_operators();
    test__compound_assignment_operators();
    test__unary_operators();
    test__ternary_operator();
    test__bitwise_operators();
    test__logical_operators();
    test__keywords();
    test__conditional_statements();
    test__switch_statement();
}
