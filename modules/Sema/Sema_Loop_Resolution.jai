sema_loop_labeling :: (ast: *Ast.Program, error_reporter: *Error_Reporter) {
    for decl: ast.decls {
        if #complete decl.kind == {
            case .FN;  label_fn(cast(*Ast.Fn_Decl) decl, error_reporter);
            case .VAR; // noop;
        }
    }
}

#scope_file

label_fn :: (fn: *Ast.Fn_Decl, error_reporter: *Error_Reporter) {
    label_info: [..]Label_Info;

    if fn.body != null label_block(fn.body, *label_info, error_reporter);
}

label_block :: (block: *Ast.Block, label_info: *[..]Label_Info, error_reporter: *Error_Reporter) {
    assert(block != null, "Block cannot be null");
    label_block_item(*block.items, label_info, error_reporter);
}

label_block_item :: (block_items: *[..]*Ast.Block_Item, label_info: *[..]Label_Info, error_reporter: *Error_Reporter) {
    for block_items.* {
        if #complete it.kind == {
            case .DECL; // noop
            case .STMT; 
                item_stmt := cast(*Ast.Block_Item_Stmt) it;
                label_stmt(item_stmt.stmt, label_info, error_reporter);
        }
    }

}

label_stmt :: (stmt: *Ast.Stmt, label_info: *[..]Label_Info, error_reporter: *Error_Reporter) {
    if #complete stmt.kind == {
        case .DEFAULT;
            stmt_default := cast(*Ast.Stmt_Default) stmt;
            switch_label_info := get_closest_switch_label(label_info);
            if !switch_label_info {
                error_report(error_reporter, stmt.line, stmt.start, "Default case without switch");
            }
            if has_default_case(*switch_label_info.cases_label) {
                error_report(error_reporter, stmt.line, stmt.start, "Default case already defined");
            }

            label := sprint("L.switch_default_case_%.%.r%", switch_label_info.label, switch_label_info.cases_label.count, get_4_digit_random());
            stmt_default.label = label;
            array_add(*switch_label_info.cases_label, .{label = label, value = "", is_default = true});
        case .CASE;
            stmt_case := cast(*Ast.Stmt_Case) stmt;
            slabel := get_closest_switch_label(label_info);

            if !slabel  error_report(error_reporter, stmt.line, stmt.start, "default case without switch");
            if has_same_case(*slabel.cases_label, stmt_case.value)  error_report(error_reporter, stmt.line, stmt.start, "case already defined");

            label := sprint("L.c%.%.r%", slabel.label, slabel.cases_label.count, get_4_digit_random());
            array_add(*slabel.cases_label, .{label = label, value = stmt_case.value, is_default = false});
            stmt_case.label = label;
        case .SWITCH;
            stmt_switch := cast(*Ast.Stmt_Switch) stmt;
            label := sprint("L.switch.%.r%", label_info.count, get_4_digit_random());
            stmt_switch.label = label;
            array_add(label_info, .{.SWITCH, .{ switch = .{ label = label }}});
            label_block_item(*stmt_switch.body, label_info, error_reporter);
            switch_label_info := pop(label_info);
            // saving references to all cases switch has
            // Need this on tacky gen phase to know what cases we have so we can jump to right location
            stmt_switch.cases_label = switch_label_info.as.switch.cases_label;
        case .IF;
            stmt_if := cast(*Ast.Stmt_If) stmt;
            label_stmt(stmt_if.if_block, label_info, error_reporter);
            if stmt_if.else_block != null label_stmt(stmt_if.else_block, label_info, error_reporter);
        case .COMPOUND;
            stmt_compound := cast(*Ast.Stmt_Compound) stmt;
            label_block(stmt_compound.block, label_info, error_reporter);
        case .WHILE;
            stmt_while := cast(*Ast.Stmt_While) stmt;
            label := sprint("L.wloop.%.r%", label_info.count, get_4_digit_random());
            stmt_while.label = label;
            array_add(label_info, .{.LOOP, .{ loop = .{label} }});
            label_stmt(stmt_while.body, label_info, error_reporter);
            pop(label_info);
        case .CONTINUE;
            stmt_continue := cast(*Ast.Stmt_Continue) stmt;
            loop_info := get_closest_loop_label(label_info);
            if !loop_info error_report(error_reporter, stmt.line, stmt.start, "you need to be in loop to use continue");
            stmt_continue.label = loop_info.label;
        case .BREAK;
            stmt_break := cast(*Ast.Stmt_Break) stmt;
            if label_info.count <= 0  error_report(error_reporter, stmt.line, stmt.start, "you need to be in loop or switch to use break");
            stmt_break.label = get_any_closest_label(label_info);
        case .FOR;
            stmt_for := cast(*Ast.Stmt_For) stmt;
            label := sprint("L.forloop.%.r%", label_info.count, get_4_digit_random());
            stmt_for.label = label;
            {
                array_add(label_info, .{ .LOOP, .{loop = .{label}}});
                defer pop(label_info);
                label_stmt(stmt_for.body,label_info, error_reporter);
            }
        case .DO_WHILE;
            stmt_do_while := cast(*Ast.Stmt_Do_While) stmt;
            label := sprint("L.dwloop.%.r%", label_info.count, get_4_digit_random());
            stmt_do_while.label = label;
            array_add(label_info, .{ .LOOP, .{loop = .{label}}});
            label_stmt(stmt_do_while.body, label_info, error_reporter);
            pop(label_info);
        case .LABEL;
            stmt_label := cast(*Ast.Stmt_Label) stmt;
            label_stmt(stmt_label.stmt, label_info, error_reporter);
        case .RETURN; #through;
        case .EXPR;   #through;
        case .GOTO;   #through;
        case .NULL;   // noop
    }
}

