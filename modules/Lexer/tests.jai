#scope_file

#import "Compiler";

#run _run_tests();

_run_tests :: () {
    log("Running test for file: %", #file);
    run_tests:: () -> bool {
        options := get_build_options();
        args := options.compile_time_command_line;
        for args if it == "tests" return true;
        return false;
    }

    get_lexer :: (src: string) -> Lexer {
        lexer := Lexer.{src = src};
        scan(*lexer);
        return lexer;
    }

    verify_tokens :: (test_name: string, src: string, expected_tokens: [..]Token) {
        lexer := get_lexer(src);
        assert(expected_tokens.count == lexer.tokens.count, "Lexer token count doesn't match");

        for 0..lexer.tokens.count-1 {
            a_token := lexer.tokens.data[it];
            e_token := expected_tokens[it];
            assert(a_token.type ==e_token.type, "idx: % - Lexer token type doesn't match. Expected % found %", it, e_token.type, a_token.type);
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
            .{.INT, "int", 1}, 
            .{.IDENT, "main", 1}, 
            .{.LPAREN, "(", 1}, 
            .{.VOID, "void", 1}, 
            .{.RPAREN, ")", 1}, 
            .{.LCURLY, "{", 1},
            // return 0;
            .{.RETURN, "return", 2}, 
            .{.INT_LITERAL, "0", 2}, 
            .{.SEMICOLON, ";", 2},
            // }
            .{.RCURLY, "}", 3}
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
            .{.IDENT, "var", 1}, 
            .{.IDENT, "x", 1}, 
            .{.ASSIGN, "=", 1}, 
            .{.INT_LITERAL, "10", 1}, 
            .{.SEMICOLON, ";", 1}, 
            // x = 20;
            .{.IDENT, "x", 2}, 
            .{.ASSIGN, "=", 2}, 
            .{.INT_LITERAL, "20", 2}, 
            .{.SEMICOLON, ";", 2}
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
            .{.IDENT, "a", 1},
            .{.LESS, "<", 1},
            .{.IDENT, "b", 1},
            .{.SEMICOLON, ";", 1},
            // a <= b;
            .{.IDENT, "a", 2},
            .{.LESS_EQUAL, "<=", 2},
            .{.IDENT, "b", 2},
            .{.SEMICOLON, ";", 2},
            // a > b;
            .{.IDENT, "a", 3},
            .{.GREATER, ">", 3},
            .{.IDENT, "b", 3},
            .{.SEMICOLON, ";", 3},
            // a >= b;
            .{.IDENT, "a", 4},
            .{.GREATER_EQUAL, ">=", 4},
            .{.IDENT, "b", 4},
            .{.SEMICOLON, ";", 4},
            // a == b;
            .{.IDENT, "a", 5},
            .{.EQUAL_EQUAL, "==", 5},
            .{.IDENT, "b", 5},
            .{.SEMICOLON, ";", 5},
            // a != b;
            .{.IDENT, "a", 6},
            .{.NOT_EQUAL, "!=", 6},
            .{.IDENT, "b", 6},
            .{.SEMICOLON, ";", 6}
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
        array_add(*expected_tokens, 
            // a += b;
            .{.IDENT, "a", 1},
            .{.PLUS_EQUAL, "+=", 1},
            .{.IDENT, "b", 1},
            .{.SEMICOLON, ";", 1},
            // a -= b;
            .{.IDENT, "a", 2},
            .{.MINUS_EQUAL, "-=", 2},
            .{.IDENT, "b", 2},
            .{.SEMICOLON, ";", 2},
            // a *= b;
            .{.IDENT, "a", 3},
            .{.MULTIPLY_EQUAL, "*=", 3},
            .{.IDENT, "b", 3},
            .{.SEMICOLON, ";", 3},
            // a /= b;
            .{.IDENT, "a", 4},
            .{.DIVIDE_EQUAL, "/=", 4},
            .{.IDENT, "b", 4},
            .{.SEMICOLON, ";", 4},
            // a %= b;
            .{.IDENT, "a", 5},
            .{.MOD_EQUAL, "%=", 5},
            .{.IDENT, "b", 5},
            .{.SEMICOLON, ";", 5},
            // a <<= b;
            .{.IDENT, "a", 6},
            .{.LEFT_SHIFT_EQUAL, "<<=", 6},
            .{.IDENT, "b", 6},
            .{.SEMICOLON, ";", 6},
            // a >>= b;
            .{.IDENT, "a", 7},
            .{.RIGHT_SHIFT_EQUAL, ">>=", 7},
            .{.IDENT, "b", 7},
            .{.SEMICOLON, ";", 7},
            // a &= b;
            .{.IDENT, "a", 8},
            .{.BITWISE_AND_EQUAL, "&=", 8},
            .{.IDENT, "b", 8},
            .{.SEMICOLON, ";", 8},
            // a |= b;
            .{.IDENT, "a", 9},
            .{.BITWISE_OR_EQUAL, "|=", 9},
            .{.IDENT, "b", 9},
            .{.SEMICOLON, ";", 9},
            // a ^= b;
            .{.IDENT, "a", 10},
            .{.BITWISE_XOR_EQUAL, "^=", 10},
            .{.IDENT, "b", 10},
            .{.SEMICOLON, ";", 10}
        );
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
            .{.NOT, "!", 1},
            .{.IDENT, "a", 1},
            .{.SEMICOLON, ";", 1},
            // ~b;
            .{.BITWISE_NOT, "~", 2},
            .{.IDENT, "b", 2},
            .{.SEMICOLON, ";", 2},
            // ++c;
            .{.PLUS_PLUS, "++", 3},
            .{.IDENT, "c", 3},
            .{.SEMICOLON, ";", 3},
            // --d;
            .{.MINUS_MINUS, "--", 4},
            .{.IDENT, "d", 4},
            .{.SEMICOLON, ";", 4},
            // c++;
            .{.IDENT, "c", 5},
            .{.PLUS_PLUS, "++", 5},
            .{.SEMICOLON, ";", 5},
            // d--;
            .{.IDENT, "d", 6},
            .{.MINUS_MINUS, "--", 6},
            .{.SEMICOLON, ";", 6}
        );
        verify_tokens(#procedure_name(), src, expected_tokens);
    }

    test__ternary_operator :: () {
        src := #string DONE
        x = a ? b : c;
        DONE
        expected_tokens: [..]Token;
        array_add(*expected_tokens, 
            // x = a ? b : c;
            .{.IDENT, "x", 1},
            .{.ASSIGN, "=", 1},
            .{.IDENT, "a", 1},
            .{.QUESTION_MARK, "?", 1},
            .{.IDENT, "b", 1},
            .{.COLON, ":", 1},
            .{.IDENT, "c", 1},
            .{.SEMICOLON, ";", 1}
        );
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
            .{.IDENT, "a", 1},
            .{.BITWISE_AND, "&", 1},
            .{.IDENT, "b", 1},
            .{.SEMICOLON, ";", 1},
            // c | d;
            .{.IDENT, "c", 2},
            .{.BITWISE_OR, "|", 2},
            .{.IDENT, "d", 2},
            .{.SEMICOLON, ";", 2},
            // e ^ f;
            .{.IDENT, "e", 3},
            .{.BITWISE_XOR, "^", 3},
            .{.IDENT, "f", 3},
            .{.SEMICOLON, ";", 3},
            // ~g;
            .{.BITWISE_NOT, "~", 4},
            .{.IDENT, "g", 4},
            .{.SEMICOLON, ";", 4},
            // h << i;
            .{.IDENT, "h", 5},
            .{.LEFT_SHIFT, "<<", 5},
            .{.IDENT, "i", 5},
            .{.SEMICOLON, ";", 5},
            // j >> k;
            .{.IDENT, "j", 6},
            .{.RIGHT_SHIFT, ">>", 6},
            .{.IDENT, "k", 6},
            .{.SEMICOLON, ";", 6}
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
            .{.IDENT, "a", 1},
            .{.AND, "&&", 1},
            .{.IDENT, "b", 1},
            .{.SEMICOLON, ";", 1},
            // c || d;
            .{.IDENT, "c", 2},
            .{.OR, "||", 2},
            .{.IDENT, "d", 2},
            .{.SEMICOLON, ";", 2},
            // !e;
            .{.NOT, "!", 3},
            .{.IDENT, "e", 3},
            .{.SEMICOLON, ";", 3}
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
        array_add(*expected_tokens, 
            // int x;
            .{.INT, "int", 1},
            .{.IDENT, "x", 1},
            .{.SEMICOLON, ";", 1},
            // void func(void);
            .{.VOID, "void", 2},
            .{.IDENT, "func", 2},
            .{.LPAREN, "(", 2},
            .{.VOID, "void", 2},
            .{.RPAREN, ")", 2},
            .{.SEMICOLON, ";", 2},
            // return value;
            .{.RETURN, "return", 3},
            .{.IDENT, "value", 3},
            .{.SEMICOLON, ";", 3},
            // if (condition) { body; }
            .{.IF, "if", 4},
            .{.LPAREN, "(", 4},
            .{.IDENT, "condition", 4},
            .{.RPAREN, ")", 4},
            .{.LCURLY, "{", 4},
            .{.IDENT, "body", 4},
            .{.SEMICOLON, ";", 4},
            .{.RCURLY, "}", 4},
            // else { alternative; }
            .{.ELSE, "else", 5},
            .{.LCURLY, "{", 5},
            .{.IDENT, "alternative", 5},
            .{.SEMICOLON, ";", 5},
            .{.RCURLY, "}", 5},
            // label:
            .{.IDENT, "label", 6},
            .{.COLON, ":", 6},
            // goto label;
            .{.GOTO, "goto", 7},
            .{.IDENT, "label", 7},
            .{.SEMICOLON, ";", 7},
            // for (int i = 0; i < 10; i++ ) { int x = i; }
            .{.FOR, "for", 8},
            .{.LPAREN, "(", 8},
            .{.INT, "int", 8},
            .{.IDENT, "i", 8},
            .{.ASSIGN, "=", 8},
            .{.INT_LITERAL, "0", 8},
            .{.SEMICOLON, ";", 8},
            .{.IDENT, "i", 8},
            .{.LESS, "<", 8},
            .{.INT_LITERAL, "10", 8},
            .{.SEMICOLON, ";", 8},
            .{.IDENT, "i", 8},
            .{.PLUS_PLUS, "++", 8},
            .{.RPAREN, ")", 8},
            .{.LCURLY, "{", 8},
            .{.INT, "int", 8},
            .{.IDENT, "x", 8},
            .{.ASSIGN, "=", 8},
            .{.IDENT, "i", 8},
            .{.SEMICOLON, ";", 8},
            .{.RCURLY, "}", 8},
            // do { int x = 1; } while ( i < 10 );
            .{.DO, "do", 9},
            .{.LCURLY, "{", 9},
            .{.INT, "int", 9},
            .{.IDENT, "x", 9},
            .{.ASSIGN, "=", 9},
            .{.INT_LITERAL, "1", 9},
            .{.SEMICOLON, ";", 9},
            .{.RCURLY, "}", 9},
            .{.WHILE, "while", 9},
            .{.LPAREN, "(", 9},
            .{.IDENT, "i", 9},
            .{.LESS, "<", 9},
            .{.INT_LITERAL, "10", 9},
            .{.RPAREN, ")", 9},
            .{.SEMICOLON, ";", 9},
            // while (i < 10) { ++i; }
            .{.WHILE, "while", 10},
            .{.LPAREN, "(", 10},
            .{.IDENT, "i", 10},
            .{.LESS, "<", 10},
            .{.INT_LITERAL, "10", 10},
            .{.RPAREN, ")", 10},
            .{.LCURLY, "{", 10},
            .{.PLUS_PLUS, "++", 10},
            .{.IDENT, "i", 10},
            .{.SEMICOLON, ";", 10},
            .{.RCURLY, "}", 10},
            // break;
            .{.BREAK, "break", 11},
            .{.SEMICOLON, ";", 11},
            // continue;
            .{.CONTINUE, "continue", 12},
            .{.SEMICOLON, ";", 12},
            // switch (value) {
            .{.SWITCH, "switch", 13},
            .{.LPAREN, "(", 13},
            .{.IDENT, "value", 13},
            .{.RPAREN, ")", 13},
            .{.LCURLY, "{", 13},
            // case 1: stmt1;
            .{.CASE, "case", 14},
            .{.INT_LITERAL, "1", 14},
            .{.COLON, ":", 14},
            .{.IDENT, "stmt1", 14},
            .{.SEMICOLON, ";", 14},
            // default: stmt_default;
            .{.DEFAULT, "default", 15},
            .{.COLON, ":", 15},
            .{.IDENT, "stmt_default", 15},
            .{.SEMICOLON, ";", 15},
            // }
            .{.RCURLY, "}", 16}
        );
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
        array_add(*expected_tokens, 
            // if (a > b) {
            .{.IF, "if", 1},
            .{.LPAREN, "(", 1},
            .{.IDENT, "a", 1},
            .{.GREATER, ">", 1},
            .{.IDENT, "b", 1},
            .{.RPAREN, ")", 1},
            .{.LCURLY, "{", 1},
            // c = 1;
            .{.IDENT, "c", 2},
            .{.ASSIGN, "=", 2},
            .{.INT_LITERAL, "1", 2},
            .{.SEMICOLON, ";", 2},
            // }
            .{.RCURLY, "}", 3},
            // else if (a < b) {
            .{.ELSE, "else", 3},
            .{.IF, "if", 3},
            .{.LPAREN, "(", 3},
            .{.IDENT, "a", 3},
            .{.LESS, "<", 3},
            .{.IDENT, "b", 3},
            .{.RPAREN, ")", 3},
            .{.LCURLY, "{", 3},
            // c = 2;
            .{.IDENT, "c", 4},
            .{.ASSIGN, "=", 4},
            .{.INT_LITERAL, "2", 4},
            .{.SEMICOLON, ";", 4},
            // }
            .{.RCURLY, "}", 5},
            // else {
            .{.ELSE, "else", 5},
            .{.LCURLY, "{", 5},
            // c = 3;
            .{.IDENT, "c", 6},
            .{.ASSIGN, "=", 6},
            .{.INT_LITERAL, "3", 6},
            .{.SEMICOLON, ";", 6},
            // }
            .{.RCURLY, "}", 7},
            
            // result = (x > y) ? x : y;
            .{.IDENT, "result", 9},
            .{.ASSIGN, "=", 9},
            .{.LPAREN, "(", 9},
            .{.IDENT, "x", 9},
            .{.GREATER, ">", 9},
            .{.IDENT, "y", 9},
            .{.RPAREN, ")", 9},
            .{.QUESTION_MARK, "?", 9},
            .{.IDENT, "x", 9},
            .{.COLON, ":", 9},
            .{.IDENT, "y", 9},
            .{.SEMICOLON, ";", 9}
        );
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
        array_add(*expected_tokens, 
            // switch (value) {
            .{.SWITCH, "switch", 1},
            .{.LPAREN, "(", 1},
            .{.IDENT, "value", 1},
            .{.RPAREN, ")", 1},
            .{.LCURLY, "{", 1},
            // case 1:
            .{.CASE, "case", 2},
            .{.INT_LITERAL, "1", 2},
            .{.COLON, ":", 2},
            // result = one;
            .{.IDENT, "result", 3},
            .{.ASSIGN, "=", 3},
            .{.IDENT, "one", 3},
            .{.SEMICOLON, ";", 3},
            // break;
            .{.BREAK, "break", 4},
            .{.SEMICOLON, ";", 4},
            // case 2:
            .{.CASE, "case", 5},
            .{.INT_LITERAL, "2", 5},
            .{.COLON, ":", 5},
            // result = two;
            .{.IDENT, "result", 6},
            .{.ASSIGN, "=", 6},
            .{.IDENT, "two", 6},
            .{.SEMICOLON, ";", 6},
            // break;
            .{.BREAK, "break", 7},
            .{.SEMICOLON, ";", 7},
            // default:
            .{.DEFAULT, "default", 8},
            .{.COLON, ":", 8},
            // result = other;
            .{.IDENT, "result", 9},
            .{.ASSIGN, "=", 9},
            .{.IDENT, "other", 9},
            .{.SEMICOLON, ";", 9},
            // }
            .{.RCURLY, "}", 10}
        );
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