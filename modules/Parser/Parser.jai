Parser :: struct {
    tokens         : []Token;
    start          : int = 0;
    current        : int = 0;
    error_reporter : *Error_Reporter;
}

parse_ast :: (tokens: []Token, error_reporter: *Error_Reporter, debug_log: bool = false) -> *Program_Ast {
    parser := Parser.{ tokens = tokens, error_reporter = error_reporter };
    
    program := parse_program(*parser);
    if !is_at_end(*parser) parse_err(*parser, "All token not consumed\n");
    
    if debug_log print_program_ast(*stdout_writer_new(), program);
    
    return program;
}

#scope_module

parse_err :: (parser: *Parser, msg_fmt: string, args: .. Any) #expand {
    cur_token := peek(parser);
    error_report(parser.error_reporter, cur_token.line, cur_token.start, msg_fmt, .. args);
}

parse_err :: (parser: *Parser, tok: Token, msg_fmt: string, args: .. Any) #expand {
    error_report(parser.error_reporter, tok.line, tok.start, msg_fmt, .. args);
}

#scope_file

parse_program :: (parser: *Parser) -> *Program_Ast {
    fns: [..]*Fn_Decl_Ast;
    while !is_at_end(parser) array_add(*fns, parse_fn_decl(parser));
    return program_new(fns);
}

parse_fn_decl :: (parser: *Parser, only_decl: bool = false) -> *Fn_Decl_Ast {
    consume(parser, .INT);
    ident_token := consume(parser, .IDENT);

    consume(parser, .LPAREN);
    params := parse_fn_params(parser);
    consume(parser, .RPAREN);

    if peek(parser).*.type == .SEMICOLON {
        consume(parser, .SEMICOLON);
        return fn_decl_new(ident_token.value, params, null, ident_token.line, ident_token.start);
    }
    if only_decl parse_err(parser, "fn decl expected, found body");

    body := parse_block(parser);
    return fn_decl_new(ident_token.value, params, body, ident_token.line, ident_token.start);
}

parse_fn_params :: (parser: *Parser) -> [..]*Fn_Param {
    params: [..]*Fn_Param;
    if peek(parser).type == .VOID {
        consume(parser, .VOID);
        return params;
    }
    while peek(parser).type != .RPAREN {
        // we only support int type for now
        type := consume(parser, .INT); 
        ident := consume(parser, .IDENT);
        
        fn_param := New(Fn_Param, .{ ident = ident.value, line = ident.line, start = ident.start });
        array_add(*params, fn_param);
        
        // maybe we need to break if we can't find comma?
        if peek(parser).type == .COMMA {
            consume(parser, .COMMA);
            if peek(parser).*.type == .RPAREN {
                parse_err(parser, "trailing command on parameter list is not allowed");
            }
        }
    }
    return params;
}

parse_block :: (parser: *Parser) -> *Block_Ast {
    start_tok := consume(parser, .LCURLY);
    body: [..]*Block_Item_Ast;
    
    while peek(parser).type != .RCURLY {
        array_add(*body, parse_block_item(parser));
    }
    consume(parser, .RCURLY);

    return block_new(body, start_tok.line, start_tok.start);
}


parse_block_item :: (parser: *Parser) -> *Block_Item_Ast {
    if peek(parser).type == .INT {
        decl := parser_decl(parser);
        return block_item_decl_new(decl);
    }
        
    if peek(parser).type == .SEMICOLON {
        tok := consume(parser);
        stmt := stmt_null_new(tok.line, tok.start);
        return block_item_stmt_new(stmt);
    }
    stmt := parse_stmt(parser);
    return block_item_stmt_new(stmt);
}

is_fn_decl :: (parser: *Parser) -> bool {
    return peek(parser).type == .INT 
            && peek(parser, 1).type == .IDENT 
            && peek(parser, 2).type == .LPAREN;
}

parser_decl :: (parser: *Parser) -> *Decl_Ast {
    // .INT because we only suppor int data type, but
    if peek(parser).type != .INT parse_err(parser, "Expected int found %", peek(parser).type);

    if is_fn_decl(parser) {
        fn_decl_ast := parse_fn_decl(parser, only_decl = true);
        return decl_fn_new(fn_decl_ast);
    }
    // normal variable decl
    consume(parser, .INT);
    ident_tok := consume(parser);
    ident := ident_tok.value;
    
    if is_digit(ident.data.*) parse_err(parser, "identifier should not start with digit");

    expr := null;
    if peek(parser).type == .ASSIGN {
        consume(parser);
        expr = parse_expr(parser, 0);
    }
    consume(parser, .SEMICOLON);
    return decl_var_new(ident, expr, ident_tok.line, ident_tok.start);
}

