
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

    decl.ident = new_ident;
    if decl.init sema_var_resolution_expr(decl.init, table);
}

sema_var_resolution_expr :: (expr: *Expr_Ast_Node, table: *Hash_Table.Table(string, string)) {
    if #complete expr.type == {
        case .CONSTANT;
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
            if assignment.dst.type != .VAR {
                assert(false, "expected variable (invalid lvalue) found: %", expr.as.assignment.dst);
            }
            sema_var_resolution_expr(assignment.dst, table);
            sema_var_resolution_expr(assignment.src, table);
    }
}

make_variable :: (name: string, n: int) -> string {
    return tprint("var_%.%", name, n);
}

#scope_file
Hash_Table :: #import "Hash_Table";
#scope_export