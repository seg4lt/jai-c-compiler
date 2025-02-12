Parser :: struct {
    tokens: []Token;
    start: int = 0;
    current: int = 0;
}

Ast_Node_Type :: enum { PROGRAM; FN; STMT; EXPR; }

Ast_Node :: struct {
    type: Ast_Node_Type;
    as: union {
        program: Program_Ast_Node;
        fn: Fn_Ast_Node;
        stmt: Stmt_Ast_Node;
        expr: Expr_Ast_Node;
    };
}

Program_Ast_Node :: struct { fn: *Ast_Node; }

Fn_Ast_Node :: struct { name: string; body: []*Ast_Node; }

Stmt_Type :: enum { RETURN; }
Stmt_Ast_Node :: struct {
    type: Stmt_Type;
    as: union {
        return_stmt: Return_Stmt;
    };
}

Return_Stmt :: struct { expr: *Ast_Node; }

Expr_Ast_Type :: enum { CONSTANT; UNARY; GROUP; }
Expr_Ast_Node :: struct {
    type: Expr_Ast_Type;
    as: union {
        constant: Constant_Expr;
        unary: Unary_Expr;
        group: *Expr_Ast_Node;
    };
}

Constant_Expr :: struct {
    value: int;
}
Unary_Expr :: struct {
    op: Unary_Operator_Type;
    expr: *Expr_Ast_Node;
}
Unary_Operator_Type :: enum { BITWISE_NOT; NEGATE; }

parse_program_ast_node :: (using parser: *Parser) -> *Ast_Node {
    program := New(Ast_Node);
    fn := parse_function_ast_node(parser);
    if current < tokens.count {
        log_error("found extra token: %", peek(parser).type);
        exit(1);
    }
    program.* = .{ type = .PROGRAM, as = .{ program = .{ fn = fn }} };
    return program;
}

parse_function_ast_node :: (using parser: *Parser) -> *Ast_Node {
    consume(parser, .INT);
    ident := consume(parser, .IDENT);
    fn_name := ident.value;

    // TOOD: parameters
    consume(parser, .LPAREN);
    {
        possible_void := peek(parser);
        if possible_void.type == .VOID {
            consume(parser, .VOID);
        }
    }
    consume(parser, .RPAREN);
    consume(parser, .LCURLY);

    stmt := parse_stmt_ast_node(parser);
    stmts : [..]*Ast_Node;
    array_add(*stmts, stmt);

    consume(parser, .RCURLY);

    node := New(Ast_Node);
    node.* = .{ type = .FN, as =.{ fn = .{ fn_name, stmts }}};
    return node;
}

parse_stmt_ast_node :: (using parser: *Parser) -> *Ast_Node {
    return_stmt := parse_return_stmt(parser);
    node := New(Ast_Node);
    node.* = .{ type = .STMT, as = .{ stmt = return_stmt}};
    return node;
}

parse_return_stmt :: (using parser: *Parser) -> *Stmt_Ast_Node {
    consume(parser, .RETURN);
    expr := parse_expression_ast_node(parser);
    consume(parser, .SEMICOLON);
    node := New(Stmt_Ast_Node);
    node.* = .{ type = .RETURN, as = .{ return_stmt = .{ expr = expr } }};
    return node;
}

parse_expression_ast_node :: (using parser: *Parser) -> *Ast_Node {
    current_token := peek(parser);
    if current_token == null {
        log_error("expected expression but reached end of tokens");
        exit(1);
    }
    expr : Expr_Ast_Node;
    if current_token.type ==  {
        case .BITWISE_NOT;
            expr = parse_bitwise_not_unary_expression(parser);
        case .INT_VALUE;
            expr = parse_constant_expr(parser);
        case .LPAREN;
            expr = parse_group_expr(parser);
        case .MINUS;
            expr = parse_negate_expr(parser);
        case;
            log_error("Wanted expression don't know what I got: %", current_token.*);
            exit(1);
    }
    node := New(Ast_Node);
    node.* = .{ type = .EXPR, as = .{ expr = expr }};
     return node;
}

