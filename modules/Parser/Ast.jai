Ast :: struct {
    Program :: struct {
        decls: [..]*Decl;

        new :: (decls: [..]*Decl) -> *Program #expand {
            p := New(Program);
            p.decls = decls;
            return p;
        }
    }

    Builtin_Type :: struct {
        kind: Kind;

        Kind :: enum { INT; LONG; FN; };
    };
    Builtin_Type_Int :: struct {
        #as using base: Builtin_Type;
        kind = .INT;

        new :: () -> *Builtin_Type_Int #expand {
            builtin_type := New(Builtin_Type_Int);
            return builtin_type;
        }
    };

    Builtin_Type_Long :: struct {
        #as using base: Builtin_Type;
        kind = .LONG;

        new :: () -> *Builtin_Type_Long #expand {
            builtin_type := New(Builtin_Type_Long);
            return builtin_type;
        }
    };

    Builtin_Type_Fn :: struct {
        #as using base: Builtin_Type;
        kind = .FN;
        params: [..]*Builtin_Type;
        return_type: *Builtin_Type; 
        
        new :: (params: [..]*Builtin_Type, return_type: *Builtin_Type) -> *Builtin_Type_Fn #expand {
            assert(return_type != null, "return_type cannot be null");
            builtin_type := New(Builtin_Type_Fn);
            builtin_type.params = params;
            builtin_type.return_type = return_type;
            return builtin_type;
        } 
    };

    Storage_Class :: enum { EXTERN; STATIC; NONE; };

    Decl_Kind :: enum { FN; VAR; };
    Decl :: struct {
        kind: Decl_Kind;
        ident: string;
        storage_class: Storage_Class;
        type: *Builtin_Type;
        using loc: Source_Location;
    };

    Fn_Decl :: struct {
        #as using decl: Decl;
        kind = Decl_Kind.FN;
        params: [..]*Fn_Param;
        body: *Block; @Optional

        Fn_Param :: struct {
            ident:     string;
            using loc: Source_Location;
        }

        new :: (ident: string, fn_type: *Builtin_Type, params: [..]*Fn_Param, block: *Block, storage_class: Storage_Class, line: int, start: int) -> *Fn_Decl #expand {
            assert(ident != "", "ident can't be null");
            fn := New(Fn_Decl);
            fn.ident = ident;
            fn.storage_class = storage_class;
            fn.loc = .{line, start};
            fn.params = params;
            fn.body = block;
            fn.type = fn_type;
            return fn;
        }

        as_decl :: (fn: *Fn_Decl) -> *Decl #expand {
            assert(fn != null, "fn cannot be null");
            return fn;
        }
    };

    Var_Decl :: struct {
        #as using decl: Decl;
        kind = Decl_Kind.VAR;
        init: *Expr; @Optional

        new :: (ident: string, var_type: *Builtin_Type, init: *Expr, storage_class: Storage_Class, line: int, start: int) -> *Decl #expand {
            assert(ident != "", "ident can't be null");
            var := New(Var_Decl);
            var.ident = ident;
            var.storage_class = storage_class;
            var.loc = .{line, start};
            var.init = init;
            var.type = var_type;
            return var;
        }
    }

    Block_Item_Kind :: enum { STMT; DECL; };
    Block_Item :: struct {
        kind: Block_Item_Kind;
    }

    Block_Item_Stmt :: struct {
        #as using base: Block_Item;
        kind = Block_Item_Kind.STMT;
        stmt: *Stmt;

        new :: (stmt: *Stmt) -> *Block_Item #expand {
            assert(stmt != null, "stmt cannot be null");
            item := New(Block_Item_Stmt);
            item.stmt = stmt;
            return item;
        }
    }

    Block_Item_Decl :: struct {
        #as using base: Block_Item;
        kind = Block_Item_Kind.DECL;
        decl: *Decl;

        new :: (decl: *Decl) -> *Block_Item #expand {
            assert(decl != null, "decl cannot be null");
            item := New(Block_Item_Decl);
            item.decl = decl;
            return item;
        }
    }

    For_Init_Kind :: enum { DECL; EXPR; };
    For_Init :: struct {
        kind: For_Init_Kind;
    }

    For_Init_Decl :: struct {
        #as using base: For_Init;
        kind = For_Init_Kind.DECL;
        decl: *Decl;

        new :: (decl: *Decl) -> *For_Init #expand {
            assert(decl != null, "decl cannot be null");
            init := New(For_Init_Decl);
            init.decl = decl;
            return init;
        }
    }

    For_Init_Expr :: struct {
        #as using base: For_Init;
        kind = For_Init_Kind.EXPR;
        expr: *Expr; @Optional

        new :: (expr: *Expr) -> *For_Init #expand {
            init := New(For_Init_Expr);
            init.expr = expr;
            return init;
        }
    }

    Stmt_Kind :: enum {
        BREAK;
        CASE;
        COMPOUND;
        CONTINUE;
        DEFAULT;
        DO_WHILE;
        EXPR;
        FOR;
        GOTO;
        IF;
        LABEL;
        NULL;
        RETURN;
        SWITCH;
        WHILE;
    };

    Stmt :: struct {
        kind: Stmt_Kind;
        using loc: Source_Location;
    }

    Stmt_Break :: struct {
        #as using base: Stmt;
        kind = Stmt_Kind.BREAK;
        label: string;

        new :: (line: int, start: int) -> *Stmt #expand {
            stmt := New(Stmt_Break);
            stmt.loc = .{line, start};
            stmt.label = "$$$UNPROCESSED$$$";
            return stmt;
        }
    }

    Stmt_Case :: struct {
        #as using base: Stmt;
        kind = Stmt_Kind.CASE;
        value: string;
        label: string;

        new :: (value: string, line: int, start: int) -> *Stmt #expand {
            assert(value != "", "value cannot be null");
            stmt := New(Stmt_Case);
            stmt.loc = .{line, start};
            stmt.value = value;
            stmt.label = "$$UNPROCESSED$$";
            return stmt;
        }
    }

    Stmt_Compound :: struct {
        #as using base: Stmt;
        kind = Stmt_Kind.COMPOUND;
        block: *Block;

        new :: (block: *Block) -> *Stmt #expand {
            assert(block != null, "block cannot be null");
            stmt := New(Stmt_Compound);
            stmt.loc = .{block.line, block.start};
            stmt.block = block;
            return stmt;
        }
    }

    Stmt_Continue :: struct {
        #as using base: Stmt;
        kind = Stmt_Kind.CONTINUE;
        label: string;

        new :: (line: int, start: int) -> *Stmt #expand {
            stmt := New(Stmt_Continue);
            stmt.loc = .{line, start};
            stmt.label = "$$$UNPROCESSED$$$";
            return stmt;
        }
    }

    Stmt_Default :: struct {
        #as using base: Stmt;
        kind = Stmt_Kind.DEFAULT;
        label: string;

        new :: (line: int, start: int) -> *Stmt #expand {
            stmt := New(Stmt_Default);
            stmt.loc = .{line, start};
            stmt.label = "$$UNPROCESSED$$";
            return stmt;
        }
    }

    Stmt_Do_While :: struct {
        #as using base: Stmt;
        kind = Stmt_Kind.DO_WHILE;
        body: *Stmt;
        condition: *Expr;
        label: string;

        new :: (body: *Stmt, condition: *Expr, line: int, start: int, label: string = "$$UNPROCESSED$$") -> *Stmt #expand {
            assert(body != null, "body cannot be null");
            assert(condition != null, "condition cannot be null");
            stmt := New(Stmt_Do_While);
            stmt.loc = .{line, start};
            stmt.body = body;
            stmt.condition = condition;
            stmt.label = label;
            return stmt;
        }
    }

    Stmt_Expr :: struct {
        #as using base: Stmt;
        kind = Stmt_Kind.EXPR;
        expr: *Expr;

        new :: (expr: *Expr, line: int, start: int) -> *Stmt #expand {
            assert(expr != null, "expr cannot be null");
            stmt := New(Stmt_Expr);
            stmt.loc = .{line, start};
            stmt.expr = expr;
            return stmt;
        }
    }

    Stmt_For :: struct {
        #as using base: Stmt;
        kind = Stmt_Kind.FOR;
        init: *For_Init;
        condition: *Expr; @Optional
        post: *Expr; @Optional
        body: *Stmt;
        label: string;

        new :: (init: *For_Init, condition: *Expr, post: *Expr, body: *Stmt, line: int, start: int, label: string = "$$UNPROCESSED$$") -> *Stmt #expand {
            assert(init != null, "init cannot be null");
            assert(body != null, "body cannot be null");
            stmt := New(Stmt_For);
            stmt.loc = .{line, start};
            stmt.init = init;
            stmt.condition = condition;
            stmt.post = post;
            stmt.body = body;
            stmt.label = label;
            return stmt;
        }
    }

    Stmt_Goto :: struct {
        #as using base: Stmt;
        kind = Stmt_Kind.GOTO;
        label: string;

        new :: (label: string, line: int, start: int) -> *Stmt #expand {
            assert(label != "", "label cannot be null");
            stmt := New(Stmt_Goto);
            stmt.loc = .{line, start};
            stmt.label = label;
            return stmt;
        }
    }

    Stmt_If :: struct {
        #as using base: Stmt;
        kind = Stmt_Kind.IF;
        condition: *Expr;
        if_block: *Stmt;
        else_block: *Stmt; @Optional

        new :: (condition: *Expr, if_block: *Stmt, else_block: *Stmt, line: int, start: int) -> *Stmt #expand {
            assert(condition != null, "condition cannot be null");
            assert(if_block != null, "if_block cannot be null");
            stmt := New(Stmt_If);
            stmt.loc = .{line, start};
            stmt.condition = condition;
            stmt.if_block = if_block;
            stmt.else_block = else_block;
            return stmt;
        }
    }

    Stmt_Label :: struct {
        #as using base: Stmt;
        kind = Stmt_Kind.LABEL;
        label: string;
        stmt: *Stmt;

        new :: (label: string, l_stmt: *Stmt, line: int, start: int) -> *Stmt #expand {
            assert(label != "", "label cannot be null");
            stmt := New(Stmt_Label);
            stmt.loc = .{line, start};
            stmt.label = label;
            stmt.stmt = l_stmt;
            return stmt;
        }
    }

    Stmt_Null :: struct {
        #as using base: Stmt;
        kind = Stmt_Kind.NULL;

        new :: (line: int, start: int) -> *Stmt #expand {
            stmt := New(Stmt_Null);
            stmt.loc = .{line, start};
            return stmt;
        }
    }

    Stmt_Return :: struct {
        #as using base: Stmt;
        kind = Stmt_Kind.RETURN;
        expr: *Expr;

        new :: (expr: *Expr, line: int, start: int) -> *Stmt #expand {
            assert(expr != null, "expr cannot be null");
            stmt := New(Stmt_Return);
            stmt.loc = .{line, start};
            stmt.expr = expr;
            return stmt;
        }
    }

    Stmt_Switch :: struct {
        #as using base: Stmt;
        kind = Stmt_Kind.SWITCH;
        condition: *Expr;
        body: [..]*Block_Item;
        label: string;
        cases_label: [..]Case_Label_Info;

        new :: (condition: *Expr, body: [..]*Block_Item, line: int, start: int, label: string = "$$$$$$$$$") -> *Stmt #expand {
            assert(condition != null, "condition cannot be null");
            stmt := New(Stmt_Switch);
            stmt.loc = .{line, start};
            stmt.condition = condition;
            stmt.body = body;
            stmt.label = label;
            return stmt;
        }
    }

    Stmt_While :: struct {
        #as using base: Stmt;
        kind = Stmt_Kind.WHILE;
        condition: *Expr;
        body: *Stmt;
        label: string;

        new :: (condition: *Expr, body: *Stmt, line: int, start: int, label: string = "$$UNPROCESSED$$") -> *Stmt #expand {
            assert(condition != null, "condition cannot be null");
            assert(body != null, "body cannot be null");
            stmt := New(Stmt_While);
            stmt.loc = .{line, start};
            stmt.condition = condition;
            stmt.body = body;
            stmt.label = label;
            return stmt;
        }
    }

    Case_Label_Info :: struct {
        label:      string;
        value:      string;
        is_default: bool = true;
    }

    Expr_Kind :: enum {
        ASSIGNMENT;
        BINARY;
        CONSTANT;
        FN_CALL;
        GROUP;
        TERNARY;
        UNARY;
        VAR;
        PREFIX;
        POSTFIX;
        CAST;
    };

    Expr :: struct {
        kind: Expr_Kind;
        type: *Builtin_Type;
        using loc: Source_Location;
    }


    Expr_Cast :: struct {
        #as using base: Expr;
        kind = .CAST;

        target_type: *Builtin_Type;
        expr: *Expr;

        new :: (target_type: *Builtin_Type, expr: *Expr, line: int, start: int) -> *Expr #expand {
            assert(target_type != null, "target_type cannot be null");
            assert(expr != null, "expr cannot be null");
            cast_expr := New(Expr_Cast);
            cast_expr.line = line;
            cast_expr.start = start;
            cast_expr.target_type = target_type;
            cast_expr.expr = expr;
            return cast_expr;
        }
    };

    Expr_Assignment :: struct {
        #as using base: Expr;
        kind = Expr_Kind.ASSIGNMENT;
        dst: *Expr;
        src: *Expr;

        new :: (dst: *Expr, src: *Expr, line: int, start: int) -> *Expr #expand {
            assert(dst != null, "dst cannot be null");
            assert(src != null, "src cannot be null");
            expr := New(Expr_Assignment);
            expr.loc = .{line, start};
            expr.dst = dst;
            expr.src = src;
            return expr;
        }
    }

    Expr_Binary :: struct {
        #as using base: Expr;
        kind = .BINARY;

        op: Binary_Operator;
        left: *Expr;
        right: *Expr;

        new :: (op: Binary_Operator, left: *Expr, right: *Expr, line: int, start: int) -> *Expr #expand {
            assert(left != null, "left cannot be null");
            assert(right != null, "right cannot be null");
            expr := New(Expr_Binary);
            expr.loc = .{line, start};
            expr.op = op;
            expr.left = left;
            expr.right = right;
            return expr;
        }
    }


    Constant :: struct {
        kind: Kind;
        Kind :: enum { INT; LONG; };
    }

    Constant_Int :: struct {
        #as using base: Constant;
        kind = .INT;
        value: int;

        new :: (value: int) -> *Constant_Int #expand {
            constant := New(Constant_Int);
            constant.value = value;
            return constant;
        }
    }

    Constant_Long :: struct {
        #as using base: Constant;
        kind = .LONG;
        value: s64;

        new :: (value: s64) -> *Constant_Long #expand {
            constant := New(Constant_Long);
            constant.value = value;
            return constant;
        }
    }

    Expr_Constant :: struct {
        #as using base: Expr;
        kind = .CONSTANT;
        value: *Constant;

        new_int :: (value: int, line: int, start: int) -> *Expr #expand {
            expr := New(Expr_Constant);
            expr.loc = .{line, start};
            constant := Constant_Int.new(value);
            expr.value = constant;
            return expr;
        }

        new_long :: (value: s64, line: int, start: int) -> *Expr #expand {
            expr := New(Expr_Constant);
            expr.loc = .{line, start};
            constant := Constant_Long.new(value);
            expr.value = constant;
            return expr;
        }
    }

    Expr_Fn_Call :: struct {
        #as using base: Expr;
        kind = Expr_Kind.FN_CALL;
        ident: string;
        args: [..]*Expr;

        new :: (ident: string, args_list: [..]*Expr, line: int, start: int) -> *Expr #expand {
            assert(ident != "", "ident cannot be null");
            expr := New(Expr_Fn_Call);
            expr.loc = .{line, start};
            expr.ident = ident;
            expr.args = args_list;
            return expr;
        }
    }

    Expr_Group :: struct {
        #as using base: Expr;
        kind = Expr_Kind.GROUP;
        expr: *Expr;

        new :: (expr: *Expr, line: int, start: int) -> *Expr #expand {
            assert(expr != null, "expr cannot be null");
            e := New(Expr_Group);
            e.loc = .{line, start};
            e.expr = expr;
            return e;
        }
    }

    Expr_Ternary :: struct {
        #as using base: Expr;
        kind = Expr_Kind.TERNARY;
        condition: *Expr;
        true_expr: *Expr;
        false_expr: *Expr;

        new :: (condition: *Expr, true_expr: *Expr, false_expr: *Expr, line: int, start: int) -> *Expr #expand {
            assert(condition != null, "condition cannot be null");
            assert(true_expr != null, "true_expr cannot be null");
            assert(false_expr != null, "false_expr cannot be null");
            expr := New(Expr_Ternary);
            expr.loc = .{line, start};
            expr.condition = condition;
            expr.true_expr = true_expr;
            expr.false_expr = false_expr;
            return expr;
        }
    }

    Expr_Unary :: struct {
        #as using base: Expr;
        kind = Expr_Kind.UNARY;
        op: Unary_Operator;
        expr: *Expr;

        new :: (op: Unary_Operator, expr: *Expr, line: int, start: int) -> *Expr #expand {
            assert(expr != null, "expr cannot be null");
            e := New(Expr_Unary);
            e.loc = .{line, start};
            e.op = op;
            e.expr = expr;
            return e;
        }
    }

    Expr_Var :: struct {
        #as using base: Expr;
        kind = Expr_Kind.VAR;
        ident: string;

        new :: (ident: string, line: int, start: int) -> *Expr #expand {
            assert(ident != "", "ident cannot be null");
            expr := New(Expr_Var);
            expr.loc = .{line, start};
            expr.ident = ident;
            return expr;
        }
    }

    Expr_Postfix :: struct {
        #as using base: Expr;
        kind = Expr_Kind.POSTFIX;
        op: Postfix_Operator;
        expr: *Expr;

        new :: (op: Postfix_Operator, expr: *Expr, line: int, start: int) -> *Expr #expand {
            assert(expr != null, "expr cannot be null");
            e := New(Expr_Postfix);
            e.loc = .{line, start};
            e.op = op;
            e.expr = expr;
            return e;
        }
    }

    Expr_Prefix :: struct {
        #as using base: Expr;
        kind = Expr_Kind.PREFIX;
        op: Prefix_Operator;
        expr: *Expr;

        new :: (op: Prefix_Operator, expr: *Expr, line: int, start: int) -> *Expr #expand {
            assert(expr != null, "expr cannot be null");
            e := New(Expr_Prefix);
            e.loc = .{line, start};
            e.op = op;
            e.expr = expr;
            return e;
        }
    }

    Block :: struct {
        items:     [..]*Block_Item;
        using loc: Source_Location;

        new :: (items: [..]*Block_Item, line: int, start: int) -> *Block #expand {
            return New(Block, .{items, .{line, start}});
        }
    }

    Source_Location :: struct {
        line, start: int;
    }

    Postfix_Operator :: enum { ADD; SUBTRACT; }

    Prefix_Operator :: Postfix_Operator;

    Unary_Operator :: enum { BITWISE_NOT; NEGATE; NOT; }

    Binary_Operator :: enum {
        ADD;
        AND;
        BITWISE_AND;
        BITWISE_OR;
        BITWISE_XOR;
        DIV;
        EQUAL_EQUAL;
        GREATER;
        GREATER_EQUAL;
        LEFT_SHIFT;
        LESS;
        LESS_EQUAL;
        MOD;
        MUL;
        NOT_EQUAL;
        OR;
        RIGHT_SHIFT;
        SUB;
    }
}

set_builtin_type :: (expr: *Ast.Expr, type: *Ast.Builtin_Type) {
    assert(expr != null, "expr cannot be null");
    assert(type != null, "type cannot be null");
    expr.type = type;
}
