Parser :: struct {
    tokens: []Token;
    start: int = 0;
    current: int = 0;
}

Program_Ast_Node :: struct {
    fn: *Fn_Ast_Node;
}
Fn_Ast_Node :: struct {
    ident: string;
    body: *Stmt_Ast_Node;
}
Stmt_Ast_Node :: struct {
    type: enum { RETURN; };
    as: union {
        return_stmt: struct { expr: *Expr_Ast_Node; };
    };
}
Expr_Ast_Node :: struct {
    type: enum { CONSTANT; UNARY; GROUP; }
    as: union {
        constant: int;
        unary: struct { op: enum {BITWISE_NOT; NEGATE;}; expr: *Expr_Ast_Node; };
        group: *Expr_Ast_Node;
    };
}

ast_parse :: (lexer: *Lexer) -> *Program_Ast_Node {
    parser := Parser.{ tokens = lexer.tokens };
    program := parse_program_ast_node(*parser);
    print_program_ast(program);
    if !is_at_end(*parser) assert(false, "All token not consumed");
    return program;
}

parse_program_ast_node :: (parser: *Parser) -> *Program_Ast_Node {
    fn := parse_fn_ast_node(parser);
    program := New(Program_Ast_Node);
    program.* = .{fn};
    return program;
}

parse_fn_ast_node :: (parser: *Parser) -> *Fn_Ast_Node {
    consume(parser, .INT);
    ident_token := consume(parser, .IDENT);

    consume(parser, .LPAREN);
    if peek(parser).*.type == .VOID consume(parser, .VOID);
    consume(parser, .RPAREN);

    consume(parser, .LCURLY);
    stmt := Stmt.parse_stmt_ast_node(parser);
    consume(parser, .SEMICOLON);
    consume(parser, .RCURLY);

    fn := New(Fn_Ast_Node);
    fn.* = .{ident_token.value, stmt};
    return fn;
}

// ??? Maybe using it as name space to make things more clearer
Stmt :: struct {
    parse_stmt_ast_node :: (parser: *Parser) -> *Stmt_Ast_Node {
        if peek(parser).type == .RETURN {
            return Stmt.parse_return_stmt(parser);
        }
        assert(false, "This kind of statemnt is not know to me at the moment %", peek(parser).*);
        return null;
    }
    parse_return_stmt :: (parser: *Parser) -> *Stmt_Ast_Node {
        consume(parser, .RETURN);
        expr := Expr.parse_expr_ast_node(parser);
        stmt := New(Stmt_Ast_Node);
        stmt.* = .{type = .RETURN, as = .{return_stmt =  .{expr = expr}}};
        return stmt;
    }
}

Expr :: struct {
    parse_expr_ast_node :: (parser: *Parser) -> *Expr_Ast_Node {
        if peek(parser).*.type ==  {
            case .INT_LITERAL;
                int_literal := consume(parser, .INT_LITERAL);
                int_value, success := string_to_int(int_literal.value);
                if !success {
                    assert(false, "Expected int found %", int_literal.value);
                    exit(1);
                }
                expr := New(Expr_Ast_Node);
                expr.* = .{ type = .CONSTANT, as = .{ constant = int_value }};
                return expr;
            // Note: MINUS and BITWISE NOT are unary
            // and can be moved to parse_unary_expr maybe to make this code reusable
            case .MINUS;
                consume(parser, .MINUS);
                inner_expr := parse_expr_ast_node(parser);
                expr := New(Expr_Ast_Node);
                expr.* = .{ type = .UNARY, as = .{ unary = .{ op =  .NEGATE, expr = inner_expr} }};
                return expr;
            case .BITWISE_NOT;
                consume(parser, .BITWISE_NOT);
                inner_expr := parse_expr_ast_node(parser);
                expr := New(Expr_Ast_Node);
                expr.* = .{ type = .UNARY, as = .{ unary = .{ op =  .BITWISE_NOT, expr = inner_expr} }};
                return expr;
            case .LPAREN;
                consume(parser, .LPAREN);
                inner_expr := parse_expr_ast_node(parser);
                expr := New(Expr_Ast_Node);
                expr.* = .{ type = .GROUP , as = .{ group = inner_expr }};
                consume(parser, .RPAREN);
                return expr;
            case;
                assert(false, "This expression is not something I can handle. Duh!! %", peek(parser).*);
                exit(1);
                return null;

        }
    }
}

