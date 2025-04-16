const std = @import("std");
const log = std.log;
const Allocator = std.mem.Allocator;
pub const TokenArray = std.ArrayList(Token);

const Self = @This();

src: []const u8,
tokens: TokenArray,
allocator: Allocator,
line: u16 = 1,
start: usize = 0, // current token start position
current: usize = 0, // where is cursor right now

pub fn initFromSrcPath(allocator: Allocator, src_path: []const u8) !Self {
    const file = std.fmt.allocPrint(allocator, "{s}.i", .{src_path[0 .. src_path.len - 2]}) catch unreachable;
    defer allocator.free(file);
    const src = try std.fs.cwd().readFileAlloc(allocator, file, 4096);
    return initFromSrc(allocator, src);
}

pub fn initFromSrc(allocator: Allocator, src: []const u8) !Self {
    var lexer = Self{ .src = src, .tokens = TokenArray.init(allocator), .allocator = allocator };
    try lexer.scan();
    printTokens(lexer.tokens);
    return lexer;
}

fn printTokens(tokens: TokenArray) void {
    log.info("\n -- Lexer -- \n", .{});
    for (tokens.items) |it| log.debug("{s:<20} | {s:<12} | {d}", .{ @tagName(it.type), it.value, it.line });
    log.info("\n", .{});
}

fn consumeAnyAndAddToken(s: *Self, token_type: TokenType) !void {
    _ = s.consumeAny();
    try s.addToken(token_type);
}

fn addToken(s: *Self, token_type: TokenType) !void {
    try s.tokens.append(.{ .type = token_type, .value = s.src[s.start..s.current], .line = s.line });
}

const LexerError = error{
    InvalidCharacter,
    InvalidNumber,
    ErrorParsingComment,
};

fn scan(s: *Self) !void {
    while (!s.isAtEnd()) {
        s.start = s.current;
        const current_char = s.consumeAny();

        if (std.ascii.isWhitespace(current_char)) {
            continue;
        }
        if (std.ascii.isAlphabetic(current_char) or current_char == '_') {
            try s.identOrKeyword();
            continue;
        }
        if (std.ascii.isDigit(current_char)) {
            try s.number();
            continue;
        }

        try switch (current_char) {
            '(' => s.addToken(.lparen),
            ')' => s.addToken(.rparen),
            '{' => s.addToken(.lcurly),
            '}' => s.addToken(.rcurly),
            ';' => s.addToken(.semicolon),
            '~' => s.addToken(.bitwise_not),
            '+' => switch (s.peek()) {
                '=' => s.consumeAnyAndAddToken(.plus_equal),
                '+' => s.consumeAnyAndAddToken(.plus_plus),
                else => s.addToken(.plus),
            },
            '*' => switch (s.peek()) {
                '=' => s.consumeAnyAndAddToken(.multiply_equal),
                else => s.addToken(.multiply),
            },
            '%' => switch (s.peek()) {
                '=' => s.consumeAnyAndAddToken(.mod_equal),
                else => s.addToken(.mod),
            },
            '&' => switch (s.peek()) {
                '&' => s.consumeAnyAndAddToken(.@"and"),
                '=' => s.consumeAnyAndAddToken(.bitwise_and_equal),
                else => s.addToken(.bitwise_and),
            },
            '|' => switch (s.peek()) {
                '|' => s.consumeAnyAndAddToken(.@"or"),
                '=' => s.consumeAnyAndAddToken(.bitwise_or_equal),
                else => s.addToken(.bitwise_or),
            },
            '^' => switch (s.peek()) {
                '=' => s.consumeAnyAndAddToken(.bitwise_xor_equal),
                else => s.addToken(.bitwise_xor),
            },
            '>' => switch (s.peek()) {
                '>' => {
                    _ = s.consumeAny();
                    switch (s.peekWithOffset(1)) {
                        '=' => try s.consumeAnyAndAddToken(.right_shift_equal),
                        else => try s.addToken(.right_shift),
                    }
                },
                '=' => s.consumeAnyAndAddToken(.greater_equal),
                else => s.addToken(.greater),
            },
            '<' => switch (s.peek()) {
                '<' => {
                    _ = s.consumeAny();
                    try switch (s.peekWithOffset(1)) {
                        '=' => s.consumeAnyAndAddToken(.left_shift_equal),
                        else => s.addToken(.left_shift),
                    };
                },
                '=' => s.consumeAnyAndAddToken(.less_equal),
                else => s.addToken(.less),
            },
            '/' => switch (s.peek()) {
                '/' => s.comment(),
                '*' => s.comment(),
                '=' => s.consumeAnyAndAddToken(.divide_equal),
                else => s.addToken(.divide),
            },
            '-' => switch (s.peek()) {
                '=' => s.consumeAnyAndAddToken(.minus_equal),
                '-' => s.consumeAnyAndAddToken(.minus_minus),
                else => s.addToken(.minus),
            },
            '=' => switch (s.peek()) {
                '=' => s.consumeAnyAndAddToken(.equal_equal),
                else => s.addToken(.assign),
            },
            '!' => switch (s.peek()) {
                '=' => s.consumeAnyAndAddToken(.not_equal),
                else => s.addToken(.not),
            },
            '?' => s.addToken(.question_mark),
            ':' => s.addToken(.colon),
            else => {
                log.err("Unexpected character: {c}\n", .{current_char});
                return LexerError.InvalidCharacter;
            },
        };
    }
}