parse_stmt :: (parser: *Parser) -> *Stmt_Ast {
    if peek(parser).type == {
        case .LCURLY;
            body := parse_block(parser);
            return stmt_compound_new(body);
        case .BREAK;
            break_tok := consume(parser);
            stmt := stmt_break_new(break_tok.line, break_tok.start);
            consume(parser, .SEMICOLON);
            return stmt;
        case .CONTINUE;
            continue_tok := consume(parser);
            consume(parser, .SEMICOLON);
            return stmt_continue_new(continue_tok.line, continue_tok.start);
        case .WHILE; return parse_while_stmt(parser) ;
        case .DO; return parse_do_while_stmt(parser);
        case .FOR; return parse_for_stmt(parser);
        case .RETURN; return parse_return_stmt(parser);
        case .IF; return parse_if_stmt(parser);
        case .SWITCH; return parse_switch_stmt(parser);
        case .CASE;
            consume(parser, .CASE);
            token := consume(parser, .INT_LITERAL);
            consume(parser, .COLON);
            expr := stmt_case_new(token.value, token.line, token.start);
            return expr;
        case .DEFAULT;
            token := consume(parser, .DEFAULT);
            consume(parser, .COLON);
            return stmt_default_new(token.line, token.start);
        case .GOTO;
            consume(parser, .GOTO);
            token := consume(parser, .IDENT);
            consume(parser, .SEMICOLON);
            return stmt_goto_new(token.value, token.line, token.start);
        case .SEMICOLON;
            null_tok := consume(parser, .SEMICOLON);
            return stmt_null_new(null_tok.line, null_tok.start);
    }
    // .LABEL;
    if peek(parser).type == .IDENT && peek(parser, 1).type == .COLON {
        token := consume(parser, .IDENT);
        consume(parser, .COLON);
        label_stmt := parse_stmt(parser);
        return stmt_label_new(token.value, label_stmt, token.line, token.start);
    }
    expr := parse_expr(parser, 0);
    consume(parser, .SEMICOLON);
    return stmt_expr_new(expr, expr.loc.line, expr.loc.start);
}

parse_switch_stmt :: (parser: *Parser) -> *Stmt_Ast {
    switch_tok := consume(parser, .SWITCH);
    consume(parser, .LPAREN);

    condition := parse_expr(parser, 0);
    consume(parser, .RPAREN);

    body: [..]*Block_Item_Ast;
    if peek(parser).type == .LCURLY {
        consume(parser, .LCURLY);
        
        case_found := false;
        while peek(parser).type != .RCURLY {
            peeked_token := peek(parser);
            item := parse_block_item(parser);
            if item.type == .STMT && item.as.stmt.type == .CASE || item.as.stmt.type == .DEFAULT {
                case_found = true;
            }
            if case_found && item.type == .DECL {
                parse_err(parser, peeked_token, "switch case should not have decl");
            }
            array_add(*body, item);
        }
        consume(parser, .RCURLY);
        return stmt_switch_new(condition, body, switch_tok.line, switch_tok.start);
    }
    // if switch doesn't have block `{}` then it might have one case stmt
    block_item := parse_block_item(parser);
    array_add(*body, block_item);
    
    if block_item.type == .STMT && block_item.as.stmt.type  == .CASE {
        case_stmt := parse_block_item(parser);
        array_add(*body, case_stmt);
    }
    return stmt_switch_new(condition, body, switch_tok.line, switch_tok.start);
}

parse_while_stmt :: (parser: *Parser) -> *Stmt_Ast {
    while_token := consume(parser, .WHILE);

    consume(parser, .LPAREN);
    condition := parse_expr(parser, 0);
    consume(parser, .RPAREN);

    body := parse_stmt(parser);
    return stmt_while_new(condition, body, while_token.line, while_token.start);
}

