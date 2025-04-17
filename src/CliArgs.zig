flag: CliFlags = .all,
src: []const u8,

pub fn parse() CliArgsError!Self {
    var args = std.process.args();

    var flag: CliFlags = .all;
    var src: ?[]const u8 = null;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, "--lex", arg)) {
            flag = .lex;
        } else if (std.mem.eql(u8, "--parse", arg)) {
            flag = .parse;
        } else if (std.mem.eql(u8, "--validate", arg)) {
            flag = .sema;
        } else if (std.mem.eql(u8, "--tacky", arg)) {
            flag = .tacky;
        } else if (std.mem.eql(u8, "--code-gen", arg)) {
            flag = .code_gen;
        } else {
            src = arg;
        }
    }

    if (!std.mem.endsWith(u8, src orelse return CliArgsError.NoSourceFile, ".c")) {
        return CliArgsError.SourceFileNotACExtension;
    }
    return .{ .flag = flag, .src = src.? };
}

pub const CliFlags = enum(u8) {
    lex = 1,
    parse = 2,
    sema = 3,
    tacky = 4,
    code_gen = 5,
    all = 6,

    pub fn isEnabled(self: *const CliFlags, check_flag: CliFlags) bool {
        if (self.* == .all) return true;
        return @intFromEnum(self.*) >= @intFromEnum(check_flag);
    }
};

const CliArgsError = error{ NoSourceFile, SourceFileNotACExtension };

const Self = @This();
const std = @import("std");

test "test cli args" {
    const TestData = struct {
        arg: [*:0]const u8,
        flags: []const CliFlags,
    };
    
    const test_data = [_]TestData{
        .{ .arg = "--lex", .flags = &[_]CliFlags{.lex} },
        .{ .arg = "--parse", .flags = &[_]CliFlags{ .lex, .parse } },
        .{ .arg = "--validate", .flags = &[_]CliFlags{ .lex, .parse, .sema } },
        .{ .arg = "--tacky", .flags = &[_]CliFlags{ .lex, .parse, .sema, .tacky } },
        .{ .arg = "--code-gen", .flags = &[_]CliFlags{ .lex, .parse, .sema, .tacky, .code_gen } },
        .{ .arg = "", .flags = &[_]CliFlags{ .lex, .parse, .sema, .tacky, .code_gen, .all } },
    };

    for (test_data) |data| {
        var argv = [_][*:0]u8{
            @constCast(data.arg),
            @constCast("main.c"),
        };
        std.os.argv = &argv;

        const args = try parse();
        for (data.flags) |expected_flag| {
            try std.testing.expect(args.flag.isEnabled(expected_flag));
        }
    }
}

test "test error" {}
