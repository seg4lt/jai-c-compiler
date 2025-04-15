const std = @import("std");
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

    pub fn initStmt(allocator: Allocator, stmt: *Stmt) *@This() {
        const block_item = allocator.create(BlockItem) catch unreachable;
        block_item.* = .{ .stmt = stmt };
        return block_item;
    }
    pub fn initDecl(allocator: Allocator, decl: *Decl) *@This() {
        const block_item = allocator.create(BlockItem) catch unreachable;
        block_item.* = .{ .decl = decl };
        return block_item;
    }
};

pub const Decl = struct {
    ident: []const u8,
    init: ?*Expr,
};

pub const Stmt = union(enum) {
    @"return": *Expr,
    null,

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
};

pub const Expr = union(enum) {
    constant: i32,
    binary: struct {
        op: BinaryOp,
        left: *Expr,
        right: *Expr,
    },

    pub const BinaryOp = enum { add, sub, mul, div, mod, left_shift, right_shift, bitwise_and, bitwise_xor, bitwise_or, not_equal, equal_equal, greater, greater_equal, less, less_equal, @"and", @"or" };

    pub fn constantExpr(allocator: Allocator, constant: i32) *@This() {
        const expr = allocator.create(Expr) catch unreachable;
        expr.* = .{ .constant = constant };
        return expr;
    }

    pub fn binaryExpr(allocator: Allocator, op: BinaryOp, left: *Expr, right: *Expr) *@This() {
        const expr = allocator.create(Expr) catch unreachable;
        expr.* = .{ .binary = .{ .op = op, .left = left, .right = right } };
        return expr;
    }
};
