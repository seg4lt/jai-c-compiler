print_program_ast :: (writer: *Writer, pg: *Program_Ast) {
    write(writer, "-- AST --\n");
    
    for decl: pg.decls {
        using decl;
        if decl.type == {
            case .FN; print_fn_decl_ast(writer, decl_fn, 0);
            case .VAR; 
                print_var_decl_ast(writer, decl_var, 0, false);
                write(writer, ";");
        }
        if it_index < pg.decls.count - 1 write(writer, "\n");
    }
    
    write(writer, "\n");
}

print_storage_class :: (writer: *Writer, class: Storage_Class_Ast) {
    if #complete class == {
        case .EXTERN; write(writer, "% ", "extern");
        case .STATIC; write(writer, "% ", "static");
        case .NONE;   // noop
    }
}
    

print_fn_decl_ast :: (writer: *Writer, fn_decl: *Fn_Decl_Ast, depth: int, indent: bool = false) {
    if indent print_space(writer, depth);
    print_storage_class(writer, fn_decl.storage_class);
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
        write(writer, ";");
    }
}

print_block_ast :: (writer: *Writer, block: *Block_Ast, depth: int, new_line: bool) {
    for item: block.items {
        print_space(writer, depth);
        print_block_item_ast(writer, item, depth, new_line);
    }
}

print_block_item_ast :: (writer: *Writer, using block_item: *Block_Item_Ast, depth: int, new_line: bool) {
    if #complete block_item.type == {
        case .STMT; print_stmt_ast(writer, block_item_stmt, depth);
        case .DECL; print_decl_ast(writer, block_item_decl, depth, new_line);
    }
}

print_decl_ast :: (writer: *Writer, using decl: *Decl_Ast, depth: int, new_line: bool) {
    if #complete decl.type == {
        case .FN; print_fn_decl_ast(writer, decl_fn, depth);
        case .VAR; print_var_decl_ast(writer, decl_var, depth, new_line);
    }
}

print_var_decl_ast :: (writer: *Writer, using var_decl: *Var_Decl_Ast, depth: int, new_line: bool) {
    if #complete storage_class == {
        case .STATIC; write(writer, "static ");
        case .EXTERN; write(writer, "extern ");
        case .NONE; // noop
    }
    write(writer, "int ");
    write(writer, "%", var_decl.ident);
    if var_decl.init != null {
        initializer := var_decl.init;
        write(writer, " = ");
        print_expr_ast(writer, initializer);
    }
    if new_line write(writer, ";\n");
}

print_if_stmt_ast :: (writer: *Writer, using stmt: *Stmt_Ast, depth: int) {
    if type != .IF unreachable("** compiler bug ** wanted if statement got %", stmt.type);

    write(writer, "if (");
    print_expr_ast(writer, stmt_if.condition);
    write(writer, ")\n");

    if_depth := ifx stmt_if.if_block.type == .COMPOUND depth else depth + 1;
    print_space(writer, if_depth);
    print_stmt_ast(writer, stmt_if.if_block, if_depth);
    if stmt_if.else_block {
        else_stmt := stmt_if.else_block;
        if stmt_if.if_block.type == .COMPOUND write(writer, "\n");
        
        print_space(writer, depth);
        write(writer, "else");
        if (else_stmt.type == .IF) {
            write(writer, " ");
            print_if_stmt_ast(writer, else_stmt, depth);
        } else {
            write(writer, "\n");
            else_depth := ifx stmt_if.if_block.type == .COMPOUND depth else depth + 1;
            print_space(writer, else_depth);
            print_stmt_ast(writer, else_stmt, else_depth);
        }
    }
    write(writer, "\n");
}

print_do_while_stmt_ast :: (writer: *Writer, using stmt: *Stmt_Ast, depth: int) {
    if type != .DO_WHILE unreachable("** compiler bug ** wanted do while statement got %", stmt.type);
    
    write(writer, "do\n");
    print_space(writer, depth);
    do_depth := ifx (stmt_do_while.body.type == .COMPOUND) depth else depth + 1;
    print_stmt_ast(writer, stmt_do_while.body, do_depth);
    write(writer, " while ( ");
    print_expr_ast(writer, stmt_do_while.condition);
    write(writer, " );\n");
}

print_while_stmt_ast :: (writer: *Writer, using stmt: *Stmt_Ast, depth: int) {
    if type != .WHILE unreachable("** compiler bug ** wanted while statement got %", stmt.type);
    
    write(writer, "while ( ");
    print_expr_ast(writer, stmt_while.condition);
    write(writer, " )\n");

    while_depth := ifx stmt_while.body.type == .COMPOUND depth else depth + 1;

    print_space(writer, depth);
    print_stmt_ast(writer, stmt_while.body, while_depth);
    write(writer, "\n");
}

