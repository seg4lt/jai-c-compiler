Lexer :: struct {
    src:            string;
    tokens:         [..]Token;
    error_reporter: *Error_Reporter;
    line:           int = 1;
    start:          int = 0; 
    current:        int = 0; 
}

Token :: struct {
    type:  Token_Type;
    value: string;
    line:  int;
    start: int;
}

scan_tokens :: (src: string, error_reporter: *Error_Reporter, debug_log: bool = true) -> []Token {
    lexer := Lexer.{ src = src, error_reporter = error_reporter };
    scan(*lexer);
    if debug_log print_tokens(lexer.tokens);
    return array_view(lexer.tokens, 0);
}

print_tokens :: (tokens: []Token) {
    print("-- Lexer --\n");
    for token: tokens {
        print("% % %\n", 
            string_format(tprint("%", token.type), 15, .RIGHT),
            string_format(token.value, 15, .RIGHT),
            string_format(tprint("%:%", token.line, token.start), 7, .RIGHT)
        ); 
    }
}

#scope_module

scan :: (using lexer: *Lexer) {
    while !is_at_end(lexer) {
        start = current;
        current_char := consume(lexer);

        if is_space(current_char) {
            if current_char == "\n" line += 1;
            continue;
        }
        
        if is_alpha(current_char) || current_char == "_" { 
            ident_or_keyword(lexer); 
            continue; 
        }
        
        if is_digit(current_char) { 
            number(lexer); 
            continue; 
        }

        if current_char == {
            case "("; add_token(lexer, .LPAREN);
            case ")"; add_token(lexer, .RPAREN);
            case "{"; add_token(lexer, .LCURLY);
            case "}"; add_token(lexer, .RCURLY);
            case ";"; add_token(lexer, .SEMICOLON);
            case "~"; add_token(lexer, .BITWISE_NOT);
            case ","; add_token(lexer, .COMMA);
            case "?"; add_token(lexer, .QUESTION_MARK);
            case ":"; add_token(lexer, .COLON);
            case "+"; 
                if peek(lexer) == "=" {
                    consume(lexer);
                    add_token(lexer, .PLUS_EQUAL);
                    continue;
                }
                if peek(lexer) == "+" {
                    consume(lexer);
                    add_token(lexer, .PLUS_PLUS);
                    continue;
                }
                add_token(lexer, .PLUS);
            case "*"; 
                if peek(lexer) == "=" {
                    consume(lexer);
                    add_token(lexer, .MULTIPLY_EQUAL);
                    continue;
                }
                add_token(lexer, .MULTIPLY);
            case "%"; 
                if peek(lexer) == "=" {
                    consume(lexer);
                    add_token(lexer, .MOD_EQUAL);
                    continue;
                }
                add_token(lexer, .MOD);
            case "&"; 
                if peek(lexer) == "&" {
                    consume(lexer);
                    add_token(lexer, .AND);
                    continue;
                }
                if peek(lexer) == "=" {
                    consume(lexer);
                    add_token(lexer, .BITWISE_AND_EQUAL);
                    continue;
                }
                add_token(lexer, .BITWISE_AND);
            case "|"; 
                if peek(lexer) == "|" {
                    consume(lexer);
                    add_token(lexer, .OR);
                    continue;
                }
                if peek(lexer) == "=" {
                    consume(lexer);
                    add_token(lexer, .BITWISE_OR_EQUAL);
                    continue;
                }
                add_token(lexer, .BITWISE_OR);
            case "^"; 
                if peek(lexer) == "=" {
                    consume(lexer);
                    add_token(lexer, .BITWISE_XOR_EQUAL);
                    continue;
                }
                add_token(lexer, .BITWISE_XOR);
            case ">";
                if peek(lexer) == ">" {
                    consume(lexer);
                    if peek(lexer) == "=" {
                        consume(lexer);
                        add_token(lexer, .RIGHT_SHIFT_EQUAL);
                        continue;
                    }
                    add_token(lexer, .RIGHT_SHIFT);
                    continue;
                }
                if peek(lexer) == "=" {
                    consume(lexer);
                    add_token(lexer, .GREATER_EQUAL);
                    continue;
                }
                add_token(lexer, .GREATER);
            case "<";
                if peek(lexer) == "<" {
                    consume(lexer);
                    if peek(lexer) == "=" {
                        consume(lexer);
                        add_token(lexer, .LEFT_SHIFT_EQUAL);
                        continue;
                    }
                    add_token(lexer, .LEFT_SHIFT);
                    continue;
                }
                if peek(lexer) == "=" {
                    consume(lexer);
                    add_token(lexer, .LESS_EQUAL);
                    continue;
                }
                add_token(lexer, .LESS);
            case "/"; 
                if peek(lexer) == "/" || peek(lexer) == "*" {
                    comment(lexer);
                    continue;
                }
                if peek(lexer) == "=" {
                    consume(lexer);
                    add_token(lexer, .DIVIDE_EQUAL);
                    continue;
                }
                add_token(lexer, .DIVIDE);
            case "-"; 
                if peek(lexer) == "=" {
                    consume(lexer);
                    add_token(lexer, .MINUS_EQUAL);
                    continue;
                }
                if peek(lexer) == "-" {
                    consume(lexer);
                    add_token(lexer, .MINUS_MINUS);
                    continue;
                }
                add_token(lexer, .MINUS);
            case "=";
                if peek(lexer) == "=" {
                    consume(lexer);
                    add_token(lexer, .EQUAL_EQUAL);
                    continue;
                }
                add_token(lexer, .ASSIGN);
            case "!";
                if peek(lexer) == "=" {
                    consume(lexer);
                    add_token(lexer, .NOT_EQUAL);
                    continue;
                }
                add_token(lexer, .NOT);
            case; 
                lex_err(lexer, "Unexpected character %", to_string(*current_char, 1));
        }
    }
}

