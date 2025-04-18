#import "Basic";
#import "String";

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
    block: *Block_Ast_Node;
}

Block_Ast_Node :: struct {
    items: [..]*Block_Item_Ast_Node;
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

For_Init_Ast_Node :: struct {
    type: enum { INIT_DECL; INIT_EXPR; };
    as: union {
        decl: *Decl_Ast_Node;
        expr: * /*Optional*/ Expr_Ast_Node;
    };
}

Stmt_Ast_Node :: struct {
    type: enum { RETURN; EXPR; IF; NULL; LABEL; GOTO; COMPOUND; BREAK;CONTINUE;WHILE;DO_WHILE;FOR;};
    as: union {
        return_stmt: struct { expr: *Expr_Ast_Node; };
        expr: *Expr_Ast_Node;
        if_stmt: struct { condition: *Expr_Ast_Node; if_block: *Stmt_Ast_Node; else_block: *Stmt_Ast_Node; /* Optional */ };
        label: string;
        goto: string;
        compound: *Block_Ast_Node; 
        break_stmt: string;
        continue_stmt: string;
        while_stmt: struct { condition: *Expr_Ast_Node; body: *Stmt_Ast_Node; label: string; };
        do_while: struct {  body: *Stmt_Ast_Node; condition: *Expr_Ast_Node; label: string;};
        for_stmt: struct { init: *For_Init_Ast_Node; condition: /* Optional */ *Expr_Ast_Node; post: /* Optional */ *Expr_Ast_Node; body: *Stmt_Ast_Node; label: string; }
        // null : doesn't need value
    };
}
Expr_Ast_Node :: struct {
    type: enum { CONSTANT; UNARY; BINARY; GROUP; VAR; ASSIGNMENT; CONDITIONAL;}
    as: union {
        constant: int;
        unary: struct { op: enum {BITWISE_NOT; NEGATE; NOT;}; expr: *Expr_Ast_Node; };
        binary: struct { op: Bin_Op_Ast; left: *Expr_Ast_Node; right: *Expr_Ast_Node;};
        group: *Expr_Ast_Node;
        var: string; // this is when we use a variable
        assignment: struct { dst: *Expr_Ast_Node; src: *Expr_Ast_Node; };
        conditional: struct {condition: *Expr_Ast_Node; true_block: *Expr_Ast_Node; false_block: *Expr_Ast_Node;};
    };
    postfix:  enum {NONE;INCR;DECR;} = .NONE;
}
Bin_Op_Ast :: enum {
    ADD; SUB; MUL; DIV; MOD;
    BITWISE_AND; BITWISE_OR; BITWISE_XOR;
    LEFT_SHIFT; RIGHT_SHIFT;
    AND; OR;
    NOT_EQUAL; EQUAL_EQUAL;
    GREATER; GREATER_EQUAL;
    LESS; LESS_EQUAL;
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
    body := Block.parse_block_ast(parser);
    consume(parser, .RCURLY);
    fn := New(Fn_Ast_Node);
    fn.* = .{ident_token.value, body};
    return fn;
}


Block :: struct {
    parse_block_ast :: (parser: *Parser) -> *Block_Ast_Node {
        body: [..]*Block_Item_Ast_Node;
        while peek(parser).type != .RCURLY {
            b_item := Block_Item.parse_block_item(parser);
            array_add(*body, b_item);
        }
        block := New(Block_Ast_Node);
        block.* = .{body};
        return block;
    }
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
        stmt := Stmt.parse_stmt_ast_node(parser);
        block := New(Block_Item_Ast_Node);
        block.* = .{.STMT, .{stmt = stmt}};
        return block;
    }

}

Decl :: struct {
    parse_decl_ast_node :: (parser: *Parser) -> *Decl_Ast_Node {
        if peek(parser).type == .INT {
            consume(parser, .INT);
            ident := consume(parser).value;
            if is_digit(ident.data.*) assert(false, "identifier should not start with digit");

            expr := ifx peek(parser).type == .ASSIGN {
                consume(parser);
                expr := Expr.parse_expr(parser, 0);
                // parse_postfix_expr_ast(parser, expr);
                expr;
            } else null;


            consume(parser, .SEMICOLON);
            decl :=  New(Decl_Ast_Node);
            decl.* = .{ident, expr};
            return decl;
        }
        assert(false, "unreachable");
        return null;
    }
}