fn comment(s: *Self) LexerError!void {
    switch (s.peek()) {
        '/' => {
            while (!s.isAtEnd() and s.peek() != '\n') {
                _ = s.consumeAny();
            }
            s.line += 1;
        },
        '*' => {
            _ = s.consumeAny();
            while (!s.isAtEnd()) {
                const c = s.consumeAny();
                if (c == '\n') {
                    s.line += 1;
                }
                if (c == '*' and s.peek() == '/') break;
            }
            _ = try s.consume('/'); // consume closing /
        },
        else => return LexerError.ErrorParsingComment,
    }
}

fn number(s: *Self) !void {
    var found_alpha = false;
    while (!s.isAtEnd() and (std.ascii.isDigit(s.peek()) or std.ascii.isAlphabetic(s.peek()))) {
        if (std.ascii.isAlphabetic(s.peek())) found_alpha = true;
        _ = s.consumeAny();
    }
    const value = s.src[s.start..s.current];
    if (found_alpha) {
        log.err("Invalid number: {s}\n", .{value});
        return LexerError.InvalidNumber;
    }
    try s.addToken(.int_literal);
}

fn identOrKeyword(s: *Self) !void {
    while (!s.isAtEnd() and std.ascii.isAlphanumeric(s.peek())) _ = s.consumeAny();
    const lexeme = s.src[s.start..s.current];
    const token_type = isKeywordOrIdent(lexeme);
    try s.addToken(token_type);
}

fn eatWhitespace(s: *Self) void {
    while (std.ascii.isWhitespace(s.peek())) {
        const token = s.consumeAny();
        if (token == '\n') s.line += 1;
    }
}

fn isKeywordOrIdent(lexeme: []const u8) TokenType {
    if (std.mem.eql(u8, "int", lexeme)) return .int;
    if (std.mem.eql(u8, "void", lexeme)) return .void;
    if (std.mem.eql(u8, "return", lexeme)) return .@"return";
    if (std.mem.eql(u8, "if", lexeme)) return .@"if";
    if (std.mem.eql(u8, "else", lexeme)) return .@"else";
    if (std.mem.eql(u8, "goto", lexeme)) return .goto;
    if (std.mem.eql(u8, "for", lexeme)) return .@"for";
    if (std.mem.eql(u8, "do", lexeme)) return .do;
    if (std.mem.eql(u8, "while", lexeme)) return .@"while";
    if (std.mem.eql(u8, "break", lexeme)) return .@"break";
    if (std.mem.eql(u8, "continue", lexeme)) return .@"continue";
    if (std.mem.eql(u8, "switch", lexeme)) return .@"switch";
    if (std.mem.eql(u8, "case", lexeme)) return .case;
    if (std.mem.eql(u8, "default", lexeme)) return .default;
    return .ident;
}

fn consume(s: *Self, char: u8) !u8 {
    defer s.current += 1;
    const c = s.peek();
    if (c != char) {
        log.err("Unexpected character: {c}\n", .{c});
        return LexerError.InvalidCharacter;
    }
    if (c == '\n') s.line += 1;
    return c;
}

fn consumeAny(s: *Self) u8 {
    defer s.current += 1;
    const c = s.peek();
    if (c == '\n') s.line += 1;
    return c;
}

fn peek(s: *Self) u8 {
    return s.peekWithOffset(0);
}

fn peekWithOffset(s: *Self, offset: usize) u8 {
    if (s.current + offset >= s.src.len) return 0;
    return s.src[s.current + offset];
}

fn isAtEnd(s: *Self) bool {
    return s.current >= s.src.len;
}

pub const TokenType = enum {
    lparen,
    rparen,
    lcurly,
    rcurly,
    semicolon,

    ident,
    int_literal,
    // keyword
    int,
    void,
    @"return",
    // operator
    bitwise_not,
    bitwise_and,
    bitwise_or,
    bitwise_xor,
    left_shift,
    right_shift,
    minus,
    plus,
    divide,
    multiply,
    mod,
    not,
    @"and",
    @"or",
    equal_equal,
    not_equal,
    less,
    less_equal,
    greater,
    greater_equal,
    assign,

    plus_equal,
    minus_equal,
    multiply_equal,
    divide_equal,
    mod_equal,
    left_shift_equal,
    right_shift_equal,
    bitwise_and_equal,
    bitwise_or_equal,
    bitwise_xor_equal,

    minus_minus,
    plus_plus,

    @"if",
    @"else",
    question_mark,
    colon,

    goto,

    @"for",
    do,
    @"while",
    @"continue",
    @"break",

    @"switch",
    case,
    default,
    eof,
};

pub const Token = struct {
    type: TokenType,
    value: []const u8,
    line: u16,
};
