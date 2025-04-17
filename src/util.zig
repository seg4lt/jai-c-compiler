const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

pub fn preprocessor(allocator: Allocator, src_path: []const u8) void {
    const file = src_path[0 .. src_path.len - 2];
    const i_file = std.fmt.allocPrint(allocator, "{s}.i", .{file}) catch unreachable;
    log.info("Preprocessing file: {s}\n", .{i_file});

    defer allocator.free(i_file);
    var child = std.process.Child.init(&[_][]const u8{ "gcc", "-E", "-P", src_path, "-o", i_file }, allocator);
    const result = child.spawnAndWait() catch unreachable;
    std.debug.assert(result == .Exited);
}

pub const log = struct {
    pub fn info(comptime format: []const u8, args: anytype) void {
        std.log.info(format, args);
    }

    pub fn debug(comptime format: []const u8, args: anytype) void {
        std.log.debug(format, args);
    }

    // Test will fail when there is error log, even if I try to test error scenario. Ahh!!!
    pub fn err(comptime format: []const u8, args: anytype) void {
        if (!builtin.is_test) {
            std.log.err(format, args);
        } else {
            std.log.info(format, args);
        }
    }
};
