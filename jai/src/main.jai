main :: () {
    // everything on temporary allocator, don't wanna manage memory for now
    push_allocator(temp);
    defer { reset_temporary_storage(); report_memory_leaks(); };

    args := get_cli_args();
    // print("Args % \n", args);

    print("WD: %\n", get_working_directory());

    lexer := ifx args.flags & .LEX {
        src, r_success := File.read_entire_file(args.source_file_path);
        if !r_success {
            log_error("Unable to read file -- '%'", args.source_file_path);
            exit(1);
        }
        lexer := Lexer.{src = src};
        success, msg := scan(*lexer);
        if !success {
            log_error("Failed to Lex: %", msg);
            exit(1);
        }
        lexer;
    };
    for lexer.tokens {
        print("%\n", it);
    }

    ast := ifx args.flags & .PARSE {
        parser := Parser.{tokens = lexer.tokens};
        success, program := parse_program(*parser);
        program;
    };
    print("----\n");
    ast_print(ast);
}

ast_print :: (node: *Ast_Node, depth: int = 0) {
    for 0..depth-1 print("    ");
    if node == null return;
    if #complete node.type == {
        case .FUNCTION;
            print("fn: %\n", node.as.function.name);
            for node.as.function.body ast_print(it, depth + 1);
        case .RETURN_STMT;
            print("return:\n");
            ast_print(node.as.return_stmt.value, depth + 1);
        case .INT_VALUE;
            print("int: %\n", node.as.int_value);
    }
}

Parser :: struct {
    tokens: []Token;
    start: int = 0;
    current: int = 0;
}

parse_program :: (parser: *Parser) -> success: bool = true, node: *Ast_Node = null {
    program := parse_function(parser);
    return success = true, node= program;
}

parse_function :: (using parser: *Parser) -> *Ast_Node {
    consume(parser, .INT);
    ident := consume(parser, .IDENT);
    fn_name := ident.value;
    consume(parser, .LPAREN);
    consume(parser, .RPAREN);
    consume(parser, .LCURLY);
    stmt := parse_stmt(parser);
    consume(parser, .RCURLY);
    fn_node := New(Ast_Node);
    stmts : [..]*Ast_Node;
    array_add(*stmts, stmt);
    fn_node.* = .{
        type = .FUNCTION,
        as = .{ function = .{ name = fn_name, body = stmts }, },
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


Ast_Node_Type :: enum {
    FUNCTION;
    RETURN_STMT;
    INT_VALUE;
}

Ast_Node :: struct {
    type: Ast_Node_Type;
    as: union {
        function: Fn_Ast_Node;
        return_stmt: Return_Stmt_Ast_Node;
        int_value: int;
    };
}

Fn_Ast_Node :: struct {
    name: string;
    body: []*Ast_Node;
    // return_type: string;
    // params: []Ast_Node_Param;
    // body: []Ast_Node;
}

Return_Stmt_Ast_Node :: struct {
    value: *Ast_Node;
}

#import "Basic"()(MEMORY_DEBUGGER=true);
String :: #import "String";
Process :: #import "Process";
File :: #import "File";
#load "Lexer.jai";
#load "Cli_Args.jai";




