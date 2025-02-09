const std = @import("std");
const CliArgs = @import("CliArgs.zig");
const Lexer = @import("Lexer.zig");
const Ast = @import("Ast.zig");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpaa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpaa.deinit();
    const gpa = gpaa.allocator();
    // const arena_ = std.heap.ArenaAllocator.init(gpa);
    // defer _ = arena_.deinit();
    // const arena = arena_.allocator();
    const src =
        \\int main(void) {
        \\  return 2;
        \\}
    ;
    var lexer = Lexer.init(src);
    const tokens = try lexer.scanTokens(gpa);
    defer tokens.deinit();
    Lexer.printTokens(&tokens);

    var ast = Ast.init(gpa, &tokens);
    defer ast.deinit();

    const program =  ast.parse_program();
    _ = program;
}
