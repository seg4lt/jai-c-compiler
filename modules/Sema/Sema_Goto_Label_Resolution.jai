sema_label_resolution :: (ast: *Program_Ast, erp: *Error_Reporter) {
    for *decl: ast.decls {
        using decl.*;
        if #complete type == {
            case .FN; label_fn(decl_fn, erp);
            case .VAR; // noop;
        }
    }
}

#scope_file

Label_Store :: Table(
    string,
    struct {
        owing_block:     bool;
        processed_label: string;
        using loc:       Source_Location;
    }
);

label_fn :: (fn: *Fn_Decl_Ast, erp: *Error_Reporter) {
    label_store : Label_Store;
    init(*label_store);

    // find all labels in source code
    // doing this so we can make sure goto is pointing to correct label
    if fn.block label_block(fn.block, *label_store, erp);

    goto_labels: Label_Store;
    init(*goto_labels);

    // resolve all goto with correct label
    if fn.block resolve_block(fn.block, *goto_labels, *label_store, erp);

    // any ghost labels?
    for goto_labels {
        success, value := table_find_new(*label_store, it_index);
        if !success error_report(erp, it.loc.line, it.loc.start, "undeclared label: '%'", it_index);
    }
}

resolve_block :: (block: *Block_Ast, goto_labels: *Label_Store, label_store: *Label_Store, erp: *Error_Reporter) {
    for block.items {
        using it;
        if #complete type == {
            case .DECL; // noop
            case .STMT; resolve_stmt(block_item_stmt, goto_labels, label_store, erp);
        }
    }
}

label_block :: (block: *Block_Ast, label_store: *Label_Store, erp: *Error_Reporter) {
    label_block_item(*block.items, label_store, erp);
}

label_block_item :: (block_items: *[..]*Block_Item_Ast, label_store: *Label_Store, erp: *Error_Reporter) {
    for block_items.* {
        using it;
        if #complete type == {
            case .DECL; // noop
            case .STMT; label_stmt(block_item_stmt, label_store, erp);
        }
    }

}

label_stmt :: (using stmt: *Stmt_Ast, label_store: *Label_Store, erp: *Error_Reporter) {
    if #complete type == {
        case .RETURN;
            label_expr(stmt_return.expr, label_store, erp);
        case .EXPR;
            label_expr(stmt_expr, label_store, erp);
        case .IF;
            label_expr(stmt_if.condition, label_store, erp);
            label_stmt(stmt_if.if_block, label_store, erp);
            if stmt_if.else_block != null label_stmt(stmt_if.else_block, label_store, erp);
        case .LABEL;
            if table_contains(label_store, stmt_label.label) {
            error_report(erp, stmt.loc.line, stmt.loc.start, "duplicate label declaration! : %", stmt_label);
            }
            new_label := make_goto_label(stmt_label.label);
            table_set(label_store, stmt_label.label, .{true, new_label, stmt.loc});
            stmt.* = .{ .LABEL, .{ stmt_label = .{new_label, stmt_label.stmt }}, stmt.loc};
            label_stmt(stmt_label.stmt, label_store, erp);
        case .COMPOUND;
            compound := stmt_compound;
            label_block(compound, label_store, erp);
        case .FOR;
            label_stmt(stmt_for.body, label_store, erp);
        case .DO_WHILE;
            do_while_stmt := stmt_do_while;
            label_stmt(do_while_stmt.body, label_store, erp);
        case .WHILE;
            label_stmt(stmt_while.body, label_store, erp);
        case .SWITCH;
            label_block_item(*stmt_switch.body, label_store, erp);
        case .GOTO;     #through;
        case .CONTINUE; #through;
        case .BREAK;    #through;
        case .DEFAULT;  #through;
        case .CASE;     #through;
        case .NULL;     // noop
    }
}

