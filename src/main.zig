pub fn main() !void {
    const gpa, const deinit = getAllocator();
    defer _ = if (deinit) debug_allocator.deinit();

    var arena_ = std.heap.ArenaAllocator.init(gpa);
    const arena = arena_.allocator();
    defer _ = arena_.reset(.free_all);

    const args = try CliArgs.parse();

    const tokens: ?Lexer = if (args.flag.isEnabled(.lex)) try .initFromSrcPath(arena, args.src) else null;
    _ = tokens;
}

pub fn getAllocator() struct { Allocator, bool } {
    return gpa: {
        if (native_os == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
}

test "test check" {
    try std.testing.expect(true);
}

const std = @import("std");
const CliArgs = @import("CliArgs.zig");
const Lexer = @import("Lexer.zig");
const builtin = @import("builtin");
const native_os = builtin.os.tag;
const log = std.log;
const Allocator = std.mem.Allocator;
var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
