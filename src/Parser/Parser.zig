const std = @import("std");
const log = @import("../util.zig").log;
const Lexer = @import("../Lexer.zig");
const ErrorReporter = @import("../ErrorReporter.zig");
const Allocator = std.mem.Allocator;
pub const AstPrinter = @import("AstPrinter.zig");
pub const Ast = @import("Ast.zig");

const Parser = @This();

pub const ParseError = error{
    AllTokenNotConsumed,
    ReceivedUnexpectedToken,
    InvalidIntValue,
    ExpectedSomeToken,
    InvalidLValue,
    InvalidPostfixOperator,
};

allocator: Allocator,
tokens: Lexer.TokenArray,
current: usize = 0,
err_reporter: *ErrorReporter,

pub fn parse(allocator: Allocator, tokens: Lexer.TokenArray, err_reporter: *ErrorReporter) ParseError!*Ast.Program {
    var p: Parser = .{ .allocator = allocator, .tokens = tokens, .err_reporter = err_reporter };
    const program = try p.parseProgram();
    if (!p.isAtEnd()) {
        const tok = p.peekOrError();
        p.parseError(tok, "Not all token consumed: {s}n\n", .{tok.value});
    }
    print(allocator, program);
    return program;
}

fn parseError(p: *const Parser, token: *const Lexer.Token, comptime msg_fmt: []const u8, args: anytype) noreturn {
    p.err_reporter.addErrorAndPanic(token.line, token.start, msg_fmt, args) catch unreachable;
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
    _ = p.consume(.int);
    const ident_token = p.consume(.ident);

    _ = p.consume(.lparen);
    _ = if (p.peek()) |token| if (token.type == .void) p.consume(.void);
    _ = p.consume(.rparen);

    _ = p.consume(.lcurly);
    const body = try p.parseBlock();
    _ = p.consume(.rcurly);

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
    const cur = p.peekOrError();
    switch (cur.type) {
        .int => {
            const decl = try p.parseDecl();
            return .declBlockItem(p.allocator, decl);
        },
        .semicolon => {
            _ = p.consume(.semicolon);
            return .stmtBlockItem(p.allocator, .nullStmt(p.allocator));
        },
        else => {
            const stmt = try p.parseStmt();
            return .stmtBlockItem(p.allocator, stmt);
        },
    }
}

fn parseDecl(p: *Parser) ParseError!*Ast.Decl {
    _ = p.consume(.int);
    const ident_token = p.consume(.ident);
    const ident = ident_token.value;
    if (std.ascii.isDigit(ident[0])) {
        p.parseError(ident_token, "Invalid identifier - ident cannot start with digits {s}\n", .{ident});
        return ParseError.InvalidIntValue;
    }
    const rvalue: ?*Ast.Expr = rvalue_l: {
        if (p.peek()) |token| {
            if (token.type == .assign) {
                _ = p.consumeAny();
                break :rvalue_l try p.parseExpr(0);
            }
        }
        break :rvalue_l null;
    };
    _ = p.consume(.semicolon);
    return .initDecl(p.allocator, ident, rvalue);
}

