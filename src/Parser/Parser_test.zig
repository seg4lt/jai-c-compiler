const std = @import("std");
const Lexer = @import("../Lexer.zig");
const Parser = @import("Parser.zig");
const AstPrinter = Parser.AstPrinter;

test "multi_digit" {
    const testing = std.testing;
    const allocator = testing.allocator;
    var arena_ = std.heap.ArenaAllocator.init(allocator);
    const arena = arena_.allocator();
    defer _ = arena_.reset(.free_all);

    const src =
        \\int main(void) {
        \\  // test case w/ multi-digit constant
        \\  return 100;
        \\}
    ;
    const lexer = try Lexer.initFromSrc(arena, src);
    const program = try Parser.parse(arena, lexer.tokens);

    var buffer = std.ArrayList(u8).init(arena);
    var writer = buffer.writer().any();

    AstPrinter.printProgram(&writer, program, 0);

    const result = buffer.toOwnedSlice() catch unreachable;
    const expected =
        \\ -- AST -- 
        \\[PROGRAM] 
        \\|-[FN] main
        \\|-|-[BLOCK] 
        \\|-|-|-[RETURN] 
        \\|-|-|-|-100
    ;
    try testing.expectEqualSlices(u8, expected, result);
}
