const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexer = @import("Lexer.zig");
const Token = Lexer.Token;

const Data = struct { msg: []const u8, token: Token };

buffer: std.ArrayList(Data),
allocator: std.mem.Allocator,

const Self = @This();

pub fn init(allocator: Allocator) Self {
    return .{ .allocator = allocator, .buffer = std.ArrayList(Data).init(allocator) };
}

pub fn add(s: *Self, token: Token, comptime fmt: []const u8, args: anytype) void {
    const owned_msg = std.fmt.allocPrint(s.allocator, fmt, args) catch unreachable;
    s.buffer.append(.{ .msg = owned_msg, .token = token }) catch unreachable;
}

pub fn hasError(s: *Self) bool {
    return s.buffer.len > 0;
}

pub fn printErrors(s: *Self, writer: *std.io.AnyWriter) void {
    for (s.buffer.items) |*it| printErrorItem(writer, it);
}

pub fn printErrorsStdOut(s: *Self) void {
    var stdout = std.io.getStdOut().writer().any();
    printErrors(s, &stdout);
}

fn printErrorItem(writer: *std.io.AnyWriter, item: *const Data) void {
    const column = if (item.token.line <= 1) item.token.start else getColumnIndex(item.token.src, item.token.line, item.token.start);

    writer.print("Error: {s} at line {d}:{d}\n", .{ item.token.src, item.token.line }) catch unreachable;
    _ = writer.print(" -- {s}\n", .{item.msg}) catch unreachable;
}

fn getColumnIndex(src: []const u8, line: u16, start: usize) usize {
    var column: usize = 0;
    for (src[0..start]) |c| {
        if (c == '\n') {
            line -= 1;
            column = 0;
        } else if (line == 1) {
            column += 1;
        }
    }
    return column;
}
