Lexer :: struct {
    line: int = 1;
    src: string;
    start: int = 0; // current token start position
    current: int = 0; // where is cursor right now
    tokens: [..]Token;
}

lex :: (args: Cli_Args) -> Lexer {
    src, r_success := read_entire_file(tprint("%.i", args.source_file_path_without_ext));
    if !r_success {
        assert(false, "Unable to read file -- '%'", args.source_file_path);
        exit(1);
    }
    lexer := Lexer.{src = src};
    scan(*lexer);
    print_tokens(lexer.tokens);
    return lexer;
}

Token_Type :: enum {
    LPAREN;
    RPAREN;
    LCURLY;
    RCURLY;
    SEMICOLON;

    IDENT;
    INT_LITERAL;
    // Keyword
    INT;
    VOID;
    RETURN;
    // Operator
    BITWISE_NOT;
    BITWISE_AND;
    BITWISE_OR;
    BITWISE_XOR;
    LEFT_SHIFT;
    RIGHT_SHIFT;
    MINUS;
    PLUS;
    DIVIDE;
    MULTIPLY;
    MOD;
    NOT;
    AND;
    OR;
    EQUAL_EQUAL;
    NOT_EQUAL;
    LESS;
    LESS_EQUAL;
    GREATER;
    GREATER_EQUAL;
    ASSIGN;

    PLUS_EQUAL;
    MINUS_EQUAL;
    MULTIPLY_EQUAL;
    DIVIDE_EQUAL;
    MOD_EQUAL;
    LEFT_SHIFT_EQUAL;
    RIGHT_SHIFT_EQUAL;
    BITWISE_AND_EQUAL;
    BITWISE_OR_EQUAL;
    BITWISE_XOR_EQUAL;

    MINUS_MINUS;
    PLUS_PLUS;

    IF;
    ELSE;
    QUESTION_MARK;
    COLON;

    GOTO;

    FOR;
    DO;
    WHILE;
    CONTINUE;
    BREAK;

    SWITCH;
    CASE;
    DEFAULT;
}

Token :: struct {
    type: Token_Type;
    value: string;
    line: int;
}

#scope_file

print_tokens :: (tokens: []Token) {
    print("\n -- Lexer -- \n");
    for tokens print("%\n", it); 
    print("\n");
}

add_token(using lexer: *Lexer, type: Token_Type) {
    array_add(*tokens, .{ type, slice(src, start, current-start, line }));
}

scan :: (using lexer: *Lexer) {
    while !is_at_end(lexer) {
        start = current;
        current_char := consume(lexer);

        if is_space(current_char) continue;
        if is_alpha(current_char) || current_char == #char "_" { ident_or_keyword(lexer); continue; }
        if is_digit(current_char) { number(lexer); continue; }

        if current_char == {
            case #char "("; array_add(*tokens, .{.LPAREN,      "(", line});
            case #char ")"; array_add(*tokens, .{.RPAREN,      ")", line});
            case #char "{"; array_add(*tokens, .{.LCURLY,      "{", line});
            case #char "}"; array_add(*tokens, .{.RCURLY,      "}", line});
            case #char ";"; array_add(*tokens, .{.SEMICOLON,   ";", line});
            case #char "~"; array_add(*tokens, .{.BITWISE_NOT, "~", line});
            case #char "+"; 
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    array_add(*tokens, .{.PLUS_EQUAL, "+=", line});
                    continue;
                }
                if peek(lexer) == #char "+" {
                    consume(lexer);
                    array_add(*tokens, .{.PLUS_PLUS, "++", line});
                    continue;
                }
                array_add(*tokens, .{.PLUS,        "+", line});
            case #char "*"; 
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    array_add(*tokens, .{.MULTIPLY_EQUAL, "*=", line});
                    continue;
                }
                array_add(*tokens, .{.MULTIPLY, "*", line});
            case #char "%"; 
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    array_add(*tokens, .{.MOD_EQUAL, "%=", line});
                    continue;
                }
                array_add(*tokens, .{.MOD,"%", line});
            case #char "&"; 
                if peek(lexer) == #char "&" {
                    consume(lexer);
                    array_add(*tokens, .{.AND, "&&", line});
                    continue;
                }
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    array_add(*tokens, .{.BITWISE_AND_EQUAL, "&=", line});
                    continue;
                }
                array_add(*tokens, .{.BITWISE_AND, "&", line});
            case #char "|"; 
                if peek(lexer) == #char "|" {
                    consume(lexer);
                    array_add(*tokens, .{.OR, "&&", line});
                    continue;
                }
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    array_add(*tokens, .{.BITWISE_OR_EQUAL, "|=", line});
                    continue;
                }
                array_add(*tokens, .{.BITWISE_OR, "|", line});
            case #char "^"; 
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    array_add(*tokens, .{.BITWISE_XOR_EQUAL, "^=", line});
                    continue;
                }
                array_add(*tokens, .{.BITWISE_XOR, "^", line});
            case #char ">";
                if peek(lexer) == #char ">" {
                    consume(lexer);

                    if peek(lexer) == #char "=" {
                        consume(lexer);
                        array_add(*tokens, .{.RIGHT_SHIFT_EQUAL, ">>=", line});
                        continue;
                    }

                    array_add(*tokens, .{.RIGHT_SHIFT, ">>", line});
                    continue;
                }
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    array_add(*tokens, .{.GREATER_EQUAL, ">=", line});
                    continue;
                }
                array_add(*tokens, .{.GREATER, ">", line});
            case #char "<";
                if peek(lexer) == #char "<" {
                    consume(lexer);
                    if peek(lexer) == #char "=" {
                        consume(lexer);
                        array_add(*tokens, .{.LEFT_SHIFT_EQUAL, "<<=", line});
                        continue;
                    }
                    array_add(*tokens, .{.LEFT_SHIFT, "<<", line});
                    continue;
                }
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    array_add(*tokens, .{.LESS_EQUAL, "<=", line});
                    continue;
                }
                array_add(*tokens, .{.LESS, "<", line});
            case #char "/"; 
                if peek(lexer) == #char "/" || peek(lexer) == #char "*" {
                    comment(lexer);
                    continue;
                }
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    array_add(*tokens, .{.DIVIDE_EQUAL, "/=", line});
                    continue;
                }
                array_add(*tokens, .{.DIVIDE, "+", line});
            case #char "-"; 
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    array_add(*tokens, .{.MINUS_EQUAL, "-=", line});
                    continue;
                }
                if peek(lexer) == #char "-" {
                    consume(lexer);
                    array_add(*tokens, .{.MINUS_MINUS, "--", line});
                    continue;
                }
                array_add(*tokens, .{.MINUS, "-", line});
            case #char "=";
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    array_add(*tokens, .{.EQUAL_EQUAL, "==", line});
                    continue;
                }
                array_add(*tokens, .{.ASSIGN, "=", line});
            case #char "!";
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    array_add(*tokens, .{.NOT_EQUAL, "!=", line});
                    continue;
                }
                array_add(*tokens, .{.NOT, "!", line});
            case #char "?"; array_add(*tokens, .{.QUESTION_MARK, "?", line});
            case #char ":"; array_add(*tokens, .{.COLON, ":", line});
            case; 
                log_error(tprint("Unexpected character %\n", to_string(*current_char, 1)));
                exit(1);
        }
    }
}

