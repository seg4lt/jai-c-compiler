
sema :: (ast: *Program_Ast_Node) {
    block_items := ast.fn.body;
    sema_variable_resolution(*block_items);
    sema_label_resolution(*block_items);
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

sema_label_resolution :: (block_items: *[..]Block_Item_Ast_Node) {
    label_table : Hash_Table.Table(string, string);
    Hash_Table.init(*label_table);
    defer Hash_Table.deinit(*label_table);

    // gather all labels
    for block_items.* {
        if #complete it.type == {
            case .DECL; // noop
            case .STMT; 
                sema_label_resolution_stmt(it.as.stmt, *label_table, block_items.*, it_index);
        }
    }

    goto_labels: Hash_Table.Table(string, string);
    Hash_Table.init(*goto_labels);
    defer Hash_Table.deinit(*goto_labels);

    // resolve all goto with correct label
    for block_items.* {
        if #complete it.type == {
            case .DECL; // noop
            case .STMT; sema_goto_resolution_stmt(it.as.stmt, *goto_labels, *label_table);
        }
    }
    // any ghost labels?
    for goto_labels {
        value, success := Hash_Table.table_find(*label_table, it_index);
        if !success assert(false, "goto label '%' not found.", it_index);
    }
}

sema_label_resolution_stmt :: (stmt: *Stmt_Ast_Node, table: *Table(string, string), block_items: []Block_Item_Ast_Node, index: int) {
    if #complete stmt.type == {
        case .RETURN;
            sema_label_resolution_expr(stmt.as.return_stmt.expr, table);
        case .EXPR;
            sema_label_resolution_expr(stmt.as.expr, table);
        case .IF;
            sema_label_resolution_expr(stmt.as.if_stmt.condition, table);
            sema_label_resolution_stmt(stmt.as.if_stmt.if_block, table, block_items, index);
            if stmt.as.if_stmt.else_block != null sema_label_resolution_stmt(stmt.as.if_stmt.else_block, table, block_items, index);
        case .LABEL; 
            if Hash_Table.table_contains(table, stmt.as.label) {
                assert(false, "duplicate label declaration! : %", stmt.as.label);
            }

            next_block_item := block_items.data + index + 1; 
            if (index + 1) >= block_items.count || next_block_item.*.type == .DECL { 
                assert(false, "label '%': must be followed by a statement, not a declaration or end of block.", stmt.as.label);
            }

            new_label := make_goto_label(stmt.as.label, table.count);
            Hash_Table.table_set(table, stmt.as.label, new_label);
            stmt.* = .{ .LABEL, .{ label = new_label }};

        case .GOTO; #through;
        case .NULL;
            // noop
    }
}
sema_goto_resolution_stmt :: (stmt: *Stmt_Ast_Node, goto_labels: *Hash_Table.Table(string, string), label_table: *Hash_Table.Table(string, string)) {
    if #complete stmt.type == {
        case .RETURN;
            sema_goto_resolution_expr(stmt.as.return_stmt.expr, goto_labels, label_table);
        case .EXPR;
            sema_goto_resolution_expr(stmt.as.expr, goto_labels, label_table);
        case .IF;
            sema_goto_resolution_expr(stmt.as.if_stmt.condition, goto_labels, label_table);
            sema_goto_resolution_stmt(stmt.as.if_stmt.if_block, goto_labels,label_table);
            if stmt.as.if_stmt.else_block != null sema_goto_resolution_stmt(stmt.as.if_stmt.else_block, goto_labels, label_table);
        case .GOTO; 
            value, success := Hash_Table.table_find(label_table, stmt.as.goto);
            if !success {
                assert(false, "undeclared label: '%'", stmt.as.goto);
            } 
            Hash_Table.table_set(goto_labels, stmt.as.goto, value);
            stmt.* = .{.GOTO, .{goto = value}};
        case .LABEL; #through;
        case .NULL;
            // noop
    }
}

sema_goto_resolution_expr :: (expr: *Expr_Ast_Node, goto_labels: *Hash_Table.Table(string, string), label_table: Table(string, string)) {
    if #complete expr.type == {
        case .CONSTANT; #through;
        case .UNARY;  #through;
        case .BINARY; #through;
        case .ASSIGNMENT; #through;
        case .VAR; // noop

        case .GROUP; 
            sema_goto_resolution_expr(expr.as.group, goto_labels, label_table);
        case .CONDITIONAL;
            conditional := expr.as.conditional;
            sema_goto_resolution_expr(conditional.true_block, goto_labels, label_table);
            sema_goto_resolution_expr(conditional.false_block, goto_labels, label_table);
    }
}

sema_label_resolution_expr :: (expr: *Expr_Ast_Node, table: *Hash_Table.Table(string, string)) {
    if #complete expr.type == {
        case .CONSTANT; #through;
        case .UNARY;  #through;
        case .BINARY; #through;
        case .ASSIGNMENT; #through;
        case .VAR; // noop

        case .GROUP; 
            sema_label_resolution_expr(expr.as.group, table);
        case .CONDITIONAL;
            conditional := expr.as.conditional;
            sema_label_resolution_expr(conditional.true_block, table);
            sema_label_resolution_expr(conditional.false_block, table);
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
        case .GOTO; #through;
        case .LABEL; #through;
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
make_goto_label :: (name: string, n: int) -> string {
    return tprint("goto_l_%.%", name, n);
}

#scope_file
Hash_Table :: #import "Hash_Table";
#import "Hash_Table";
#scope_export