consume:: (parser: *Parser, token_type: Token_Type) -> Token {
    tok := peek(parser);
    if tok.type != token_type  {
        assert(false, "Expected % found %", token_type, tok.type);
        exit(1);
    }
    parser.current += 1;
    return tok;
}

peek :: (using parser: *Parser, offset: int = 0) -> *Token {
    if is_at_end(parser, offset) return null;
    return *tokens[current + offset];
}

is_at_end :: (using parser: *Parser, offset: int = 0) -> bool {
    return (current + offset) >= tokens.count;
}


print_program_ast :: (program: *Program_Ast_Node, depth: int = 0) {
    print("[PROGRAM] ");
    print_fn_ast(program.fn, depth + 1);
}

print_fn_ast :: (fn: *Fn_Ast_Node, depth: int = 0) {
    print_space(depth);
    print("[FN] %", fn.ident);
    print_space(depth+1);
    print_stmt_ast(fn.body, depth + 1);
}

print_stmt_ast :: (stmt: *Stmt_Ast_Node, depth: int = 0)  {
    if #complete stmt.type == {
        case .RETURN;
            print("[RETURN] ");
            print_space(depth+1);
            print_expr_ast(stmt.as.return_stmt.expr, depth+1);
    }
}

print_expr_ast :: (expr: *Expr_Ast_Node, depth: int = 0) {
    if #complete expr.type == {
        case .CONSTANT;
            print("%", expr.as.constant);
        case .UNARY;
            print("[UNARY] ");
            print("%", expr.as.unary.op);
            print_space(depth + 1);
            print_expr_ast(expr.as.unary.expr, depth + 1);
        case .GROUP;
            print("[GROUP] ");
            print_space(depth + 1);
            print_expr_ast(expr.as.group, depth + 1);
    }
}

print_space :: (depth: int = 0) {
    print("\n");
    for 0..depth-1 print("┊−");
}

#scope_file

#run run_test();
run_test :: () {
    #import "Compiler";
    options := get_build_options();
    args := options.compile_time_command_line;
    for arg: args {
        if arg == {
            case "test";  
            test_simple();
        }
    }
}

test_bitwise_not_and_minus :: () {
    src := #string done
        int main () {
            return ~(-2);
        }
    done
    lexer := Lexer.{src = src};
    l_success, msg := scan(*lexer);

    parser := Parser.{tokens = lexer.tokens};
    program := parse_program_ast_node(*parser);
}

test_simple :: () {
    src := #string done
        int main () {
            return 2;
        }
    done
    lexer := Lexer.{src = src};
    l_success, msg := scan(*lexer);

    parser := Parser.{tokens = lexer.tokens};
    program := parse_program_ast_node(*parser);
}

#scope_export

/* -- ADSL AST -- 

program              = Program(function_definition)
function_definition  = Function(identifier name, statement body)
statement            = Return(exp)
exp                  = Constant(int) | Unary(unary_operator, exp)
unary_operator       = Complement | Negate

*/

/* E-BNF

<program>         ::= <function>
<function>        ::= "int" <identifier> "(" "void" ")" "{" <statement> "}"
<statement>       ::= "return" <exp> ";"
<exp>             ::= <int> | <unop> <exp> | "(" <exp> ")"
<unop>            ::= "-" | "~"
<identifier>      ::= ? An identifier token ?
<int>             ::= ? A constant token ?

*/
