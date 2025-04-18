const std = @import("std");
const log = @import("../util.zig").log;
const Lexer = @import("../Lexer.zig");
const Parser = @import("./Parser.zig");
const ParseError = Parser.ParseError;
const Allocator = std.mem.Allocator;

pub const Program = struct {
    @"fn": *Function,

    pub fn init(allocator: Allocator, fn_node: *Function) *@This() {
        const program = allocator.create(Program) catch unreachable;
        program.* = .{ .@"fn" = fn_node };
        return program;
    }
};

pub const Function = struct {
    ident: []const u8,
    block: *Block,

    pub fn init(allocator: Allocator, ident: []const u8, block: *Block) *@This() {
        const fn_node = allocator.create(Function) catch unreachable;
        fn_node.* = .{ .ident = ident, .block = block };
        return fn_node;
    }
};

pub const Block = struct {
    items: std.ArrayList(*BlockItem),

    pub fn init(allocator: Allocator, items: std.ArrayList(*BlockItem)) *@This() {
        const block = allocator.create(Block) catch unreachable;
        block.* = .{ .items = items };
        return block;
    }
};

pub const BlockItem = union(enum) {
    stmt: *Stmt,
    decl: *Decl,

    pub fn stmtBlockItem(allocator: Allocator, stmt: *Stmt) *@This() {
        const block_item = allocator.create(BlockItem) catch unreachable;
        block_item.* = .{ .stmt = stmt };
        return block_item;
    }
    pub fn declBlockItem(allocator: Allocator, decl: *Decl) *@This() {
        const block_item = allocator.create(BlockItem) catch unreachable;
        block_item.* = .{ .decl = decl };
        return block_item;
    }
};

pub const Decl = struct {
    ident: []const u8,
    init: ?*Expr,

    pub fn initDecl(allocator: Allocator, ident: []const u8, init: ?*Expr) *@This() {
        const decl = allocator.create(Decl) catch unreachable;
        decl.* = .{ .ident = ident, .init = init };
        return decl;
    }
};

pub const Stmt = union(enum) {
    @"return": *Expr,
    label: []const u8,
    expr: *Expr,
    if_stmt: struct { condition: *Expr, if_block: *Stmt, else_block: ?*Stmt },
    compound: *Block,
    null,

    pub fn compoundStmt(allocator: Allocator, block: *Block) *@This() {
        const compound = allocator.create(Stmt) catch unreachable;
        compound.* = .{ .compound = block };
        return compound;
    }

    pub fn ifStmt(allocator: Allocator, condition: *Expr, if_block: *Stmt, else_block: ?*Stmt) *@This() {
        const stmt = allocator.create(Stmt) catch unreachable;
        stmt.* = .{ .if_stmt = .{ .condition = condition, .if_block = if_block, .else_block = else_block } };
        return stmt;
    }

    pub fn nullStmt(allocator: Allocator) *@This() {
        const stmt = allocator.create(Stmt) catch unreachable;
        stmt.* = .null;
        return stmt;
    }

    pub fn returnStmt(allocator: Allocator, expr: *Expr) *@This() {
        const stmt = allocator.create(Stmt) catch unreachable;
        stmt.* = .{ .@"return" = expr };
        return stmt;
    }
    pub fn labelStmt(allocator: Allocator, label: []const u8) *@This() {
        const stmt = allocator.create(Stmt) catch unreachable;
        stmt.* = .{ .label = label };
        return stmt;
    }
    pub fn exprStmt(allocator: Allocator, expr: *Expr) *@This() {
        const stmt = allocator.create(Stmt) catch unreachable;
        stmt.* = .{ .expr = expr };
        return stmt;
    }
};

pub const Expr = union(enum) {
    constant: i32,
    unary: struct { op: UnaryOp, expr: *Expr },
    binary: struct { op: BinaryOp, left: *Expr, right: *Expr },
    group: *Expr,
    postfix: union(enum) { increment: *Expr, decrement: *Expr },
    @"var": []const u8,
    assignment: struct { dst: *Expr, src: *Expr },
    ternary: struct { condition: *Expr, true_block: *Expr, false_block: *Expr },

    pub const UnaryOp = enum { bitwise_not, negate, not };
    pub const BinaryOp = enum { add, sub, mul, div, mod, left_shift, right_shift, bitwise_and, bitwise_xor, bitwise_or, not_equal, equal_equal, greater, greater_equal, less, less_equal, @"and", @"or" };

    pub fn constantExpr(allocator: Allocator, constant: i32) *@This() {
        const expr_value = allocator.create(Expr) catch unreachable;
        expr_value.* = .{ .constant = constant };
        return expr_value;
    }

    pub fn binaryExpr(allocator: Allocator, op: BinaryOp, left: *Expr, right: *Expr) *@This() {
        const expr = allocator.create(Expr) catch unreachable;
        expr.* = .{ .binary = .{ .op = op, .left = left, .right = right } };
        return expr;
    }

    pub fn unaryExpr(allocator: Allocator, op: UnaryOp, expr: *Expr) *@This() {
        const unary_expr = allocator.create(Expr) catch unreachable;
        unary_expr.* = .{ .unary = .{ .op = op, .expr = expr } };
        return unary_expr;
    }

    pub fn groupExpr(allocator: Allocator, expr: *Expr) *@This() {
        const group_expr = allocator.create(Expr) catch unreachable;
        group_expr.* = .{ .group = expr };
        return group_expr;
    }

    pub fn varExpr(allocator: Allocator, ident: []const u8) *@This() {
        const var_expr = allocator.create(Expr) catch unreachable;
        var_expr.* = .{ .@"var" = ident };
        return var_expr;
    }

    pub fn assignmentExpr(allocator: Allocator, dst: *Expr, src: *Expr) *@This() {
        const assignment_expr = allocator.create(Expr) catch unreachable;
        assignment_expr.* = .{ .assignment = .{ .dst = dst, .src = src } };
        return assignment_expr;
    }

    pub fn ternaryExpr(allocator: Allocator, condition: *Expr, true_block: *Expr, false_block: *Expr) *@This() {
        const ternary_expr = allocator.create(Expr) catch unreachable;
        ternary_expr.* = .{ .ternary = .{ .condition = condition, .true_block = true_block, .false_block = false_block } };
        return ternary_expr;
    }

    pub fn postfixExpr(allocator: Allocator, token_type: Lexer.TokenType, expr: *Expr) ParseError!*@This() {
        const postfix_expr = allocator.create(Expr) catch unreachable;
        postfix_expr.* = .{
            .postfix = switch (token_type) {
                .plus_plus => .{ .increment = expr },
                .minus_minus => .{ .decrement = expr },
                else => {
                    log.err("Mapping to postfix operator failed for {any}", .{token_type});
                    return ParseError.InvalidPostfixOperator;
                },
            },
        };
        return postfix_expr;
    }
};
