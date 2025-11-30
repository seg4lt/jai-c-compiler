print_program_ast :: (writer: *Writer, pg: *Ast.Program) {
    write(writer, "-- AST --\n");

    for decl: pg.decls {
        if decl.kind == {
            case .FN; print_fn_decl_ast(writer, cast(*Ast.Fn_Decl) decl, 0);
            case .VAR;
                print_var_decl_ast(writer, cast(*Ast.Var_Decl) decl, 0, false);
                write(writer, ";");
        }
        if it_index < pg.decls.count - 1 write(writer, "\n");
    }

    write(writer, "\n");
}

print_storage_class :: (writer: *Writer, class: Ast.Storage_Class) {
    if #complete class == {
        case .EXTERN; write(writer, "% ", "extern");
        case .STATIC; write(writer, "% ", "static");
        case .NONE;   // noop
    }
}


print_fn_decl_ast :: (writer: *Writer, fn_decl: *Ast.Fn_Decl, depth: int, indent: bool = false) {
    if indent print_space(writer, depth);
    print_storage_class(writer, fn_decl.storage_class);
    if #complete fn_decl.type.(*Ast.Decl_Type_Fn).return_type.kind == {
        case .INT; write(writer, "int ");
        case .LONG; write(writer, "long ");
        case .FN; unreachable("** compiler bug ** this is fn return type, and fn type is not supported");
    }
    write(writer, "%( ", fn_decl.ident);
    for param: fn_decl.params {
        if #complete fn_decl.type.(*Ast.Decl_Type_Fn).params[it_index].kind == {
            case .INT; write(writer, "int ");
            case .LONG; write(writer, "long ");
            case .FN; unreachable("** compiler bug ** this is fn param type, and fn type is not supported");
        }
        write(writer, "%", param.ident);
        if it_index < fn_decl.params.count - 1 write(writer, ", ");
    }
    write(writer, " )");

    if fn_decl.body != null {
        body := fn_decl.body;
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

print_block_ast :: (writer: *Writer, block: *Ast.Block, depth: int, new_line: bool) {
    for item: block.items {
        print_space(writer, depth);
        print_block_item_ast(writer, item, depth, new_line);
    }
}

print_block_item_ast :: (writer: *Writer, block_item: *Ast.Block_Item, depth: int, new_line: bool) {
    if #complete block_item.kind == {
        case .STMT; 
            item_stmt := cast(*Ast.Block_Item_Stmt) block_item;
            print_stmt_ast(writer, item_stmt.stmt, depth);
        case .DECL; 
            item_decl := cast(*Ast.Block_Item_Decl) block_item;
            print_decl_ast(writer, item_decl.decl, depth, new_line);
    }
}

print_decl_ast :: (writer: *Writer, using decl: *Ast.Decl, depth: int, new_line: bool) {
    if #complete decl.kind == {
        case .FN; print_fn_decl_ast(writer, cast(*Ast.Fn_Decl) decl, depth);
        case .VAR; print_var_decl_ast(writer, cast(*Ast.Var_Decl) decl, depth, new_line);
    }
}

print_var_decl_ast :: (writer: *Writer, using var_decl: *Ast.Var_Decl, depth: int, new_line: bool) {
    if #complete storage_class == {
        case .STATIC; write(writer, "static ");
        case .EXTERN; write(writer, "extern ");
        case .NONE; // noop
    }
    if #complete var_decl.type.kind == {
        case .INT; write(writer, "int ");
        case .LONG; write(writer, "long ");
        case .FN; unreachable("** compiler bug ** this is var decl ast");
    }
    write(writer, "%", ident);
    if init != null {
        initializer := init;
        write(writer, " = ");
        print_expr_ast(writer, initializer);
    }
    if new_line write(writer, ";\n");
}

