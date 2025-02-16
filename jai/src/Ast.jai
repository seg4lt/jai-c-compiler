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
    type: enum { CONSTANT; UNARY; BINARY; GROUP; }
    as: union {
        constant: int;
        unary: struct { op: enum {BITWISE_NOT; NEGATE;}; expr: *Expr_Ast_Node; };
        binary: struct { op: enum {ADD;SUB;MUL;DIV;MOD;}; left: *Expr_Ast_Node; right: *Expr_Ast_Node;};
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
            return parse_return_stmt(parser);
        }
        assert(false, "This kind of statemnt is not know to me at the moment %", peek(parser).*);
        return null;
    }
    parse_return_stmt :: (parser: *Parser) -> *Stmt_Ast_Node {
        consume(parser, .RETURN);
        expr := Expr.parse_expr(parser, 0);
        stmt := New(Stmt_Ast_Node);
        stmt.* = .{type = .RETURN, as = .{return_stmt =  .{expr = expr}}};
        return stmt;
    }
}

is_binary_operator :: (tt: Token_Type) -> bool {
    if tt == {
        case .MINUS; #through;
        case .PLUS; #through;
        case .DIVIDE; #through;
        case .MULTIPLY; #through;
        case .MOD; return true;
        case; return false;
    }
}

precedence :: (tt: Token_Type) -> int {
    if tt == {
        case .MINUS; #through;
        case .PLUS; 45;
        case .DIVIDE; #through;
        case .MULTIPLY; #through;
        case .MOD; return 50;
        case; assert(false, "precendence calc for any other token is currently not supported: %", tt);
    }
    return 0; // unreachable
}

Expr :: struct {
     parse_expr :: (parser: *Parser, min_prec: int)  -> *Expr_Ast_Node {
        left := parse_factor(parser);
        next_token := peek(parser);
      
        while is_binary_operator(next_token.type) && precedence(next_token.type) >= min_prec {
            op := parse_binary_op(consume(parser).type);
            right := parse_expr(parser, precedence(next_token.type) + 1);
            binary := New(Expr_Ast_Node);
            binary.* = .{.BINARY, .{binary=.{op,left,right}}};
            left = binary;
            next_token = peek(parser);
        }
        return left;
    }

    parse_factor :: (parser: *Parser) -> *Expr_Ast_Node {
        if peek(parser).*.type ==  {
            case .INT_LITERAL;
                int_literal := consume(parser, .INT_LITERAL);
                int_value, success := string_to_int(int_literal.value);
                if !success {
                    assert(false, "Expected int found %", int_literal.value);
                    return null; // unreachable
                }
                expr := New(Expr_Ast_Node);
                expr.* = .{ type = .CONSTANT, as = .{ constant = int_value }};
                return expr;
            case .MINUS; #through;
            case .BITWISE_NOT;
                op := parse_unary_op(consume(parser).type);
                inner_expr := parse_factor(parser);
                expr := New(Expr_Ast_Node);
                expr.* = .{.UNARY,.{unary=.{op,inner_expr}}};
                return expr;
            case .LPAREN;
                consume(parser, .LPAREN);
                inner_expr := parse_expr(parser, 0); // grp resets precedence level for its internal expr
                expr := New(Expr_Ast_Node);
                expr.* = .{ type = .GROUP , as = .{ group = inner_expr }};
                consume(parser, .RPAREN);
                return expr;
            case;
                assert(false, "This expression is not something I can handle. Duh!! %", peek(parser).*);
                return null; // unreachable

        }
    }
}

parse_unary_op :: (tt: Token_Type) -> type_of(Expr_Ast_Node.as.unary.op) {
    if tt == {
        case .BITWISE_NOT; return .BITWISE_NOT;
        case .MINUS; return .NEGATE;
        case; assert(false, "Wanted unary operator found %", tt);
    }
    // unreachable 
    return .NEGATE;
}

parse_binary_op :: (tt: Token_Type) -> type_of(Expr_Ast_Node.as.binary.op) {
    if tt == {
        case .PLUS; return .ADD;
        case .MINUS; return .SUB;
        case .MULTIPLY; return .MUL;
        case .DIVIDE; return .DIV;
        case .MOD; return .MOD;
        case; assert(false, "Wanted binary operator found %", tt);
    }
    // unreachable 
    return .ADD;
}

consume :: (using parser: *Parser) -> Token {
    defer current += 1;
    return peek(parser);
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
    print("\n\n -- AST -- \n");
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
        case .BINARY;
            print("[BINARY] ");
            print("%", expr.as.binary.op);
            print_space(depth + 1);
            print_expr_ast(expr.as.binary.left, depth + 1);
            print_space(depth + 1);
            print_expr_ast(expr.as.binary.right, depth + 1);
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

/* -- ADSL AST -- 

program              = Program(function_definition)
function_definition  = Function(identifier name, statement body)
statement            = Return(exp)
exp                  = Constant(int) 
                     | Unary(unary_operator, exp)
                     | Binary(binary_operator, exp, exp)
unary_operator       = Complement | Negate
binary_operator      = Add | Subtract | Multiply | Divide | Remainder

*/

/* E-BNF

<program>         ::= <function>
<function>        ::= "int" <identifier> "(" "void" ")" "{" <statement> "}"
<statement>       ::= "return" <exp> ";"
<exp>             ::= <factor> | <exp> <binop> <exp>
<factor>          ::= <int> | <unop> <factor> | "(" <exp> ")"
<unop>            ::= "-" | "~"
<binop>           ::= "-" | "+" | "*" | "/" | "%"
<identifier>      ::= ? An identifier token ?
<int>             ::= ? A constant token ?

*/
