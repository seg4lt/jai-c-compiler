const std = @import("std");
const Ast = @import("Ast.zig");
const AnyWriter = std.io.AnyWriter;

pub fn printProgram(writer: *AnyWriter, program: *Ast.Program, depth: u8) void {
    write(writer, " -- AST -- \n");
    write(writer, "[PROGRAM] ");
    printFn(writer, program.@"fn", depth + 1);
}

pub fn printFn(writer: *AnyWriter, func: *Ast.Function, depth: u8) void {
    printSpace(writer, depth);
    print(writer, "[FN] {s}", .{func.ident});
    printBlock(writer, func.block, depth + 1);
}

pub fn printBlock(writer: *AnyWriter, block: *Ast.Block, depth: u8) void {
    printSpace(writer, depth);
    write(writer, "[BLOCK] ");
    for (block.items.items) |item| {
        printSpace(writer, depth + 1);
        switch (item.*) {
            .stmt => |stmt| printStmt(writer, stmt, depth + 1),
            .decl => |decl| printDecl(writer, decl, depth + 1),
        }
    }
}
pub fn printDecl(writer: *AnyWriter, decl: *Ast.Decl, depth: u8) void {
    print(writer, "[DECL] {s}", .{decl.ident});
    if (decl.init) |init| printExpr(writer, init, depth + 1);
}

pub fn printStmt(writer: *AnyWriter, stmt: *Ast.Stmt, depth: u8) void {
    switch (stmt.*) {
        .@"return" => |expr| {
            write(writer, "[RETURN] ");
            printSpace(writer, depth + 1);
            printExpr(writer, expr, depth + 1);
        },
        .null => write(writer, "[NULL]"),
    }
}
pub fn printExpr(writer: *AnyWriter, expr: *Ast.Expr, depth: u8) void {
    switch (expr.*) {
        .constant => |constant| print(writer, "{d}", .{constant}),
        .binary => |binary| {
            print(writer, "[BINARY] {s}", .{@tagName(binary.op)});
            printSpace(writer, depth + 1);
            printExpr(writer, binary.left, depth + 1);
            printSpace(writer, depth + 1);
            printExpr(writer, binary.right, depth + 1);
        },
    }
}

fn write(writer: *AnyWriter, bytes: []const u8) void {
    _ = writer.write(bytes) catch unreachable; // ignore error
}

fn print(writer: *AnyWriter, comptime format: []const u8, args: anytype) void {
    _ = writer.print(format, args) catch unreachable; // ignore error, we are brave here
}

fn printSpace(writer: *AnyWriter, depth: u8) void {
    write(writer, "\n");
    for (0..depth) |_| write(writer, "|-");
}
