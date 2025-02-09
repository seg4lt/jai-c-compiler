const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !void {}

const Lexer = struct {
    src: []const u8,

    line: usize,
    start: usize,
    current: usize,

    tokens: std.ArrayList(Token),
    gpa: std.mem.Allocator,

    const Self = @This();

    pub fn init(gpa: Allocator, src: []const u8) Self {
        return .{
            .line = 1,
            .tokens = std.ArrayList(Token).init(gpa),
            .gpa = gpa,
            .src = src,
            .start = 0,
            .current = 0,
        };
    }
    pub fn deinit(s: *Self) void {
        s.tokens.deinit();
    }

    pub fn scan(s: *Self) void {
        var counter: usize = 0;
        while (!s.isAtEnd()) {
            counter += 1;
            if (counter > 100000) {
                @panic("Force close scanner...");
            }

            if (isWhitespace(s.peek())) {
                if (s.peek() == '\n') {
                    s.line += 1;
                }
                s.consume();
                break;
            }

            if (isAlpha(s.peek())) {
                s.identifier_or_keyword();
            }
        }
    }

    pub fn identifier_or_keyword(s: *Self) void {
        while (!s.isAtEnd() and isAlphaNum(s.peek())) {
            s.consume();
        }
        const current = s.src[s.start..s.current];
        const token_type = ident_type(current);
        const token = makeToken();
        s.tokens.append(token);
    }

    fn ident_type(c: []const u8) TokenType {}

    fn makeToken(s: *Self, token_type: TokenType) Token {
        return .{
            .token_type = token_type,
            .line = s.line,
            .value = s.src[s.start..s.current],
        };
    }

    pub fn consume(s: *Self) void {
        s.current += 1;
        s.column += 1;
    }

    pub fn isWhitespace(c: u8) bool {
        return c == ' ' or c == '\t' or c == '\n' or c == '\r';
    }
    pub fn isAlpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
    }

    pub fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    pub fn isAlphaNum(c: u8) bool {
        return isAlpha(c) or isDigit(c) or c == '_';
    }

    pub fn peek(s: *Self) u8 {
        return s.src[s.current];
    }

    pub fn isAtEnd(s: *Self) bool {
        return s.current < s.src.len;
    }
};

const Token = struct {
    token_type: TokenType,
    line: usize,
    column: usize,
    value: []const u8,
};

const TokenType = enum {
    LParen,
    RParen,
    LCurly,
    RCurly,
    SemiColon,

    Ident,
    IntValue,

    // Keyword
    Int,
    Return,
    Void,
};

test "Lexer" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const src =
        \\ int main () {
        \\    return 2;
        \\ }
    ;

    var lexer = Lexer.init(allocator, src);
    defer lexer.deinit();
    _ = lexer.scan();
}
