const std = @import("std");
const parser_test_util = @import("parser_test_util.zig");
const doTest = parser_test_util.doTest;

test "parser - basic add" {
    const src =
        \\int main(void) {
        \\    return 42 + 42;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[BINARY] add
        \\|-|-|-|-|-42
        \\|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "parser - chain binary" {
    const src =
        \\int main(void) {
        \\    return 42 + 42 + 42;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[BINARY] add
        \\|-|-|-|-|-[BINARY] add
        \\|-|-|-|-|-|-42
        \\|-|-|-|-|-|-42
        \\|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "parser - group and chain binary" {
    const src =
        \\int main(void) {
        \\    return (3 / 2 * 4) + (5 - 4 + 3);
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[BINARY] add
        \\|-|-|-|-|-[GROUP] 
        \\|-|-|-|-|-|-[BINARY] mul
        \\|-|-|-|-|-|-|-[BINARY] div
        \\|-|-|-|-|-|-|-|-3
        \\|-|-|-|-|-|-|-|-2
        \\|-|-|-|-|-|-|-4
        \\|-|-|-|-|-[GROUP] 
        \\|-|-|-|-|-|-[BINARY] add
        \\|-|-|-|-|-|-|-[BINARY] sub
        \\|-|-|-|-|-|-|-|-5
        \\|-|-|-|-|-|-|-|-4
        \\|-|-|-|-|-|-|-3
    ;
    try doTest(src, expected);
}

test "parser - binary operator precedence" {
    const src =
        \\int main(void) {
        \\    return 100 + 20 * 45 / (10 - 5) % 10;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[BINARY] add
        \\|-|-|-|-|-100
        \\|-|-|-|-|-[BINARY] mod
        \\|-|-|-|-|-|-[BINARY] div
        \\|-|-|-|-|-|-|-[BINARY] mul
        \\|-|-|-|-|-|-|-|-20
        \\|-|-|-|-|-|-|-|-45
        \\|-|-|-|-|-|-|-[GROUP] 
        \\|-|-|-|-|-|-|-|-[BINARY] sub
        \\|-|-|-|-|-|-|-|-|-10
        \\|-|-|-|-|-|-|-|-|-5
        \\|-|-|-|-|-|-10
    ;
    try doTest(src, expected);
}

test "parser - divide neg number" {
    const src =
        \\int main(void) {
        \\    return -42 / 42;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[BINARY] div
        \\|-|-|-|-|-[UNARY] negate
        \\|-|-|-|-|-|-42
        \\|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "parser - binary div" {
    const src =
        \\int main(void) {
        \\    return 42 / 42;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[BINARY] div
        \\|-|-|-|-|-42
        \\|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "parser - binary mod" {
    const src =
        \\int main(void) {
        \\    return 42 % 42;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[BINARY] mod
        \\|-|-|-|-|-42
        \\|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "parser - binary mul" {
    const src =
        \\int main(void) {
        \\    return 42 * 42;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[BINARY] mul
        \\|-|-|-|-|-42
        \\|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "parser - subtract neg number" {
    const src =
        \\int main(void) {
        \\    return 42- - 42;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[BINARY] sub
        \\|-|-|-|-|-42
        \\|-|-|-|-|-[UNARY] negate
        \\|-|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "parser - unary and binary combined" {
    const src =
        \\int main(void) {
        \\    return ~42 + -42;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[BINARY] add
        \\|-|-|-|-|-[UNARY] bitwise_not
        \\|-|-|-|-|-|-42
        \\|-|-|-|-|-[UNARY] negate
        \\|-|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "parser - binary group with unary" {
    const src =
        \\int main(void) {
        \\    return ~(42 + -42);
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[UNARY] bitwise_not
        \\|-|-|-|-|-[GROUP] 
        \\|-|-|-|-|-|-[BINARY] add
        \\|-|-|-|-|-|-|-42
        \\|-|-|-|-|-|-|-[UNARY] negate
        \\|-|-|-|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "parser error: double operator" {
    const src =
        \\int main(void) {
        \\    return 42 / * 42;
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "parser error: binary operator with missing closing paren" {
    const src =
        \\int main(void) {
        \\    return (42 + 42;
        \\}
    ;

    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "parser error: binary operator but paren is in wrong place" {
    const src =
        \\int main(void) {
        \\    return 42 (-42);
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "parser error: semicolon in wrong place" {
    const src =
        \\int main(void) {
        \\    return (42 + 42;)
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "parser error: divide used as unary" {
    const src =
        \\int main(void) {
        \\    return /42;
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "parser error: plus without second operand" {
    const src =
        \\int main(void) {
        \\    return 42 +;
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}
