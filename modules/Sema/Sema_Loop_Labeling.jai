sema_loop_labeling :: (ast: *Program_Ast, error_reporter: *Error_Reporter) {
    sema_loop_labeling_fn(ast.fn, error_reporter);
}

#scope_file

sema_loop_labeling_fn :: (fn: *Fn_Ast, error_reporter: *Error_Reporter) {
    label_stack: [..]string;
    defer free(*label_stack);

    sema_loop_labeling_block(fn.block, *label_stack, error_reporter);
}

sema_loop_labeling_block :: (block: *Block_Ast, label_stack: *[..]string, error_reporter: *Error_Reporter) {
    sema_loop_labeling_block_item(*block.items, label_stack, error_reporter);
}

sema_loop_labeling_block_item :: (block_items: *[..]*Block_Item_Ast, label_stack: *[..]string, error_reporter: *Error_Reporter) {
    for block_items.* {
        if #complete it.type == {
            case .DECL; // noop
            case .STMT; 
                sema_loop_labeling_stmt(it.as.stmt, label_stack, error_reporter);
        }
    }
   
}

sema_loop_labeling_stmt :: (stmt: *Stmt_Ast, label_stack: *[..]string, error_reporter: *Error_Reporter) {
    if #complete stmt.type == {
        case .IF;
            if_stmt := stmt.as.if_stmt;
            sema_loop_labeling_stmt(if_stmt.if_block, label_stack, error_reporter);
            if stmt.as.if_stmt.else_block != null
                sema_loop_labeling_stmt(if_stmt.else_block, label_stack, error_reporter);
        case .COMPOUND; 
            compound := stmt.as.compound;
            sema_loop_labeling_block(compound, label_stack, error_reporter);
        case .WHILE;
            label := tprint("L.wloop.%", label_stack.count);
            stmt.as.while_stmt.label = label;
            array_add(label_stack, label);
            sema_loop_labeling_stmt(stmt.as.while_stmt.body, label_stack, error_reporter);
            pop(label_stack);
        case .CONTINUE;
            if label_stack.count <= 0 {
                error_report(error_reporter, stmt.loc.line, stmt.loc.start, "You need to be in construct that supports continue");
            }
            stmt.as.continue_stmt = peek(label_stack.*);
        case .BREAK;
            if label_stack.count <= 0 {
                error_report(error_reporter, stmt.loc.line, stmt.loc.start, "You need to be in construct that supports break");
            }
            stmt.as.break_stmt = peek(label_stack.*);
        case .FOR;
            label := tprint("L.forloop.%", label_stack.count);
            stmt.as.for_stmt.label = label;
            {
                array_add(label_stack, label);
                defer pop(label_stack);

                sema_loop_labeling_stmt(stmt.as.for_stmt.body, label_stack, error_reporter);
            }
        case .DO_WHILE;
            label := tprint("L.dwloop.%", label_stack.count);
            stmt.as.do_while.label = label;
            array_add(label_stack, label);
            sema_loop_labeling_stmt(stmt.as.do_while.body, label_stack, error_reporter);
            pop(label_stack);
        case .RETURN; #through;
        case .EXPR; #through;
        case .LABEL; #through;
        case .GOTO; #through;
        case .NULL;
            // noop
    }
}

sema_loop_labeling_expr :: (expr: *Expr_Ast, label_stack: *[..]string, error_reporter: *Error_Reporter) {
    if #complete expr.type == {
        case .CONSTANT; #through;
        case .UNARY;  #through;
        case .BINARY; #through;
        case .ASSIGNMENT; #through;
        case .VAR; // noop

        case .GROUP; 
            sema_loop_labeling_expr(expr.as.group, label_stack, error_reporter);
        case .CONDITIONAL;
            conditional := expr.as.conditional;
            sema_loop_labeling_expr(conditional.true_block, label_stack, error_reporter);
            sema_loop_labeling_expr(conditional.false_block, label_stack, error_reporter);
    }
}
