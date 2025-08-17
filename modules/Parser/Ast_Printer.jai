print_program_ast :: (writer: *Writer, pg: *Program_Ast) {
    write(writer, "-- AST --\n");
    for fn_decl: pg.fns {
        print_fn_decl_ast(writer, fn_decl, 1);
        write(writer, "\n");
    }
    write(writer, "\n");
}

print_fn_decl_ast :: (writer: *Writer, fn_decl: *Fn_Decl_Ast, depth: int) {
    if fn_decl.block != null print_space(writer, depth);
    write(writer, "int %( ", fn_decl.ident);
    for param: fn_decl.params {
        if fn_decl.block != null write(writer, "int ");
        write(writer, "%", param.ident);
        if it_index < fn_decl.params.count - 1 write(writer, ", ");
    }
    write(writer, " )");

    if fn_decl.block != null {
        body := fn_decl.block;
        write(writer, "\n");
        print_space(writer, depth);
        write(writer, "{\n");
        print_block_ast(writer, body, depth + 1, true);
        print_space(writer, depth);
        write(writer, "}");
    } else {
        write(writer, ";\n");
    }
}

print_block_ast :: (writer: *Writer, block: *Block_Ast, depth: int, new_line: bool) {
    for item: block.items {
        print_space(writer, depth);
        print_block_item_ast(writer, item, depth, new_line);
    }
}

print_block_item_ast :: (writer: *Writer, block_item: *Block_Item_Ast, depth: int, new_line: bool) {
    if #complete block_item.type == {
        case .STMT;
            stmt := block_item.as.stmt;
            print_stmt_ast(writer, stmt, depth);
        case .DECL;
            decl := block_item.as.decl;
            print_decl_ast(writer, decl, depth, new_line);
    }
}

print_decl_ast :: (writer: *Writer, decl: *Decl_Ast, depth: int, new_line: bool) {
    if #complete decl.type == {
        case .FN;
            fn_decl := decl.as.fn;
            print_fn_decl_ast(writer, fn_decl, depth);
        case .VAR;
            var := decl.as.var;
            print_var_decl_ast(writer, var, depth, new_line);
    }
}

print_var_decl_ast :: (writer: *Writer, var_decl: *Var_Decl_Ast, depth: int, new_line: bool) {
    _ = depth;
    write(writer, "int ");
    write(writer, "%", var_decl.ident);
    if var_decl.init != null {
        initializer := var_decl.init;
        write(writer, " = ");
        print_expr_ast(writer, initializer);
    }
    if new_line write(writer, ";\n");
}

print_if_stmt_ast :: (writer: *Writer, stmt: *Stmt_Ast, depth: int) {
    if stmt.type != .IF unreachable("** compiler bug ** wanted if statement got %", stmt.type);
    if_stmt := stmt.as.if_stmt;

    write(writer, "if (");
    print_expr_ast(writer, if_stmt.condition);
    write(writer, ")\n");

    if_depth := ifx if_stmt.if_block.type == .COMPOUND depth else depth + 1;
    print_space(writer, if_depth);
    print_stmt_ast(writer, if_stmt.if_block, if_depth);
    if if_stmt.else_block {
        else_stmt := if_stmt.else_block;
        if if_stmt.if_block.type == .COMPOUND write(writer, "\n");
        
        print_space(writer, depth);
        write(writer, "else");
        if (else_stmt.type == .IF) {
            write(writer, " ");
            print_if_stmt_ast(writer, else_stmt, depth);
        } else {
            write(writer, "\n");
            else_depth := ifx if_stmt.if_block.type == .COMPOUND depth else depth + 1;
            print_space(writer, else_depth);
            print_stmt_ast(writer, else_stmt, else_depth);
        }
    }
    write(writer, "\n");
}

