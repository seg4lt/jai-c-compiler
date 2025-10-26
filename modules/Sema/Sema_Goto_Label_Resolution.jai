sema_label_resolution :: (ast: *Ast.Program, erp: *Error_Reporter) {
    for decl: ast.decls {
        if #complete decl.kind == {
            case .FN; label_fn(cast(*Ast.Fn_Decl) decl, erp);
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
        using loc:       Ast.Source_Location;
    }
);

label_fn :: (fn: *Ast.Fn_Decl, erp: *Error_Reporter) {
    label_store : Label_Store;
    init(*label_store);

    // find all labels in source code
    // doing this so we can make sure goto is pointing to correct label
    if fn.body label_block(fn.body, *label_store, erp);

    goto_labels: Label_Store;
    init(*goto_labels);

    // resolve all goto with correct label
    if fn.body resolve_block(fn.body, *goto_labels, *label_store, erp);

    // any ghost labels?
    for goto_labels {
        success, value := table_find(*label_store, it_index);
        if !success error_report(erp, it.loc.line, it.loc.start, "undeclared label: '%'", it_index);
    }
}

resolve_block :: (block: *Ast.Block, goto_labels: *Label_Store, label_store: *Label_Store, erp: *Error_Reporter) {
    for block.items {
        if #complete it.kind == {
            case .DECL; // noop
            case .STMT; 
                item_stmt := cast(*Ast.Block_Item_Stmt) it;
                resolve_stmt(item_stmt.stmt, goto_labels, label_store, erp);
        }
    }
}

label_block :: (block: *Ast.Block, label_store: *Label_Store, erp: *Error_Reporter) {
    label_block_item(*block.items, label_store, erp);
}

label_block_item :: (block_items: *[..]*Ast.Block_Item, label_store: *Label_Store, erp: *Error_Reporter) {
    for block_items.* {
        if #complete it.kind == {
            case .DECL; // noop
            case .STMT; 
                item_stmt := cast(*Ast.Block_Item_Stmt) it;
                label_stmt(item_stmt.stmt, label_store, erp);
        }
    }

}

label_stmt :: (stmt: *Ast.Stmt, label_store: *Label_Store, erp: *Error_Reporter) {
    if #complete stmt.kind == {
        case .RETURN;
            stmt_return := cast(*Ast.Stmt_Return) stmt;
            label_expr(stmt_return.expr, label_store, erp);
        case .EXPR;
            stmt_expr := cast(*Ast.Stmt_Expr) stmt;
            label_expr(stmt_expr.expr, label_store, erp);
        case .IF;
            stmt_if := cast(*Ast.Stmt_If) stmt;
            label_expr(stmt_if.condition, label_store, erp);
            label_stmt(stmt_if.if_block, label_store, erp);
            if stmt_if.else_block != null label_stmt(stmt_if.else_block, label_store, erp);
        case .LABEL;
            stmt_label := cast(*Ast.Stmt_Label) stmt;
            if table_contains(label_store, stmt_label.label) {
            error_report(erp, stmt.line, stmt.start, "duplicate label declaration! : %", stmt_label.label);
            }
            new_label := make_goto_label(stmt_label.label);
            table_set(label_store, stmt_label.label, .{true, new_label, .{stmt.line, stmt.start}});
            stmt_label.label = new_label;
            label_stmt(stmt_label.stmt, label_store, erp);
        case .COMPOUND;
            stmt_compound := cast(*Ast.Stmt_Compound) stmt;
            label_block(stmt_compound.block, label_store, erp);
        case .FOR;
            stmt_for := cast(*Ast.Stmt_For) stmt;
            label_stmt(stmt_for.body, label_store, erp);
        case .DO_WHILE;
            stmt_do_while := cast(*Ast.Stmt_Do_While) stmt;
            label_stmt(stmt_do_while.body, label_store, erp);
        case .WHILE;
            stmt_while := cast(*Ast.Stmt_While) stmt;
            label_stmt(stmt_while.body, label_store, erp);
        case .SWITCH;
            stmt_switch := cast(*Ast.Stmt_Switch) stmt;
            label_block_item(*stmt_switch.body, label_store, erp);
        case .GOTO;     #through;
        case .CONTINUE; #through;
        case .BREAK;    #through;
        case .DEFAULT;  #through;
        case .CASE;     #through;
        case .NULL;     // noop
    }
}

