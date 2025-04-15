const std = @import("std");
const log = std.log;
const Lexer = @import("../Lexer.zig");
const Allocator = std.mem.Allocator;
pub const AstPrinter = @import("AstPrinter.zig");
pub const Ast = @import("Ast.zig");

const Parser = @This();

const ParseError = error{ UnexpectedToken, InvalidIntValue, ExpectedSomeToken };

allocator: Allocator,
tokens: Lexer.TokenArray,
current: usize = 0,

pub fn parse(allocator: Allocator, tokens: Lexer.TokenArray) ParseError!*Ast.Program {
    var p: Parser = .{ .allocator = allocator, .tokens = tokens };
    const program = try p.parseProgram();
    if (!p.isAtEnd()) {
        log.err("Parser did not consume all tokens", .{});
        return ParseError.UnexpectedToken;
    }
    print(allocator, program);
    return program;
}

fn print(allocator: Allocator, program: *Ast.Program) void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer _ = arena.reset(.free_all);

    var buffer = std.ArrayList(u8).init(arena.allocator());
    var writer = buffer.writer().any();
    AstPrinter.printProgram(&writer, program, 0);
    const result = buffer.toOwnedSlice() catch unreachable;
    log.debug("{s}", .{result});
}

fn parseProgram(p: *Parser) ParseError!*Ast.Program {
    const fn_node = try p.parserFn();
    return .init(p.allocator, fn_node);
}

fn parserFn(p: *Parser) ParseError!*Ast.Function {
    _ = try p.consume(.int);
    const ident_token = try p.consume(.ident);

    _ = try p.consume(.lparen);
    _ = if (p.peek()) |token| if (token.type == .void) try p.consume(.void);
    _ = try p.consume(.rparen);

    _ = try p.consume(.lcurly);
    const body = try p.parseBlock();
    _ = try p.consume(.rcurly);

    return .init(p.allocator, ident_token.value, body);
}

fn parseBlock(p: *Parser) ParseError!*Ast.Block {
    var item = std.ArrayList(*Ast.BlockItem).init(p.allocator);

    while (p.peek()) |token| {
        if (token.type == .rcurly) break;
        const block_item = try p.parseBlockItem();
        item.append(block_item) catch unreachable;
    }
    return .init(p.allocator, item);
}

fn parseBlockItem(p: *Parser) ParseError!*Ast.BlockItem {
    const cur = p.peek() orelse return ParseError.ExpectedSomeToken;
    switch (cur.type) {
        .int => unreachable,
        .semicolon => {
            _ = try p.consume(.semicolon);
            return .initStmt(p.allocator, .nullStmt(p.allocator));
        },
        else => {
            const stmt = try p.parseStmt();
            return .initStmt(p.allocator, stmt);
        },
    }
}

fn parseStmt(p: *Parser) ParseError!*Ast.Stmt {
    const cur = p.peek() orelse return ParseError.ExpectedSomeToken;
    return switch (cur.type) {
        .@"return" => try p.parseReturnStmt(),
        else => {
            log.err("Unexpected token {any}", .{cur});
            unreachable;
        },
    };
}

fn parseReturnStmt(p: *Parser) ParseError!*Ast.Stmt {
    _ = try p.consume(.@"return");
    const expr = try p.parseExpr(0);
    _ = try p.consume(.semicolon);
    return .returnStmt(p.allocator, expr);
}

fn parseExpr(p: *Parser, min_precedence: u8) ParseError!*Ast.Expr {
    var left = try p.parseFactor();
    var next_token = p.peek() orelse return ParseError.ExpectedSomeToken;

    while (isBinaryOperator(next_token.type) and precedence(next_token.type) >= min_precedence) {
        if (next_token.type == .assign) {
            unreachable;
        } else if (isCompoundAssignmentOperator(next_token.type)) {
            unreachable;
        } else if (next_token.type == .question_mark) {
            unreachable;
        } else {
            const op = mapToBinaryOperator(next_token.type);
            const right = try p.parseExpr(precedence(next_token.type) + 1);
            const binary: *Ast.Expr = .binaryExpr(p.allocator, op, left, right);
            left = binary;
        }
        next_token = p.peek() orelse return ParseError.ExpectedSomeToken;
    }
    return left;
}