print_do_while_stmt_ast :: (writer: *Writer, stmt: *Stmt_Ast, depth: int) {
    if stmt.type != .DO_WHILE unreachable("** compiler bug ** wanted do while statement got %", stmt.type);
    do_while := stmt.as.do_while;
    write(writer, "do\n");
    print_space(writer, depth);
    do_depth := ifx (do_while.body.type == .COMPOUND) depth else depth + 1;
    print_stmt_ast(writer, do_while.body, do_depth);
    write(writer, " while ( ");
    print_expr_ast(writer, do_while.condition);
    write(writer, " );\n");
}

print_while_stmt_ast :: (writer: *Writer, stmt: *Stmt_Ast, depth: int) {
    if stmt.type != .WHILE unreachable("** compiler bug ** wanted while statement got %", stmt.type);
    while_stmt := stmt.as.while_stmt;
    
    write(writer, "while ( ");
    print_expr_ast(writer, while_stmt.condition);
    write(writer, " )\n");

    while_depth := ifx while_stmt.body.type == .COMPOUND depth else depth + 1;

    print_space(writer, depth);
    print_stmt_ast(writer, while_stmt.body, while_depth);
    write(writer, "\n");
}

print_for_stmt_ast :: (writer: *Writer, stmt: *Stmt_Ast, depth: int) {
    if stmt.type != .FOR unreachable("** compiler bug ** wanted for statement got %", stmt.type);
    for_stmt := stmt.as.for_stmt;
    
    write(writer, "for (");
    if #complete for_stmt.init.type == {
        case .INIT_DECL;
            decl := for_stmt.init.as.decl;
            print_decl_ast(writer, decl, depth + 1, false);
        case .INIT_EXPR;
            expr := for_stmt.init.as.expr;
            if expr print_expr_ast(writer, expr);
    }
    write(writer, " ; ");

    if for_stmt.condition {
        print_expr_ast(writer,  for_stmt.condition);
    }
    write(writer, " ; ");

    if for_stmt.post {
        print_expr_ast(writer, for_stmt.post);
    }

    write(writer, " )\n");

    print_space(writer, depth);
    for_depth := ifx for_stmt.body.type == .COMPOUND depth else depth + 1;
    print_stmt_ast(writer, for_stmt.body, for_depth);
    write(writer, "\n");
}

