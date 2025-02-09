const std = @import("std");

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    while (args.next()) |it| {
        std.debug.print("{s}\n", .{it});
    }
}

const CliArgs = struct {};

const Lexer = struct {};
