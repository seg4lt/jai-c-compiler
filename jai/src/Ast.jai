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
    body: [..]Block_Item_Ast_Node;
}
Block_Item_Ast_Node :: struct {
    type: enum { STMT; DECL; };
    as: union {
        stmt: *Stmt_Ast_Node;
        decl: *Decl_Ast_Node;
    };
}

Decl_Ast_Node :: struct {
    ident: string;
    init: *Expr_Ast_Node; // optional
}

Stmt_Ast_Node :: struct {
    type: enum { RETURN; EXPR; NULL;};
    as: union {
        return_stmt: struct { expr: *Expr_Ast_Node; };
        expr: *Expr_Ast_Node;
        // null : doesn't need value
    };
}
Expr_Ast_Node :: struct {
    type: enum { CONSTANT; UNARY; BINARY; GROUP; VAR; ASSIGNMENT; }
    as: union {
        constant: int;
        unary: struct { op: enum {BITWISE_NOT; NEGATE; NOT;}; expr: *Expr_Ast_Node; };
        binary: struct { op: Bin_Op_Ast; left: *Expr_Ast_Node; right: *Expr_Ast_Node;};
        group: *Expr_Ast_Node;
        var: string;
        assignment: struct { dst: *Expr_Ast_Node; src: *Expr_Ast_Node;};
    };
}
Bin_Op_Ast :: enum {
    ADD;
    SUB;
    MUL;
    DIV;
    MOD;
    BITWISE_AND;
    BITWISE_OR;
    BITWISE_XOR;
    LEFT_SHIFT;
    RIGHT_SHIFT;
    AND;
    OR;
    NOT_EQUAL;
    EQUAL_EQUAL;
    GREATER;
    GREATER_EQUAL;
    LESS;
    LESS_EQUAL;
};

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

    body: [..]Block_Item_Ast_Node;

    while peek(parser).type != .RCURLY {
        b_item := Block_Item.parse_block_item(parser);
        array_add(*body, b_item);
    }
    consume(parser, .RCURLY);
    fn := New(Fn_Ast_Node);
    fn.* = .{ident_token.value, body};
    return fn;
}

Block_Item :: struct {

parse_block_item :: (parser: *Parser) -> *Block_Item_Ast_Node {
    cp := peek(parser);
    cp_type := cp.type;
    if peek(parser).type == .INT {
        decl := Decl.parse_decl_ast_node(parser);
        bi := New(Block_Item_Ast_Node);
        bi.* = .{.DECL, .{decl = decl}};
        return bi;
    }
    if peek(parser).type == .SEMICOLON {
        consume(parser);
        bi := New(Block_Item_Ast_Node);
        null_stmt := New(Stmt_Ast_Node);
        null_stmt.* = .{.NULL, .{}};
        bi.* = .{.STMT, .{stmt = null_stmt}};
        return bi;
    }
    return_stmt := Stmt.parse_stmt_ast_node(parser);
    block := New(Block_Item_Ast_Node);
    block.* = .{.STMT, .{stmt = return_stmt}};
    return block;
}

}

Decl :: struct {
parse_decl_ast_node :: (parser: *Parser) -> *Decl_Ast_Node {
    if peek(parser).type == .INT {
        consume(parser, .INT);
        ident := consume(parser).value;
        if String.is_digit(ident.data.*) assert(false, "identifier should not start with digit");

        expr := ifx peek(parser).type == .ASSIGN {
            consume(parser);
            expr := Expr.parse_expr(parser, 0);
            expr;
        } else null;
        consume(parser, .SEMICOLON);
        decl :=  New(Decl_Ast_Node);
        decl.* = .{ident, expr};
        return decl;
    }
    assert(false, "not implemented");
    return null;
}
}

