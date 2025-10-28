Parser :: struct {
    tokens:         []Token;
    start, current: int = 0;
    error_reporter: *Error_Reporter;
}

parse_ast :: (tokens: []Token, error_reporter: *Error_Reporter, debug_log: bool = false) -> *Program {
    parser := Parser.{ tokens = tokens, error_reporter = error_reporter };

    program := parse_program(*parser);
    if !is_at_end(*parser) parse_err(*parser, "All token not consumed\n");

    if debug_log print_program_ast(*stdout_writer_new(), program);

    return program;
}

#scope_module

parse_err :: (parser: *Parser, msg_fmt: string, args: .. Any) #expand {
    token := peek(parser);
    parse_err(parser, token, msg_fmt, .. args);
}

parse_err :: (parser: *Parser, token: Token, msg_fmt: string, args: .. Any) #expand {
    error_report(parser.error_reporter, token.line, token.start, msg_fmt, .. args);
    // If we encounter parser error, we can't know where we can continue from, so panic
    // TODO(seg4lt): maybe we need to propagate error up the chain
    print_errors(parser.error_reporter, panic = true);
    parser.current = parser.tokens.count;
}

#scope_file

parse_program :: (parser: *Parser) -> *Program {
    decls: [..]*Decl;
    while !is_at_end(parser)
        array_add(*decls, parse_decl(parser, only_fn_decl = false));
    return Program.new(decls);
}

parse_fn_decl :: (parser: *Parser, only_decl: bool = false) -> *Fn_Decl {
    ret_type, storage_class := parse_type_and_storage_class_for_decl(parser);

    using ident_token := consume(parser, .IDENT);

    consume(parser, .LPAREN);
    params := parse_fn_params(parser);
    consume(parser, .RPAREN);

    if peek(parser).type == .SEMICOLON {
        consume(parser, .SEMICOLON);
        return Fn_Decl.new(value, params, null, storage_class, line, start);
    }

    body := parse_block(parser);
    return Fn_Decl.new(value, params, body, storage_class, line, start);
}

parse_fn_params :: (parser: *Parser) -> [..]*Fn_Decl.Fn_Param {
    params: [..]*Fn_Decl.Fn_Param;
    if peek(parser).type == .VOID {
        consume(parser, .VOID);
        return params;
    }
    while peek(parser).type != .RPAREN {
        // we only support int type for now
        type := consume(parser, .INT);
        ident := consume(parser, .IDENT);

        fn_param := New(Fn_Decl.Fn_Param, .{ ident = ident.value, line = ident.line, start = ident.start });
        array_add(*params, fn_param);

        if peek(parser).type == .COMMA {
            consume(parser, .COMMA);
            if peek(parser).type == .RPAREN parse_err(parser, "trailing comma on parameter list is not allowed");
        }
    }
    return params;
}

parse_block :: (parser: *Parser) -> *Block {
    start_tok := consume(parser, .LCURLY);
    body: [..]*Block_Item;

    while peek(parser).type != .RCURLY array_add(*body, parse_block_item(parser));

    consume(parser, .RCURLY);
    return Block.new(body, start_tok.line, start_tok.start);
}

parse_block_item :: (parser: *Parser) -> *Block_Item {
    if is_decl(parser) {
        decl := parse_decl(parser, only_fn_decl = true);
        return Block_Item_Decl.new(decl);
    }

    if peek(parser).type == .SEMICOLON {
        tok := consume(parser);
        stmt := Stmt_Null.new(tok.line, tok.start);
        return Block_Item_Stmt.new(stmt);
    }
    stmt := parse_stmt(parser);
    return Block_Item_Stmt.new(stmt);
}


is_fn_decl :: (parser: *Parser) -> bool {
    peek_offset := 0;
    while is_decl(parser, peek_offset) peek_offset += 1;

    if peek_offset < 1 return false; // expect at least return type

    if peek(parser, peek_offset).type != .IDENT return false;
    peek_offset += 1;

    if peek(parser, peek_offset).type != .LPAREN return false;

    return true;
}