resolve_stmt :: (using stmt: *Stmt_Ast, goto_labels: *Label_Store, label_store: *Label_Store, erp: *Error_Reporter) {
    if #complete type == {
        case .SWITCH;
            for stmt_switch.body {
                using it;
                if #complete type == {
                    case .DECL; // noop
                    case .STMT; resolve_stmt(block_item_stmt, goto_labels, label_store, erp);
                }
            }
        case .RETURN;
            resolve_expr(stmt_return.expr, goto_labels, label_store, erp);
        case .EXPR;
            resolve_expr(stmt_expr, goto_labels, label_store, erp);
        case .IF;
            resolve_expr(stmt_if.condition, goto_labels, label_store, erp);
            resolve_stmt(stmt_if.if_block, goto_labels,label_store, erp);
            if stmt_if.else_block != null resolve_stmt(stmt_if.else_block, goto_labels, label_store, erp);
        case .GOTO;
            success, value := table_find_new(label_store, stmt_goto);
            if !success {
                error_report(erp, stmt.loc.line, stmt.loc.start, "undeclared label: '%'", stmt_goto);
            }
            table_set(goto_labels, stmt_goto, value);
            // mark
            stmt.* = .{ type = .GOTO, stmt_goto = value.processed_label, line = line, start = start };
        case .COMPOUND;
            resolve_block(stmt_compound, goto_labels, label_store, erp);
        case .FOR;
            resolve_stmt(stmt_for.body, goto_labels, label_store, erp);
        case .DO_WHILE;
            resolve_expr(stmt_do_while.condition, goto_labels, label_store, erp);
            resolve_stmt(stmt_do_while.body, goto_labels, label_store, erp);
        case .WHILE;
            resolve_expr(stmt_while.condition, goto_labels, label_store, erp);
            resolve_stmt(stmt_while.body, goto_labels, label_store, erp);
        case .LABEL;
            resolve_stmt(stmt_label.stmt, goto_labels, label_store, erp);
        case .CONTINUE;  #through;
        case .BREAK;     #through;
        case .DEFAULT;   #through;
        case .CASE;      #through;
        case .NULL;      // noop
    }
}

resolve_expr :: (using expr: *Expr_Ast, goto_labels: *Label_Store, label_store: Label_Store, erp: *Error_Reporter) {
    if #complete type == {
        case .POSTFIX;
            resolve_expr(expr_postfix.expr, goto_labels, label_store, erp);
        case .PREFIX;
            resolve_expr(expr_prefix.expr, goto_labels, label_store, erp);
        case .GROUP;
            resolve_expr(expr_group, goto_labels, label_store, erp);
        case .TERNARY;
            resolve_expr(expr_ternary.true_expr, goto_labels, label_store, erp);
            resolve_expr(expr_ternary.false_expr, goto_labels, label_store, erp);
        case .FN_CALL; 
            for arg_expr: expr_fn_call.args resolve_expr(arg_expr, goto_labels, label_store, erp);
        case .CONSTANT;   #through;
        case .UNARY;      #through;
        case .BINARY;     #through;
        case .ASSIGNMENT; #through;
        case .VAR;        // noop
    }
}

label_expr :: (using expr: *Expr_Ast, label_store: *Label_Store, erp: *Error_Reporter) {
    if #complete type == {
        case .POSTFIX;
            label_expr(expr_postfix.expr, label_store, erp);
        case .PREFIX;
            label_expr(expr_prefix.expr, label_store, erp);
        case .FN_CALL;  
            for arg_expr: expr_fn_call.args label_expr(arg_expr, label_store, erp);
        case .GROUP;
            label_expr(expr_group, label_store, erp);
        case .TERNARY;
            label_expr(expr_ternary.true_expr, label_store, erp);
            label_expr(expr_ternary.false_expr, label_store, erp);
        case .ASSIGNMENT; #through;
        case .BINARY;     #through;
        case .CONSTANT;   #through;
        case .UNARY;      #through;
        case .VAR;        // noop
    }
}