#scope_file

lex_err :: (using lexer: *Lexer, msg_fmt: string, args: .. Any) {
    error_report(error_reporter, line, start, msg_fmt, .. args);
}


comment :: (using lexer: *Lexer) {
    if peek(lexer) == {
        case "/";
            while !is_at_end(lexer) && peek(lexer) != "\n" {
                consume(lexer);
            }
            line += 1;
        case "*";
            consume(lexer);
            while !is_at_end(lexer) {
                c := consume(lexer);
                if c == "\n" line += 1;
                if c == "*" && peek(lexer) == "/" break;
            }
            consume(lexer); // consume closing /, if not found, this is an error
        case; lex_err(lexer, "unable to parse comment\n");
    }
}

number :: (using lexer: *Lexer) {
    found_alpha := false;
    while !is_at_end(lexer) && (is_digit(peek(lexer)) || is_alpha(peek(lexer))) {
        if is_alpha(peek(lexer)) found_alpha = true;
        consume(lexer);
    }
    str := str_slice(src, start, current);
    if found_alpha lex_err(lexer, "Invalid number found %", str);

    token := Token.{ .INT_LITERAL, str, line, start};
    array_add(*tokens, token); 
}

ident_or_keyword :: (using lexer: *Lexer) {
    while !is_at_end(lexer) && is_alnum(peek(lexer)) consume(lexer);
    str := str_slice(src, start, current);
    token_type := ident(str);
    token := Token.{ token_type, str, line, start };
    array_add(*tokens, token);
}

eat_whitespace :: (lexer: *Lexer) {
    while is_space(peek(lexer)) {
        token := consume(lexer);
        if token == "\n" lexer.line += 1;
    }
}

ident :: (str: string) -> Token_Type {
    if str == {
        case "int";      return .INT;
        case "void";     return .VOID;
        case "return";   return .RETURN;
        case "if";       return .IF;
        case "else";     return .ELSE;
        case "goto";     return .GOTO;
        case "for";      return .FOR;
        case "do";       return .DO;
        case "while";    return .WHILE;
        case "break";    return .BREAK;
        case "continue"; return .CONTINUE;
        case "switch";   return .SWITCH;
        case "case";     return .CASE;
        case "default";  return .DEFAULT;
        case;            return .IDENT;
    }
}

add_token :: (using lexer: *Lexer, type: Token_Type) #expand {
    array_add(*tokens, .{ type = type, value = str_slice(src, start, current), line = line, start = start });
}

consume :: (using lexer: *Lexer) -> u8 {
    defer current += 1;
    c := peek(lexer);
    if c == "\n" line += 1;
    return c;
}

peek :: (using lexer: *Lexer, offset: int = 0) -> u8 {
    if is_at_end(lexer) return 0;
    return src.data[current + offset];
}

is_at_end :: (using lexer: *Lexer) -> bool {
    return current >= src.count;
}

#import "Basic";
#import "String";
#import "Compiler_Util";
#import "File";
#import "Error_Reporter";
#import "Not_Basic";