is_decl :: (parser: *Parser, offset: int = 0) -> bool {
    if peek(parser, offset).type == {
        case .INT;    #through;
        case .STATIC; #through;
        case .EXTERN; return true;
        case;         return false;
    }
    return false;
}

parse_type_and_storage_class_for_decl :: (parser: *Parser) -> (string, Storage_Class) {
    types: [..]string;
    storage_classes: [..]Storage_Class;

    while (true) {
        using token := peek(parser);
        if type == {
            case .INT;    consume(parser); array_add(*types, value);
            case .STATIC; consume(parser); array_add(*storage_classes, .STATIC);
            case .EXTERN; consume(parser); array_add(*storage_classes, .EXTERN);
            case;         break;
        }
    }
    if types.count != 1 parse_err(parser, "decl can only have one type. Found `%`", types);
    if storage_classes.count > 1 parse_err(parser, "decl can only have one storage class found `%`", storage_classes);

    return types[0],
           ifx storage_classes.count == 0 then .NONE else storage_classes[0];
}

parse_decl :: (parser: *Parser, only_fn_decl: bool) -> *Decl {
    if is_fn_decl(parser) {
        fn_decl_ast := parse_fn_decl(parser, only_decl = only_fn_decl);
        return Fn_Decl.as_decl(fn_decl_ast);
    }
    _, storage_class := parse_type_and_storage_class_for_decl(parser);
    using ident_tok := consume(parser);
    if is_digit(value.data.*) parse_err(parser, "identifier should not start with digit");

    expr := null;
    if peek(parser).type == .ASSIGN {
        consume(parser);
        expr = parse_expr(parser, 0);
    }
    consume(parser, .SEMICOLON);
    return Var_Decl.new(value, expr, storage_class, line, start);
}

parse_stmt :: (parser: *Parser) -> *Stmt {
    if peek(parser).type == {
        case .LCURLY;
            body := parse_block(parser);
            return Stmt_Compound.new(body);
        case .BREAK;
            using break_tok := consume(parser);
            stmt := Stmt_Break.new(line, start);
            consume(parser, .SEMICOLON);
            return stmt;
        case .CONTINUE;
            using continue_tok := consume(parser);
            consume(parser, .SEMICOLON);
            return Stmt_Continue.new(line, start);
        case .WHILE;
            return parse_while_stmt(parser) ;
        case .DO;
            return parse_do_while_stmt(parser);
        case .FOR;
            return parse_for_stmt(parser);
        case .RETURN;
            return parse_return_stmt(parser);
        case .IF;
            return parse_if_stmt(parser);
        case .SWITCH;
            return parse_switch_stmt(parser);
        case .CASE;
            consume(parser, .CASE);
            using token := consume(parser, .INT_LITERAL);
            consume(parser, .COLON);
            return Stmt_Case.new(value, line, start);
        case .DEFAULT;
            using token := consume(parser, .DEFAULT);
            consume(parser, .COLON);
            return Stmt_Default.new(line, start);
        case .GOTO;
            consume(parser, .GOTO);
            using token := consume(parser, .IDENT);
            consume(parser, .SEMICOLON);
            return Stmt_Goto.new(value, line, start);
        case .SEMICOLON;
            using null_tok := consume(parser, .SEMICOLON);
            return Stmt_Null.new(line, start);
    }
    // .LABEL;
    if peek(parser).type == .IDENT && peek(parser, 1).type == .COLON {
        using token := consume(parser, .IDENT);
        consume(parser, .COLON);
        label_stmt := parse_stmt(parser);
        return Stmt_Label.new(value, label_stmt, line, start);
    }
    using expr := parse_expr(parser, 0);
    consume(parser, .SEMICOLON);
    return Stmt_Expr.new(expr, line, start);
}

