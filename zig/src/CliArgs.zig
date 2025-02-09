const std = @import("std");
const CliFlags = enum(u8) { All, Lex, Parse, CodeGen };

src_file: []const u8 = "",
flag: CliFlags = .All,

const Self = @This();
pub fn init() Self {
    var self: Self = .{};
    var args = std.process.args();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, "--lex", arg)) {
            self.flag = .Lex;
        } else if (std.mem.eql(u8, "--parse", arg)) {
            self.flag = .Parse;
        } else if (std.mem.eql(u8, "--code-gen", arg)) {
            self.flag = .CodeGen;
        } else {
            self.src_file = arg;
        }
    }
    return self;
}
