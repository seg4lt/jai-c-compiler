sema_label_resolution :: (ast: *Program_Ast, error_reporter: *Error_Reporter) {
    sema_label_res_fn(ast.fn, error_reporter);
}

#scope_file

Label_Store :: Table(string, struct { owing_block: bool; processed_label: string; loc: Source_Location; });

sema_label_res_fn :: (fn: *Fn_Ast, error_reporter: *Error_Reporter) {
    label_store : Label_Store;
    init(*label_store);
    defer deinit(*label_store);

    // @note
    // find all labels in source code
    // doing this so we can make sure goto is pointing to correct label
    sema_label_resolution_block(fn.block, *label_store, error_reporter);

    goto_labels: Label_Store;
    init(*goto_labels);
    defer deinit(*goto_labels);

    // @note
    // resolve all goto with correct label
    for fn.block.items {
        if #complete it.type == {
            case .DECL; // noop
            case .STMT; sema_goto_resolution_stmt(it.as.stmt, *goto_labels, *label_store, error_reporter);
        }
    }
    // @note
    // any ghost labels?
    for goto_labels {
        value, success := table_find(*label_store, it_index);
        if !success 
            error_report(error_reporter, it.loc.line, it.loc.start, "undeclared label: '%'", it_index);
    }
}

sema_label_resolution_block :: (block: *Block_Ast, label_store: *Label_Store, error_reporter: *Error_Reporter) {
    sema_label_resolution_block_item(*block.items, label_store, error_reporter);
}

sema_label_resolution_block_item :: (block_items: *[..]*Block_Item_Ast, label_store: *Label_Store, error_reporter: *Error_Reporter) {
    // gather all labels
    for block_items.* {
        if #complete it.type == {
            case .DECL; // noop
            case .STMT; 
                sema_label_resolution_stmt(it.as.stmt, label_store, block_items.*, it_index, error_reporter);
        }
    }
   
}

sema_label_resolution_stmt :: (stmt: *Stmt_Ast, label_store: *Label_Store, block_items: []*Block_Item_Ast, index: int, error_reporter: *Error_Reporter) {
    if #complete stmt.type == {
        case .SWITCH;
            assert(false, "Not implemented yet");
        case .RETURN;
            sema_label_resolution_expr(stmt.as.return_stmt.expr, label_store, error_reporter);
        case .EXPR;
            sema_label_resolution_expr(stmt.as.expr, label_store, error_reporter);
        case .IF;
            if_stmt := stmt.as.if_stmt;
            sema_label_resolution_expr(if_stmt.condition, label_store, error_reporter);
            sema_label_resolution_stmt(if_stmt.if_block, label_store, block_items, index, error_reporter);
            if stmt.as.if_stmt.else_block != null
                sema_label_resolution_stmt(if_stmt.else_block, label_store, block_items, index, error_reporter);
        case .LABEL; 
            if table_contains(label_store, stmt.as.label) {
                error_report(error_reporter, stmt.loc.line, stmt.loc.start, "duplicate label declaration! : %", stmt.as.label);
            }
            // label must have one stmt, label cannot be followed with declaration on c17, c23 allows this.
            next_block_item := block_items.data + index + 1; 
            if (index + 1) >= block_items.count || next_block_item.*.type == .DECL { 
                error_report(error_reporter, stmt.loc.line, stmt.loc.start, "label '%': must be followed by a statement, not a declaration or end of block.", stmt.as.label);
            }
           
            new_label := make_goto_label(stmt.as.label, label_store.count);
            table_set(label_store, stmt.as.label, .{true, new_label, stmt.loc});
            stmt.* = .{ .LABEL, .{ label = new_label }, stmt.loc};
        case .COMPOUND; 
            compound := stmt.as.compound;
            sema_label_resolution_block(compound, label_store, error_reporter);
        case .FOR;
            for_stmt := stmt.as.for_stmt;
            sema_label_resolution_stmt(for_stmt.body, label_store, block_items,index, error_reporter);
        case .DO_WHILE;
            do_while_stmt := stmt.as.do_while;
            sema_label_resolution_stmt(do_while_stmt.body, label_store, block_items, index, error_reporter);
        case .WHILE;
            while_stmt := stmt.as.while_stmt;
            sema_label_resolution_stmt(while_stmt.body, label_store, block_items, index, error_reporter);
        case .CONTINUE; #through;
        case .BREAK; #through;
        case .GOTO; #through;
        case .NULL;
            // noop
    }
}