parse_do_while_stmt :: (parser: *Parser) -> *Stmt_Ast {
    do_token := consume(parser, .DO);
    body := parse_stmt(parser);

    consume(parser, .WHILE);
    
    consume(parser, .LPAREN);
    condition := parse_expr(parser, 0);
    consume(parser, .RPAREN);
    
    consume(parser, .SEMICOLON);

    return stmt_do_while_new(body, condition, do_token.line, do_token.start);
}

parse_for_init :: (parser: *Parser) -> *For_Init_Ast {
    peek_token := peek(parser);
    if peek_token.*.type == .INT {
        decl := parser_decl(parser);
        if decl.type != .VAR {
            parse_err(parser, peek_token, "Expected variable declaration in for loop init, found %", decl.type);
            return null;
        }
        return for_init_decl_new(decl);
    }

    expr := parse_optional_expr(parser, 0);
    return for_init_expr_new(expr);
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

    body := parse_stmt(parser);

    return stmt_for_new(for_init, condition, post, body, for_tok.line, for_tok.start);
}

parse_if_stmt :: (parser: *Parser) -> *Stmt_Ast {
    if_tok := consume(parser, .IF);
    consume(parser, .LPAREN);
    condition := parse_expr(parser, 0);
    consume(parser, .RPAREN);

    if_block := parse_stmt(parser);

    else_block := null;
    if peek(parser).type == .ELSE {
        consume(parser, .ELSE);
        else_block = parse_stmt(parser);
    } 

    return stmt_if_new(condition, if_block, else_block, if_tok.line, if_tok.start);
}

parse_return_stmt :: (parser: *Parser) -> *Stmt_Ast {
    ret_tok := consume(parser, .RETURN);
    expr := parse_expr(parser, 0);
    consume(parser, .SEMICOLON);
    return stmt_return_new(expr, ret_tok.line, ret_tok.start);
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
            assignment := expr_assignment_new(left, right, assign_tok.line, assign_tok.start);
            left = assignment;
        } else if is_compound_assignment_operator(next_token.type) {
            op_tok := consume(parser);
            op := parse_binary_op(parser, op_tok.type);
            right := parse_expr(parser, precedence(parser, next_token.type));

            // @note
            // cloning here because on sema phase we replace variable identifier
            // if we use same pointer, it will look for updated name on our map which is wrong
            left_clone := New(Expr_Ast, left.*);

            binary := expr_binary_new(op, left_clone, right, op_tok.line, op_tok.start);
            assignment := expr_assignment_new(left, binary, op_tok.line, op_tok.start);

            left = assignment;
        } else if next_token.type == .QUESTION_MARK {
            q_tok := consume(parser, .QUESTION_MARK);
            true_block := parse_expr(parser, 0);
            consume(parser, .COLON);
            false_block := parse_expr(parser, precedence(parser, next_token.type));
            conditional := expr_ternary_new(left, true_block, false_block, q_tok.line, q_tok.start);
            left = conditional;
        } else {
            op_tok := consume(parser);
            op := parse_binary_op(parser, op_tok.type);
            right := parse_expr(parser, precedence(parser, next_token.type) + 1);
            binary := expr_binary_new(op, left, right, op_tok.line, op_tok.start);
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
            return expr_constant_new(int_value, int_literal.line , int_literal.start);
        case .MINUS; #through;
        case .NOT; #through;
        case .BITWISE_NOT;
            op_tok := consume(parser);
            op := parse_unary_op(parser, op_tok.type);
            inner_expr := parse_factor(parser);
            expr := expr_unary_new(op, inner_expr, op_tok.line, op_tok.start);
            return expr;
        case .MINUS_MINUS; #through;
        case .PLUS_PLUS;
            postfix_op_token := consume(parser);
            ident_expr := parse_factor(parser);
            if !(ident_expr.type == .VAR || (ident_expr.type == .GROUP && ident_expr.as.group.type == .VAR)) {
                parse_err(parser, "expected var identifier");
            }
            ident := ifx ident_expr.type == .VAR ident_expr.as.var else ident_expr.as.group.as.var;

            var := expr_var_new(ident, ident_expr.loc.line, ident_expr.loc.start);
            // @note
            // on sema phase we replace variable with identifier
            // we we use same reference we will update identifier twice
            var_clone := expr_var_new(ident, ident_expr.loc.line, ident_expr.loc.start);

            one := expr_constant_new(1, postfix_op_token.line, postfix_op_token.start);
            op := parse_postfix_binary_op(parser, postfix_op_token.type);
            binary := expr_binary_new(op, var, one, postfix_op_token.line, postfix_op_token.start);
            return expr_assignment_new(var_clone, binary, postfix_op_token.line, postfix_op_token.start);
        case .LPAREN;
            grp_start_tok := consume(parser, .LPAREN);
            inner_expr := parse_expr(parser, 0);
            expr := expr_group_new(inner_expr, grp_start_tok.line, grp_start_tok.start);
            consume(parser, .RPAREN);
            parse_postfix_expr_ast(parser, expr);
            return expr;
        case .IDENT;
            ident := consume(parser);
            expr := ifx peek(parser).*.type != .LPAREN  expr_var_new(ident.value, ident.line, ident.start)
                    else expr_fn_call_new(ident.value, parse_args_expr(parser), ident.line, ident.start);
            parse_postfix_expr_ast(parser, expr);
            return expr;
    }
    parse_err(parser, "This expression is not something I can handle. Duh!! %", peek(parser).*);
    return null;
}