comment :: (using lexer: *Lexer) {
    if peek(lexer) == {
        case #char "/";
            while !is_at_end(lexer) && peek(lexer) != #char "\n" {
                consume(lexer);
            }
            line += 1;
        case #char "*";
            consume(lexer);
            while !is_at_end(lexer) {
                c := consume(lexer);
                if c == #char "\n" line += 1;
                if c == #char "*" && peek(lexer) == #char "/" break;
            }
            consume(lexer); // consume closing /, if not found, this is an error
        case; 
          log_error("unable to parse comment\n");
          exit(1);
    }
}


number :: (using lexer: *Lexer) {
    found_alpha := false;
    while !is_at_end(lexer) && (is_digit(peek(lexer)) || is_alpha(peek(lexer))) {
        if is_alpha(peek(lexer)) found_alpha = true;
        consume(lexer);
    }
    str := slice(src, start, current-start);
    if found_alpha  {
        log_error(tprint("Invalid number found %", str));
        exit(1);
    }

    token := Token.{ .INT_LITERAL, str, line};
    array_add(*tokens, token); 
}

ident_or_keyword :: (using lexer: *Lexer) {
    while !is_at_end(lexer) && is_alnum(peek(lexer)) consume(lexer);
    str := slice(src, start, current-start);
    token_type := find_keyword_or_ident(str);
    token := Token.{ token_type, str, line};
    array_add(*tokens, token);
}

eat_whitespace :: (lexer: *Lexer) {
    while is_space(peek(lexer)) {
        token := consume(lexer);
        if token == #char "\n" lexer.line += 1;
    }
}

find_keyword_or_ident :: (str: string) -> Token_Type {
    if str == {
        case "int"; return .INT;
        case "void"; return .VOID;
        case "return"; return .RETURN;
        case "if"; return .IF;
        case "else"; return .ELSE;
        case "goto"; return .GOTO;
        case "for"; return .FOR;
        case "do"; return .DO;
        case "while"; return .WHILE;
        case "break"; return .BREAK;
        case "continue"; return .CONTINUE;
        case "switch"; return .SWITCH;
        case "case"; return .CASE;
        case "default"; return .DEFAULT;
        case; return .IDENT;
    }
}

consume :: (using lexer: *Lexer) -> u8 {
    defer current += 1;
    c := peek(lexer);
    if c == #char "\n" line += 1;
    return c;
}

peek :: (using lexer: *Lexer, offset: int = 0) -> u8 {
    return src.data[current + offset];
}

is_at_end :: (using lexer: *Lexer) -> bool {
    return current >= src.count;
}

#scope_file

#import "Basic";
#import "String";

#scope_export