print_for_stmt_ast :: (writer: *Writer, using stmt: *Stmt_Ast, depth: int) {
    if type != .FOR unreachable("** compiler bug ** wanted for statement got %", stmt.type);
    
    write(writer, "for (");
    init := stmt_for.init;
    if #complete init.type == {
        case .DECL; print_decl_ast(writer, init.for_init_decl, depth + 1, false);
        case .EXPR; if init.for_init_expr print_expr_ast(writer, init.for_init_expr);
    }
    write(writer, " ; ");

    if stmt_for.condition {
        print_expr_ast(writer,  stmt_for.condition);
    }
    write(writer, " ; ");

    if stmt_for.post {
        print_expr_ast(writer, stmt_for.post);
    }

    write(writer, " )\n");

    print_space(writer, depth);
    for_depth := ifx stmt_for.body.type == .COMPOUND depth else depth + 1;
    print_stmt_ast(writer, stmt_for.body, for_depth);
    write(writer, "\n");
}

print_stmt_ast :: (writer: *Writer, using stmt: *Stmt_Ast, depth: int) {
    if #complete type == {
        case .SWITCH; 
            write(writer, "switch (");
            print_expr_ast(writer, stmt_switch.condition);
            write(writer, ")\n");
            print_space(writer, depth);
            write(writer, "{\n");
            for item: stmt_switch.body {
                using item;
                is_default_or_case_stmt := type == .STMT && (block_item_stmt.type == .CASE || block_item_stmt.type == .DEFAULT); 
                if is_default_or_case_stmt print_space(writer, depth + 1);
                else print_space(writer, depth + 2);
                print_block_item_ast(writer, item, depth, true);
            }
            print_space(writer, depth);
            write(writer, "}\n");
        case .CASE;
            write(writer, "case ");
            write(writer, "%:\n", stmt_case.value);
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
            label_stmt := stmt_label;
            write(writer, "%:\n", label_stmt.label);
            print_stmt_ast(writer, label_stmt.stmt, depth + 1);
        case .GOTO;
            goto_stmt := stmt_goto;
            write(writer, "goto %;\n", goto_stmt);
        case .IF; 
            print_if_stmt_ast(writer, stmt, depth);
        case .COMPOUND;
            compound_stmt := stmt_compound;
            write(writer, "{\n");
            print_block_ast(writer, compound_stmt, depth + 1, true);
            print_space(writer, depth);
            write(writer, "}");
        case .RETURN;
            write(writer, "return");
            write(writer, " ");
            print_expr_ast(writer, stmt_return.expr);
            write(writer, ";\n");
        case .EXPR;
            expr := stmt_expr;
            print_expr_ast(writer, expr);
            write(writer, ";\n");
        case .NULL;
            write(writer, ";\n");
    }
}
print_expr_ast :: (writer: *Writer, using expr: *Expr_Ast) {
    if #complete type == {
        case .PREFIX;
            write(writer, "%", ifx expr_prefix.op == .ADD "++" else "--");
            print_expr_ast(writer, expr_prefix.expr);
        case .FN_CALL;
            write(writer, "%(", expr_fn_call.ident);
            for arg: expr_fn_call.args {
                print_expr_ast(writer, arg);
                if (it_index < expr_fn_call.args.count - 1) write(writer, ", ");
            }
            write(writer, ")");
        case .TERNARY; 
            print_expr_ast(writer, expr_ternary.condition);
            write(writer, " ? ");
            print_expr_ast(writer, expr_ternary.true_expr);
            write(writer, " : ");
            print_expr_ast(writer, expr_ternary.false_expr);
        case .VAR;
            write(writer, "%", expr_var);
        case .POSTFIX; 
            print_expr_ast(writer, expr_postfix.expr);
            if #complete expr_postfix.op == {
                case .ADD; write(writer, "++");
                case .SUBTRACT; write(writer, "--");
            }
        case .GROUP;
            write(writer, "(");
            print_expr_ast(writer, expr_group);
            write(writer, ")");
        case .ASSIGNMENT;
            print_expr_ast(writer, expr_assignment.dst);
            write(writer, " = ");
            print_expr_ast(writer, expr_assignment.src);
        case .CONSTANT;
            write(writer, "%", expr_constant);
        case .UNARY;
            write(writer, "(");
            op : string = ---;
            if #complete expr_unary.op == {
                case .NEGATE; op =  "-";
                case .BITWISE_NOT; op =  "~";
                case .NOT; op =  "!";
            }
            write(writer, "%", op);
            print_expr_ast(writer, expr_unary.expr);
            write(writer, ")");
        case .BINARY;
            write(writer, "(");
            print_expr_ast(writer, expr_binary.left);
            op: string = ---;
            if #complete expr_binary.op == {
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
            print_expr_ast(writer, expr_binary.right);
            write(writer, ")");
    }
}

print_space :: (writer: *Writer, depth: int) {
    for 0..depth-1 write(writer, "  ");
}

#import "Not_Basic";
