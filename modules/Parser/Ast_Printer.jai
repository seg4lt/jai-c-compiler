print_program_ast :: (writer: *Writer, program: *Program_Ast, depth: int = 0) {
    write(writer, "-- AST --\n");
    write(writer, "[PROGRAM]・");
    print_fn_ast(writer, program.fn, depth + 1);
    write(writer, "\n");
}

print_fn_ast :: (writer: *Writer, fn: *Fn_Ast, depth: int = 0) {
    print_space(writer, depth);
    write(writer, "[FN]・%", fn.ident);
    print_block_ast(writer, fn.block, depth + 1);
}

print_block_ast :: (writer: *Writer, block: *Block_Ast, depth: int = 0) {
    print_space(writer, depth);
    write(writer, "[BLOCK]");
    for block.items {
        print_space(writer, depth + 1);
        if #complete it.type == {
            case .STMT; print_stmt_ast(writer, it.as.stmt, depth + 1);
            case .DECL; print_decl_ast(writer, it.as.decl, depth + 1);
        }
    }
}

print_decl_ast :: (writer: *Writer, using decl: *Decl_Ast, depth: int = 0)  {
    write(writer, "[DECL]・");
    write(writer, "%", ident);
    if init != null {
        write(writer, "・=・");
        print_expr_ast(writer, init, depth + 1);
    }
}

print_stmt_ast :: (writer: *Writer, stmt: *Stmt_Ast, depth: int = 0)  {
    if #complete stmt.type == {
        case .DEFAULT;
            write(writer, "[DEFAULT]・%", stmt.as.default);
            print_space(writer, depth + 1);
        case .CASE; 
            write(writer, "[CASE]・%・% ", stmt.as.case_stmt.value, stmt.as.case_stmt.label);
        case .RETURN;
            write(writer, "[RETURN]・");
            print_space(writer, depth+1);
            print_expr_ast(writer, stmt.as.return_stmt.expr, depth+1);
        case .SWITCH;
            switch_stmt := stmt.as.switch;
            write(writer, "[SWITCH]・% ", switch_stmt.label);
            write(writer, "( ");
            print_expr_ast(writer, switch_stmt.condition, depth + 1);
            write(writer, " )");
            print_space(writer, depth + 1);
            for switch_stmt.body {
                if #complete it.type == {
                    case .STMT; print_stmt_ast(writer, it.as.stmt, depth + 1);
                    case .DECL; print_decl_ast(writer, it.as.decl, depth + 1);
                }
                print_space(writer, depth + 1);
            }
        case .EXPR;
            write(writer, "[EXPR]・");
            print_space(writer, depth + 1);
            print_expr_ast(writer, stmt.as.return_stmt.expr, depth+1);
        case .NULL;
            write(writer, "[NULL_STMT]");
        case .IF;
            write(writer, "[IF]");
            print_space(writer, depth + 1);
            print_expr_ast(writer, stmt.as.if_stmt.condition, depth + 1);
            print_space(writer, depth + 2);
            print_stmt_ast(writer, stmt.as.if_stmt.if_block, depth + 2);
            if stmt.as.if_stmt.else_block != null {
                print_space(writer, depth);
                write(writer, "[ELSE]");
                print_space(writer, depth + 2);
                print_stmt_ast(writer, stmt.as.if_stmt.else_block, depth + 2); 
            }
        case .LABEL;
            write(writer, "[LABEL]・%", stmt.as.label.label);
            print_space(writer, depth + 1);
            print_stmt_ast(writer, stmt.as.label.stmt, depth + 1);
        case .GOTO;
            write(writer, "[GOTO]・%", stmt.as.goto);
            print_space(writer, depth + 1);
        case .COMPOUND;
            write(writer, "[COMPOUND]");
            print_block_ast(writer, stmt.as.compound, depth + 2);
        case .CONTINUE;
            write(writer, "[CONTINUE]・%", stmt.as.continue_stmt);
        case .BREAK;
            write(writer, "[BREAK]・%", stmt.as.break_stmt);
        case .FOR;
            for_stmt := stmt.as.for_stmt;
            write(writer, "[FOR]・%", for_stmt.label);
            print_space(writer, depth + 1);
            write(writer, "<init>・");
            if #complete for_stmt.init.type == {
                case .INIT_DECL;
                    print_decl_ast(writer, for_stmt.init.as.decl, depth + 1);
                case .INIT_EXPR;
                    if for_stmt.init.as.expr != null {
                        print_expr_ast(writer, for_stmt.init.as.expr, depth + 1);
                    }
            }
            print_space(writer, depth + 1);
            write(writer, "<condition>・");
            if for_stmt.condition != null {
                print_expr_ast(writer, for_stmt.condition, depth + 1);
            }
            print_space(writer, depth + 1);
            write(writer, "<post>・");
            if for_stmt.post != null  {
                print_expr_ast(writer, for_stmt.post, depth + 1);
            }
            print_space(writer, depth + 1);
            print_stmt_ast(writer, for_stmt.body, depth + 1);
        case .WHILE;
            while_stmt := stmt.as.while_stmt;
            write(writer, "[WHILE]・%・", while_stmt.label);
            print_expr_ast(writer, while_stmt.condition, depth);
            print_space(writer, depth + 1);
            print_stmt_ast(writer, while_stmt.body, depth + 1);
        case .DO_WHILE;
            do_while_stmt := stmt.as.do_while;
            write(writer, "[DO]・%・", do_while_stmt.label);
            // print_space(depth + 1);
            print_stmt_ast(writer, do_while_stmt.body, depth + 1);
            print_space(writer, depth);
            write(writer, "[DO_WHILE]・%・", do_while_stmt.label);
            print_expr_ast(writer, do_while_stmt.condition, depth +1);
    }
}

