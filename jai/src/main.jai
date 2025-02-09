main :: () {
    src :: #string DONE
    int main () {
        return 2;
    }
    DONE
    lexer := Lexer.{src = src, allocator = temp};
    scan(*lexer);

    for lexer.tokens {
        print("%\n", it);
    }
}

#import "Basic";
String :: #import "String";
Process :: #import "Process";
#load "Lexer.jai";