parse_switch_stmt :: (parser: *Parser) -> *Stmt {
    switch_tok := consume(parser, .SWITCH);
    consume(parser, .LPAREN);

    condition := parse_expr(parser, 0);
    consume(parser, .RPAREN);

    body: [..]*Block_Item;
    if peek(parser).type == .LCURLY {
        consume(parser, .LCURLY);

        case_found := false;
        while peek(parser).type != .RCURLY {
            peeked_token := peek(parser);
            item := parse_block_item(parser);
            if item.kind == .STMT {
                item_stmt := cast(*Block_Item_Stmt) item;
                if item_stmt.stmt.kind == .CASE || item_stmt.stmt.kind == .DEFAULT {
                    case_found = true;
                }
            }

            if case_found && item.kind == .DECL {
                item_decl := cast(*Block_Item_Decl) item;
                if !is_static_decl(item_decl.decl) {
                    parse_err(parser, peeked_token, "switch case should not have decl");
                }
            }
            array_add(*body, item);
        }
        consume(parser, .RCURLY);
        return Stmt_Switch.new(condition, body, switch_tok.line, switch_tok.start);
    }
    // if switch doesn't have block `{}` then it might have one case stmt
    block_item := parse_block_item(parser);
    array_add(*body, block_item);

    if block_item.kind == .STMT {
        item_stmt := cast(*Block_Item_Stmt) block_item;
        if item_stmt.stmt.kind == .CASE {
            case_stmt := parse_block_item(parser);
            array_add(*body, case_stmt);
        }
    }
    return Stmt_Switch.new(condition, body, switch_tok.line, switch_tok.start);
}

is_static_decl :: (decl: Decl) -> bool {
    if decl.kind != .VAR return false;
    var_decl := cast(*Var_Decl) *decl;
    return var_decl.storage_class == .EXTERN || var_decl.storage_class == .STATIC;
}

parse_while_stmt :: (parser: *Parser) -> *Stmt {
    using while_token := consume(parser, .WHILE);

    consume(parser, .LPAREN);
    condition := parse_expr(parser, 0);
    consume(parser, .RPAREN);

    body := parse_stmt(parser);
    return Stmt_While.new(condition, body, line, start);
}

parse_do_while_stmt :: (parser: *Parser) -> *Stmt {
    using do_token := consume(parser, .DO);
    body := parse_stmt(parser);

    consume(parser, .WHILE);

    consume(parser, .LPAREN);
    condition := parse_expr(parser, 0);
    consume(parser, .RPAREN);

    consume(parser, .SEMICOLON);

    return Stmt_Do_While.new(body, condition, line, start);
}

parse_for_init :: (parser: *Parser) -> *For_Init {
    peek_token := peek(parser);
    if is_decl(parser) {
        decl := parse_decl(parser, only_fn_decl = true);
        if decl.kind != .VAR {
            parse_err(parser, peek_token, "Expected variable declaration in for loop init, found %", decl.kind);
            return null;
        }
        return For_Init_Decl.new(decl);
    }

    expr := parse_optional_expr(parser, 0);
    return For_Init_Expr.new(expr);
}

parse_for_stmt :: (parser: *Parser) -> *Stmt {
    for_tok := consume(parser, .FOR);
    consume(parser, .LPAREN);

    for_init := parse_for_init(parser);
    if for_init.kind == .EXPR consume(parser, .SEMICOLON);

    condition := parse_optional_expr(parser, 0);
    consume(parser, .SEMICOLON);

    post := ifx peek(parser).type == .RPAREN null
            else parse_expr(parser, 0);

    consume(parser, .RPAREN);

    body := parse_stmt(parser);

    return Stmt_For.new(for_init, condition, post, body, for_tok.line, for_tok.start);
}

parse_if_stmt :: (parser: *Parser) -> *Stmt {
    using if_tok := consume(parser, .IF);
    consume(parser, .LPAREN);
    condition := parse_expr(parser, 0);
    consume(parser, .RPAREN);

    if_block := parse_stmt(parser);

    else_block := null;
    if peek(parser).type == .ELSE {
        consume(parser, .ELSE);
        else_block = parse_stmt(parser);
    }

    return Stmt_If.new(condition, if_block, else_block, line, start);
}

parse_return_stmt :: (parser: *Parser) -> *Stmt {
    using ret_tok := consume(parser, .RETURN);
    expr := parse_expr(parser, 0);
    consume(parser, .SEMICOLON);
    return Stmt_Return.new(expr, line, start);
}

