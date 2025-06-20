sema_label_resolution :: (ast: *Program_Ast, erp: *Error_Reporter) {
    for fn: ast.fns label_fn(fn, erp);
}

#scope_file

Label_Store :: Table(
    string,
    struct {
        owing_block: bool;
        processed_label: string;
        loc: Source_Location;
    }
);

label_fn :: (fn: *Fn_Decl_Ast, erp: *Error_Reporter) {
    label_store : Label_Store;
    init(*label_store);
    defer deinit(*label_store);

    // @note
    // find all labels in source code
    // doing this so we can make sure goto is pointing to correct label
    if fn.block label_block(fn.block, *label_store, erp);

    goto_labels: Label_Store;
    init(*goto_labels);
    defer deinit(*goto_labels);

    // @note
    // resolve all goto with correct label
    if fn.block resolve_block(fn.block, *goto_labels, *label_store, erp);

    // @note
    // any ghost labels?
    for goto_labels {
        success, value := table_find_new(*label_store, it_index);
        if !success
            error_report(erp, it.loc.line, it.loc.start, "undeclared label: '%'", it_index);
    }
}

resolve_block :: (block: *Block_Ast, goto_labels: *Label_Store, label_store: *Label_Store, erp: *Error_Reporter) {
    for block.items {
        if #complete it.type == {
            case .DECL; // noop
            case .STMT; resolve_stmt(it.as.stmt, goto_labels, label_store, erp);
        }
    }
}

label_block :: (block: *Block_Ast, label_store: *Label_Store, erp: *Error_Reporter) {
    label_block_item(*block.items, label_store, erp);
}

label_block_item :: (block_items: *[..]*Block_Item_Ast, label_store: *Label_Store, erp: *Error_Reporter) {
    for block_items.* {
        if #complete it.type == {
            case .DECL; // noop
            case .STMT;
                label_stmt(it.as.stmt, label_store, erp);
        }
    }

}

label_stmt :: (stmt: *Stmt_Ast, label_store: *Label_Store, erp: *Error_Reporter) {
    if #complete stmt.type == {
        case .RETURN;
            label_expr(stmt.as.return_stmt.expr, label_store, erp);
        case .EXPR;
            label_expr(stmt.as.expr, label_store, erp);
        case .IF;
            if_stmt := stmt.as.if_stmt;
            label_expr(if_stmt.condition, label_store, erp);
            label_stmt(if_stmt.if_block, label_store, erp);
            if stmt.as.if_stmt.else_block != null
                label_stmt(if_stmt.else_block, label_store, erp);
        case .LABEL;
            if table_contains(label_store, stmt.as.label.label) {
                error_report(erp, stmt.loc.line, stmt.loc.start, "duplicate label declaration! : %", stmt.as.label);
            }
            new_label := make_goto_label(stmt.as.label.label);
            table_set(label_store, stmt.as.label.label, .{true, new_label, stmt.loc});
            stmt.* = .{ .LABEL, .{ label = .{new_label, stmt.as.label.stmt }}, stmt.loc};
            label_stmt(stmt.as.label.stmt, label_store, erp);
        case .COMPOUND;
            compound := stmt.as.compound;
            label_block(compound, label_store, erp);
        case .FOR;
            for_stmt := stmt.as.for_stmt;
            label_stmt(for_stmt.body, label_store, erp);
        case .DO_WHILE;
            do_while_stmt := stmt.as.do_while;
            label_stmt(do_while_stmt.body, label_store, erp);
        case .WHILE;
            while_stmt := stmt.as.while_stmt;
            label_stmt(while_stmt.body, label_store, erp);
        case .SWITCH;
            label_block_item(*stmt.as.switch.body, label_store, erp);
        case .GOTO; #through;
        case .CONTINUE; #through;
        case .BREAK; #through;
        case .DEFAULT; #through;
        case .CASE; #through;
        case .NULL;
            // noop
    }
}

