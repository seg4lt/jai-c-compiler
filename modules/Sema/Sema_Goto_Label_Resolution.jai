sema_label_resolution :: (ast: *Program_Ast) {
    sema_label_res_fn(ast.fn);
}

#scope_file
sema_label_res_fn :: (fn: *Fn_Ast) {
    label_store : Store;
    init(*label_store);
    defer deinit(*label_store);

    sema_label_resolution_block(fn.block, *label_store);

    goto_labels: Store;
    init(*goto_labels);
    defer deinit(*goto_labels);

    // resolve all goto with correct label
    for fn.block.items {
        if #complete it.type == {
            case .DECL; // noop
            case .STMT; sema_goto_resolution_stmt(it.as.stmt, *goto_labels, *label_store);
        }
    }
    // any ghost labels?
    for goto_labels {
        value, success := table_find(*label_store, it_index);
        if !success assert(false, "goto label '%' not found.", it_index);
    }
}

sema_label_resolution_block :: (block: *Block_Ast, label_store: *Store) {
    sema_label_resolution_block_item(*block.items, label_store);
}

sema_label_resolution_block_item :: (block_items: *[..]*Block_Item_Ast, label_store: *Store) {
    // gather all labels
    for block_items.* {
        if #complete it.type == {
            case .DECL; // noop
            case .STMT; 
                sema_label_resolution_stmt(it.as.stmt, label_store, block_items.*, it_index);
        }
    }
   
}

sema_label_resolution_stmt :: (stmt: *Stmt_Ast, label_store: *Store, block_items: []*Block_Item_Ast, index: int) {
    if #complete stmt.type == {
        case .RETURN;
            sema_label_resolution_expr(stmt.as.return_stmt.expr, label_store);
        case .EXPR;
            sema_label_resolution_expr(stmt.as.expr, label_store);
        case .IF;
            if_stmt := stmt.as.if_stmt;
            sema_label_resolution_expr(if_stmt.condition, label_store);
            sema_label_resolution_stmt(if_stmt.if_block, label_store, block_items, index);
            if stmt.as.if_stmt.else_block != null
                sema_label_resolution_stmt(if_stmt.else_block, label_store, block_items, index);
        case .LABEL; 
            if table_contains(label_store, stmt.as.label) {
                assert(false, "duplicate label declaration! : %", stmt.as.label);
            }
            // label must have one stmt, label cannot be followed with declaration on c17, c23 allows this.
            next_block_item := block_items.data + index + 1; 
            if (index + 1) >= block_items.count || next_block_item.*.type == .DECL { 
                assert(false, "label '%': must be followed by a statement, not a declaration or end of block.", stmt.as.label);
            }
           
            new_label := make_goto_label(stmt.as.label, label_store.count);
            table_set(label_store, stmt.as.label, .{true, new_label});
            stmt.* = .{ .LABEL, .{ label = new_label }, stmt.loc};
        case .COMPOUND; 
            compound := stmt.as.compound;
            sema_label_resolution_block(compound, label_store);
        case .FOR;
            for_stmt := stmt.as.for_stmt;
            sema_label_resolution_stmt(for_stmt.body, label_store, block_items,index);
        case .DO_WHILE;
            do_while_stmt := stmt.as.do_while;
            sema_label_resolution_stmt(do_while_stmt.body, label_store, block_items, index);
        case .WHILE;
            while_stmt := stmt.as.while_stmt;
            sema_label_resolution_stmt(while_stmt.body, label_store, block_items, index);
        case .CONTINUE; #through;
        case .BREAK; #through;
        case .GOTO; #through;
        case .NULL;
            // noop
    }
}

sema_goto_resolution_stmt :: (stmt: *Stmt_Ast, goto_labels: *Store, label_store: *Store) {
    if #complete stmt.type == {
        case .RETURN;
            sema_goto_resolution_expr(stmt.as.return_stmt.expr, goto_labels, label_store);
        case .EXPR;
            sema_goto_resolution_expr(stmt.as.expr, goto_labels, label_store);
        case .IF;
            sema_goto_resolution_expr(stmt.as.if_stmt.condition, goto_labels, label_store);
            sema_goto_resolution_stmt(stmt.as.if_stmt.if_block, goto_labels,label_store);
            if stmt.as.if_stmt.else_block != null sema_goto_resolution_stmt(stmt.as.if_stmt.else_block, goto_labels, label_store);
        case .GOTO; 
            value, success := table_find(label_store, stmt.as.goto);
            if !success {
                assert(false, "undeclared label: '%'", stmt.as.goto);
            } 
            table_set(goto_labels, stmt.as.goto, value);
            stmt.* = .{.GOTO, .{goto = value.processed}, .{stmt.loc.line, stmt.loc.start}};
        case .COMPOUND; 
            compound := stmt.as.compound;
            sema_label_resolution_block(compound, label_store);
        case .FOR;
            for_stmt := stmt.as.for_stmt;
            sema_goto_resolution_stmt(stmt.as.for_stmt.body, goto_labels, label_store);
        case .DO_WHILE;
            sema_goto_resolution_expr(stmt.as.do_while.condition, goto_labels, label_store);
            sema_goto_resolution_stmt(stmt.as.do_while.body, goto_labels, label_store);
        case .WHILE;
            sema_goto_resolution_expr(stmt.as.while_stmt.condition, goto_labels, label_store);
            sema_goto_resolution_stmt(stmt.as.while_stmt.body, goto_labels, label_store);
        case .CONTINUE; #through;
        case .BREAK; #through;
        case .LABEL; #through;
        case .NULL;
            // noop
    }
}

sema_goto_resolution_expr :: (expr: *Expr_Ast, goto_labels: *Store, label_store: Store) {
    if #complete expr.type == {
        case .CONSTANT; #through;
        case .UNARY;  #through;
        case .BINARY; #through;
        case .ASSIGNMENT; #through;
        case .VAR; // noop

        case .GROUP; 
            sema_goto_resolution_expr(expr.as.group, goto_labels, label_store);
        case .CONDITIONAL;
            conditional := expr.as.conditional;
            sema_goto_resolution_expr(conditional.true_block, goto_labels, label_store);
            sema_goto_resolution_expr(conditional.false_block, goto_labels, label_store);
    }
}

sema_label_resolution_expr :: (expr: *Expr_Ast, label_store: *Store) {
    if #complete expr.type == {
        case .CONSTANT; #through;
        case .UNARY;  #through;
        case .BINARY; #through;
        case .ASSIGNMENT; #through;
        case .VAR; // noop

        case .GROUP; 
            sema_label_resolution_expr(expr.as.group, label_store);
        case .CONDITIONAL;
            conditional := expr.as.conditional;
            sema_label_resolution_expr(conditional.true_block, label_store);
            sema_label_resolution_expr(conditional.false_block, label_store);
    }
}