parse_negate_expr :: (using parser: *Parser) -> *Expr_Ast_Node {
    consume(parser, .MINUS);
    expr_ast_node := parse_expression_ast_node(parser);
    node := New(Expr_Ast_Node);
    node.* = .{ type = .UNARY, as = .{ unary = .{ op = .NEGATE, expr = *expr_ast_node.as.expr }}};
    return node;
}

parse_group_expr :: (using parser: *Parser) -> *Expr_Ast_Node {
    consume(parser, .LPAREN);
    expr_ast_node := parse_expression_ast_node(parser);
    consume(parser, .RPAREN);
    node := New(Expr_Ast_Node);
    node.* = .{ type = .GROUP, as = .{ group = *expr_ast_node.as.expr }};
    return node;
}

parse_bitwise_not_unary_expression :: (using parser: *Parser) -> *Expr_Ast_Node {
    consume(parser, .BITWISE_NOT);
    expr_ast_node := parse_expression_ast_node(parser);
    node := New(Expr_Ast_Node);
    node.* = .{ type = .UNARY, as = .{ unary = .{ op = .BITWISE_NOT, expr = *expr_ast_node.as.expr }}};
    return node;
}

parse_constant_expr :: (using parser: *Parser) -> *Expr_Ast_Node {
    token := consume(parser, .INT_VALUE);
    value, success := string_to_int(token.value);

    if !success {
        log_error("expected int found %", token.value);
        exit(1);
    }
    node := New(Expr_Ast_Node);
    node.* = .{ type = .CONSTANT, as = .{ constant = .{value = value} }};
    return node;
}

consume :: (using parser: *Parser, type: Token_Type) -> Token {
    token := peek(parser);
    if token == null || token.type != type {
        log_error("Expected % but got %: %", type, token.type, token.value);
        exit(1);
    }
    current += 1;
    return token;
}

peek :: (using parser: *Parser) -> *Token {
    if is_at_end(parser) {
        return null;
    }
    return *tokens[current];
}

is_at_end :: (using parser: *Parser) -> bool {
    return current >= parser.tokens.count;
}


num_space_print :: "┆⎯";

ast_parse :: (lexer: *Lexer) -> *Ast_Node {
    parser := Parser.{tokens = lexer.tokens};
    program := parse_program_ast_node(*parser);
    print("----\n");
    ast_print(program);
    return program;
}

ast_print :: (using node: *Ast_Node, depth: int = 0) {
    if node == null return;
    if #complete type == {
        case .PROGRAM;
            for 0..depth-1 print(num_space_print);
            print("PROGRAM: \n");
            ast_print(as.program.fn, depth + 1);
            print("\n");
            for 0..depth-1 print(num_space_print);
            print(")");
        case .FN;
            for 0..depth-1 print(num_space_print);
            print("FN: ( ident: %\n", as.fn.name);
            for as.fn.body ast_print(it, depth + 1);
            print("\n");
            for 0..depth-1 print(num_space_print);
            print(")");
        case .STMT;
            for 0..depth-1 print(num_space_print);
            ast_print_stmt(as.stmt, depth);
        case .EXPR;
            ast_print_expr(as.expr, depth);
    }
}

ast_print_expr :: (using expr: Expr_Ast_Node, depth: int) {
    if #complete type == {
        case .CONSTANT; 
            print("%", as.constant.value);
        case .UNARY; 
            for 0..depth-1 print(num_space_print);
            print("UNARY ( %, ",as.unary.op);
            ast_print_expr(as.unary.expr, depth + 1);
            print("\n");
            for 0..depth-1 print(num_space_print);
            print(")");
        case .GROUP;
            print("GROUP (\n");
            ast_print_expr(as.group, depth + 1);
            print("\n");
            for 0..depth-1 print(num_space_print);
            print(")");
    }
}

ast_print_stmt :: (using stmt: Stmt_Ast_Node, depth: int) {
    if #complete type == {
        case .RETURN;
            print("RETURN ( \n");
            ast_print(as.return_stmt.expr, depth + 1);
            print("\n");
            for 0..depth-1 print(num_space_print);
            print(")");
    }
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