fn parseStmt(p: *Parser) ParseError!*Ast.Stmt {
    const peek_tok = p.peekOrError();
    return switch (peek_tok.type) {
        .lcurly => {
            _ = p.consume(.lcurly);
            const body = try p.parseBlock();
            _ = p.consume(.rcurly);
            return .compoundStmt(p.allocator, body);
        },
        .@"break" => {
            _ = p.consume(.@"break");
            const stmt: *Ast.Stmt = .breakStmt(p.allocator);
            _ = p.consume(.semicolon);
            return stmt;
        },
        .@"continue" => {
            _ = p.consume(.@"continue");
            const stmt: *Ast.Stmt = .continueStmt(p.allocator);
            _ = p.consume(.semicolon);
            return stmt;
        },
        .@"while" => try p.parseWhileStmt(),
        .do => try p.parseDoWhileStmt(),
        .@"for" => try p.parseForStmt(),
        .@"return" => try p.parseReturnStmt(),
        .@"if" => try p.parseIfStmt(),
        .goto => {
            _ = p.consume(.goto);
            const token = p.consume(.ident);
            _ = p.consume(.semicolon);
            return .gotoStmt(p.allocator, token.value);
        },
        .semicolon => {
            _ = p.consume(.semicolon);
            return .nullStmt(p.allocator);
        },
        else => {
            const next_peek_tok = p.peekOffset(1);
            if (peek_tok.type == .ident and next_peek_tok != null and next_peek_tok.?.type == .colon) {
                const label_ident = p.consume(.ident);
                _ = p.consume(.colon);
                return .labelStmt(p.allocator, label_ident.value);
            }
            const expr = try p.parseExpr(0);
            _ = p.consume(.semicolon);
            return .exprStmt(p.allocator, expr);
        },
    };
}

fn parseForStmt(p: *Parser) ParseError!*Ast.Stmt {
    _ = p.consume(.@"for");
    _ = p.consume(.lparen);

    const for_init = try p.parseForInit();
    if (for_init.* == .expr) _ = p.consume(.semicolon);

    const condition = try p.parseOptionalExpr(0);
    _ = p.consumeAny();

    const post = if (p.peekOrError().type == .rparen) null else try p.parseExpr(0);

    _ = p.consume(.rparen);

    const body = try p.parseStmt();
    return .forStmt(p.allocator, for_init, condition, post, body);
}

fn parseForInit(p: *Parser) ParseError!*Ast.ForInit {
    const tok = p.peekOrError();
    if (tok.type == .int) {
        const decl = try p.parseDecl();
        return .declForInit(p.allocator, decl);
    }
    const expr = try p.parseOptionalExpr(0);
    return .exprForInit(p.allocator, expr);
}

fn parseDoWhileStmt(p: *Parser) ParseError!*Ast.Stmt {
    _ = p.consume(.do);
    const body = try p.parseStmt();

    _ = p.consume(.@"while");
    _ = p.consume(.lparen);
    const condition = try p.parseExpr(0);
    _ = p.consume(.rparen);
    _ = p.consume(.semicolon);
    return .doWhileStmt(p.allocator, body, condition);
}

fn parseWhileStmt(p: *Parser) ParseError!*Ast.Stmt {
    _ = p.consume(.@"while");
    _ = p.consume(.lparen);
    const condition = try p.parseExpr(0);
    _ = p.consume(.rparen);
    const body = try p.parseStmt();
    return .whileStmt(p.allocator, condition, body);
}

fn parseReturnStmt(p: *Parser) ParseError!*Ast.Stmt {
    _ = p.consume(.@"return");
    const expr = try p.parseExpr(0);
    _ = p.consume(.semicolon);
    return .returnStmt(p.allocator, expr);
}

fn parseIfStmt(p: *Parser) ParseError!*Ast.Stmt {
    _ = p.consume(.@"if");
    _ = p.consume(.lparen);
    const condition = try p.parseExpr(0);
    _ = p.consume(.rparen);

    const if_block = try p.parseStmt();

    const else_block = else_block: {
        if (p.peek()) |token| {
            if (token.type == .@"else") {
                _ = p.consume(.@"else");
                break :else_block try p.parseStmt();
            }
        }
        break :else_block null;
    };
    return .ifStmt(p.allocator, condition, if_block, else_block);
}

fn parseOptionalExpr(p: *Parser, min_precedence: u8) ParseError!?*Ast.Expr {
    if (p.peekOrError().type == .semicolon) return null;
    return p.parseExpr(min_precedence);
}

