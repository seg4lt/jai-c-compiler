const std = @import("std");
const Lexer = @import("Lexer.zig");
const Allocator = std.mem.Allocator;
const Token = Lexer.Token;
const TokenType = Lexer.TokenType;

tokens: *const std.ArrayList(Token),
start: usize = 0,
current: usize = 0,

arena_allocator: std.heap.ArenaAllocator,
arena: Allocator,

const Self = @This();

pub fn init(gpa: Allocator, tokens: *const std.ArrayList(Token)) Self {
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    const arena = arena_allocator.allocator();
    return .{ .tokens = tokens, .arena_allocator = arena_allocator, .arena = arena };
}

pub fn deinit(s: Self) void {
    s.arena_allocator.deinit();
}

pub fn parse_program(s: *Self) Program {
    const function = s.parse_fn();
    return Program{ .function = function };
}

fn parse_fn(s: *Self) Function {
    const name = s.consume(.Int) orelse {
        std.debug.panic("Expected function name\n");
    };
    s.consume(TokenType.Lparen) orelse {
        std.debug.panic("Expected '(' after function name\n");
    };
    {
        if (s.peek() == .Void) {
            _ = s.consume(.Void);
        }
    }
    s.consume(TokenType.Rparen) orelse {
        std.debug.panic("Expected ')' after function name\n");
    };
    s.consume(TokenType.Lcurly) orelse {
        std.debug.panic("Expected '{' after function name\n");
    };
    const body = s.parse_stmts();
    s.consume(TokenType.Rcurly) orelse {
        std.debug.panic("Expected '}' after function body\n");
    };
    return Function{ .name = name, .body = body };
}

fn parse_stmts(s: *Self) void {
    return switch (s.peek()) {
        .Return => s.parse_return_stmt(),
    };
}

fn parse_return_stmt(s: *Self) Stmt {
    _ = s.consume(.Return);
    const value = s.parse_expr();
    return Stmt.Return{ .value = value };
}

fn parse_expr(s: *Self) Expr {
    return switch (s.peek()) {
        .IntLiteral => s.parse_int_literal(),
        .Lparen => s.parse_group_expr(),
        .Unary => s.parse_unary_expr(),
        else => std.debug.panic("Unexpected expression type\n"),
    };
}
fn parse_int_literal(s: *Self) Expr {
    const token = s.consume(.IntLiteral) orelse {
        std.debug.panic("Expected integer literal\n");
    };
    return Expr{ .IntLiteral = token.value };
}
fn parse_group_expr(s: *Self) Expr {
    s.consume(.Lparen) orelse {
        std.debug.panic("Expected '(' before group expression\n");
    };
    const expr = s.parse_expr();
    s.consume(.Rparen) orelse {
        std.debug.panic("Expected ')' after group expression\n");
    };
    return Expr{ .Group = expr };
}
fn parse_unary_expr(s: *Self) Expr {
    // const token = s.consume(.Unary) orelse {
    //     std.debug.panic("Expected unary operator\n");
    // };
    switch (s.peek()) {
        .Negate => return s.parse_negate_expr(),
        .BitwiseNot => return s.parse_bitwise_not_expr(),
        else => std.debug.panic("Unexpected unary operator\n"),
    }
}
fn parse_negate_expr(s: *Self) Expr {
    _ = s.consume(.Negate);
    const expr = s.parse_expr();
    return Expr{ .Unary = UnaryExpr.Negate{ .expr = expr } };
}

fn parse_bitwise_not_expr(s: *Self) Expr {
    _ = s.consume(.BitwiseNot);
    const expr = s.parse_expr();
    return Expr{ .Unary = UnaryExpr.BitwiseNot{ .expr = expr } };
}

fn consume(s: *Self, token_type: TokenType) ?Token {
    if (s.peek() != token_type) {
        return null;
    }
    defer s.current += 1;
    return s.tokens.items[s.current];
}
fn peek(s: *Self) TokenType {
    return s.tokens.items[s.current].token;
}

const Program = struct {
    function: Function,
};

const Function = struct {
    name: []const u8,
    body: []const Stmt,
};

const Stmt = union(enum) { Return: struct {
    value: Expr,
} };

const Expr = union(enum) {
    IntLiteral: u64,
    Unary: UnaryExpr,
    Group: *Expr,
};

const UnaryExpr = union(enum) {
    Negate: *Expr,
    BitwiseNot: *Expr,
};
const std = @import("std");
const Lexer = @import("Lexer.zig");
const Allocator = std.mem.Allocator;
const Token = Lexer.Token;
const TokenType = Lexer.TokenType;

tokens: *const std.ArrayList(Token),
start: usize = 0,
current: usize = 0,

arena_allocator: std.heap.ArenaAllocator,
arena: Allocator,

const Self = @This();

pub fn init(gpa: Allocator, tokens: *const std.ArrayList(Token)) Self {
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    const arena = arena_allocator.allocator();
    return .{ .tokens = tokens, .arena_allocator = arena_allocator, .arena = arena };
}

pub fn deinit(s: Self) void {
    s.arena_allocator.deinit();
}

pub fn parse_program(s: *Self) Program {
    const function = s.parse_fn();
    return Program{ .function = function };
}

fn parse_fn(s: *Self) Function {
    const name = s.consume(.Int) orelse {
        std.debug.panic("Expected function name\n");
    };
    s.consume(TokenType.Lparen) orelse {
        std.debug.panic("Expected '(' after function name\n");
    };
    {
        if (s.peek() == .Void) {
            _ = s.consume(.Void);
        }
    }
    s.consume(TokenType.Rparen) orelse {
        std.debug.panic("Expected ')' after function name\n");
    };
    s.consume(TokenType.Lcurly) orelse {
        std.debug.panic("Expected '{' after function name\n");
    };
    const body = s.parse_stmts();
    s.consume(TokenType.Rcurly) orelse {
        std.debug.panic("Expected '}' after function body\n");
    };
    return Function{ .name = name, .body = body };
}

const Program = struct {
    function: Function,
};

const Function = struct {
    name: []const u8,
    body: []const Stmt,
};

const Stmt = union(enum) { Return: struct {
    value: Expr,
} };

const Expr = union(enum) {
    IntLiteral: u64,
    Unary: UnaryExpr,
    Group: *Expr,
};

const UnaryExpr = union(enum) {
    Negate: *Expr,
    BitwiseNot: *Expr,
};