// ??? Maybe using it as name space to make things more clearer
Stmt :: struct {



parse_stmt_ast_node :: (parser: *Parser) -> *Stmt_Ast_Node {
    if peek(parser).type == .RETURN {
        return parse_return_stmt(parser);
    }
    if peek(parser).type == .SEMICOLON {
        stmt := New(Stmt_Ast_Node);
        stmt.* = .{.NULL, .{}};
        return stmt;
    }
    expr := Expr.parse_expr(parser, 0);
    consume(parser, .SEMICOLON);
    stmt := New(Stmt_Ast_Node);
    stmt.* = .{.EXPR, .{expr = expr}};
    return stmt;
}

parse_return_stmt :: (parser: *Parser) -> *Stmt_Ast_Node {
    consume(parser, .RETURN);
    expr := Expr.parse_expr(parser, 0);
    consume(parser, .SEMICOLON);
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
        case .MOD; #through;
        case .LEFT_SHIFT; #through;
        case .RIGHT_SHIFT; #through; 
        case .BITWISE_AND; #through;
        case .BITWISE_XOR; #through;
        case .BITWISE_OR; #through;
        case .AND; #through;
        case .OR; #through;
        case .NOT_EQUAL; #through;
        case .EQUAL_EQUAL; #through;
        case .GREATER; #through;
        case .GREATER_EQUAL; #through;
        case .LESS; #through;
        case .LESS_EQUAL; #through;
        case .ASSIGN;
        return true;

        case; return false;
    }
}

precedence :: (tt: Token_Type) -> int {
    // https://en.cppreference.com/w/c/language/operator_precedence
    if tt == {
        case .BITWISE_NOT; #through;
        case .NOT; return 70;

        case .DIVIDE; #through;
        case .MULTIPLY; #through;
        case .MOD; return 50;

        case .MINUS; #through;
        case .PLUS; return 45;

        case .LEFT_SHIFT; #through;
        case .RIGHT_SHIFT; return 40; 

        case .LESS; #through;
        case .LESS_EQUAL; #through;
        case .GREATER; #through;
        case .GREATER_EQUAL; return 35;

        case .EQUAL_EQUAL; #through;
        case .NOT_EQUAL; return 30;

        case .BITWISE_AND; return 25;
        case .BITWISE_XOR; return 24;
        case .BITWISE_OR; return 23;

        case .AND; return 10;
        case .OR; return 5;
        case .ASSIGN; return 1;
    }
    assert(false, "precendence calc for any other token is currently not supported: %", tt);
    return 0; // unreachable
}

Expr :: struct {
     parse_expr :: (parser: *Parser, min_prec: int)  -> *Expr_Ast_Node {
        left := parse_factor(parser);
        next_token := peek(parser);
      
        while is_binary_operator(next_token.type) && precedence(next_token.type) >= min_prec {
            if next_token.type == .ASSIGN {
                consume(parser);
                right := parse_expr(parser, precedence(next_token.type));
                assignment := New(Expr_Ast_Node);
                assignment.* = .{.ASSIGNMENT, .{assignment =.{left, right}}};
                left = assignment;
            } else {
                op := parse_binary_op(consume(parser).type);
                right := parse_expr(parser, precedence(next_token.type) + 1);
                binary := New(Expr_Ast_Node);
                binary.* = .{.BINARY, .{binary=.{op,left,right}}};
                left = binary;
            }
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
            case .NOT; #through;
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
            case .IDENT;
                token := consume(parser);
                expr := New(Expr_Ast_Node);
                expr.* = .{ type = .VAR , as = .{ var = token.value }};
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
        case .NOT; return .NOT;
        case; assert(false, "Wanted unary operator found %", tt);
    }
    assert(false, "Wanted unary operator found %", tt);
    return .NEGATE; // unreachable 
}

parse_binary_op :: (tt: Token_Type) -> type_of(Expr_Ast_Node.as.binary.op) {
    if tt == {
        case .PLUS; return .ADD;
        case .MINUS; return .SUB;
        case .MULTIPLY; return .MUL;
        case .DIVIDE; return .DIV;
        case .MOD; return .MOD;

        case .LEFT_SHIFT; return .LEFT_SHIFT;
        case .RIGHT_SHIFT; return .RIGHT_SHIFT;
        case .BITWISE_AND; return .BITWISE_AND;
        case .BITWISE_OR; return .BITWISE_OR;
        case .BITWISE_XOR; return .BITWISE_XOR;

        case .NOT_EQUAL; return .NOT_EQUAL;
        case .EQUAL_EQUAL; return .EQUAL_EQUAL;
        case .GREATER; return .GREATER;
        case .GREATER_EQUAL; return .GREATER_EQUAL;
        case .LESS; return .LESS;
        case .LESS_EQUAL; return .LESS_EQUAL;
        case .AND; return .AND;
        case .OR; return .OR;
    }
    // unreachable 
    assert(false, "Wanted binary operator found %", tt);
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
    print("\n\n");
}

print_fn_ast :: (fn: *Fn_Ast_Node, depth: int = 0) {
    print_space(depth);
    print("[FN] %", fn.ident);

    for fn.body {
        print_space(depth+1);
        if #complete it.type == {
            case .STMT; print_stmt_ast(it.as.stmt, depth + 1);
            case .DECL; print_decl_ast(it.as.decl, depth + 1);
        }
    }
}

