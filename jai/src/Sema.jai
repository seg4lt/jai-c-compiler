
sema :: (ast: *Program_Ast_Node) {
    block_items := ast.fn.body;
    sema_variable_resolution(*block_items);
    print("\n-- AFTER SEMA --\n");
    print_program_ast(ast);
}

sema_variable_resolution :: (block_items: *[..]Block_Item_Ast_Node) {

    table : Hash_Table.Table(string, string);
    Hash_Table.init(*table);
    defer Hash_Table.deinit(*table);

    for block_items.* {
        if #complete it.type == {
            case .DECL; sema_var_resolution_decl(it.as.decl, *table);
            case .STMT; sema_var_resolution_stmt(it.as.stmt, *table);
        }
    }
}

sema_var_resolution_stmt :: (stmt: *Stmt_Ast_Node, table: *Hash_Table.Table(string, string)) {
    if #complete stmt.type == {
        case .RETURN;
            sema_var_resolution_expr(stmt.as.return_stmt.expr, table);
        case .EXPR;
            sema_var_resolution_expr(stmt.as.expr, table);
        case .IF;
            sema_var_resolution_expr(stmt.as.if_stmt.condition, table);
            sema_var_resolution_stmt(stmt.as.if_stmt.if_block, table);
            if stmt.as.if_stmt.else_block != null sema_var_resolution_stmt(stmt.as.if_stmt.else_block, table);
        case .NULL;
            // noop
    }
}

sema_var_resolution_decl:: (decl: *Decl_Ast_Node, table: *Hash_Table.Table(string, string)) {
    if Hash_Table.table_contains(table, decl.ident) {
        assert(false, "duplicate variable declaration! : %", decl.ident);
    }
    new_ident := make_variable(decl.ident, table.count);
    Hash_Table.table_set(table, decl.ident, new_ident);

    ifx decl.init sema_var_resolution_expr(decl.init, table);
    decl.* = .{ new_ident, decl.init};
}

sema_var_resolution_expr :: (expr: *Expr_Ast_Node, table: *Hash_Table.Table(string, string)) {
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
            value, success := Hash_Table.table_find(table, expr.as.var);
            if !success {
                assert(false, "undeclared variable: %", expr.as.var);
            }
            expr.as.var = value;
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

make_variable :: (name: string, n: int) -> string {
    return tprint("var_%.%", name, n);
}

#scope_file
Hash_Table :: #import "Hash_Table";
#scope_export