resolve_stmt :: (stmt: *Ast.Stmt, goto_labels: *Label_Store, label_store: *Label_Store, erp: *Error_Reporter) {
    if #complete stmt.kind == {
        case .SWITCH;
            stmt_switch := cast(*Ast.Stmt_Switch) stmt;
            for stmt_switch.body {
                if #complete it.kind == {
                    case .DECL; // noop
                    case .STMT; 
                        item_stmt := cast(*Ast.Block_Item_Stmt) it;
                        resolve_stmt(item_stmt.stmt, goto_labels, label_store, erp);
                }
            }
        case .RETURN;
            stmt_return := cast(*Ast.Stmt_Return) stmt;
            resolve_expr(stmt_return.expr, goto_labels, label_store, erp);
        case .EXPR;
            stmt_expr := cast(*Ast.Stmt_Expr) stmt;
            resolve_expr(stmt_expr.expr, goto_labels, label_store, erp);
        case .IF;
            stmt_if := cast(*Ast.Stmt_If) stmt;
            resolve_expr(stmt_if.condition, goto_labels, label_store, erp);
            resolve_stmt(stmt_if.if_block, goto_labels,label_store, erp);
            if stmt_if.else_block != null resolve_stmt(stmt_if.else_block, goto_labels, label_store, erp);
        case .GOTO;
            stmt_goto := cast(*Ast.Stmt_Goto) stmt;
            success, value := table_find(label_store, stmt_goto.label);
            if !success {
                error_report(erp, stmt.line, stmt.start, "undeclared label: '%'", stmt_goto.label);
            }
            table_set(goto_labels, stmt_goto.label, value);
            // mark
            stmt_goto.label = value.processed_label;
        case .COMPOUND;
            stmt_compound := cast(*Ast.Stmt_Compound) stmt;
            resolve_block(stmt_compound.block, goto_labels, label_store, erp);
        case .FOR;
            stmt_for := cast(*Ast.Stmt_For) stmt;
            resolve_stmt(stmt_for.body, goto_labels, label_store, erp);
        case .DO_WHILE;
            stmt_do_while := cast(*Ast.Stmt_Do_While) stmt;
            resolve_expr(stmt_do_while.condition, goto_labels, label_store, erp);
            resolve_stmt(stmt_do_while.body, goto_labels, label_store, erp);
        case .WHILE;
            stmt_while := cast(*Ast.Stmt_While) stmt;
            resolve_expr(stmt_while.condition, goto_labels, label_store, erp);
            resolve_stmt(stmt_while.body, goto_labels, label_store, erp);
        case .LABEL;
            stmt_label := cast(*Ast.Stmt_Label) stmt;
            resolve_stmt(stmt_label.stmt, goto_labels, label_store, erp);
        case .CONTINUE;  #through;
        case .BREAK;     #through;
        case .DEFAULT;   #through;
        case .CASE;      #through;
        case .NULL;      // noop
    }
}

resolve_expr :: (expr: *Ast.Expr, goto_labels: *Label_Store, label_store: Label_Store, erp: *Error_Reporter) {
    if #complete expr.kind == {
        case .POSTFIX;
            expr_postfix := cast(*Ast.Expr_Postfix) expr;
            resolve_expr(expr_postfix.expr, goto_labels, label_store, erp);
        case .PREFIX;
            expr_prefix := cast(*Ast.Expr_Prefix) expr;
            resolve_expr(expr_prefix.expr, goto_labels, label_store, erp);
        case .GROUP;
            expr_group := cast(*Ast.Expr_Group) expr;
            resolve_expr(expr_group.expr, goto_labels, label_store, erp);
        case .TERNARY;
            expr_ternary := cast(*Ast.Expr_Ternary) expr;
            resolve_expr(expr_ternary.condition, goto_labels, label_store, erp);
            resolve_expr(expr_ternary.true_expr, goto_labels, label_store, erp);
            resolve_expr(expr_ternary.false_expr, goto_labels, label_store, erp);
        case .FN_CALL;
            expr_fn_call := cast(*Ast.Expr_Fn_Call) expr;
            for arg_expr: expr_fn_call.args resolve_expr(arg_expr, goto_labels, label_store, erp);
        case .CONSTANT;   #through;
        case .UNARY;      #through;
        case .BINARY;     #through;
        case .ASSIGNMENT; #through;
        case .VAR;        // noop
    }
}

label_expr :: (expr: *Ast.Expr, label_store: *Label_Store, erp: *Error_Reporter) {
    if #complete expr.kind == {
        case .POSTFIX;
            expr_postfix := cast(*Ast.Expr_Postfix) expr;
            label_expr(expr_postfix.expr, label_store, erp);
        case .PREFIX;
            expr_prefix := cast(*Ast.Expr_Prefix) expr;
            label_expr(expr_prefix.expr, label_store, erp);
        case .FN_CALL;
            expr_fn_call := cast(*Ast.Expr_Fn_Call) expr;
            for arg_expr: expr_fn_call.args label_expr(arg_expr, label_store, erp);
        case .GROUP;
            expr_group := cast(*Ast.Expr_Group) expr;
            label_expr(expr_group.expr, label_store, erp);
        case .TERNARY;
            expr_ternary := cast(*Ast.Expr_Ternary) expr;
            label_expr(expr_ternary.condition, label_store, erp);
            label_expr(expr_ternary.true_expr, label_store, erp);
            label_expr(expr_ternary.false_expr, label_store, erp);
        case .ASSIGNMENT; #through;
        case .BINARY;     #through;
        case .CONSTANT;   #through;
        case .UNARY;      #through;
        case .VAR;        // noop
    }
}