print_expr_ast :: (writer: *Writer, expr: *Expr_Ast, depth: int = 0) {
    if #complete expr.type == {
        case .CONSTANT;
            write(writer, "%", expr.as.constant);
        case .UNARY;
            write(writer, "[UNARY]・");
            write(writer, "%", expr.as.unary.op);
            print_space(writer, depth + 1);
            print_expr_ast(writer, expr.as.unary.expr, depth + 1);
        case .BINARY;
            write(writer, "[BINARY]・");
            write(writer, "%", expr.as.binary.op);
            print_space(writer, depth + 1);
            print_expr_ast(writer, expr.as.binary.left, depth + 1);
            print_space(writer, depth + 1);
            print_expr_ast(writer, expr.as.binary.right, depth + 1);
        case .GROUP;
            write(writer, "[GROUP]・");
            print_space(writer, depth + 1);
            print_expr_ast(writer, expr.as.group, depth + 1);
        case .VAR;
            write(writer, "[VAR]・%・", expr.as.var);
        case .ASSIGNMENT;
            write(writer, "[ASSIGNMENT]・");
            print_expr_ast(writer, expr.as.assignment.dst, depth);
            write(writer, "・=・");
            print_expr_ast(writer, expr.as.assignment.src, depth);
        case .CONDITIONAL;
            write(writer, "[TERNARY]");
            print_space(writer, depth + 1);
            print_expr_ast(writer, expr.as.conditional.condition, depth);
            print_space(writer, depth + 1);
            write(writer, "・?・");
            print_expr_ast(writer, expr.as.conditional.true_block, depth+2);
            print_space(writer, depth + 1);
            write(writer, "・:・");
            print_expr_ast(writer, expr.as.conditional.false_block, depth+2);
    }
    if #complete expr.postfix  == {
        case .INCR; write(writer, "[POSTFIX]・++");
        case .DECR; write(writer, "[PREFIX]・--");
        case .NONE;
    }
}

print_space :: (writer: *Writer, depth: int = 0) {
    write(writer, "\n");
    for 0..depth-1 write(writer, "┊﹣");
}

#import "Not_Basic";