print_stmt_ast :: (writer: *Writer, stmt: *Stmt_Ast, depth: int) {
    if #complete stmt.type == {
        case .SWITCH; 
            switch_stmt := stmt.as.switch;
            write(writer, "switch (");
            print_expr_ast(writer, switch_stmt.condition);
            write(writer, ")\n");
            print_space(writer, depth);
            write(writer, "{\n");
            for item: switch_stmt.body {
                if (item.type == .STMT && item.as.stmt.type == .CASE) {
                    print_space(writer, depth + 1);
                } else if (item.type == .STMT && item.as.stmt.type == .DEFAULT) {
                    print_space(writer, depth + 1);
                } else {
                    print_space(writer, depth + 2);
                }
                print_block_item_ast(writer, item, depth, true);
            }
            print_space(writer, depth);
            write(writer, "}\n");
        case .CASE;
            case_stmt := stmt.as.case_stmt;
            write(writer, "case ");
            write(writer, "%:\n", case_stmt.value);
        case .DEFAULT;
            write(writer, "default:\n");
        case .BREAK;
            write(writer, "break");
            write(writer, ";\n");
        case .CONTINUE; 
            write(writer, "continue");
            write(writer, ";\n");
        case .DO_WHILE;
            print_do_while_stmt_ast(writer, stmt, depth);
        case .WHILE;
            print_while_stmt_ast(writer, stmt, depth);
        case .FOR;
            print_for_stmt_ast(writer, stmt, depth);
        case .LABEL;
            label_stmt := stmt.as.label;
            write(writer, "%:\n", label_stmt.label);
            print_stmt_ast(writer, label_stmt.stmt, depth + 1);
        case .GOTO;
            goto_stmt := stmt.as.goto;
            write(writer, "goto %;\n", goto_stmt);
        case .IF; 
            print_if_stmt_ast(writer, stmt, depth);
        case .COMPOUND;
            compound_stmt := stmt.as.compound;
            write(writer, "{\n");
            print_block_ast(writer, compound_stmt, depth + 1, true);
            print_space(writer, depth);
            write(writer, "}");
        case .RETURN;
            return_stmt := stmt.as.return_stmt;
            write(writer, "return");
            write(writer, " ");
            print_expr_ast(writer, return_stmt.expr);
            write(writer, ";\n");
        case .EXPR;
            expr := stmt.as.expr;
            print_expr_ast(writer, expr);
            write(writer, ";\n");
        case .NULL;
            write(writer, ";\n");
    }
}
print_expr_ast :: (writer: *Writer, expr: *Expr_Ast) {
    if #complete expr.type == {
        case .PREFIX;
           prefix_expr := expr.as.prefix_expr;
            write(writer, "%", ifx prefix_expr.op == .ADD "++" else "--");
            print_expr_ast(writer, prefix_expr.expr);
        case .FN_CALL;
            fn_call_expr := expr.as.fn_call;
            write(writer, "%(", fn_call_expr.ident);
            for arg: fn_call_expr.args {
                print_expr_ast(writer, arg);
                if (it_index < fn_call_expr.args.count - 1) write(writer, ", ");
            }
            write(writer, ")");
        case .TERNARY; 
            ternary_expr := expr.as.ternary;
            print_expr_ast(writer, ternary_expr.condition);
            write(writer, " ? ");
            print_expr_ast(writer, ternary_expr.true_expr);
            write(writer, " : ");
            print_expr_ast(writer, ternary_expr.false_expr);
        case .VAR;
            var_expr := expr.as.var;
            write(writer, "%", var_expr);
        case .POSTFIX; 
            postfix_expr := expr.as.postfix_expr;
            print_expr_ast(writer, postfix_expr.expr);
            if #complete postfix_expr.op == {
                case .ADD; write(writer, "++");
                case .SUBTRACT; write(writer, "--");
            }
        case .GROUP;
            group_expr := expr.as.group;
            write(writer, "(");
            print_expr_ast(writer, group_expr);
            write(writer, ")");
        case .ASSIGNMENT;
            assignment_expr := expr.as.assignment;
            print_expr_ast(writer, assignment_expr.dst);
            write(writer, " = ");
            print_expr_ast(writer, assignment_expr.src);
        case .CONSTANT;
            constant_expr := expr.as.constant;
            write(writer, "%", constant_expr);
        case .UNARY;
            unary_expr := expr.as.unary;
            write(writer, "(");
            op : string = ---;
            if #complete unary_expr.op == {
                case .NEGATE; op =  "-";
                case .BITWISE_NOT; op =  "~";
                case .NOT; op =  "!";
            }
            write(writer, "%", op);
            print_expr_ast(writer, unary_expr.expr);
            write(writer, ")");
        case .BINARY;
            binary_expr := expr.as.binary;
            write(writer, "(");
            print_expr_ast(writer, binary_expr.left);
            op: string = ---;
            if #complete binary_expr.op == {
                case .ADD; op = "+";
                case .SUB; op = "-";
                case .MUL; op = "*";
                case .DIV; op = "/";
                case .MOD; op = "%";
                case .BITWISE_AND; op = "&";
                case .BITWISE_OR; op = "|";
                case .BITWISE_XOR; op = "^";
                case .LEFT_SHIFT; op = "<<";
                case .RIGHT_SHIFT; op = ">>";
                case .AND; op = "&&";
                case .OR; op = "||";
                case .EQUAL_EQUAL; op = "==";
                case .NOT_EQUAL; op = "!=";
                case .LESS; op = "<";
                case .LESS_EQUAL; op = "<=";
                case .GREATER; op = ">";
                case .GREATER_EQUAL; op = ">=";
            };
            write(writer, " % ", op);
            print_expr_ast(writer, binary_expr.right);
            write(writer, ")");
    }
}

print_space :: (writer: *Writer, depth: int) {
    for 0..depth-1 write(writer, "  ");
}

#import "Not_Basic";
