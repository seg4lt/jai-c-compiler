
sema_var_resolution :: (ast: *Program_Ast, error_reporter: *Error_Reporter) {
    block := ast.fn.block;
    sema_var_resolution_block(block, null, error_reporter);
}

#scope_file

sema_var_resolution_block :: (block: *Block_Ast, block_store: *Store, error_reporter: *Error_Reporter) {
    sema_var_resolution_block_item(*block.items, block_store, error_reporter);
}

sema_var_resolution_block_item :: (block_items: *[..]*Block_Item_Ast, block_store: *Store, error_reporter: *Error_Reporter) {
    new_block_store : Store;

    if block_store == null  {
        log("setting up totally new block .. \n");
        init(*new_block_store);
    } else   {
        log("setting up nested block ... \n");
        new_block_store = table_clone_owing_entry(block_store);
    }
    defer deinit(*new_block_store);

    for block_items.* {
        if #complete it.type == {
            case .DECL; sema_var_resolution_decl(it.as.decl, *new_block_store, error_reporter);
            case .STMT; sema_var_resolution_stmt(it.as.stmt, *new_block_store, error_reporter);
        }
    }
}

sema_var_resolution_stmt :: (stmt: *Stmt_Ast, block_store: *Store, error_reporter: *Error_Reporter) {
    if #complete stmt.type == {
        case .SWITCH;
            sema_var_resolution_expr(stmt.as.switch.condition, block_store, error_reporter);
            sema_var_resolution_block_item(*stmt.as.switch.body, block_store, error_reporter);
        case .RETURN;
            sema_var_resolution_expr(stmt.as.return_stmt.expr, block_store, error_reporter);
        case .EXPR;
            sema_var_resolution_expr(stmt.as.expr, block_store, error_reporter);
        case .IF;
            if_stmt := stmt.as.if_stmt;
            sema_var_resolution_expr(if_stmt.condition, block_store, error_reporter);
            sema_var_resolution_stmt(if_stmt.if_block, block_store, error_reporter);
            if if_stmt.else_block != null 
                sema_var_resolution_stmt(if_stmt.else_block, block_store, error_reporter);
        case .COMPOUND;
            compound := stmt.as.compound;
            sema_var_resolution_block(compound, block_store, error_reporter);
        case .FOR;
            new_block_store : Store;
            defer deinit(*new_block_store);
            new_block_store = table_clone_owing_entry(block_store);
            for_stmt := stmt.as.for_stmt;
            if #complete for_stmt.init.type == {
                case .INIT_DECL;
                    sema_var_resolution_decl(for_stmt.init.as.decl, *new_block_store, error_reporter);
                case .INIT_EXPR;
                    if for_stmt.init.as.expr != null {
                        sema_var_resolution_expr(for_stmt.init.as.expr, *new_block_store, error_reporter);
                    }
            }
            if for_stmt.condition != null {
                sema_var_resolution_expr(for_stmt.condition, *new_block_store, error_reporter);
            }
            if for_stmt.post != null {
                sema_var_resolution_expr(for_stmt.post, *new_block_store, error_reporter);
            }
            sema_var_resolution_stmt(for_stmt.body, *new_block_store, error_reporter);
        case .DO_WHILE;
            do_while_stmt := stmt.as.do_while;
            sema_var_resolution_stmt(do_while_stmt.body, block_store, error_reporter);
            sema_var_resolution_expr(do_while_stmt.condition, block_store, error_reporter);
        case .WHILE;
            while_stmt := stmt.as.while_stmt;
            sema_var_resolution_expr(while_stmt.condition, block_store, error_reporter);
            sema_var_resolution_stmt(while_stmt.body, block_store, error_reporter);
        case .CONTINUE; #through;
        case .BREAK; #through;
        case .GOTO; #through;
        case .LABEL; #through;
        case .DEFAULT; #through;
        case .CASE; #through;
        case .NULL;
            // noop
    }
}

sema_var_resolution_decl:: (decl: *Decl_Ast, block_store: *Store, error_reporter: *Error_Reporter) {
    entry, success := table_find(block_store, decl.ident);
    if success && entry.owing_block {
        error_report(error_reporter, decl.loc.line, decl.loc.start, "duplicate variable declaration! : %", decl.ident);
    } 
    new_ident := make_variable(decl.ident, block_store.count);
    table_set(block_store, decl.ident, .{true, new_ident});

    ifx decl.init sema_var_resolution_expr(decl.init, block_store, error_reporter);
    decl.* = .{ new_ident, decl.init, decl.loc };
}

sema_var_resolution_expr :: (expr: *Expr_Ast, table: *Store, error_reporter: *Error_Reporter) {
    if #complete expr.type == {
        case .CONSTANT; // noop
        case .UNARY; 
            sema_var_resolution_expr(expr.as.unary.expr, table, error_reporter);
        case .BINARY;
            sema_var_resolution_expr(expr.as.binary.left, table, error_reporter);
            sema_var_resolution_expr(expr.as.binary.right, table, error_reporter);
        case .GROUP;
            sema_var_resolution_expr(expr.as.group, table, error_reporter);
        case .VAR;
            value, success := table_find(table, expr.as.var);
            if !success {
                error_report(error_reporter, expr.loc.line, expr.loc.start, "undeclared variable: %", expr.as.var);
            }
            expr.as.var = value.processed;
        case .ASSIGNMENT;
            assignment := expr.as.assignment;
            // verify dst is valid lvalue
            if !(assignment.dst.type == .VAR || (assignment.dst.type == .GROUP && assignment.dst.as.group.type == .VAR)) {
                error_report(error_reporter, expr.loc.line, expr.loc.start,"expected variable (invalid lvalue) found: %", expr.as.assignment.dst.*);
            }
            dst := ifx assignment.dst.type == .VAR then assignment.dst else assignment.dst.as.group;
            sema_var_resolution_expr(dst, table, error_reporter);
            sema_var_resolution_expr(assignment.src, table, error_reporter);
        case .CONDITIONAL;
            conditional := expr.as.conditional;
            sema_var_resolution_expr(conditional.condition, table, error_reporter);
            sema_var_resolution_expr(conditional.true_block, table, error_reporter);
            sema_var_resolution_expr(conditional.false_block, table, error_reporter);
    }
}