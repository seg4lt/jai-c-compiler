Lexer :: struct {
    line: int = 1;
    line_start: int = 0;
    src: string;
    start: int = 0; // current token start position
    current: int = 0; // where is cursor right now
    tokens: [..]Token;
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
    // OPERATOR
    BITWISE_NOT;
    BITWISE_AND;
    BITWISE_OR;
    BITWISE_XOR;
    LEFT_SHIFT;
    RIGHT_SHIFT;
    UNARY_MINUS;
    MINUS;
    PLUS;
    DIVIDE;
    MULTIPLY;
    MOD;
}

Token :: struct {
    type: Token_Type;
    value: string;
    line: int;
}

lex :: (args: Cli_Args) -> Lexer {
    src, r_success := read_entire_file(tprint("%.i", args.source_file_path_without_ext));
    if !r_success {
        log_error("Unable to read file -- '%'", args.source_file_path);
        exit(1);
    }
    lexer := Lexer.{src = src};
    scan(*lexer);

    print("\n -- Lexer -- \n");
    for lexer.tokens {
        print("%\n", it);
    }
    print("\n");

    return lexer;
}

scan :: (using lexer: *Lexer) {
    c := 0;
    while !is_at_end(lexer) {
        c += 1;
        if c > 100000 {
            log_error("Force lexer scan exit");
            exit(1);
        } 
        start = current;
        current_char := consume(lexer);

        if String.is_space(current_char) {
            continue;
        }

        if String.is_alpha(current_char) {
            ident_or_keyword(lexer);
            continue;
        }
        if String.is_digit(current_char) {
            number(lexer);
            continue;
        }

        if current_char == {
            case #char "("; array_add(*tokens, .{.LPAREN, "(", line});
            case #char ")"; array_add(*tokens, .{.RPAREN, ")", line});
            case #char "{"; array_add(*tokens, .{.LCURLY, "{", line});
            case #char "}"; array_add(*tokens, .{.RCURLY, "}", line});
            case #char ";"; array_add(*tokens, .{.SEMICOLON, ";", line});
            case #char "~"; array_add(*tokens, .{.BITWISE_NOT, "~", line});
            case #char "+"; array_add(*tokens, .{.PLUS, "+", line});
            case #char "*"; array_add(*tokens, .{.MULTIPLY, "*", line});
            case #char "%"; array_add(*tokens, .{.MOD, "%", line});
            case #char "&"; 
                if peek(lexer) == #char "&" {
                    assert(false, "&& -- is not supported yet");
                    continue;
                }
                array_add(*tokens, .{.BITWISE_AND, "&", line});
            case #char "|"; 
                if peek(lexer) == #char "|" {
                    assert(false, "|| -- is not supported yet");
                    continue;
                }
                array_add(*tokens, .{.BITWISE_OR, "|", line});
            case #char "^"; 
                array_add(*tokens, .{.BITWISE_XOR, "^", line});
            case #char ">";
                if peek(lexer) == #char ">" {
                    consume(lexer);
                    array_add(*tokens, .{.RIGHT_SHIFT, ">>", line});
                    continue;
                }
                assert(false, "> not supported yet");
            case #char "<";
                if peek(lexer) == #char "<" {
                    consume(lexer);
                    array_add(*tokens, .{.LEFT_SHIFT, "<<", line});
                    continue;
                }
                assert(false, "< not supported yet");
            case #char "/"; 
                if peek(lexer) == #char "/" || peek(lexer) == #char "*" {
                    comment(lexer);
                    continue;
                }
                array_add(*tokens, .{.DIVIDE, "+", line});
            case #char "-"; 
                if peek(lexer) == #char "-" {
                    assert(false, "infix -- is not supported yet");
                    consume(lexer);
                    array_add(*tokens, .{.UNARY_MINUS, "--", line});
                    continue;
                }
                array_add(*tokens, .{.MINUS, "-", line});
            case; 
                print_line(lexer);
                assert(false, "Unexpected character %\n", String.to_string(*current_char, 1));
        }
    }
}

print_line :: (using lexer: *Lexer) {
    new_line_index := current;
    while (src.data + new_line_index).* != #char "\n" && new_line_index < src.count {
        new_line_index += 1;
    }
    print("%\n", String.slice(src, line_start, new_line_index-line_start));
    for 0..current-line_start-2 print(" ");
    print("^---");
}

comment :: (using lexer: *Lexer) {
    if peek(lexer) == {
        case #char "/";
            while !is_at_end(lexer) && peek(lexer) != #char "\n" {
                consume(lexer);
            }
            line += 1;
            line_start = current;
        case #char "*";
            consume(lexer);
            while !is_at_end(lexer) {
                c := consume(lexer);
                if c == #char "\n"  { line += 1; line_start = current; }
                if c == #char "*" && peek(lexer) == #char "/" break;
            }
            consume(lexer); // consume closing /, if not found, this is an error
        case; assert(false, "unable to parse comment");
    }
}

number :: (using lexer: *Lexer) {
    found_alpha := false;
    while !is_at_end(lexer) && (String.is_digit(peek(lexer)) || String.is_alpha(peek(lexer))) {
        if String.is_alpha(peek(lexer)) {
            found_alpha = true;
        }
        consume(lexer);
    }
    str := String.slice(src, start, current-start);
    if found_alpha {
        assert(false, "Invalid identifier found: %", str);
    }
    token := Token.{ .INT_LITERAL, str, line};
    array_add(*tokens, token); 
}

ident_or_keyword :: (using lexer: *Lexer) {
    while !is_at_end(lexer) && String.is_alnum(peek(lexer)) {
        consume(lexer);
    }
    str := String.slice(src, start, current-start);
    token := Token.{ find_token_type(str), str, line};
    array_add(*tokens, token);
}

find_token_type :: (str: string) -> Token_Type {
    if str == {
        case "int"; return .INT;
        case "void"; return .VOID;
        case "return"; return .RETURN;
        case; return .IDENT;
    }
}

consume :: (using lexer: *Lexer) -> u8 {
    defer current += 1;
    c := peek(lexer);
    if c == #char "\n" {
        line += 1;
        line_start = current;
    }
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
String :: #import "String";


#scope_export