#import "Basic";
#import "String";
#import "Memory";
#import "Lexer";
#import "Compiler_Util";
#import "Not_Basic";

Parser :: struct { 
    tokens: []Token; 
    start: int = 0; 
    current: int = 0;
    error_reporter: *Error_Reporter;
}

parse_ast :: (lexer: *Lexer, error_reporter: *Error_Reporter, do_print: bool = false) -> *Program_Ast {
    parser := Parser.{ tokens = lexer.tokens, error_reporter = error_reporter };
    program := parse_program_ast(*parser);
    if !is_at_end(*parser) parse_err(*parser, "All token not consumed\n");
    if do_print {
        writer := make_stdout_writer();
        print_program_ast(*writer, program);
        // sb: String_Builder;
        // writer := make_sb_writer(*sb);
        // print_program_ast(*writer, program);
        // print("%", builder_to_string(*sb));
    }
    return program;
}

#scope_module

parse_err :: (using parser: *Parser, msg_fmt: string, args: .. Any) {
    cur_token := peek(parser);
    error_report(error_reporter, cur_token.line, cur_token.start, msg_fmt, .. args);
}

#scope_file

parse_program_ast :: (parser: *Parser) -> *Program_Ast {
    fn := parse_fn_ast(parser);
    return create_program_ast(fn);
}

parse_fn_ast :: (parser: *Parser) -> *Fn_Ast {
    consume(parser, .INT);
    ident_token := consume(parser, .IDENT);

    consume(parser, .LPAREN);
    if peek(parser).*.type == .VOID consume(parser, .VOID);
    consume(parser, .RPAREN);

    body := parse_block_ast(parser);

    return create_fn_ast(ident_token.value, body, ident_token.line, ident_token.start);
}


parse_block_ast :: (parser: *Parser) -> *Block_Ast {
    start_tok := consume(parser, .LCURLY);

    body: [..]*Block_Item_Ast;
    while peek(parser).type != .RCURLY {
        b_item := parse_block_item(parser);
        array_add(*body, b_item);
    }
    consume(parser, .RCURLY);

    return create_block_ast(body, start_tok.line, start_tok.start);
}


parse_block_item :: (parser: *Parser) -> *Block_Item_Ast {
    if peek(parser).type == .INT return create_decl_block_item(parse_decl_ast(parser));
    if peek(parser).type == .SEMICOLON {
        tok := consume(parser);
        return create_stmt_block_item(create_null_stmt(tok.line, tok.start));
    }
    return create_stmt_block_item(parse_stmt_ast(parser));
}


parse_decl_ast :: (parser: *Parser) -> *Decl_Ast {
    if peek(parser).type != .INT parse_err(parser, "Expected int found %", peek(parser).type);

    consume(parser, .INT);
    ident_tok := consume(parser);
    ident := ident_tok.value;
    if is_digit(ident.data.*) parse_err(parser, "identifier should not start with digit");

    expr := ifx peek(parser).type == .ASSIGN {
        consume(parser);
        parse_expr(parser, 0);
    } else null;

    consume(parser, .SEMICOLON);
    return create_decl_ast(ident, expr, ident_tok.line, ident_tok.start);
}

parse_stmt_ast :: (parser: *Parser) -> *Stmt_Ast {
    if peek(parser).type == {
        case .LCURLY;
            body := parse_block_ast(parser);
            return create_compound_stmt(body);
        case .BREAK;
            break_tok := consume(parser);
            stmt := create_break_stmt(break_tok.line, break_tok.start);
            consume(parser, .SEMICOLON);
            return stmt;
        case .CONTINUE;
            continue_tok := consume(parser);
            return create_continue_stmt(continue_tok.line, continue_tok.start);
        case .WHILE; return parse_while_stmt(parser) ;
        case .DO; return parse_do_while_stmt(parser);
        case .FOR; return parse_for_stmt(parser);
        case .RETURN; return parse_return_stmt(parser);
        case .IF; return parse_if_stmt(parser);
        case .GOTO; 
            consume(parser, .GOTO);
            token := consume(parser, .IDENT);
            consume(parser, .SEMICOLON);
            return create_goto_stmt(token.value, token.line, token.start);
        case .SEMICOLON;
            null_tok := consume(parser, .SEMICOLON);
            return create_null_stmt(null_tok.line, null_tok.start);
    }
    if peek(parser).type == .IDENT && peek(parser, 1).type == .COLON {
        token := consume(parser, .IDENT);
        consume(parser, .COLON);
        return create_label_stmt(token.value, token.line, token.start);
    }
    expr := parse_expr(parser, 0);
    consume(parser, .SEMICOLON);
    return create_expr_stmt(expr, expr.loc.line, expr.loc.start);
}

