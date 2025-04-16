const std = @import("std");
const Lexer = @import("../../Lexer.zig");
const Parser = @import("../Parser.zig");
const AstPrinter = Parser.AstPrinter;

pub fn doTest(src: []const u8, expected: []const u8) !void {
    const testing = std.testing;
    const allocator = testing.allocator;

    var arena_ = std.heap.ArenaAllocator.init(allocator);
    const arena = arena_.allocator();
    defer _ = arena_.reset(.free_all);

    const lexer = try Lexer.initFromSrc(arena, src);
    const program = try Parser.parse(arena, lexer.tokens);

    var buffer = std.ArrayList(u8).init(arena);
    var writer = buffer.writer().any();

    AstPrinter.printProgram(&writer, program, 0);

    const result = buffer.toOwnedSlice() catch unreachable;
    try testing.expectEqualSlices(u8, expected, result);
}
