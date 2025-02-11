Lexer :: struct {
    line: int = 1;
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
    INT_VALUE;
    // Keyword
    INT;
    VOID;
    RETURN;
}

Token :: struct {
    type: Token_Type;
    value: string;
    line: int;
}

scan :: (using lexer: *Lexer) -> success: bool = true #must, err_msg: string = "" {
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
            success, err_msg := number(lexer);
            if !success return success = success, err_msg = err_msg;
            continue;
        }

        if current_char == {
            case #char "("; array_add(*tokens, .{.LPAREN, "(", line});continue; 
            case #char ")"; array_add(*tokens, .{.RPAREN, ")", line});continue;
            case #char "{"; array_add(*tokens, .{.LCURLY, "{", line});continue;
            case #char "}"; array_add(*tokens, .{.RCURLY, "}", line});continue;
            case #char ";"; array_add(*tokens, .{.SEMICOLON, ";", line});continue;
            case #char "/"; comment(lexer); continue;
        }
        return success = false, err_msg = tprint("Unexpected character %", String.to_string(*current_char, 1));
    }
    return success = true;
}

comment :: (using lexer: *Lexer) -> success: bool = true {
    if peek(lexer) == {
        case #char "/";
            while !is_at_end(lexer) && peek(lexer) != #char "\n" {
                consume(lexer);
            }
            line += 1;
        case #char "*";
            consume(lexer);
            while !is_at_end(lexer) && consume(lexer) != #char "*" && peek(lexer) != #char "/" {}
            consume(lexer); // consume closing /, if not found, this is an error
        case; return success = false;
    }
    return true;
}

number :: (using lexer: *Lexer) -> status: bool = true, err_msg: string = "" {
    found_alpha := false;
    while !is_at_end(lexer) && (String.is_digit(peek(lexer)) || String.is_alpha(peek(lexer))) {
        if String.is_alpha(peek(lexer)) {
            found_alpha = true;
        }
        consume(lexer);
    }
    str := String.slice(src, start, current-start);
    if found_alpha {
        return status = false, err_msg = tprint("Invalid identifier found: %", str);
    }
    token := Token.{ .INT_VALUE, str, line};
    array_add(*tokens, token); 
    return status = true;
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
    c := peek(lexer);
    if c == #char "\n" line += 1;
    current += 1;
    return c;
}

peek :: (using lexer: *Lexer) -> u8 {
    return src.data[current];
}

is_at_end :: (using lexer: *Lexer) -> bool {
    return current >= src.count;
}

#scope_file

#import "Basic";
String :: #import "String";

#run run_test();

run_test :: () {
    #import "Compiler";
    options := get_build_options();
    args := options.compile_time_command_line;
    for arg: args {
        if arg == {
          case "test";  
            test_simple_program();
            test_with_slash_comment();
            test_with_multiline_comment();
            test_invalid_identifier();
        }
    }
}

test_invalid_identifier :: () {
    src := #string done
    int main () {
        return 2a;
    }
    done
    lexer := Lexer.{src = src};
    success, msg := scan(*lexer);
    assert(!success, "Invalid identifier test should have failed");
    assert(msg == "Invalid identifier found: 2a");
}

test_with_multiline_comment :: () {
    src := #string done
    /* yello this is long comment
        new line
    */
    int main () {
        return 2;
    }
    done
    lexer := Lexer.{src = src};
    success := scan(*lexer);
    assert(success);
    assert(lexer.tokens.count == 9, "number of tokens must be 9, found %", lexer.tokens.count);
}


test_with_slash_comment :: () {
    src := #string done
    int main () {
        // this is a comment
        return 2;
    }
    done
    lexer := Lexer.{src = src};
    success := scan(*lexer);
    assert(success);
    assert(lexer.tokens.count == 9, "number of tokens must be 9, found %", lexer.tokens.count);
}

test_simple_program :: () {
    src := #string done
    int main () {
        return 2;
    }
    done

    lexer := Lexer.{src = src};
    success := scan(*lexer);
    assert(success);

    assert(lexer.tokens.count == 9, "number of tokens must be 9, found %", lexer.tokens.count);
    assert(lexer.tokens[0].type == .INT, "expected token to be int, found %", lexer.tokens[0].type);
    assert(lexer.tokens[1].type == .IDENT, "expected to be ident with value \"main\". found % with value %", lexer.tokens[1].type, lexer.tokens[1].value);
    assert(lexer.tokens[2].type == .LPAREN, "expected ( found %", lexer.tokens[2].value);
    assert(lexer.tokens[3].type == .RPAREN, "expected ) found %", lexer.tokens[3].value);
    assert(lexer.tokens[4].type == .LCURLY, "expected { found %", lexer.tokens[4].value);
    assert(lexer.tokens[5].type == .RETURN, "experted return found %", lexer.tokens[5].value);
    assert(lexer.tokens[6].type == .INT_VALUE, "expeted INT_VAL with 2. Found % with value %", lexer.tokens[6].type, lexer.tokens[0].value);
    assert(lexer.tokens[7].type == .SEMICOLON, "expected ; found %", lexer.tokens[7].value);
    assert(lexer.tokens[8].type == .RCURLY, "expected } found %", lexer.tokens[8].value);
}

#scope_export