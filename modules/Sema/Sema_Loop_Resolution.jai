sema_loop_labeling :: (ast: *Program_Ast, error_reporter: *Error_Reporter) {
    for *decl: ast.decls {
        using decl.*;
        if #complete type == {
            case .FN;  label_fn(decl_fn, error_reporter); 
            case .VAR; // noop;
        }
    }
}

#scope_file

label_fn :: (fn: *Fn_Decl_Ast, error_reporter: *Error_Reporter) {
    label_info: [..]Label_Info;

    if fn.block != null label_block(fn.block, *label_info, error_reporter);
}

label_block :: (block: *Block_Ast, label_info: *[..]Label_Info, error_reporter: *Error_Reporter) {
    assert(block != null, "Block cannot be null");
    label_block_item(*block.items, label_info, error_reporter);
}

label_block_item :: (block_items: *[..]*Block_Item_Ast, label_info: *[..]Label_Info, error_reporter: *Error_Reporter) {
    for block_items.* {
        using it;
        if #complete type == {
            case .DECL; // noop
            case .STMT; label_stmt(block_item_stmt, label_info, error_reporter);
        }
    }

}

label_stmt :: (using stmt: *Stmt_Ast, label_info: *[..]Label_Info, error_reporter: *Error_Reporter) {
    if #complete stmt.type == {
        case .DEFAULT;
            switch_label_info := get_closest_switch_label(label_info);
            if !switch_label_info {
                error_report(error_reporter, stmt.loc.line, stmt.loc.start, "Default case without switch");
            }
            if has_default_case(*switch_label_info.cases_label) {
                error_report(error_reporter, stmt.loc.line, stmt.loc.start, "Default case already defined");
            }

            label := sprint("L.switch_default_case_%.%.r%", switch_label_info.label, switch_label_info.cases_label.count, get_4_digit_random());
            stmt_default = label;
            array_add(*switch_label_info.cases_label, .{label = label, value = "", is_default = true});
        case .CASE;
            slabel := get_closest_switch_label(label_info);
            
            if !slabel  error_report(error_reporter, line, start, "default case without switch");
            if has_same_case(*slabel.cases_label, stmt_case.value)  error_report(error_reporter, line, start, "case already defined");
            
            label := sprint("L.c%.%.r%", slabel.label, slabel.cases_label.count, get_4_digit_random());
            array_add(*slabel.cases_label, .{label = label, value = stmt_case.value, is_default = false});
            stmt_case.label = label;
        case .SWITCH;
            label := sprint("L.switch.%.r%", label_info.count, get_4_digit_random());
            stmt_switch.label = label;
            array_add(label_info, .{.SWITCH, .{ switch = .{ label = label }}});
            label_block_item(*stmt_switch.body, label_info, error_reporter);
            switch_label_info := pop(label_info);
            // saving references to all cases switch has
            // Need this on tacky gen phase to know what cases we have so we can jump to right location
            stmt_switch.cases_label = switch_label_info.as.switch.cases_label;
        case .IF;
            label_stmt(stmt_if.if_block, label_info, error_reporter);
            if stmt.as.stmt_if.else_block != null label_stmt(stmt_if.else_block, label_info, error_reporter);
        case .COMPOUND;
            label_block(stmt_compound, label_info, error_reporter);
        case .WHILE;
            label := sprint("L.wloop.%.r%", label_info.count, get_4_digit_random());
            stmt_while.label = label;
            array_add(label_info, .{.LOOP, .{ loop = .{label} }});
            label_stmt(stmt_while.body, label_info, error_reporter);
            pop(label_info);
        case .CONTINUE;
            loop_info := get_closest_loop_label(label_info);
            if !loop_info error_report(error_reporter, line, start, "you need to be in loop to use continue");
            stmt_continue = loop_info.label;
        case .BREAK;
            if label_info.count <= 0  error_report(error_reporter, line, start, "you need to be in loop or switch to use break");
            stmt_break = get_any_closest_label(label_info);
        case .FOR;
            label := sprint("L.forloop.%.r%", label_info.count, get_4_digit_random());
            stmt_for.label = label;
            {
                array_add(label_info, .{ .LOOP, .{loop = .{label}}});
                defer pop(label_info);
                label_stmt(stmt_for.body,label_info, error_reporter);
            }
        case .DO_WHILE;
            label := sprint("L.dwloop.%.r%", label_info.count, get_4_digit_random());
            stmt_do_while.label = label;
            array_add(label_info, .{ .LOOP, .{loop = .{label}}});
            label_stmt(stmt_do_while.body, label_info, error_reporter);
            pop(label_info);
        case .LABEL;
            label_stmt(stmt_label.stmt, label_info, error_reporter);
        case .RETURN; #through;
        case .EXPR;   #through;
        case .GOTO;   #through;
        case .NULL;   // noop
    }
}

label_expr :: (expr: *Expr_Ast, label_stack: *[..]Label_Info, error_reporter: *Error_Reporter) {
    if #complete expr.type == {
        case .CONSTANT;   #through;
        case .UNARY;      #through;
        case .BINARY;     #through;
        case .ASSIGNMENT; #through;
        case .VAR;        // noop

        case .GROUP;
            label_expr(expr.as.group, label_stack, error_reporter);
        case .CONDITIONAL;
            conditional := expr.as.conditional;
            label_expr(conditional.true_block, label_stack, error_reporter);
            label_expr(conditional.false_block, label_stack, error_reporter);
    }
}


Loop_Label :: struct {
    label: string;
};

Switch_Label :: struct {
    label       : string;
    cases_label : [..]Case_Label_Info;
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

has_default_case :: (case_labels: *[..]Case_Label_Info) -> bool {
    for case_labels.* {
        if it.is_default == true {
            return true;
        }
    }
    return false;
}

has_same_case :: (case_labels: *[..]Case_Label_Info, value: string) -> bool {
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