const std = @import("std");
const Allocator = std.mem.Allocator;

src: []const u8,
line_start: usize = 0,
line: usize,
start: usize,
current: usize,

const Self = @This();

pub fn init(src: []const u8) Self {
    return .{ .src = src, .start = 0, .current = 0, .line = 1 };
}

pub fn scanTokens(s: *Self, allocator: Allocator) !std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(allocator);
    while (!s.isAtEnd()) {
        s.start = s.current;
        const current_char = s.consume();
        if (isWhitespace(current_char)) {
            if (current_char == '\n') {
                s.line += 1;
                s.line_start = s.current;
            }
            continue;
        }
        const token = t: {
            if (isAlpha(current_char)) {
                break :t s.identifier_or_keyword();
            }
            if (isDigit(current_char)) {
                break :t s.number();
            }
            switch (current_char) {
                '(' => break :t s.makeToken(.Lparen),
                ')' => break :t s.makeToken(.Rparen),
                '{' => break :t s.makeToken(.Lcurly),
                '}' => break :t s.makeToken(.Rcurly),
                ';' => break :t s.makeToken(.Semicolon),
                '~' => break :t s.makeToken(.BitwiseNot),
                '-' => {
                    if (peek(s) == '-') s.logLexError();
                    break :t s.makeToken(.Minus);
                },
                else => {
                    s.logLexError();
                    unreachable;
                },
            }
        };
        try tokens.append(token);
    }
    return tokens;
}

fn logLexError(s: *Self) void {
    // ANSI color codes:
    // Teal: \x1B[36m, Blue: \x1B[34m, Red: \x1B[31m, Reset: \x1B[0m
    std.log.err("\x1B[36mUnrecognized token on line:\x1B[0m \x1B[36m{d}\x1B[0m", .{s.line});
    std.log.err("\x1B[34mLine: {s}\x1B[0m", .{s.getLine()});
    std.log.err("\x1B[31mLexeme: {s}\x1B[0m", .{s.curLexeme()});
    std.process.exit(1);
}

fn getLine(s: *Self) []const u8 {
    const end_of_line = std.mem.indexOf(u8, s.src[s.current..], "\n") orelse s.src.len;
    return s.src[s.line_start .. s.current + end_of_line];
}

fn makeToken(s: *Self, token: TokenType) Token {
    return .{ .token = token, .value = s.curLexeme(), .line = s.line };
}
fn curLexeme(s: *Self) []const u8 {
    return s.src[s.start..s.current];
}

fn number(s: *Self) Token {
    while (!s.isAtEnd() and isAlphaNum(s.peek())) {
        const c = s.consume();
        if (isAlpha(c) or c == '_') {
            std.log.err("Expected digit found: {any}", .{c});
            std.process.exit(1);
        }
    }
    return .{ .token = .IntLiteral, .value = s.src[s.start..s.current], .line = s.line };
}

fn identifier_or_keyword(s: *Self) Token {
    while (!s.isAtEnd() and isAlphaNum(s.peek())) {
        _ = s.consume();
    }
    const token_str = s.src[s.start..s.current];
    if (isKeyword(token_str)) |ident| {
        return .{ .token = ident, .value = token_str, .line = s.line };
    }
    return .{ .token = .Ident, .value = token_str, .line = s.line };
}

fn isKeyword(str: []const u8) ?TokenType {
    if (std.mem.eql(u8, "int", str)) return .Int;
    if (std.mem.eql(u8, "void", str)) return .Void;
    if (std.mem.eql(u8, "return", str)) return .Return;
    return null;
}

fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n';
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

fn isDigit(c: u8) bool {
    return (c >= '0' and c <= '9');
}
fn isAlphaNum(c: u8) bool {
    return isAlpha(c) or isDigit(c) or c == '_';
}

fn isAtEnd(s: *Self) bool {
    return s.current >= s.src.len;
}
fn consume(s: *Self) u8 {
    defer s.current += 1;
    return s.peek();
}
fn peek(s: *Self) u8 {
    return s.src[s.current];
}

fn peekOffset(s: *Self, offset: isize) u8 {
    const pos = @as(isize, @intCast(s.current)) + offset;
    return s.src[@as(usize, @intCast(pos))];
}

pub fn printTokens(tokens: *const std.ArrayList(Token)) void {
    for (tokens.items) |t| {
        std.debug.print("{any}, {s}\n", .{ t.token, t.value });
    }
}

pub const Token = struct {
    token: TokenType,
    line: usize,
    value: []const u8,
};

pub const TokenType = enum {
    Lparen,
    Rparen,
    Lcurly,
    Rcurly,
    Semicolon,

    // Keyword
    Int,
    Void,
    Return,

    // Literals
    Ident,
    IntLiteral,

    // Operators
    BitwiseNot,
    Minus,
};

test "basic return" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const src =
        \\int main(void) {
        \\  return 0;
        \\}
    ;
    var lexer = init(src);
    var tokens = try lexer.scanTokens(allocator);
    defer tokens.deinit();
    try testing.expectEqual(tokens.items.len, 10);
}

test "bitwise not and negate" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const src =
        \\int main(void) {
        \\  return ~(-9);
        \\}
    ;
    var lexer = init(src);
    var tokens = try lexer.scanTokens(allocator);
    defer tokens.deinit();
    try testing.expectEqual(tokens.items.len, 14);
}
