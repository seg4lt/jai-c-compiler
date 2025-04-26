const std = @import("std");
const util = @import("../../util.zig");
const Lexer = @import("../../Lexer.zig");
const Parser = @import("../Parser.zig");
const AstPrinter = Parser.AstPrinter;

pub fn doTest(src: []const u8, expected: []const u8) !void {
    return doTest_(src, expected, false);
}

pub fn doTestPreprocess(src: []const u8, expected: []const u8) !void {
    return doTest_(src, expected, true);
}

fn doTest_(src: []const u8, expected: []const u8, preprocess: bool) !void {
    const testing = std.testing;
    const allocator = testing.allocator;

    var arena_ = std.heap.ArenaAllocator.init(allocator);
    const arena = arena_.allocator();
    defer _ = arena_.reset(.free_all);

    const lexer = if (preprocess) try Lexer.initFromSrcPath(arena, try preprocessFile(arena, src)) else try Lexer.initFromSrc(arena, src);
    const program = try Parser.parse(arena, lexer.tokens);

    var buffer = std.ArrayList(u8).init(arena);
    var writer = buffer.writer().any();

    AstPrinter.printProgram(&writer, program, 0);

    const result = buffer.toOwnedSlice() catch unreachable;
    try testing.expectEqualSlices(u8, expected, result);
}

pub fn preprocessFile(allocator: std.mem.Allocator, contents: []const u8) ![]const u8 {
    var tmp = std.testing.tmpDir(.{});
    const path = try std.fmt.allocPrint(allocator, "c_compiler_{d}.c", .{std.time.milliTimestamp()});
    defer allocator.free(path);

    {
        const file = try tmp.dir.createFile(path, .{});
        defer file.close();
        try file.writeAll(contents);
    }
    const full_path = tmp.dir.realpathAlloc(allocator, path) catch unreachable;

    util.preprocessor(allocator, full_path);

    return full_path;
}