fn parseExpr(p: *Parser, min_precedence: u8) ParseError!*Ast.Expr {
    var left = try p.parseFactor();
    var next_token = p.peekOrError();

    while (isBinaryOperator(next_token.type) and p.precedence(next_token) >= min_precedence) {
        if (next_token.type == .assign) {
            _ = p.consumeAny();
            const right = try p.parseExpr(p.precedence(next_token));
            const expr: *Ast.Expr = .assignmentExpr(p.allocator, left, right);
            left = expr;
        } else if (isCompoundAssignmentOperator(next_token.type)) {
            const token = p.consumeAny();
            const op = p.mapToBinaryOperator(token);
            const right = try p.parseExpr(p.precedence(token));

            // @note
            // cloning the left side, as we will modify the content in sema phase
            const left_clone = p.allocator.create(Ast.Expr) catch unreachable;
            left_clone.* = left.*;

            const binary: *Ast.Expr = .binaryExpr(p.allocator, op, left_clone, right);
            const assignment: *Ast.Expr = .assignmentExpr(p.allocator, left, binary);
            left = assignment;
        } else if (next_token.type == .question_mark) {
            _ = p.consume(.question_mark);
            const true_block = try p.parseExpr(0);
            _ = p.consume(.colon);
            const false_block = try p.parseExpr(p.precedence(next_token));
            left = .ternaryExpr(p.allocator, left, true_block, false_block);
        } else {
            const cur_token = p.consumeAny();
            const op = p.mapToBinaryOperator(cur_token);
            const right = try p.parseExpr(p.precedence(next_token) + 1);
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
            const literal = p.consume(.int_literal);
            const constant = std.fmt.parseInt(i32, literal.value, 10) catch {
                p.parseError(literal, "Failed to parse int literal: {s}\n", .{literal.value});
            };
            return .constantExpr(p.allocator, constant);
        },
        .minus, .not, .bitwise_not => {
            const token = p.consumeAny();
            const unary_op = p.mapToUnaryOperator(token);
            const inner_expr = try p.parseFactor();
            return .unaryExpr(p.allocator, unary_op, inner_expr);
        },
        .minus_minus, .plus_plus => { // prefix
            const op_token = p.consumeAny();
            const inner_expr = try p.parseFactor();
            return .prefixExpr(p.allocator, op_token, inner_expr, p.err_reporter);
            // const op_token = p.consumeAny();
            // const ident_expr = try p.parseFactor();
            // log.debug("ident_expr: {any}", .{ident_expr.*});
            // @todo
            // probably need to do this recursively
            // also this code is duplicated in parsePostfixIfNeeded
            // if (!(ident_expr.* == .@"var" or (ident_expr.* == .group and ident_expr.*.group.* == .@"var"))) {
            //     p.parseError(op_token, "Unable to parse expr. Invalid lvalue. \n", .{});
            // }
            // const op: Ast.Expr.BinaryOp = switch (op_token.*.type) {
            //     .minus_minus => .sub,
            //     .plus_plus => .add,
            //     else => p.parseError(op_token, "Invalid operator for prefix: {any}\n", .{op_token.type}),
            // };
            // const ident = if (ident_expr.* == .@"var") ident_expr.@"var" else ident_expr.*.group.@"var";
            // const var_expr: *Ast.Expr = .varExpr(p.allocator, ident);
            // // @note
            // // using copy of same variable, as we will modify the content in sema phase
            // // maybe on sema we need to create new expr instead of modifying inplace
            // const assignment_dst: *Ast.Expr = .varExpr(p.allocator, ident);
            // const one: *Ast.Expr = .constantExpr(p.allocator, 1);
            // const binary_expr: *Ast.Expr = .binaryExpr(p.allocator, op, var_expr, one);
            // return .assignmentExpr(p.allocator, assignment_dst, binary_expr);
        },
        .lparen => {
            _ = p.consume(.lparen);
            // group resets the precendence level to internal expr
            const inner_expr = try p.parseExpr(0);
            const group: *Ast.Expr = .groupExpr(p.allocator, inner_expr);
            _ = p.consume(.rparen);

            if (try p.parsePostfixIfNeeded(group)) |postfix| return postfix;

            return group;
        },
        .ident => {
            const ident = p.consume(.ident);
            const var_expr: *Ast.Expr = .varExpr(p.allocator, ident.value);
            if (try p.parsePostfixIfNeeded(var_expr)) |postfix| return postfix;
            return var_expr;
        },
        else => p.parseError(tok, "Expected factor, found {any}\n", .{tok.type}),
    };
}

