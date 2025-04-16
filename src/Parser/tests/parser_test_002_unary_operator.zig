const std = @import("std");
const parser_test_util = @import("parser_test_util.zig");
const doTest = parser_test_util.doTest;

test "bitwise any number" {
    const src =
        \\int main(void) {
        \\    return ~42;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[UNARY] bitwise_not
        \\|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "bitwise with negative number" {
    const src =
        \\int main(void) {
        \\    return ~-2147483647;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[UNARY] bitwise_not
        \\|-|-|-|-|-[UNARY] negate
        \\|-|-|-|-|-|-2147483647
    ;
    try doTest(src, expected);
}

test "bitwise zero" {
    const src =
        \\int main(void) {
        \\    return ~0;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[UNARY] bitwise_not
        \\|-|-|-|-|-0
    ;
    try doTest(src, expected);
}

test "negative number 0" {
    const src =
        \\int main(void) {
        \\    return -0;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[UNARY] negate
        \\|-|-|-|-|-0
    ;
    try doTest(src, expected);
}

test "negative number" {
    const src =
        \\int main(void) {
        \\    return -42;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[UNARY] negate
        \\|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "negative combined with not" {
    const src =
        \\int main(void) {
        \\    return -~42;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[UNARY] negate
        \\|-|-|-|-|-[UNARY] bitwise_not
        \\|-|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "not combined with negative" {
    const src =
        \\int main(void) {
        \\    return ~-42;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[UNARY] bitwise_not
        \\|-|-|-|-|-[UNARY] negate
        \\|-|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "simple group ()" {
    const src =
        \\int main(void) {
        \\    return (42);
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[GROUP] 
        \\|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "negative number group with negate" {
    const src =
        \\int main(void) {
        \\    return -(-42);
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[UNARY] negate
        \\|-|-|-|-|-[GROUP] 
        \\|-|-|-|-|-|-[UNARY] negate
        \\|-|-|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "redundant parens" {
    const src =
        \\int main(void) {
        \\    return -(((42)));
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-[UNARY] negate
        \\|-|-|-|-|-[GROUP] 
        \\|-|-|-|-|-|-[GROUP] 
        \\|-|-|-|-|-|-|-[GROUP] 
        \\|-|-|-|-|-|-|-|-42
    ;
    try doTest(src, expected);
}

test "error: unbalanced parens" {
    const src =
        \\int main(void)
        \\{
        \\    return (3));
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "error: return without expression" {
    const src =
        \\int main(void)
        \\{
        \\    return;
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "error: return with only operator" {
    const src =
        \\int main(void)
        \\{
        \\    return -;
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "error: missing semi-colon " {
    const src =
        \\int main(void)
        \\{
        \\    return 42
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "error: paren on just operator" {
    const src =
        \\int main(void)
        \\{
        \\    return (-)42;
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "error: unclosed paren" {
    const src =
        \\int main(void)
        \\{
        \\    return (42;
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "error: unary operator on wrong place" {
    const src =
        \\int main(void)
        \\{
        \\    return 42 -;
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}
