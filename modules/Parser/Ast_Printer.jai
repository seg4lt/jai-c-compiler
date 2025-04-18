print_program_ast :: (program: *Program_Ast, depth: int = 0) {
    print("\n\n -- AST -- \n");
    print("[PROGRAM] ");
    print_fn_ast(program.fn, depth + 1);
    print("\n\n");
}

print_fn_ast :: (fn: *Fn_Ast, depth: int = 0) {
    print_space(depth);
    print("[FN] %", fn.ident);
    print_block_ast(fn.block, depth + 1);
}

print_block_ast :: (block: *Block_Ast, depth: int = 0) {
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

print_decl_ast :: (using decl: *Decl_Ast, depth: int = 0)  {
    print("[DECL] ");
    print("%", ident);
    if init != null {
        print(" = ");
        print_expr_ast(init, depth + 1);
    }
}

print_stmt_ast :: (stmt: *Stmt_Ast, depth: int = 0)  {
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

print_expr_ast :: (expr: *Expr_Ast, depth: int = 0) {
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