fn parseFactor(p: *Parser) ParseError!*Ast.Expr {
    const tok = p.peek() orelse return ParseError.ExpectedSomeToken;
    return switch (tok.type) {
        .int_literal => {
            const literal = try p.consume(.int_literal);
            const constant = std.fmt.parseInt(i32, literal.value, 10) catch {
                log.err("Failed to parse int literal: {s}", .{literal.value});
                return ParseError.InvalidIntValue;
            };
            return .constantExpr(p.allocator, constant);
        },
        .minus, .not, .bitwise_not => unreachable,
        .minus_minus, .plus_plus => unreachable,
        .lparen => unreachable,
        .ident => unreachable,
        else => {
            log.err("What am I even seeing? {any}", .{tok});
            unreachable;
        },
    };
}

fn mapToBinaryOperator(token_type: Lexer.TokenType) Ast.Expr.BinaryOp {
    return switch (token_type) {
        .plus, .plus_equal => .add,
        .minus, .minus_equal => .sub,
        .multiply, .multiply_equal => .mul,
        .divide, .divide_equal => .div,
        .mod, .mod_equal => .mod,
        .left_shift, .left_shift_equal => .left_shift,
        .right_shift, .right_shift_equal => .right_shift,
        .bitwise_and, .bitwise_and_equal => .bitwise_and,
        .bitwise_xor, .bitwise_xor_equal => .bitwise_xor,
        .bitwise_or, .bitwise_or_equal => .bitwise_or,
        .not_equal => .not_equal,
        .equal_equal => .equal_equal,
        .greater => .greater,
        .greater_equal => .greater_equal,
        .less => .less,
        .less_equal => .less_equal,
        .@"and" => .@"and",
        .@"or" => .@"or",
        else => {
            log.err("Mapping to binary operator failed for {any}", .{token_type});
            unreachable;
        },
    };
}

fn isCompoundAssignmentOperator(token_type: Lexer.TokenType) bool {
    return switch (token_type) {
        .plus_equal, .minus_equal, .multiply_equal, .divide_equal, .mod_equal, .left_shift_equal, .right_shift_equal, .bitwise_and_equal, .bitwise_xor_equal, .bitwise_or_equal => true,
        else => false,
    };
}

fn isBinaryOperator(token_type: Lexer.TokenType) bool {
    return switch (token_type) {
        .minus, .plus, .divide, .multiply, .mod, .left_shift, .right_shift, .bitwise_and, .bitwise_xor, .bitwise_or, .@"and", .@"or", .not_equal, .equal_equal, .greater, .greater_equal, .less, .less_equal, .assign, .bitwise_and_equal, .bitwise_xor_equal, .bitwise_or_equal, .left_shift_equal, .right_shift_equal, .plus_equal, .minus_equal, .multiply_equal, .divide_equal, .mod_equal, .question_mark => true,
        else => false,
    };
}
fn precedence(token_type: Lexer.TokenType) u8 {
    return switch (token_type) {
        .bitwise_not, .not => 70,
        .divide, .multiply, .mod => 50,
        .minus, .plus => 45,
        .left_shift, .right_shift => 40,
        .less, .less_equal, .greater, .greater_equal => 35,
        .equal_equal, .not_equal => 30,
        .bitwise_and => 25,
        .bitwise_xor => 24,
        .bitwise_or => 23,
        .@"and" => 10,
        .@"or" => 5,
        .question_mark => 3,
        .assign, .plus_equal, .minus_equal, .multiply_equal, .divide_equal, .left_shift_equal, .right_shift_equal, .bitwise_and_equal, .bitwise_xor_equal, .bitwise_or_equal, .mod_equal => 1,
        else => {
            log.err("precendence calculation for {any} should not be reached", .{token_type});
            unreachable;
        },
    };
}

fn consume(p: *Parser, token_type: Lexer.TokenType) ParseError!*Lexer.Token {
    const token = p.peek() orelse return ParseError.ExpectedSomeToken;
    if (token.type != token_type) {
        log.err("Expected token type {any}, found {any}", .{ token_type, token.type });
        return ParseError.UnexpectedToken;
    }
    p.current += 1;
    return token;
}

fn peek(p: *const Parser) ?*Lexer.Token {
    if (p.isAtEnd()) return null;
    return &p.tokens.items[p.current];
}

fn isAtEnd(p: *const Parser) bool {
    return p.current >= p.tokens.items.len;
}

test {
    _ = @import("Parser_test.zig");
}
