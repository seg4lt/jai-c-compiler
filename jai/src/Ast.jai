Parser :: struct {
    tokens: []Token;
    start: int = 0;
    current: int = 0;
}

Ast_Node_Type :: enum {
    PROGRAM;
    FUNCTION;
    RETURN_STMT;
    INT_VALUE;
}

Ast_Node :: struct {
    type: Ast_Node_Type;
    as: union {
        program: Program_Ast_Node;
        fn: Fn_Ast_Node;
        return_stmt: Return_Stmt_Ast_Node;
        int_value: int;
    };
}

Program_Ast_Node :: struct {
    fn: *Ast_Node;
}

Fn_Ast_Node :: struct {
    name: string;
    body: []*Ast_Node;
}

Return_Stmt_Ast_Node :: struct {
    value: *Ast_Node;
}

ast_print :: (node: *Ast_Node, depth: int = 0) {
    for 0..depth-1 print("    ");
    if node == null return;
    if #complete node.type == {
        case .PROGRAM;
            print("program: \n");
            ast_print(node.as.program.fn, depth + 1);
        case .FUNCTION;
            print("fn: %\n", node.as.fn.name);
            for node.as.fn.body ast_print(it, depth + 1);
        case .RETURN_STMT;
            print("return:\n");
            ast_print(node.as.return_stmt.value, depth + 1);
        case .INT_VALUE;
            print("int: %\n", node.as.int_value);
    }
}

parse_program :: (using parser: *Parser) -> success: bool = true, program: *Ast_Node = null {
    program := New(Ast_Node);
    fn := parse_function(parser);
    if current < tokens.count {
        log_error("found extra token: %", peek(parser).type);
        exit(1);
    }
    program.* = .{
        type = .PROGRAM,
        as = .{ program = .{ fn = fn }}
    };
    return success = true, program = program;
}

parse_function :: (using parser: *Parser) -> *Ast_Node {
    consume(parser, .INT);
    ident := consume(parser, .IDENT);
    fn_name := ident.value;
    consume(parser, .LPAREN);

    {
        
        possible_void := peek(parser);
        if possible_void.type == .VOID {
            consume(parser, .VOID);
        }
    }

    consume(parser, .RPAREN);
    consume(parser, .LCURLY);
    stmt := parse_stmt(parser);
    consume(parser, .RCURLY);
    fn_node := New(Ast_Node);
    stmts : [..]*Ast_Node;
    array_add(*stmts, stmt);
    fn_node.* = .{
        type = .FUNCTION,
        as = .{ fn = .{ name = fn_name, body = stmts }, },
    };
    return fn_node; 
}

parse_stmt :: (using parser: *Parser) -> *Ast_Node {
    consume(parser, .RETURN);
    expr := parse_int_value(parser);
    consume(parser, .SEMICOLON);

    stmt_node := New(Ast_Node);
    stmt_node.* = .{
        type = .RETURN_STMT,
        as = .{ return_stmt = .{ value = expr } }
    };
    return stmt_node;
}

parse_int_value :: (using parser: *Parser) -> *Ast_Node {
    token := consume(parser, .INT_VALUE);
    int_value_node := New(Ast_Node);
    value, success := string_to_int(token.value);
    if !success {
        log_error("expected int found %", token.value);
        exit(1);
    }
    int_value_node.* = .{
        type = .INT_VALUE,
        as = .{ int_value = value }
    };
    return int_value_node;
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

test_simple :: () {
    src := #string done
        int main () {
            return 2;
        }
    done
    lexer := Lexer.{src = src};
    l_success, msg := scan(*lexer);

    parser := Parser.{tokens = lexer.tokens};
    p_success, program := parse_program(*parser);
    assert(p_success, "Parsing should be success");
}

#scope_export