parse_while_stmt :: (parser: *Parser) -> *Stmt_Ast {
    while_stmt_tok := consume(parser, .WHILE);

    consume(parser, .LPAREN);
    condition := parse_expr(parser, 0);
    consume(parser, .RPAREN);

    body := parse_stmt_ast(parser);
    return create_while_stmt(condition, body, while_stmt_tok.line, while_stmt_tok.start);
}

parse_do_while_stmt :: (parser: *Parser) -> *Stmt_Ast {
    do_tok := consume(parser, .DO);
    body := parse_stmt_ast(parser);

    consume(parser, .WHILE);
    consume(parser, .LPAREN);
    condition := parse_expr(parser, 0);
    consume(parser, .RPAREN);
    consume(parser, .SEMICOLON);

    return create_do_while_stmt(body, condition, do_tok.line, do_tok.start);
}

parse_for_init :: (parser: *Parser) -> *For_Init_Ast {
    if peek(parser).type == .INT 
        return create_decl_for_init(parse_decl_ast(parser));
        
    expr := parse_optional_expr(parser, 0);
    return create_expr_for_init(expr);
}

parse_for_stmt :: (parser: *Parser) -> *Stmt_Ast {
    for_tok := consume(parser, .FOR);
    consume(parser, .LPAREN);

    for_init := parse_for_init(parser);
    if for_init.type == .INIT_EXPR consume(parser, .SEMICOLON);

    condition := parse_optional_expr(parser, 0);
    consume(parser, .SEMICOLON);

    post := ifx peek(parser).type == .RPAREN null 
            else parse_expr(parser, 0);

    consume(parser, .RPAREN);

    body := parse_stmt_ast(parser);

    return create_for_stmt(for_init, condition, post, body, for_tok.line, for_tok.start);
}

parse_if_stmt :: (parser: *Parser) -> *Stmt_Ast {
    if_tok := consume(parser, .IF);
    consume(parser, .LPAREN);
    condition := parse_expr(parser, 0);
    consume(parser, .RPAREN);

    if_block := parse_stmt_ast(parser);

    else_block := ifx peek(parser).type == .ELSE {
        consume(parser, .ELSE);
        parse_stmt_ast(parser);
    } else null;

    return create_if_stmt(condition, if_block, else_block, if_tok.line, if_tok.start);
}

parse_return_stmt :: (parser: *Parser) -> *Stmt_Ast {
    ret_tok := consume(parser, .RETURN);
    expr := parse_expr(parser, 0);
    consume(parser, .SEMICOLON);
    return create_return_stmt(expr, ret_tok.line, ret_tok.start);
}

parse_optional_expr :: (parser: *Parser, min_prec: int) -> *Expr_Ast {
    if peek(parser).type == .SEMICOLON return null;
    return parse_expr(parser, min_prec);
}

parse_expr :: (parser: *Parser, min_prec: int)  -> *Expr_Ast {
    left := parse_factor(parser);
    next_token := peek(parser);
    
    while is_binary_operator(next_token.type) && precedence(parser, next_token.type) >= min_prec {
        if next_token.type == .ASSIGN {
            assign_tok := consume(parser);
            right := parse_expr(parser, precedence(parser, next_token.type));
            assignment := create_assignment_expr(left, right, assign_tok.line, assign_tok.start);
            left = assignment;
        } else if is_compound_assignment_operator(next_token.type) {
            op_tok := consume(parser);
            op := parse_binary_op(parser, op_tok.type);
            right := parse_expr(parser, precedence(parser, next_token.type));

            // @note
            // cloning here because on sema phase we replace variable identifier
            // if we use same pointer, it will look for updated name on our map which is wrong
            left_clone := New(Expr_Ast);
            left_clone.* = left.*;

            binary := create_binary_expr(op, left_clone, right, op_tok.line, op_tok.start);
            assignment := create_assignment_expr(left, binary, op_tok.line, op_tok.start);

            left = assignment;
        } else if next_token.type == .QUESTION_MARK {
            q_tok := consume(parser, .QUESTION_MARK);
            true_block := parse_expr(parser, 0);
            consume(parser, .COLON);
            false_block := parse_expr(parser, precedence(parser, next_token.type));
            conditional := create_ternary_expr(left, true_block, false_block, q_tok.line, q_tok.start);
            left = conditional;
        } else {
            op_tok := consume(parser);
            op := parse_binary_op(parser, op_tok.type);
            right := parse_expr(parser, precedence(parser, next_token.type) + 1);
            binary := create_binary_expr(op, left, right, op_tok.line, op_tok.start);
            left = binary;
        }
        next_token = peek(parser);
    }
    return left;
}

