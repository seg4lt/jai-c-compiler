const std = @import("std");
const testing = std.testing;
const Lexer = @import("Lexer.zig");

test "operators" {
    const allocator = testing.allocator;
    const src =
        \\ + - * / %
        \\ = += -= *= /= %=
        \\ ++ --
        \\ == != < > <= >=
        \\ && ||
        \\ ! ~
        \\ >> << >>= <<=
        \\ & | ^ &= |= ^=
        \\ ( ) { }
        \\ ;
    ;
    const lexer = Lexer.lex(allocator, src);
}