print_if_stmt_ast :: (writer: *Writer, stmt: *Ast.Stmt, depth: int) {
    if stmt.kind != .IF unreachable("** compiler bug ** wanted if statement got %", stmt.kind);
    
    stmt_if := cast(*Ast.Stmt_If) stmt;
    write(writer, "if (");
    print_expr_ast(writer, stmt_if.condition);
    write(writer, ")\n");

    if_depth := ifx stmt_if.if_block.kind == .COMPOUND depth else depth + 1;
    print_space(writer, if_depth);
    print_stmt_ast(writer, stmt_if.if_block, if_depth);
    if stmt_if.else_block {
        else_stmt := stmt_if.else_block;
        if stmt_if.if_block.kind == .COMPOUND write(writer, "\n");

        print_space(writer, depth);
        write(writer, "else");
        if (else_stmt.kind == .IF) {
            write(writer, " ");
            print_if_stmt_ast(writer, else_stmt, depth);
        } else {
            write(writer, "\n");
            else_depth := ifx stmt_if.if_block.kind == .COMPOUND depth else depth + 1;
            print_space(writer, else_depth);
            print_stmt_ast(writer, else_stmt, else_depth);
        }
    }
    write(writer, "\n");
}

print_do_while_stmt_ast :: (writer: *Writer, stmt: *Ast.Stmt, depth: int) {
    if stmt.kind != .DO_WHILE unreachable("** compiler bug ** wanted do while statement got %", stmt.kind);
    
    stmt_do_while := cast(*Ast.Stmt_Do_While) stmt;
    write(writer, "do\n");
    print_space(writer, depth);
    do_depth := ifx (stmt_do_while.body.kind == .COMPOUND) depth else depth + 1;
    print_stmt_ast(writer, stmt_do_while.body, do_depth);
    write(writer, " while ( ");
    print_expr_ast(writer, stmt_do_while.condition);
    write(writer, " );\n");
}

print_while_stmt_ast :: (writer: *Writer, stmt: *Ast.Stmt, depth: int) {
    if stmt.kind != .WHILE unreachable("** compiler bug ** wanted while statement got %", stmt.kind);
    
    stmt_while := cast(*Ast.Stmt_While) stmt;
    write(writer, "while ( ");
    print_expr_ast(writer, stmt_while.condition);
    write(writer, " )\n");

    while_depth := ifx stmt_while.body.kind == .COMPOUND depth else depth + 1;

    print_space(writer, depth);
    print_stmt_ast(writer, stmt_while.body, while_depth);
    write(writer, "\n");
}

print_for_stmt_ast :: (writer: *Writer, stmt: *Ast.Stmt, depth: int) {
    if stmt.kind != .FOR unreachable("** compiler bug ** wanted for statement got %", stmt.kind);
    
    stmt_for := cast(*Ast.Stmt_For) stmt;
    write(writer, "for (");
    init := stmt_for.init;
    if #complete init.kind == {
        case .DECL; 
            init_decl := cast(*Ast.For_Init_Decl) init;
            print_decl_ast(writer, init_decl.decl, depth + 1, false);
        case .EXPR; 
            init_expr := cast(*Ast.For_Init_Expr) init;
            if init_expr.expr print_expr_ast(writer, init_expr.expr);
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
    for_depth := ifx stmt_for.body.kind == .COMPOUND depth else depth + 1;
    print_stmt_ast(writer, stmt_for.body, for_depth);
    write(writer, "\n");
}

print_stmt_ast :: (writer: *Writer, stmt: *Ast.Stmt, depth: int) {
    if #complete stmt.kind == {
        case .SWITCH;
            stmt_switch := cast(*Ast.Stmt_Switch) stmt;
            write(writer, "switch (");
            print_expr_ast(writer, stmt_switch.condition);
            write(writer, ")\n");
            print_space(writer, depth);
            write(writer, "{\n");
            for item: stmt_switch.body {
                is_default_or_case_stmt := false;
                if item.kind == .STMT {
                    item_stmt := cast(*Ast.Block_Item_Stmt) item;
                    is_default_or_case_stmt = item_stmt.stmt.kind == .CASE || item_stmt.stmt.kind == .DEFAULT;
                }
                if is_default_or_case_stmt print_space(writer, depth + 1);
                else print_space(writer, depth + 2);
                print_block_item_ast(writer, item, depth, true);
            }
            print_space(writer, depth);
            write(writer, "}\n");
        case .CASE;
            stmt_case := cast(*Ast.Stmt_Case) stmt;
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
            stmt_label := cast(*Ast.Stmt_Label) stmt;
            write(writer, "%:\n", stmt_label.label);
            print_stmt_ast(writer, stmt_label.stmt, depth + 1);
        case .GOTO;
            stmt_goto := cast(*Ast.Stmt_Goto) stmt;
            write(writer, "goto %;\n", stmt_goto.label);
        case .IF;
            print_if_stmt_ast(writer, stmt, depth);
        case .COMPOUND;
            stmt_compound := cast(*Ast.Stmt_Compound) stmt;
            write(writer, "{\n");
            print_block_ast(writer, stmt_compound.block, depth + 1, true);
            print_space(writer, depth);
            write(writer, "}");
        case .RETURN;
            stmt_return := cast(*Ast.Stmt_Return) stmt;
            write(writer, "return");
            write(writer, " ");
            print_expr_ast(writer, stmt_return.expr);
            write(writer, ";\n");
        case .EXPR;
            stmt_expr := cast(*Ast.Stmt_Expr) stmt;
            print_expr_ast(writer, stmt_expr.expr);
            write(writer, ";\n");
        case .NULL;
            write(writer, ";\n");
    }
}

