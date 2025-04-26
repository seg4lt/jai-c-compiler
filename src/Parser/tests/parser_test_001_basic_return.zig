const std = @import("std");
const parser_test_util = @import("parser_test_util.zig");
const doTest = parser_test_util.doTest;

test "multi_digit" {
    const src =
        \\int main(void) {
        \\  // test case w/ multi-digit constant
        \\  return 100;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-100
    ;
    try doTest(src, expected);
}

test "new lines" {
    const src =
        \\int
        \\main
        \\(
        \\void
        \\)
        \\{
        \\return
        \\0
        \\;
        \\}
    ;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-0
    ;
    try doTest(src, expected);
}

test "all in one line" {
    const src = "int main(void){return 2;}";
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-2
    ;
    try doTest(src, expected);
}
test "what is up with spaces" {
    const src = "   int   main    (  void)  {   return  0 ; }";
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-0
    ;
    try doTest(src, expected);
}

test "function without end brace" {
    const src =
        \\ int main(void) {
        \\ return
    ;

    const result = doTest(src, "");
    try std.testing.expectError(error.ExpectedSomeToken, result);
}

test "extra junk" {
    const src =
        \\int main(void)
        \\{
        \\    return 2;
        \\}
        \\// A single identifier outside of a declaration isn't a valid top-level construct
        \\foo
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.AllTokenNotConsumed, result);
}
test "invalid function name" {
    const src =
        \\/* A function name must be an identifier, not a constant */
        \\int 3 (void) {
        \\    return 0;
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "wrong return keyword" {
    const src =
        \\int main(void) {
        \\  RETURN 0;
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "missing type" {
    const src =
        \\ main(void) {
        \\     return 0;
        \\ }
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "missing semi-colon" {
    const src =
        \\int main (void) {
        \\    return 0
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "invalid return stmt" {
    const src =
        \\int main(void) {
        \\    return int;
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "incorrect syntax - bracket edition - swap" {
    const src =
        \\int main )( {
        \\    return 0;
        \\}
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}

test "incorrect syntax - fn paran close bracket missing" {
    const src =
        \\ int main( {
        \\     return 0;
        \\ }
    ;
    const result = doTest(src, "");
    try std.testing.expectError(error.ReceivedUnexpectedToken, result);
}