parse_optional_expr :: (parser: *Parser, min_prec: int) -> *Expr {
    if peek(parser).type == .SEMICOLON return null;
    return parse_expr(parser, min_prec);
}

parse_expr :: (parser: *Parser, min_prec: int)  -> *Expr {
    left := parse_factor(parser);
    next_token := peek(parser);

    while is_binary_operator(next_token.type) && precedence(parser, next_token.type) >= min_prec {
        if next_token.type == .ASSIGN {
            assign_tok := consume(parser);
            right := parse_expr(parser, precedence(parser, next_token.type));
            assignment := Expr_Assignment.new(left, right, assign_tok.line, assign_tok.start);
            left = assignment;
        } else if is_compound_assignment_operator(next_token.type) {
            op_tok := consume(parser);
            op := parse_binary_op(parser, op_tok.type);
            right := parse_expr(parser, precedence(parser, next_token.type));

            // @note
            // cloning here because on sema phase we replace variable identifier
            // if we use same pointer, it will look for updated name on our map which is wrong
            left_clone := expr_clone(left);

            binary := Expr_Binary.new(op, left_clone, right, op_tok.line, op_tok.start);
            assignment := Expr_Assignment.new(left, binary, op_tok.line, op_tok.start);

            left = assignment;
        } else if next_token.type == .QUESTION_MARK {
            q_tok := consume(parser, .QUESTION_MARK);
            true_block := parse_expr(parser, 0);
            consume(parser, .COLON);
            false_block := parse_expr(parser, precedence(parser, next_token.type));
            conditional := Expr_Ternary.new(left, true_block, false_block, q_tok.line, q_tok.start);
            left = conditional;
        } else {
            op_tok := consume(parser);
            op := parse_binary_op(parser, op_tok.type);
            right := parse_expr(parser, precedence(parser, next_token.type) + 1);
            binary := Expr_Binary.new(op, left, right, op_tok.line, op_tok.start);
            left = binary;
        }
        next_token = peek(parser);
    }
    return left;
}

parse_factor :: (parser: *Parser) -> *Expr {
    if peek(parser).*.type ==  {
        case .INT_LITERAL;
            int_literal := consume(parser, .INT_LITERAL);
            int_value, success := string_to_int(int_literal.value);
            if !success  parse_err(parser, "expected int found %", int_literal.value);
            return Expr_Constant.new(int_value, int_literal.line , int_literal.start);
        case .MINUS; #through;
        case .NOT; #through;
        case .BITWISE_NOT;
            op_tok := consume(parser);
            op := parse_unary_op(parser, op_tok.type);
            inner_expr := parse_factor(parser);
            expr := Expr_Unary.new(op, inner_expr, op_tok.line, op_tok.start);
            return expr;
        case .MINUS_MINUS; #through;
        case .PLUS_PLUS;
            prefix_op_token := consume(parser);
            inner_expr := parse_factor(parser);
            op: Prefix_Operator = ---;
            if prefix_op_token.type == {
                case .MINUS_MINUS; op = .SUBTRACT;
                case .PLUS_PLUS;   op = .ADD;
                case; unreachable("** compiler bug ** only incr/decr operator support in this path");
            }
            return Expr_Prefix.new(op, inner_expr, prefix_op_token.line, prefix_op_token.start);
        case .LPAREN;
            grp_start_tok := consume(parser, .LPAREN);
            inner_expr := parse_expr(parser, 0);
            expr := Expr_Group.new(inner_expr, grp_start_tok.line, grp_start_tok.start);
            consume(parser, .RPAREN);
            return parse_postfix_expr_ast(parser, expr);
        case .IDENT;
            using ident := consume(parser);
            expr := ifx peek(parser).*.type != .LPAREN
                          Expr_Var.new(value, line, start)
                    else  Expr_Fn_Call.new(value, parse_args_expr(parser), line, start);
            return parse_postfix_expr_ast(parser, expr);
    }
    parse_err(parser, "This expression is not something I can handle. Duh!! %", print_vars(peek(parser).*));
    return null;
}