parse_args_expr :: (parser: *Parser) -> [..]*Expr_Ast {
    args: [..]*Expr_Ast;
    consume(parser, .LPAREN);
    while peek(parser).type != .RPAREN {
        expr := parse_expr(parser, 0);
        array_add(*args, expr);
        if peek(parser).type == .COMMA {
            consume(parser, .COMMA);
            if peek(parser).*.type == .RPAREN {
                parse_err(parser, "trailing comma in function call is not allowed");
            }
        }
    }
    consume(parser, .RPAREN);
    return args;
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
        case .BITWISE_AND_EQUAL; #through;
        case .BITWISE_OR_EQUAL;  #through;
        case .BITWISE_XOR_EQUAL; #through;
        case .DIVIDE_EQUAL;      #through;
        case .LEFT_SHIFT_EQUAL;  #through;
        case .MINUS_EQUAL;       #through;
        case .MOD_EQUAL;         #through;
        case .MULTIPLY_EQUAL;    #through;
        case .PLUS_EQUAL;        #through;
        case .RIGHT_SHIFT_EQUAL; return true;
        case;                    return false;
    }
}

parse_postfix_binary_op :: (parser: *Parser, token_type: Token_Type) -> Binary_Operator {
    if token_type == {
        case .MINUS_MINUS; return .SUB;
        case .PLUS_PLUS;   return .ADD;
        case;              parse_err(parser, "Wanted postfix unary operator found %", token_type);
    }
    parse_err(parser, "Wanted postfix unary operator found %", token_type);
    return .ADD;
}

parse_postfix_enum :: (parser: *Parser, tt: Token_Type) -> type_of(Expr_Ast.postfix) {
    if tt == {
        case .MINUS_MINUS; return .DECR;
        case .PLUS_PLUS;   return .INCR;
        case;              parse_err(parser, "Wanted postfix unary operator found %", tt);
    }
    parse_err(parser, "Wanted postfix unary operator found %", tt);
    return .NONE;
}

is_binary_operator :: (tt: Token_Type) -> bool {
    if tt == {
        case .AND;               #through;
        case .ASSIGN;            #through;
        case .BITWISE_AND;       #through;
        case .BITWISE_AND_EQUAL; #through;
        case .BITWISE_OR;        #through;
        case .BITWISE_OR_EQUAL;  #through;
        case .BITWISE_XOR;       #through;
        case .BITWISE_XOR_EQUAL; #through;
        case .DIVIDE;            #through;
        case .DIVIDE_EQUAL;      #through;
        case .EQUAL_EQUAL;       #through;
        case .GREATER;           #through;
        case .GREATER_EQUAL;     #through;
        case .LEFT_SHIFT;        #through;
        case .LEFT_SHIFT_EQUAL;  #through;
        case .LESS;              #through;
        case .LESS_EQUAL;        #through;
        case .MINUS;             #through;
        case .MINUS_EQUAL;       #through;
        case .MOD;               #through;
        case .MOD_EQUAL;         #through;
        case .MULTIPLY;          #through;
        case .MULTIPLY_EQUAL;    #through;
        case .NOT_EQUAL;         #through;
        case .OR;                #through;
        case .PLUS;              #through;
        case .PLUS_EQUAL;        #through;
        case .QUESTION_MARK;     #through;
        case .RIGHT_SHIFT;       #through;
        case .RIGHT_SHIFT_EQUAL; return true;
        case;                    return false;
    }
}

