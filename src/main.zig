pub fn main() !void {
    const args = CliArgs.parse();
    std.log.info("{any}", .{args});
}

test "test check" {
    try std.testing.expect(true);
}

const std = @import("std");
const CliArgs = @import("CliArgs.zig");