parse_args_expr :: (parser: *Parser) -> [..]*Expr {
    args: [..]*Expr;
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

parse_postfix_expr_ast :: (parser: *Parser, inner_expr: *Expr) -> *Expr {
    if peek(parser).type != .MINUS_MINUS && peek(parser).type != .PLUS_PLUS return inner_expr;

    using postfix_op_token := consume(parser);
    op: Postfix_Operator = ---;
    if type == {
        case .MINUS_MINUS; op = .SUBTRACT;
        case .PLUS_PLUS;   op = .ADD;
        case; unreachable("** compiler bug ** only incr/decr operator support in this path");
    }
    return Expr_Postfix.new(op, inner_expr, line, start);
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

parse_postfix_enum :: (parser: *Parser, tt: Token_Type) -> Postfix_Operator {
    if tt == {
        case .MINUS_MINUS; return .SUBTRACT;
        case .PLUS_PLUS;   return .ADD;
        case;              parse_err(parser, "Wanted postfix unary operator found %", tt);
    }
    parse_err(parser, "Wanted postfix unary operator found %", tt);
    return 0;
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

// This is more or less trying to deep clone the expr
// Maybe I need to find a way to not do this and make it work
expr_clone :: (expr: *Expr) -> *Expr {
    if expr.kind == {
        case .VAR;
            using expr_var := cast(*Expr_Var) expr;
            // we can just use new if we use using, but is this confusing ???
            return new(expr_var.ident, expr_var.line, expr_var.start);
        case .CONSTANT;
            expr_constant := cast(*Expr_Constant) expr;
            return Expr_Constant.new(expr_constant.value, expr_constant.line, expr_constant.start);
        case .UNARY;
            expr_unary := cast(*Expr_Unary) expr;
            return Expr_Unary.new(expr_unary.op, expr_clone(expr_unary.expr), expr_unary.line, expr_unary.start);
        case .BINARY;
            expr_binary := cast(*Expr_Binary) expr;
            return Expr_Binary.new(expr_binary.op, expr_clone(expr_binary.left), expr_clone(expr_binary.right), expr_binary.line, expr_binary.start);
        case .GROUP;
            expr_group := cast(*Expr_Group) expr;
            return Expr_Group.new(expr_clone(expr_group.expr), expr_group.line, expr_group.start);
        case .POSTFIX;
            expr_postfix := cast(*Expr_Postfix) expr;
            return Expr_Postfix.new(expr_postfix.op, expr_clone(expr_postfix.expr), expr_postfix.line, expr_postfix.start);
        case .PREFIX;
            expr_prefix := cast(*Expr_Prefix) expr;
            return Expr_Prefix.new(expr_prefix.op, expr_clone(expr_prefix.expr), expr_prefix.line, expr_prefix.start);
        case .ASSIGNMENT;
            expr_assignment := cast(*Expr_Assignment) expr;
            return Expr_Assignment.new(expr_clone(expr_assignment.dst), expr_clone(expr_assignment.src), expr_assignment.line, expr_assignment.start);
        case .TERNARY;
            expr_ternary := cast(*Expr_Ternary) expr;
            return Expr_Ternary.new(expr_clone(expr_ternary.condition), expr_clone(expr_ternary.true_expr), expr_clone(expr_ternary.false_expr), expr_ternary.line, expr_ternary.start);
        case .FN_CALL;
            expr_fn_call := cast(*Expr_Fn_Call) expr;
            cloned_args: [..]*Expr;
            for expr_fn_call.args {
                array_add(*cloned_args, expr_clone(it));
            }
            return Expr_Fn_Call.new(expr_fn_call.ident, cloned_args, expr_fn_call.line, expr_fn_call.start);
    }
    assert(false, "Unhandled expression type in clone");
    return null;
}

parse_unary_op :: (parser: *Parser, token_type: Token_Type) -> Unary_Operator {
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
    if is_at_end(parser, offset) || error_reporter.error_items.count >= 1 return null;
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

#scope_file
#import "Print_Vars";
using Ast;