precedence :: (parser: *Parser, token_type: Token_Type) -> int {
    // https://en.cppreference.com/w/c/language/operator_precedence
    if token_type == {
        case .BITWISE_NOT; #through;
        case .NOT;         return 70;

        case .DIVIDE;   #through;
        case .MULTIPLY; #through;
        case .MOD;      return 50;

        case .MINUS; #through;
        case .PLUS;  return 45;

        case .LEFT_SHIFT;  #through;
        case .RIGHT_SHIFT; return 40;

        case .LESS;          #through;
        case .LESS_EQUAL;    #through;
        case .GREATER;       #through;
        case .GREATER_EQUAL; return 35;

        case .EQUAL_EQUAL; #through;
        case .NOT_EQUAL;   return 30;

        case .BITWISE_AND; return 25;
        case .BITWISE_XOR; return 24;
        case .BITWISE_OR;  return 23;

        case .AND; return 10;
        case .OR;  return 5;

        case .QUESTION_MARK; return 3;

        case .ASSIGN;            #through;
        case .PLUS_EQUAL;        #through;
        case .MINUS_EQUAL;       #through;
        case .MULTIPLY_EQUAL;    #through;
        case .DIVIDE_EQUAL;      #through;
        case .LEFT_SHIFT_EQUAL;  #through;
        case .RIGHT_SHIFT_EQUAL; #through;
        case .BITWISE_AND_EQUAL; #through;
        case .BITWISE_XOR_EQUAL; #through;
        case .BITWISE_OR_EQUAL;  #through;
        case .MOD_EQUAL;         return 1;
    }
    parse_err(parser, "precendence calc for any other token is currently not supported: %", token_type);
    return 0;
}

parse_unary_op :: (parser: *Parser, token_type: Token_Type) -> type_of(Expr_Ast.as.unary.op) {
    if token_type == {
        case .BITWISE_NOT; return .BITWISE_NOT;
        case .MINUS;       return .NEGATE;
        case .NOT;         return .NOT;
        case;              parse_err(parser, "Wanted unary operator found %", token_type);
    }
    parse_err(parser, "Wanted unary operator found %", token_type);
    return .NEGATE;
}

parse_binary_op :: (parser: *Parser, token_type: Token_Type) -> Binary_Operator {
    if token_type == {
        case .PLUS;        #through;
        case .PLUS_EQUAL;  return .ADD;

        case .MINUS;       #through;
        case .MINUS_EQUAL; return .SUB;

        case .MULTIPLY;       #through;
        case .MULTIPLY_EQUAL; return .MUL;

        case .DIVIDE;       #through;
        case .DIVIDE_EQUAL; return .DIV;

        case .MOD;       #through;
        case .MOD_EQUAL; return .MOD;

        case .LEFT_SHIFT_EQUAL; #through;
        case .LEFT_SHIFT;       return .LEFT_SHIFT;

        case .RIGHT_SHIFT_EQUAL; #through;
        case .RIGHT_SHIFT;      return .RIGHT_SHIFT;

        case .BITWISE_AND_EQUAL; #through;
        case .BITWISE_AND;       return .BITWISE_AND;

        case .BITWISE_OR_EQUAL; #through;
        case .BITWISE_OR;       return .BITWISE_OR;

        case .BITWISE_XOR_EQUAL; #through;
        case .BITWISE_XOR;       return .BITWISE_XOR;

        case .NOT_EQUAL;      return .NOT_EQUAL;
        case .EQUAL_EQUAL;    return .EQUAL_EQUAL;
        case .GREATER;        return .GREATER;
        case .GREATER_EQUAL;  return .GREATER_EQUAL;
        case .LESS;           return .LESS;
        case .LESS_EQUAL;     return .LESS_EQUAL;
        case .AND;            return .AND;
        case .OR;             return .OR;
    }
    parse_err(parser, "Wanted binary operator found %", token_type);
    return .ADD;
}

consume :: (using parser: *Parser) -> Token {
    defer current += 1;
    return peek(parser);
}

consume :: (parser: *Parser, token_type: Token_Type) -> Token {
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

#import "Basic";
#import "String";
#import "Memory";
#import "Lexer";
#import "Compiler_Util";
#import "Not_Basic";