label_expr :: (expr: *Ast.Expr, label_stack: *[..]Label_Info, error_reporter: *Error_Reporter) {
    if #complete expr.kind == {
        case .CONSTANT;   #through;
        case .UNARY;      #through;
        case .BINARY;     #through;
        case .ASSIGNMENT; #through;
        case .VAR;        #through;
        case .FN_CALL;    #through;
        case .PREFIX;     #through;
        case .POSTFIX;    // noop

        case .GROUP;
            expr_group := cast(*Ast.Expr_Group) expr;
            label_expr(expr_group.expr, label_stack, error_reporter);
        case .TERNARY;
            expr_ternary := cast(*Ast.Expr_Ternary) expr;
            label_expr(expr_ternary.condition, label_stack, error_reporter);
            label_expr(expr_ternary.true_expr, label_stack, error_reporter);
            label_expr(expr_ternary.false_expr, label_stack, error_reporter);
    }
}


Loop_Label :: struct {
    label: string;
};

Switch_Label :: struct {
    label       : string;
    cases_label : [..]Ast.Case_Label_Info;
}

Label_Info :: struct {
    type : enum {
        LOOP;
        SWITCH;
    };
    as  : union {
        loop   : Loop_Label;
        switch : Switch_Label;
    };
}

has_default_case :: (case_labels: *[..]Ast.Case_Label_Info) -> bool {
    for case_labels.* {
        if it.is_default == true {
            return true;
        }
    }
    return false;
}

has_same_case :: (case_labels: *[..]Ast.Case_Label_Info, value: string) -> bool {
    for case_labels.* {
        if it.value == value {
            return true;
        }
    }
    return false;
}

get_closest_switch_label :: (label_info: *[..]Label_Info) -> *Switch_Label {
    for < label_info.* {
        if #complete it.type == {
            case .SWITCH; return *it.as.switch;
            case .LOOP;   // noop
        }
    }
    return null;
}

get_closest_loop_label :: (label_info: *[..]Label_Info) -> *Loop_Label {
    for < label_info.* {
        if #complete it.type == {
            case .LOOP;   return *it.as.loop;
            case .SWITCH; // noop
        }
    }
    return null;
}

get_any_closest_label :: (label_info: *[..]Label_Info) -> string {
    if label_info.count == 0 {
        assert(false, "No label info");
        return "";
    }
    if #complete peek(label_info.*).type == {
        case .SWITCH;
            return peek(label_info.*).as.switch.label;
        case .LOOP;
            return peek(label_info.*).as.loop.label;
    }
}