fn mapToUnaryOperator(p: *const Parser, token: *const Lexer.Token) Ast.Expr.UnaryOp {
    return switch (token.type) {
        .bitwise_not => .bitwise_not,
        .minus => .negate,
        .not => .not,
        else => {
            p.parseError(token, "Mapping to unary operator failed for {any}\n", .{token.value});
        },
    };
}

fn mapToBinaryOperator(p: *const Parser, token: *const Lexer.Token) Ast.Expr.BinaryOp {
    return switch (token.type) {
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
            p.parseError(token, "Mapping to binary operator failed for {any}\n", .{token.value});
        },
    };
}

fn parsePostfixIfNeeded(p: *Parser, group_expr: *Ast.Expr) ParseError!?*Ast.Expr {
    const token = p.peek() orelse return null;
    if (token.type != .minus_minus and token.type != .plus_plus) return null;
    // if (!(group_expr.* == .@"var" or (group_expr.* == .group and group_expr.group.* == .@"var"))) {
    //     p.parseError(token, "invalid l value for postfix operator: {any}, {any}\n", .{ group_expr.*, group_expr });
    // }
    const postfix_op_token = p.consumeAnyOrErrorWithMsg("Failed to consume postfix operator for {s}", .{token.value});
    return try .postfixExpr(p.allocator, postfix_op_token.type, group_expr);
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
fn precedence(p: *const Parser, token: *const Lexer.Token) u8 {
    return switch (token.type) {
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
            p.parseError(token, "Invalid precedence for {any}\n", .{token.value});
        },
    };
}

fn consume(p: *Parser, token_type: Lexer.TokenType) *Lexer.Token {
    const token = p.peekOrError();
    if (token.type != token_type) {
        p.parseError(token, "Expected token type {any}, found {any}\n", .{ token_type, token.type });
    }
    p.current += 1;
    return token;
}

fn consumeAny(p: *Parser) *Lexer.Token {
    const token = p.peekOrError();
    p.current += 1;
    return token;
}

fn consumeAnyOrErrorWithMsg(p: *Parser, comptime fmt: []const u8, args: anytype) *Lexer.Token {
    const token = p.peekOrErrorWithMsg(fmt, args);
    p.current += 1;
    return token;
}

fn peek(p: *const Parser) ?*Lexer.Token {
    if (p.isAtEnd()) return null;
    return &p.tokens.items[p.current];
}

fn peekOrError(p: *const Parser) *Lexer.Token {
    if (p.current == 0) {
        return p.peekOrErrorWithMsg("Expected some token\n", .{});
    }
    return p.peekOrErrorWithMsg("Expected some token after {s}\n", .{p.tokens.items[p.current - 1].value});
}

fn peekOrErrorWithMsg(p: *const Parser, comptime fmt: []const u8, args: anytype) *Lexer.Token {
    const token = p.peek() orelse {
        const prev_tok = p.tokens.items[p.current - 1];
        p.parseError(&prev_tok, fmt, args);
    };
    return token;
}

fn peekOffset(p: *const Parser, offset: u8) ?*Lexer.Token {
    if (p.current + offset >= p.tokens.items.len) return null;
    return &p.tokens.items[p.current + offset];
}

fn isAtEnd(p: *const Parser) bool {
    return p.current >= p.tokens.items.len;
}

test {
    _ = @import("tests/parser_test_001_basic_return.zig");
    _ = @import("tests/parser_test_002_unary_operator.zig");
    _ = @import("tests/parser_test_003_binary_operator.zig");
}