resolve_stmt :: (stmt: *Stmt_Ast, goto_labels: *Label_Store, label_store: *Label_Store, erp: *Error_Reporter) {
    if #complete stmt.type == {
        case .SWITCH;
            for stmt.as.switch.body {
                if #complete it.type == {
                    case .DECL; // noop
                    case .STMT; resolve_stmt(it.as.stmt, goto_labels, label_store, erp);
                }
            }
        case .RETURN;
            resolve_expr(stmt.as.return_stmt.expr, goto_labels, label_store, erp);
        case .EXPR;
            resolve_expr(stmt.as.expr, goto_labels, label_store, erp);
        case .IF;
            resolve_expr(stmt.as.if_stmt.condition, goto_labels, label_store, erp);
            resolve_stmt(stmt.as.if_stmt.if_block, goto_labels,label_store, erp);
            if stmt.as.if_stmt.else_block != null resolve_stmt(stmt.as.if_stmt.else_block, goto_labels, label_store, erp);
        case .GOTO;
            success, value := table_find_new(label_store, stmt.as.goto);
            if !success {
                error_report(erp, stmt.loc.line, stmt.loc.start, "undeclared label: '%'", stmt.as.goto);
            }
            table_set(goto_labels, stmt.as.goto, value);
            stmt.* = .{.GOTO, .{goto = value.processed_label}, .{stmt.loc.line, stmt.loc.start}};
        case .COMPOUND;
            compound := stmt.as.compound;
            resolve_block(compound, goto_labels, label_store, erp);
        case .FOR;
            for_stmt := stmt.as.for_stmt;
            resolve_stmt(stmt.as.for_stmt.body, goto_labels, label_store, erp);
        case .DO_WHILE;
            resolve_expr(stmt.as.do_while.condition, goto_labels, label_store, erp);
            resolve_stmt(stmt.as.do_while.body, goto_labels, label_store, erp);
        case .WHILE;
            resolve_expr(stmt.as.while_stmt.condition, goto_labels, label_store, erp);
            resolve_stmt(stmt.as.while_stmt.body, goto_labels, label_store, erp);
        case .LABEL;
            resolve_stmt(stmt.as.label.stmt, goto_labels, label_store, erp);
        case .CONTINUE; #through;
        case .BREAK; #through;
        case .DEFAULT; #through;
        case .CASE; #through;
        case .NULL;
            // noop
    }
}

resolve_expr :: (expr: *Expr_Ast, goto_labels: *Label_Store, label_store: Label_Store, erp: *Error_Reporter) {
    if #complete expr.type == {
        case .GROUP;
            resolve_expr(expr.as.group, goto_labels, label_store, erp);
        case .TERNARY;
            ternary := expr.as.ternary;
            resolve_expr(ternary.true_expr, goto_labels, label_store, erp);
            resolve_expr(ternary.false_expr, goto_labels, label_store, erp);
        case .FN_CALL; 
            fn_call := expr.as.fn_call;
            for arg_expr: fn_call.args resolve_expr(arg_expr, goto_labels, label_store, erp);
        case .CONSTANT; #through;
        case .UNARY;  #through;
        case .BINARY; #through;
        case .ASSIGNMENT; #through;
        case .VAR; // noop
    }
}

label_expr :: (expr: *Expr_Ast, label_store: *Label_Store, erp: *Error_Reporter) {
    if #complete expr.type == {
        case .CONSTANT; #through;
        case .UNARY;  #through;
        case .BINARY; #through;
        case .ASSIGNMENT; #through;
        case .VAR; // noop
        
        case .FN_CALL;  
            fn_call := expr.as.fn_call;
            for arg_expr: fn_call.args label_expr(arg_expr, label_store, erp);
                
        case .GROUP;
            label_expr(expr.as.group, label_store, erp);
        
        case .TERNARY;
            ternary := expr.as.ternary;
            label_expr(ternary.true_expr, label_store, erp);
            label_expr(ternary.false_expr, label_store, erp);
    }
}
