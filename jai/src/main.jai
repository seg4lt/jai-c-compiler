main :: () {
    source :: #string DONE
    int main () {
        return 2;
    }
    DONE
    lexer := Lexer.{source = source, allocator = context.allocator};
    lexer_get_tokens(*lexer);
}


lexer_get_tokens :: (lexer: *Lexer) {
    counter := 0;
    while true {
        // Temp Code
        counter += 1;
        if (counter >= 100000) {
            log_error("Hard stopping loop...");
            exit(0);
            break;
        }
        // End: Temp code

        if String.is_alpha(lexer_current_char(lexer)) {
            lexer_identifier(lexer);
        }
    }
}

lexer_identifier :: (lexer: *Lexer) {
    while lexer_end_of_file(lexer) && (String.is_alnum(lexer_current_char())) {
        lexer_consume(lexer);
    }
}

lexer_consume :: (using lexer: *Lexer) {
    current += 1;
}

lexer_current_char :: (lexer: *Lexer) -> u8 {
    return lexer.tokens.data[cursor];
}


lexer_end_of_file :: (lexer:  *Lexer) -> bool {
    return cursor >= source.count;
}

Lexer :: struct {
    line: int = 1;
    column: int = 1;
    source: string;
    start: int = 0; // current token start position
    current: int = 0; // where is cursor right now
    tokens: [..]Token;
    allocator: Allocator;
}

Token_Type :: enum {
    LPAREN;
    RPAREN;
    LCURLY;
    RCURLY;
    SEMICOLON;

    IDENT;
    INT_VAL;
    // Keyword
    INT;
    VOID;
    RETURN;
}

Token :: struct {
    type : Token_Type;
    content : string;
    line : int;
    column : int;
}


#import "Basic";
String :: #import "String";
Process :: #import "Process";
