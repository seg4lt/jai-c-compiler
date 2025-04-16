const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

pub fn preprocessor(allocator: Allocator, src_path: []const u8) void {
    const file = src_path[0 .. src_path.len - 2];
    const c_file = std.fmt.allocPrint(allocator, "{s}.c", .{file}) catch unreachable;
    defer allocator.free(c_file);
    const i_file = std.fmt.allocPrint(allocator, "{s}.i", .{file}) catch unreachable;
    defer allocator.free(i_file);
    var child = std.process.Child.init(&[_][]const u8{ "gcc", "-E", "-P", c_file, "-o", i_file }, allocator);
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
