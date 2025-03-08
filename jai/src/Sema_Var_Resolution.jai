
sema_var_resolution :: (ast: *Program_Ast_Node) {
    block := ast.fn.block;
    sema_var_resolution_block(block, null);
}

sema_var_resolution_block :: (block: *Block_Ast_Node, block_store: *Store) {
    new_block_store : Store;

    if block_store == null  {
        log("setting up totally new block .. \n");
        init(*new_block_store);
    } else   {
        log("setting up nested block ... \n");
        new_block_store = table_clone_owing_entry(block_store);
    }
    defer deinit(*new_block_store);

    sema_var_resolution_block_item(*block.items, *new_block_store);
}

sema_var_resolution_block_item :: (block_items: *[..]*Block_Item_Ast_Node, block_store: *Store) {
    for block_items.* {
        if #complete it.type == {
            case .DECL; sema_var_resolution_decl(it.as.decl, block_store);
            case .STMT; sema_var_resolution_stmt(it.as.stmt, block_store);
        }
    }
}

sema_var_resolution_stmt :: (stmt: *Stmt_Ast_Node, block_store: *Store) {
    if #complete stmt.type == {
        case .RETURN;
            sema_var_resolution_expr(stmt.as.return_stmt.expr, block_store);
        case .EXPR;
            sema_var_resolution_expr(stmt.as.expr, block_store);
        case .IF;
            if_stmt := stmt.as.if_stmt;
            sema_var_resolution_expr(if_stmt.condition, block_store);
            sema_var_resolution_stmt(if_stmt.if_block, block_store);
            if if_stmt.else_block != null 
                sema_var_resolution_stmt(if_stmt.else_block, block_store);
        case .COMPOUND;
            compound := stmt.as.compound;
            sema_var_resolution_block(compound, block_store);
        case .FOR;
            assert(false, "not implemented");
        case .DO_WHILE;
            assert(false, "not implemented");
        case .WHILE; #through;
        case .CONTINUE; #through;
        case .BREAK; #through;
        case .GOTO; #through;
        case .LABEL; #through;
        case .NULL;
            // noop
    }
}

sema_var_resolution_decl:: (decl: *Decl_Ast_Node, block_store: *Store) {
    entry, success := table_find(block_store, decl.ident);
    if success && entry.owing_block {
        assert(false, "duplicate variable declaration! : %", decl.ident);
    } 
    new_ident := make_variable(decl.ident, block_store.count);
    table_set(block_store, decl.ident, .{true, new_ident});

    ifx decl.init sema_var_resolution_expr(decl.init, block_store);
    decl.* = .{ new_ident, decl.init};
}

sema_var_resolution_expr :: (expr: *Expr_Ast_Node, table: *Store) {
    if #complete expr.type == {
        case .CONSTANT; // noop
        case .UNARY; 
            sema_var_resolution_expr(expr.as.unary.expr, table);
        case .BINARY;
            sema_var_resolution_expr(expr.as.binary.left, table);
            sema_var_resolution_expr(expr.as.binary.right, table);
        case .GROUP;
            sema_var_resolution_expr(expr.as.group, table);
        case .VAR;
            value, success := table_find(table, expr.as.var);
            if !success {
                assert(false, "undeclared variable: %", expr.as.var);
            }
            expr.as.var = value.processed;
        case .ASSIGNMENT;
            assignment := expr.as.assignment;
            // verify dst is valid lvalue

            if !(assignment.dst.type == .VAR || (assignment.dst.type == .GROUP && assignment.dst.as.group.type == .VAR)) {
                print("\n-- DEBUG -- \n");
                print_expr_ast(expr);
                print("\n-- DEBUG -- \n");
                assert(false, "expected variable (invalid lvalue) found: %", expr.as.assignment.dst.*);
            }
            dst := ifx assignment.dst.type == .VAR then assignment.dst else assignment.dst.as.group;
            sema_var_resolution_expr(dst, table);
            sema_var_resolution_expr(assignment.src, table);
        case .CONDITIONAL;
            conditional := expr.as.conditional;
            sema_var_resolution_expr(conditional.condition, table);
            sema_var_resolution_expr(conditional.true_block, table);
            sema_var_resolution_expr(conditional.false_block, table);
    }
}