print_decl_ast :: (using decl: *Decl_Ast_Node, depth: int = 0)  {
    print("[DECL] ");
    print("%", ident);
    if init != null {
        print(" = ");
        print_expr_ast(init, depth + 1);
    }
}

print_stmt_ast :: (stmt: *Stmt_Ast_Node, depth: int = 0)  {
    if #complete stmt.type == {
        case .RETURN;
            print("[RETURN] ");
            print_space(depth+1);
            print_expr_ast(stmt.as.return_stmt.expr, depth+1);
        case .EXPR;
            print("[EXPR] ");
            print_space(depth + 1);
            print_expr_ast(stmt.as.return_stmt.expr, depth+1);
        case .NULL; 
            print("[NULL_STMT]");
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
        case .VAR;
            print("[VAR] % ", expr.as.var);
        case .ASSIGNMENT;
            print("[ASSIGNMENT] ");
            print_expr_ast(expr.as.assignment.dst, depth);
            print(" = ");
            print_expr_ast(expr.as.assignment.src, depth);
    }
}

print_space :: (depth: int = 0) {
    print("\n");
    for 0..depth-1 print("┊−");
}

/* -- ADSL AST -- 

program              = Program(function_definition)
function_definition  = Function(identifier name, block_item* body)
block_item           = S(stmt) | D(decleration)
declaration          = Declaration(identifier name, exp? init)
statement            = Return(exp)
                     | Expression(exp)
                     | Null                 # like ";" on while and for which signifies empty body
exp                  = Constant(int) 
                     | Var(identifier)
                     | Unary(unary_operator, exp)
                     | Binary(binary_operator, exp, exp)
                     | Assignment(exp, exp)
unary_operator       = Complement | Negate | Not
binary_operator      = Add | Subtract | Multiply | Divide | Remainder
                     | And | Or
                     | Less | LessOrEqual
                     | Greater | GreaterOrEqual
                     | Not | NotEqual

*/

/* E-BNF production rule

<program>         ::= <function>
<function>        ::= "int" <identifier> "(" "void" ")" "{" <block-item> "}"
<block-item>      ::= <statement> | <decleration>
<decleration>     ::= "int" <identifier> [ "=" <exp> ] ";"
<statement>       ::= "return" <exp> ";" | <exp> ";" | ";"
<exp>             ::= <factor> | <exp> <binop> <exp>
<factor>          ::= <int> | <identifier> | <unop> <factor> | "(" <exp> ")"
<unop>            ::= "-" | "~" | "!"
<binop>           ::= "-" | "+" | "*" | "/" | "%" 
                    | "&&" | "||" | "==" | "!="
                    | ">" | ">=" | "<" | "<=" 
<identifier>      ::= ? An identifier token ?
<int>             ::= ? A constant token ?
*/