Stmt :: struct {

    parse_stmt_ast_node :: (parser: *Parser) -> *Stmt_Ast_Node {

        if peek(parser).type == {
            case .LCURLY;
                consume(parser, .LCURLY);
                body := Block.parse_block_ast(parser);
                consume(parser, .RCURLY);
                stmt := New(Stmt_Ast_Node);
                stmt.* = .{.COMPOUND, .{compound = body }};
                return stmt;
            case .BREAK;
                consume(parser);
                stmt := New(Stmt_Ast_Node);
                stmt.* = .{.BREAK, .{break_stmt = "$$$UNPROCESSED_BREAK_LABEL$$$"}};
                consume(parser, .SEMICOLON);
                return stmt;
            case .CONTINUE;
                consume(parser);
                stmt := New(Stmt_Ast_Node);
                consume(parser, .SEMICOLON);
                stmt.* = .{.CONTINUE, .{continue_stmt = "$$$UNPROCESSED_CONTINUE_LABEL$$$"}};
                return stmt;
            case .WHILE; return parse_while_stmt(parser) ;
            case .DO; return parse_do_while_stmt(parser);
            case .FOR; return parse_for_stmt(parser);
            case .RETURN; return parse_return_stmt(parser);
            case .IF; return parse_if_stmt(parser);
            case .GOTO; 
                consume(parser, .GOTO);
                token := consume(parser, .IDENT);
                consume(parser, .SEMICOLON);
                stmt := New(Stmt_Ast_Node);
                stmt.* = .{.GOTO, .{ goto = token.value}};
                return stmt;
            case .SEMICOLON;
                consume(parser, .SEMICOLON);
                stmt := New(Stmt_Ast_Node);
                stmt.* = .{.NULL, .{}};
                return stmt;
        }
        if peek(parser).type == .IDENT && peek(parser, 1).type == .COLON {
            token := consume(parser, .IDENT);
            consume(parser, .COLON);
            stmt := New(Stmt_Ast_Node);
            stmt.* = .{.LABEL, .{ label = token.value}};

            return stmt;
        }
        expr := Expr.parse_expr(parser, 0);
        consume(parser, .SEMICOLON);
        stmt := New(Stmt_Ast_Node);
        stmt.* = .{.EXPR, .{expr = expr}};
        return stmt;
    }

    parse_while_stmt :: (parser: *Parser) -> *Stmt_Ast_Node {
        consume(parser, .WHILE);

        consume(parser, .LPAREN);
        condition := Expr.parse_expr(parser, 0);
        consume(parser, .RPAREN);

        body := Stmt.parse_stmt_ast_node(parser);

        while_stmt := New(Stmt_Ast_Node);
        while_stmt.* = .{ .WHILE, .{ while_stmt = .{ condition, body, "$$NOT_PROCESSED$$"} } };
        return while_stmt;
    }
    parse_do_while_stmt :: (parser: *Parser) -> *Stmt_Ast_Node {
        consume(parser, .DO);
        body := Stmt.parse_stmt_ast_node(parser);

        consume(parser, .WHILE);
        consume(parser, .LPAREN);
        condition := Expr.parse_expr(parser, 0);
        consume(parser, .RPAREN);
        consume(parser, .SEMICOLON);

        do_while := New(Stmt_Ast_Node);
        do_while.* = .{ .DO_WHILE, .{ do_while = .{ body, condition, "$$NOT_PROCESSED$$"} } };
        return do_while;
    }

    parse_for_init :: (parser: *Parser) -> *For_Init_Ast_Node {
        if peek(parser).type == .INT {
            decl := Decl.parse_decl_ast_node(parser);
            for_init_decl := New(For_Init_Ast_Node);
            for_init_decl.* = .{ .INIT_DECL, .{decl = decl}};
            return for_init_decl;
        }
        expr := Expr.parse_optional_expr(parser, 0);
        for_init_expr := New(For_Init_Ast_Node);
        for_init_expr.* = .{ .INIT_EXPR, .{expr = expr}};
        return for_init_expr;
    }

    parse_for_stmt :: (parser: *Parser) -> *Stmt_Ast_Node {
        consume(parser, .FOR);
        consume(parser, .LPAREN);

        for_init := parse_for_init(parser);
        if for_init.type == .INIT_EXPR {
            consume(parser, .SEMICOLON);
        }
        condition := Expr.parse_optional_expr(parser, 0);
        consume(parser, .SEMICOLON);
        post := ifx peek(parser).type == .RPAREN null else Expr.parse_expr(parser, 0);
        consume(parser, .RPAREN);

        body := Stmt.parse_stmt_ast_node(parser);


        for_stmt := New(Stmt_Ast_Node);
        for_stmt.* = .{.FOR, .{for_stmt = .{for_init, condition, post, body, "$$ UNPROCESSED FOR LOOP LABEL $$ "}}};
        return for_stmt;
    }

    parse_if_stmt :: (parser: *Parser) -> *Stmt_Ast_Node {
        consume(parser, .IF);
        consume(parser, .LPAREN);
        condition := Expr.parse_expr(parser, 0);
        consume(parser, .RPAREN);

        if_block := parse_stmt_ast_node(parser);

        else_block := ifx peek(parser).type == .ELSE {
            consume(parser, .ELSE);
            parse_stmt_ast_node(parser);
        } else null;

        if_stmt := New(Stmt_Ast_Node);
        if_stmt.* = .{ .IF, .{ if_stmt = .{condition, if_block, else_block }}};
        return if_stmt;
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

Expr :: struct {
    create_expr_ast_node :: (expr_type: type_of(Expr_Ast_Node.type), expr_value: type_of(Expr_Ast_Node.as), postfix: type_of(Expr_Ast_Node.postfix) = .NONE) -> *Expr_Ast_Node {
        expr := New(Expr_Ast_Node);
        expr.* = .{ expr_type, expr_value, postfix};
        return expr;
    }

    parse_optional_expr :: (parser: *Parser, min_prec: int) -> *Expr_Ast_Node {
        if peek(parser).type == .SEMICOLON {
            // consume(parser, .SEMICOLON);
            return null;
        }
        expr := parse_expr(parser, min_prec);
        return expr;
    }

    parse_expr :: (parser: *Parser, min_prec: int)  -> *Expr_Ast_Node {
        left := parse_factor(parser);
        next_token := peek(parser);
      
        while is_binary_operator(next_token.type) && precedence(next_token.type) >= min_prec {
            if next_token.type == .ASSIGN {
                consume(parser);
                right := parse_expr(parser, precedence(next_token.type));
                assignment := create_expr_ast_node(.ASSIGNMENT, .{ assignment = .{left, right}});
                left = assignment;
            } else if is_compound_assignment_operator(next_token.type) {
                op := parse_binary_op(consume(parser).type);
                right := parse_expr(parser, precedence(next_token.type));

                // cloning here because on sema phase we replace variable identifier
                // if we use same pointer, it will look for updated name on our map which is wrong
                left_clone := New(Expr_Ast_Node);
                left_clone.* = left.*;

                binary := create_expr_ast_node(.BINARY, .{binary = .{op, left_clone, right}});
 
                assignment := create_expr_ast_node(.ASSIGNMENT, .{assignment = .{left, binary}});
                left = assignment;
            } else if next_token.type == .QUESTION_MARK {
                consume(parser, .QUESTION_MARK);
                true_block := parse_expr(parser, 0);
                consume(parser, .COLON);
                false_block := parse_expr(parser, precedence(next_token.type));
                conditional := create_expr_ast_node(.CONDITIONAL, .{conditional = .{left, true_block, false_block}});
                left = conditional;
            } else {
                op := parse_binary_op(consume(parser).type);
                right := parse_expr(parser, precedence(next_token.type) + 1);
                binary := create_expr_ast_node(.BINARY, .{binary = .{op, left, right}});
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
                expr := create_expr_ast_node(.UNARY, .{unary = .{op, inner_expr}});
                return expr;
            case .MINUS_MINUS; #through;
            case .PLUS_PLUS;
                postfix_op_token := consume(parser);
                ident_expr := parse_factor(parser);
                if !(ident_expr.type == .VAR || (ident_expr.type == .GROUP && ident_expr.as.group.type == .VAR)) {
                    assert(false, "expected var identifier");
                }
                ident := ifx ident_expr.type == .VAR ident_expr.as.var else ident_expr.as.group.as.var;

                var := create_expr_ast_node(.VAR, .{var = ident});

                one := create_expr_ast_node(.CONSTANT, .{constant = 1});

                op := parse_postfix_binary_op(postfix_op_token.type); 
                binary := create_expr_ast_node(.BINARY, .{binary = .{op, var, one}});

                assignment_dst := New(Expr_Ast_Node);
                assignment_dst.* = var.*;

                assignment := create_expr_ast_node(.ASSIGNMENT, .{assignment = .{assignment_dst, binary}});
                return assignment;
            case .LPAREN;
                consume(parser, .LPAREN);
                inner_expr := parse_expr(parser, 0); // grp resets precedence level for its internal expr
                expr := New(Expr_Ast_Node);
                expr.* = .{ type = .GROUP , as = .{ group = inner_expr }};
                consume(parser, .RPAREN);
                parse_postfix_expr_ast(parser, expr);
                return expr;
            case .IDENT;
                ident := consume(parser);
                var_expr := New(Expr_Ast_Node);
                var_expr.* = .{ type = .VAR , as = .{ var = ident.value }};
                parse_postfix_expr_ast(parser, var_expr);
                return var_expr;
            case;
                assert(false, "This expression is not something I can handle. Duh!! %", peek(parser).*);
                return null; // unreachable
        }
    }
}

parse_postfix_expr_ast :: (parser: *Parser, expr: *Expr_Ast_Node) {
    if peek(parser).type != .MINUS_MINUS && peek(parser).type != .PLUS_PLUS {
        return;
    }

    if !(expr.type == .VAR || (expr.type == .GROUP && expr.as.group.type == .VAR)) {
        assert(false, "invalid l value for postfix operator: %, %", expr.type, expr);
    }

    postfix_op_token := consume(parser);
    op := parse_postfix_enum(postfix_op_token.type); 
    expr.postfix = op;
}

is_compound_assignment_operator :: (token_type: Token_Type) -> bool {
    if token_type == {
        case .PLUS_EQUAL; #through;
        case .MINUS_EQUAL; #through;
        case .MULTIPLY_EQUAL; #through;
        case .DIVIDE_EQUAL; #through;
        case .MOD_EQUAL; #through;
        case .LEFT_SHIFT_EQUAL; #through;
        case .RIGHT_SHIFT_EQUAL; #through;
        case .BITWISE_AND_EQUAL; #through;
        case .BITWISE_OR_EQUAL; #through;
        case .BITWISE_XOR_EQUAL; 
            return true;
        case; return false;
    }
}
parse_postfix_binary_op :: (tt: Token_Type) -> type_of(Expr_Ast_Node.as.binary.op) {
    if tt == {
        case .PLUS_PLUS; return .ADD;
        case .MINUS_MINUS; return .SUB;
        case; assert(false, "Wanted postfix unary operator found %", tt);
    }
    assert(false, "Wanted postfix unary operator found %", tt);
    return .ADD; // unreachable
}

parse_postfix_enum :: (tt: Token_Type) -> type_of(Expr_Ast_Node.postfix) {
    if tt == {
        case .PLUS_PLUS; return .INCR;
        case .MINUS_MINUS; return .DECR;
        case; assert(false, "Wanted postfix unary operator found %", tt);
    }
    assert(false, "Wanted postfix unary operator found %", tt);
    return .NONE; // unreachable
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
        case .ASSIGN; #through;
        case .BITWISE_AND_EQUAL; #through;
        case .BITWISE_XOR_EQUAL; #through;
        case .BITWISE_OR_EQUAL; #through;
        case .LEFT_SHIFT_EQUAL; #through;
        case .RIGHT_SHIFT_EQUAL; #through; 
        case .PLUS_EQUAL; #through;
        case .MINUS_EQUAL; #through;
        case .MULTIPLY_EQUAL; #through;
        case .DIVIDE_EQUAL; #through;
        case .MOD_EQUAL; #through;
        case .QUESTION_MARK;
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

        case .QUESTION_MARK; return 3;

        case .ASSIGN; #through;
        case .PLUS_EQUAL; #through;
        case .MINUS_EQUAL; #through;
        case .MULTIPLY_EQUAL; #through;
        case .DIVIDE_EQUAL; #through;
        case .LEFT_SHIFT_EQUAL; #through;
        case .RIGHT_SHIFT_EQUAL; #through; 
        case .BITWISE_AND_EQUAL; #through;
        case .BITWISE_XOR_EQUAL; #through;
        case .BITWISE_OR_EQUAL; #through; 
        case .MOD_EQUAL;
            return 1;
    }
    assert(false, "precendence calc for any other token is currently not supported: %", tt);
    return 0; // unreachable
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
        case .PLUS; #through;
        case .PLUS_EQUAL; return .ADD;

        case .MINUS; #through;
        case .MINUS_EQUAL; return .SUB;

        case .MULTIPLY; #through;
        case .MULTIPLY_EQUAL; return .MUL;

        case .DIVIDE; #through;
        case .DIVIDE_EQUAL; return .DIV;

        case .MOD; #through;
        case .MOD_EQUAL; return .MOD;

        case .LEFT_SHIFT_EQUAL; #through;
        case .LEFT_SHIFT; return .LEFT_SHIFT;

        case .RIGHT_SHIFT_EQUAL; #through;
        case .RIGHT_SHIFT; return .RIGHT_SHIFT;

        case .BITWISE_AND_EQUAL; #through;
        case .BITWISE_AND; return .BITWISE_AND;

        case .BITWISE_OR_EQUAL; #through;
        case .BITWISE_OR; return .BITWISE_OR;

        case .BITWISE_XOR_EQUAL; #through;
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
    print_block_ast(fn.block, depth + 1);
}

print_block_ast :: (block: *Block_Ast_Node, depth: int = 0) {
    print_space(depth);
    print("[BLOCK]");
    for block.items {
        print_space(depth + 1);
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
        case .IF;
            print("[IF]");
            print_space(depth + 1);
            print_expr_ast(stmt.as.if_stmt.condition, depth + 1);
            print_space(depth + 2);
            print_stmt_ast(stmt.as.if_stmt.if_block, depth + 2);
            if stmt.as.if_stmt.else_block != null {
                print_space(depth);
                print("[ELSE]");
                print_space(depth + 2);
                print_stmt_ast(stmt.as.if_stmt.else_block, depth + 2); 
            }
        case .LABEL;
            print("[LABEL] %", stmt.as.label);
        case .GOTO;
            print("[GOTO] %", stmt.as.goto);
        case .COMPOUND;
            print("[COMPOUND]");
            print_block_ast(stmt.as.compound, depth + 2);
        case .CONTINUE;
            print("[CONTINUE] %", stmt.as.continue_stmt);
        case .BREAK;
            print("[BREAK] %", stmt.as.break_stmt);
        case .FOR;
            for_stmt := stmt.as.for_stmt;
            print("[FOR] %", for_stmt.label);
            print_space(depth + 1);
            print("<init> ");
            if #complete for_stmt.init.type == {
                case .INIT_DECL;
                    print_decl_ast(for_stmt.init.as.decl, depth + 1);
                case .INIT_EXPR;
                    if for_stmt.init.as.expr != null {
                        print_expr_ast(for_stmt.init.as.expr, depth + 1);
                    }
            }
            print_space(depth + 1);
            print("<condition> ");
            if for_stmt.condition != null {
                print_expr_ast(for_stmt.condition, depth + 1);
            }
            print_space(depth + 1);
            print("<post> ");
            if for_stmt.post != null  {
                print_expr_ast(for_stmt.post, depth + 1);
            }
            print_space(depth + 1);
            print_stmt_ast(for_stmt.body, depth + 1);
        case .WHILE;
            while_stmt := stmt.as.while_stmt;
            print("[WHILE] % ", while_stmt.label);
            print_expr_ast(while_stmt.condition, depth);
            print_space(depth + 1);
            print_stmt_ast(while_stmt.body, depth + 1);
        case .DO_WHILE;
            do_while_stmt := stmt.as.do_while;
            print("[DO] % ", do_while_stmt.label);
            // print_space(depth + 1);
            print_stmt_ast(do_while_stmt.body, depth + 1);
            print_space(depth);
            print("[DO_WHILE] % ", do_while_stmt.label);
            print_expr_ast(do_while_stmt.condition, depth +1);
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
        case .CONDITIONAL;
            print("[TERNARY]");
            print_space(depth + 1);
            print_expr_ast(expr.as.conditional.condition, depth);
            print_space(depth + 1);
            print(" ? ");
            print_expr_ast(expr.as.conditional.true_block, depth+2);
            print_space(depth + 1);
            print(" : ");
            print_expr_ast(expr.as.conditional.false_block, depth+2);
    }
    if #complete expr.postfix  == {
        case .INCR; print("[POSTFIX] ++");
        case .DECR; print("[PREFIX] --");
        case .NONE;
    }
}

print_space :: (depth: int = 0) {
    print("\n");
    for 0..depth-1 print("┊−");
}

#scope_file
#import "Memory";
#import "Lexer";
