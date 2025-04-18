pub fn main() !void {
    const gpa, const deinit = getAllocator();
    defer _ = if (deinit) debug_allocator.deinit();

    // Who even cares about memory?
    var arena_ = std.heap.ArenaAllocator.init(gpa);
    const arena = arena_.allocator();
    defer _ = arena_.reset(.free_all);

    var err_reporter = ErrorReporter.init(arena);
    start(arena, &err_reporter) catch |err| {
        log.err("Error: {any}", .{err});
        err_reporter.printErrorsStdOut();
        return err;
    };
}

pub fn start(arena: Allocator, err_reporter: *ErrorReporter) !void {
    const args = try CliArgs.parse();
    log.debug("Compiling file: {s}", .{args.src});
    preprocessor(arena, args.src);
    const lexer = if (args.flag.isEnabled(.lex)) try Lexer.initFromSrcPath(arena, err_reporter, args.src) else null;
    const ast = if (args.flag.isEnabled(.parse)) try Parser.parse(arena, err_reporter, lexer.?.tokens) else null;
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