parse_factor :: (parser: *Parser) -> *Expr_Ast {
    if peek(parser).*.type ==  {
        case .INT_LITERAL;
            int_literal := consume(parser, .INT_LITERAL);
            int_value, success := string_to_int(int_literal.value);
            if !success  parse_err(parser, "Expected int found %", int_literal.value);
            return create_constant_expr(int_value, int_literal.line , int_literal.start);
        case .MINUS; #through;
        case .NOT; #through;
        case .BITWISE_NOT;
            op_tok := consume(parser);
            op := parse_unary_op(parser, op_tok.type);
            inner_expr := parse_factor(parser);
            expr := create_unary_expr(op, inner_expr, op_tok.line, op_tok.start); 
            return expr;
        case .MINUS_MINUS; #through;
        case .PLUS_PLUS;
            postfix_op_token := consume(parser);
            ident_expr := parse_factor(parser);
            if !(ident_expr.type == .VAR || (ident_expr.type == .GROUP && ident_expr.as.group.type == .VAR)) {
                parse_err(parser, "expected var identifier");
            }
            ident := ifx ident_expr.type == .VAR ident_expr.as.var else ident_expr.as.group.as.var;

            var := create_var_expr(ident, ident_expr.loc.line, ident_expr.loc.start);
            // @note
            // on sema phase we replace variable with identifier
            // we we use same reference we will update identifier twice
            var_clone := create_var_expr(ident, ident_expr.loc.line, ident_expr.loc.start);

            one := create_constant_expr(1, postfix_op_token.line, postfix_op_token.start);
            op := parse_postfix_binary_op(parser, postfix_op_token.type); 
            binary := create_binary_expr(op, var, one, postfix_op_token.line, postfix_op_token.start);
            return create_assignment_expr(var_clone, binary, postfix_op_token.line, postfix_op_token.start);
        case .LPAREN;
            grp_start_tok := consume(parser, .LPAREN);
            inner_expr := parse_expr(parser, 0); // grp resets precedence level for its internal expr
            expr := create_group_expr(inner_expr, grp_start_tok.line, grp_start_tok.start);
            consume(parser, .RPAREN);
            parse_postfix_expr_ast(parser, expr);
            return expr;
        case .IDENT;
            ident := consume(parser);
            var_expr := create_var_expr(ident.value, ident.line, ident.start);
            parse_postfix_expr_ast(parser, var_expr);
            return var_expr;
    }
    parse_err(parser, "This expression is not something I can handle. Duh!! %", peek(parser).*);
    return null;
}

parse_postfix_expr_ast :: (parser: *Parser, expr: *Expr_Ast) {
    if peek(parser).type != .MINUS_MINUS && peek(parser).type != .PLUS_PLUS {
        return;
    }

    if !(expr.type == .VAR || (expr.type == .GROUP && expr.as.group.type == .VAR)) {
        parse_err(parser, "invalid l value for postfix operator: %, %", expr.type, expr.*);
    }

    postfix_op_token := consume(parser);
    op := parse_postfix_enum(parser, postfix_op_token.type); 
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
parse_postfix_binary_op :: (parser: *Parser, tt: Token_Type) -> Binary_Operator {
    if tt == {
        case .PLUS_PLUS; return .ADD;
        case .MINUS_MINUS; return .SUB;
        case; parse_err(parser, "Wanted postfix unary operator found %", tt);
    }
    parse_err(parser, "Wanted postfix unary operator found %", tt);
    return .ADD; 
}

parse_postfix_enum :: (parser: *Parser, tt: Token_Type) -> type_of(Expr_Ast.postfix) {
    if tt == {
        case .PLUS_PLUS; return .INCR;
        case .MINUS_MINUS; return .DECR;
        case; parse_err(parser, "Wanted postfix unary operator found %", tt);
    }
    parse_err(parser, "Wanted postfix unary operator found %", tt);
    return .NONE; 
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

precedence :: (parser: *Parser, tt: Token_Type) -> int {
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
    parse_err(parser, "precendence calc for any other token is currently not supported: %", tt);
    return 0; 
}

parse_unary_op :: (parser: *Parser, tt: Token_Type) -> type_of(Expr_Ast.as.unary.op) {
    if tt == {
        case .BITWISE_NOT; return .BITWISE_NOT;
        case .MINUS; return .NEGATE;
        case .NOT; return .NOT;
        case; parse_err(parser, "Wanted unary operator found %", tt);
    }
    parse_err(parser, "Wanted unary operator found %", tt);
    return .NEGATE;
}

parse_binary_op :: (parser: *Parser, tt: Token_Type) -> Binary_Operator {
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
    parse_err(parser, "Wanted binary operator found %", tt);
    return .ADD;
}

consume :: (using parser: *Parser) -> Token {
    defer current += 1;
    return peek(parser);
}

consume:: (parser: *Parser, token_type: Token_Type) -> Token {
    tok := peek(parser);
    if tok.type != token_type parse_err(parser, "Expected % found %", token_type, tok.type);
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

#scope_export