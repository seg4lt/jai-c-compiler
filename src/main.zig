pub fn main() !void {
    const gpa, const deinit = getAllocator();
    defer _ = if (deinit) debug_allocator.deinit();

    // Who even cares about memory?
    var arena_ = std.heap.ArenaAllocator.init(gpa);
    const arena = arena_.allocator();
    defer _ = arena_.reset(.free_all);

    try startCompiler(arena);
}

pub fn startCompiler(allocator: Allocator) !void {
    const args = try CliArgs.parse();
    log.debug("Compiling file: {s}", .{args.src_path});
    preprocessor(allocator, args.src_path);

    const file = std.fmt.allocPrint(allocator, "{s}.i", .{args.src_path[0 .. args.src_path.len - 2]}) catch unreachable;
    defer allocator.free(file);
    log.info("Reading file: {s}\n", .{file});
    const src = try std.fs.cwd().readFileAlloc(allocator, file, 4096);

    var error_reporter: ErrorReporter = .init(allocator, src, args.src_path);

    const lexer = if (args.flag.isEnabled(.lex)) try Lexer.initFromSrc(allocator, src, &error_reporter) else null;
    const ast = if (args.flag.isEnabled(.parse)) try Parser.parse(
        allocator,
        lexer.?.tokens,
        &error_reporter,
    ) else null;
    _ = ast;
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

const std = @import("std");
const CliArgs = @import("CliArgs.zig");
const Lexer = @import("Lexer.zig");
const Parser = @import("parser/Parser.zig");
const builtin = @import("builtin");
const util = @import("util.zig");
const ErrorReporter = @import("ErrorReporter.zig");
const log = util.log;
const preprocessor = util.preprocessor;

const Allocator = std.mem.Allocator;
const ProgramAst = Parser.Program;
const native_os = builtin.os.tag;
var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