sema_goto_resolution_stmt :: (stmt: *Stmt_Ast, goto_labels: *Label_Store, label_store: *Label_Store, error_reporter: *Error_Reporter) {
    if #complete stmt.type == {
        case .SWITCH;
            assert(false, "Not implemented yet");
        case .RETURN;
            sema_goto_resolution_expr(stmt.as.return_stmt.expr, goto_labels, label_store, error_reporter);
        case .EXPR;
            sema_goto_resolution_expr(stmt.as.expr, goto_labels, label_store, error_reporter);
        case .IF;
            sema_goto_resolution_expr(stmt.as.if_stmt.condition, goto_labels, label_store, error_reporter);
            sema_goto_resolution_stmt(stmt.as.if_stmt.if_block, goto_labels,label_store, error_reporter);
            if stmt.as.if_stmt.else_block != null sema_goto_resolution_stmt(stmt.as.if_stmt.else_block, goto_labels, label_store, error_reporter);
        case .GOTO; 
            value, success := table_find(label_store, stmt.as.goto);
            if !success {
                error_report(error_reporter, stmt.loc.line, stmt.loc.start, "undeclared label: '%'", stmt.as.goto);
            } 
            table_set(goto_labels, stmt.as.goto, value);
            stmt.* = .{.GOTO, .{goto = value.processed_label}, .{stmt.loc.line, stmt.loc.start}};
        case .COMPOUND; 
            compound := stmt.as.compound;
            sema_label_resolution_block(compound, label_store, error_reporter);
        case .FOR;
            for_stmt := stmt.as.for_stmt;
            sema_goto_resolution_stmt(stmt.as.for_stmt.body, goto_labels, label_store, error_reporter);
        case .DO_WHILE;
            sema_goto_resolution_expr(stmt.as.do_while.condition, goto_labels, label_store, error_reporter);
            sema_goto_resolution_stmt(stmt.as.do_while.body, goto_labels, label_store, error_reporter);
        case .WHILE;
            sema_goto_resolution_expr(stmt.as.while_stmt.condition, goto_labels, label_store, error_reporter);
            sema_goto_resolution_stmt(stmt.as.while_stmt.body, goto_labels, label_store, error_reporter);
        case .CONTINUE; #through;
        case .BREAK; #through;
        case .LABEL; #through;
        case .NULL;
            // noop
    }
}

sema_goto_resolution_expr :: (expr: *Expr_Ast, goto_labels: *Label_Store, label_store: Label_Store, error_reporter: *Error_Reporter) {
    if #complete expr.type == {
        case .CONSTANT; #through;
        case .UNARY;  #through;
        case .BINARY; #through;
        case .ASSIGNMENT; #through;
        case .VAR; // noop

        case .GROUP; 
            sema_goto_resolution_expr(expr.as.group, goto_labels, label_store, error_reporter);
        case .CONDITIONAL;
            conditional := expr.as.conditional;
            sema_goto_resolution_expr(conditional.true_block, goto_labels, label_store, error_reporter);
            sema_goto_resolution_expr(conditional.false_block, goto_labels, label_store, error_reporter);
    }
}

sema_label_resolution_expr :: (expr: *Expr_Ast, label_store: *Label_Store, error_reporter: *Error_Reporter) {
    if #complete expr.type == {
        case .CONSTANT; #through;
        case .UNARY;  #through;
        case .BINARY; #through;
        case .ASSIGNMENT; #through;
        case .VAR; // noop

        case .GROUP; 
            sema_label_resolution_expr(expr.as.group, label_store, error_reporter);
        case .CONDITIONAL;
            conditional := expr.as.conditional;
            sema_label_resolution_expr(conditional.true_block, label_store, error_reporter);
            sema_label_resolution_expr(conditional.false_block, label_store, error_reporter);
    }
}
