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
    print(writer, "[DECL] {s} ", .{decl.ident});
    if (decl.init) |init| printExpr(writer, init, depth + 1);
}

pub fn printStmt(writer: *AnyWriter, stmt: *Ast.Stmt, depth: u8) void {
    switch (stmt.*) {
        .do_while => |do_while| {
            print(writer, "[DO] {s}", .{do_while.label});
            printStmt(writer, do_while.body, depth + 1);
            printSpace(writer, depth);
            print(writer, "[DO_WHILE] {s}", .{do_while.label});
            printExpr(writer, do_while.condition, depth + 1);
        },
        .@"break" => |label| {
            print(writer, "[BREAK] {s}", .{label});
        },
        .@"continue" => |label| {
            print(writer, "[CONTINUE] {s}", .{label});
        },
        .if_stmt => |if_stmt| {
            write(writer, "[IF]");
            printSpace(writer, depth + 1);
            printExpr(writer, if_stmt.condition, depth + 1);
            printSpace(writer, depth + 2);
            printStmt(writer, if_stmt.if_block, depth + 2);
            if (if_stmt.else_block) |else_block_| {
                printSpace(writer, depth);
                write(writer, "[ELSE]");
                printSpace(writer, depth + 2);
                printStmt(writer, else_block_, depth + 2);
            }
        },
        .@"for" => |for_stmt| {
            print(writer, "[FOR] {s} ", .{for_stmt.label});
            printSpace(writer, depth + 1);
            write(writer, "<init> ");
            switch (for_stmt.init.*) {
                .decl => |decl| printDecl(writer, decl, depth + 1),
                .expr => |expr| if (expr) |it| printExpr(writer, it, depth + 1),
            }
            printSpace(writer, depth + 1);
            write(writer, "<condition> ");
            if (for_stmt.condition) |condition| printExpr(writer, condition, depth + 1);
            printSpace(writer, depth + 1);
            write(writer, "<post> ");
            if (for_stmt.post) |post| printExpr(writer, post, depth + 1);
            printSpace(writer, depth + 1);
            printStmt(writer, for_stmt.body, depth + 1);
        },
        .@"while" => |while_stmt| {
            print(writer, "[WHILE] {s} ", .{while_stmt.label});
            printExpr(writer, while_stmt.condition, 0);
            printSpace(writer, depth + 1);
            printStmt(writer, while_stmt.body, depth + 1);
        },
        .@"return" => |expr| {
            write(writer, "[RETURN] ");
            printSpace(writer, depth + 1);
            printExpr(writer, expr, depth + 1);
        },
        .expr => |expr| {
            write(writer, "[EXPR] ");
            printSpace(writer, depth + 1);
            printExpr(writer, expr, depth + 1);
        },
        .compound => |compound| {
            write(writer, "[COMPOUND]");
            printBlock(writer, compound, depth + 2);
        },
        .goto => |label| {
            print(writer, "[GOTO] {s}", .{label});
        },
        .null => write(writer, "[NULL]"),
        .label => |label| print(writer, "[LABEL] {s}", .{label}),
    }
}
pub fn printExpr(writer: *AnyWriter, expr: *Ast.Expr, depth: u8) void {
    switch (expr.*) {
        .constant => |constant| print(writer, "{d}", .{constant}),
        .unary => |unary| {
            print(writer, "[UNARY] {s}", .{@tagName(unary.op)});
            printSpace(writer, depth + 1);
            printExpr(writer, unary.expr, depth + 1);
        },
        .binary => |binary| {
            print(writer, "[BINARY] {s}", .{@tagName(binary.op)});
            printSpace(writer, depth + 1);
            printExpr(writer, binary.left, depth + 1);
            printSpace(writer, depth + 1);
            printExpr(writer, binary.right, depth + 1);
        },
        .group => |group_expr| {
            write(writer, "[GROUP] ");
            printSpace(writer, depth + 1);
            printExpr(writer, group_expr, depth + 1);
        },
        .postfix => |postfix_expr| {
            switch (postfix_expr) {
                .increment => {
                    write(writer, "[++]");
                    printExpr(writer, postfix_expr.increment, depth);
                },
                .decrement => {
                    write(writer, "[--]");
                    printExpr(writer, postfix_expr.decrement, depth);
                },
            }
        },
        .prefix => |prefix_expr| {
            switch (prefix_expr) {
                .increment => {
                    write(writer, "[++]");
                    printExpr(writer, prefix_expr.increment, depth);
                },
                .decrement => {
                    write(writer, "[--]");
                    printExpr(writer, prefix_expr.decrement, depth);
                },
            }
        },
        .@"var" => |var_value| {
            print(writer, "[VAR] {s}", .{var_value});
        },
        .assignment => |assignment| {
            write(writer, "[ASSIGNMENT] ");
            printExpr(writer, assignment.dst, depth);
            write(writer, " = ");
            printExpr(writer, assignment.src, depth);
        },
        .ternary => |ternary| {
            write(writer, "[TERNARY]");
            printSpace(writer, depth + 1);
            printExpr(writer, ternary.condition, depth);
            printSpace(writer, depth + 1);
            write(writer, " ? ");
            printExpr(writer, ternary.true_block, depth + 2);
            printSpace(writer, depth + 1);
            write(writer, " : ");
            printExpr(writer, ternary.false_block, depth + 2);
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
