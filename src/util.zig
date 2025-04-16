const std = @import("std");
const builtin = @import("builtin");

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
