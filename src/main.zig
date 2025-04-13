pub fn main() !void {}

test "test check" {
    try std.testing.expect(true);
}

const std = @import("std");
