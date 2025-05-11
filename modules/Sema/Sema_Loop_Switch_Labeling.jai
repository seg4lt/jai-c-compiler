sema_loop_labeling :: (ast: *Program_Ast, error_reporter: *Error_Reporter) {
    sema_loop_labeling_fn(ast.fn, error_reporter);
}

#scope_file
// @todo
// differnet loop might have same label because we pop, maybe we need to generate some unique label

Loop_Label :: struct { label: string; };
Switch_Label :: struct {
    label: string;
    cases_label: [..]Case_Label_Info;
}

Label_Info :: struct {
    type: enum { LOOP; SWITCH; };
    as: union {
        loop: Loop_Label;
        switch: Switch_Label ;
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
            case .SWITCH;
                return *it.as.switch;
            case .LOOP; // noop
        }
    }
    return null;
}

get_closest_loop_label :: (label_info: *[..]Label_Info) -> *Loop_Label {
    for < label_info.* {
        if #complete it.type == {
            case .LOOP;
                return *it.as.loop;
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

sema_loop_labeling_fn :: (fn: *Fn_Ast, error_reporter: *Error_Reporter) {
    label_info: [..]Label_Info;
    defer free(*label_info);

    sema_loop_labeling_block(fn.block, *label_info, error_reporter);
}

sema_loop_labeling_block :: (block: *Block_Ast, label_info: *[..]Label_Info, error_reporter: *Error_Reporter) {
    sema_loop_labeling_block_item(*block.items, label_info, error_reporter);
}

sema_loop_labeling_block_item :: (block_items: *[..]*Block_Item_Ast, label_info: *[..]Label_Info, error_reporter: *Error_Reporter) {
    for block_items.* {
        if #complete it.type == {
            case .DECL; // noop
            case .STMT; 
                sema_loop_labeling_stmt(it.as.stmt, label_info, error_reporter);
        }
    }
   
}

sema_loop_labeling_stmt :: (stmt: *Stmt_Ast, label_info: *[..]Label_Info, error_reporter: *Error_Reporter) {
    if #complete stmt.type == {
        case .DEFAULT;
            switch_label_info := get_closest_switch_label(label_info);
            if !switch_label_info {
                error_report(error_reporter, stmt.loc.line, stmt.loc.start, "Default case without switch");
            }
            if has_default_case(*switch_label_info.cases_label) {
                error_report(error_reporter, stmt.loc.line, stmt.loc.start, "Default case already defined");
            }

            label := tprint("L.switch_default_case_%.%", switch_label_info.label, switch_label_info.cases_label.count);
            stmt.as.default = label;
            array_add(*switch_label_info.cases_label, .{label = label, value = "", is_default = true});
        case .CASE;
            switch_label_info := get_closest_switch_label(label_info);
            if !switch_label_info {
                error_report(error_reporter, stmt.loc.line, stmt.loc.start, "Default case without switch");
            }
            if has_same_case(*switch_label_info.cases_label, stmt.as.case_stmt.value) {
                error_report(error_reporter, stmt.loc.line, stmt.loc.start, "Case already defined");
            }
            label := tprint("L.switch_case_%.%", switch_label_info.label, switch_label_info.cases_label.count);
            array_add(*switch_label_info.cases_label, .{label = label, value = stmt.as.case_stmt.value, is_default = false});
            stmt.as.case_stmt.label = label;
        case .SWITCH;
            label := tprint("L.switch.%",label_info.count);
            stmt.as.switch.label = label;
            array_add(label_info, .{.SWITCH, .{ switch = .{ label = label }}});
            sema_loop_labeling_block_item(*stmt.as.switch.body, label_info, error_reporter);
            switch_label_info := pop(label_info);
            // @note
            // saving references to all cases switch has
            // Need this on tacky gen phase to know what cases we have so we can jump to right location
            stmt.as.switch.cases_label = switch_label_info.as.switch.cases_label;
            // print("\n-----asdfadsf----------\n"); for stmt.as.switch.cases_label {
            //     print("case: label=%,value=%", it.label,it.value);
            // }
            // print("\n---------------\n");
        case .IF;
            if_stmt := stmt.as.if_stmt;
            sema_loop_labeling_stmt(if_stmt.if_block, label_info, error_reporter);
            if stmt.as.if_stmt.else_block != null
                sema_loop_labeling_stmt(if_stmt.else_block, label_info, error_reporter);
        case .COMPOUND; 
            compound := stmt.as.compound;
            sema_loop_labeling_block(compound, label_info, error_reporter);
        case .WHILE;
            label := tprint("L.wloop.%", label_info.count);
            stmt.as.while_stmt.label = label;
            array_add(label_info, .{.LOOP, .{ loop = .{label} }});
            sema_loop_labeling_stmt(stmt.as.while_stmt.body, label_info, error_reporter);
            pop(label_info);
        case .CONTINUE;
            loop_info := get_closest_loop_label(label_info);
            if !loop_info {
                error_report(error_reporter, stmt.loc.line, stmt.loc.start, "You need to be in loop to use continue");
            }
            stmt.as.continue_stmt = loop_info.label;
        case .BREAK;
            if label_info.count <= 0 {
                error_report(error_reporter, stmt.loc.line, stmt.loc.start, "You need to be in loop or switch to use break");
            }
            stmt.as.break_stmt = get_any_closest_label(label_info);
        case .FOR;
            label := tprint("L.forloop.%", label_info.count);
            stmt.as.for_stmt.label = label;
            {
                array_add(label_info, .{ .LOOP, .{loop = .{label}}});
                defer pop(label_info);

                sema_loop_labeling_stmt(stmt.as.for_stmt.body,label_info, error_reporter);
            }
        case .DO_WHILE;
            label := tprint("L.dwloop.%", label_info.count);
            stmt.as.do_while.label = label;
            array_add(label_info, .{ .LOOP, .{loop = .{label}}});
            sema_loop_labeling_stmt(stmt.as.do_while.body,label_info, error_reporter);
            pop(label_info);
        case .RETURN; #through;
        case .EXPR; #through;
        case .LABEL; #through;
        case .GOTO; #through;
        case .NULL;
            // noop
    }
}

sema_loop_labeling_expr :: (expr: *Expr_Ast, label_stack: *[..]Label_Info, error_reporter: *Error_Reporter) {
    if #complete expr.type == {
        case .CONSTANT; #through;
        case .UNARY;  #through;
        case .BINARY; #through;
        case .ASSIGNMENT; #through;
        case .VAR; // noop

        case .GROUP; 
            sema_loop_labeling_expr(expr.as.group, label_stack, error_reporter);
        case .CONDITIONAL;
            conditional := expr.as.conditional;
            sema_loop_labeling_expr(conditional.true_block, label_stack, error_reporter);
            sema_loop_labeling_expr(conditional.false_block, label_stack, error_reporter);
    }
}
