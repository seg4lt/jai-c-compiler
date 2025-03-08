sema_loop_labeling :: (ast: *Program_Ast_Node) {
    sema_loop_labeling_fn(ast.fn);
}
sema_loop_labeling_fn :: (fn: *Fn_Ast_Node) {
    label_stack: [..]string;
    defer free(*label_stack);

    sema_loop_labeling_block(fn.block, *label_stack);
}

sema_loop_labeling_block :: (block: *Block_Ast_Node, label_stack: *[..]string) {
    sema_loop_labeling_block_item(*block.items, label_stack);
}

sema_loop_labeling_block_item :: (block_items: *[..]*Block_Item_Ast_Node, label_stack: *[..]string) {
    for block_items.* {
        if #complete it.type == {
            case .DECL; // noop
            case .STMT; 
                // sema_loop_labeling_stmt(it.as.stmt, label_stack, block_items.*, it_index);
                sema_loop_labeling_stmt(it.as.stmt, label_stack);
        }
    }
   
}

sema_loop_labeling_stmt :: (stmt: *Stmt_Ast_Node, label_stack: *[..]string) {
    if #complete stmt.type == {
        case .IF;
            if_stmt := stmt.as.if_stmt;
            sema_loop_labeling_stmt(if_stmt.if_block, label_stack);
            if stmt.as.if_stmt.else_block != null
                sema_loop_labeling_stmt(if_stmt.else_block, label_stack);
        case .COMPOUND; 
            compound := stmt.as.compound;
            sema_loop_labeling_block(compound, label_stack);
        case .WHILE;
            label := tprint("L.wloop.%", label_stack.count);
            stmt.as.while_stmt.label = label;
            array_add(label_stack, label);
            sema_loop_labeling_stmt(stmt.as.while_stmt.body, label_stack);
            pop(label_stack);
        case .CONTINUE;
            assert(label_stack.count > 0, "You need to be in construct that supports continue");
            stmt.as.continue_stmt = peek(label_stack.*);
        case .BREAK;
            assert(label_stack.count > 0, "You need to be in construct that supports break");
            stmt.as.break_stmt = peek(label_stack.*);
        case .FOR;
            assert(false, "not implemented");
        case .DO_WHILE;
            label := tprint("L.dwloop.%", label_stack.count);
            stmt.as.do_while.label = label;
            array_add(label_stack, label);
            sema_loop_labeling_stmt(stmt.as.do_while.body, label_stack);
            pop(label_stack);
        case .RETURN; #through;
        case .EXPR; #through;
        case .LABEL; #through;
        case .GOTO; #through;
        case .NULL;
            // noop
    }
}

sema_loop_labeling_expr :: (expr: *Expr_Ast_Node, label_stack: *[..]string) {
    if #complete expr.type == {
        case .CONSTANT; #through;
        case .UNARY;  #through;
        case .BINARY; #through;
        case .ASSIGNMENT; #through;
        case .VAR; // noop

        case .GROUP; 
            sema_loop_labeling_expr(expr.as.group, label_stack);
        case .CONDITIONAL;
            conditional := expr.as.conditional;
            sema_loop_labeling_expr(conditional.true_block, label_stack);
            sema_loop_labeling_expr(conditional.false_block, label_stack);
    }
}
