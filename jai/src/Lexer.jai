Lexer :: struct {
    line: int = 1;
    line_start: int = 0;
    previous_line_start: int = 0;
    previous_line_end: int = 0;
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
}

Token :: struct {
    type: Token_Type;
    value: string;
    line: int;
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

print_tokens :: (tokens: []Token) {
    print("\n -- Lexer -- \n");
    for tokens print("%\n", it); 
    print("\n");
}

scan :: (using lexer: *Lexer) {
    while !is_at_end(lexer) {
        start = current;
        current_char := consume(lexer);

        if String.is_space(current_char) continue;
        if String.is_alpha(current_char) { ident_or_keyword(lexer); continue; }
        if String.is_digit(current_char) { number(lexer); continue; }

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
                print_err_line(lexer, tprint("Unexpected character %\n", String.to_string(*current_char, 1)));
        }
    }
}

print_err_line :: (using lexer: *Lexer, msg: string = "") {
    new_line_index := current;
    while (src.data + new_line_index).* != #char "\n" && new_line_index < src.count {
        new_line_index += 1;
    }
    print("%\n", String.slice(src, previous_line_start, previous_line_end - previous_line_start));
    print("%\n", String.slice(src, line_start, new_line_index-line_start));
    for 0..current-line_start-2 print(" ");
    print("^---");
    assert(false, "%", msg);
}

comment :: (using lexer: *Lexer) {
    if peek(lexer) == {
        case #char "/";
            while !is_at_end(lexer) && peek(lexer) != #char "\n" {
                consume(lexer);
            }
            increment_line(lexer);
        case #char "*";
            consume(lexer);
            while !is_at_end(lexer) {
                c := consume(lexer);
                if c == #char "\n"  { 
                    increment_line(lexer);
                }
                if c == #char "*" && peek(lexer) == #char "/" break;
            }
            consume(lexer); // consume closing /, if not found, this is an error
        case; print_err_line(lexer, "unable to parse comment");
    }
}

increment_line :: (using lexer: *Lexer) {
    previous_line_start = line_start;
    previous_line_end = current - 1;
    line += 1;
    line_start = current;
}

number :: (using lexer: *Lexer) {
    found_alpha := false;
    while !is_at_end(lexer) && (String.is_digit(peek(lexer)) || String.is_alpha(peek(lexer))) {
        if String.is_alpha(peek(lexer)) found_alpha = true;
        consume(lexer);
    }
    str := String.slice(src, start, current-start);
    if found_alpha print_err_line(lexer, tprint("Invalid identifier found %s", str));

    token := Token.{ .INT_LITERAL, str, line};
    array_add(*tokens, token); 
}

ident_or_keyword :: (using lexer: *Lexer) {
    while !is_at_end(lexer) && String.is_alnum(peek(lexer)) consume(lexer);
    str := String.slice(src, start, current-start);
    token := Token.{ find_keyword_or_ident(str), str, line};
    array_add(*tokens, token);
}

find_keyword_or_ident :: (str: string) -> Token_Type {
    if str == {
        case "int"; return .INT;
        case "void"; return .VOID;
        case "return"; return .RETURN;
        case "if"; return .IF;
        case "else"; return .ELSE;
        case; return .IDENT;
    }
}

consume :: (using lexer: *Lexer) -> u8 {
    defer current += 1;
    c := peek(lexer);
    if c == #char "\n" {
        increment_line(lexer);
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