print_decl_type :: (writer: *Writer, decl_type: *Ast.Decl_Type) {
    if #complete decl_type.kind == {
        case .INT; write(writer, "int");
        case .LONG; write(writer, "long");
        case .FN; unreachable("** compiler bug ** this is decl type ast");
    }
}

print_expr_ast :: (writer: *Writer, expr: *Ast.Expr) {
    if #complete expr.kind == {
        case .CAST; 
            expr_cast := expr.(*Ast.Expr_Cast);
            write(writer, "(");
            print_decl_type(writer, expr_cast.target_type);
            write(writer, ") ");
            print_expr_ast(writer, expr_cast.expr);
        case .PREFIX;
            expr_prefix := cast(*Ast.Expr_Prefix) expr;
            write(writer, "%", ifx expr_prefix.op == .ADD "++" else "--");
            print_expr_ast(writer, expr_prefix.expr);
        case .FN_CALL;
            expr_fn_call := cast(*Ast.Expr_Fn_Call) expr;
            write(writer, "%(", expr_fn_call.ident);
            for arg: expr_fn_call.args {
                print_expr_ast(writer, arg);
                if (it_index < expr_fn_call.args.count - 1) write(writer, ", ");
            }
            write(writer, ")");
        case .TERNARY;
            expr_ternary := cast(*Ast.Expr_Ternary) expr;
            print_expr_ast(writer, expr_ternary.condition);
            write(writer, " ? ");
            print_expr_ast(writer, expr_ternary.true_expr);
            write(writer, " : ");
            print_expr_ast(writer, expr_ternary.false_expr);
        case .VAR;
            expr_var := cast(*Ast.Expr_Var) expr;
            write(writer, "%", expr_var.ident);
        case .POSTFIX;
            expr_postfix := cast(*Ast.Expr_Postfix) expr;
            print_expr_ast(writer, expr_postfix.expr);
            if #complete expr_postfix.op == {
                case .ADD; write(writer, "++");
                case .SUBTRACT; write(writer, "--");
            }
        case .GROUP;
            expr_group := cast(*Ast.Expr_Group) expr;
            write(writer, "(");
            print_expr_ast(writer, expr_group.expr);
            write(writer, ")");
        case .ASSIGNMENT;
            expr_assignment := cast(*Ast.Expr_Assignment) expr;
            print_expr_ast(writer, expr_assignment.dst);
            write(writer, " = ");
            print_expr_ast(writer, expr_assignment.src);
        case .CONSTANT;
            expr_constant := cast(*Ast.Expr_Constant) expr;
            if #complete expr_constant.value.kind == {
                case .INT;
                    write(writer, "%", expr_constant.value.(*Ast.Constant_Int).value);
                case .LONG;
                    write(writer, "%L", expr_constant.value.(*Ast.Constant_Long).value);
            }
        case .UNARY;
            expr_unary := cast(*Ast.Expr_Unary) expr;
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
            expr_binary := cast(*Ast.Expr_Binary) expr;
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
                case .AND; op = "&&";
                case .OR; op = "||";
                case .EQUAL_EQUAL; op = "==";
                case .NOT_EQUAL; op = "!=";
                case .LESS; op = "<";
                case .LESS_EQUAL; op = "<=";
                case .GREATER; op = ">";
                case .GREATER_EQUAL; op = ">=";
                case .LEFT_SHIFT; op = "<<";
                case .RIGHT_SHIFT; op = ">>";
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
