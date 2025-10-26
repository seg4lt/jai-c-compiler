Tacky :: struct {
    Instruction_Kind :: enum {
        BINARY;
        COPY;
        FN_CALL;
        JUMP;
        JUMP_IF_NOT_ZERO;
        JUMP_IF_ZERO;
        LABEL;
        RETURN;
        UNARY;
    }

    Unary_Op :: enum {
        BITWISE_NOT;
        NEGATE;
        NOT;
    }

    Bin_Op :: enum {
        ADD;
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
        RIGHT_SHIFT;
        SUB;
    }

    Val_Kind :: enum {
        CONSTANT;
        VARIABLE;
    }

    Top_Level_Kind :: enum {
        FN;
        STATIC_VAR;
    }

    Val :: struct {
        kind: Val_Kind;
    }

    Val_Constant :: struct {
        #as using base: Val;
        kind = Val_Kind.CONSTANT;
        constant: int;

        new :: (value: int) -> *Val_Constant {
            v := New(Val_Constant);
            v.constant = value;
            return v;
        }
    }

    Val_Variable :: struct {
        #as using base: Val;
        kind = Val_Kind.VARIABLE;
        variable: string;

        new :: (ident: string) -> *Val_Variable {
            v := New(Val_Variable);
            v.variable = copy_string(ident);
            return v;
        }
    }

    Instruction :: struct {
        kind: Instruction_Kind;
    }

    Instruction_Binary :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.BINARY;
        op: Bin_Op;
        src1: *Val;
        src2: *Val;
        dst: *Val;

        new :: (op: Bin_Op, src1: *Val, src2: *Val, dst: *Val) -> *Instruction_Binary {
            i := New(Instruction_Binary);
            i.op = op;
            i.src1 = src1;
            i.src2 = src2;
            i.dst = dst;
            return i;
        }
    }

    Instruction_Copy :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.COPY;
        src: *Val;
        dst: *Val;

        new :: (src: *Val, dst: *Val) -> *Instruction_Copy {
            i := New(Instruction_Copy);
            i.src = src;
            i.dst = dst;
            return i;
        }
    }

    Instruction_Fn_Call :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.FN_CALL;
        ident: string;
        args: [..]*Val;
        dst: *Val;

        new :: (ident: string, args: [..]*Val, dst: *Val) -> *Instruction_Fn_Call {
            i := New(Instruction_Fn_Call);
            i.ident = copy_string(ident);
            i.args = args;
            i.dst = dst;
            return i;
        }
    }

    Instruction_Jump :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.JUMP;
        target: string;

        new :: (target: string) -> *Instruction_Jump {
            i := New(Instruction_Jump);
            i.target = copy_string(target);
            return i;
        }
    }

    Instruction_Jump_If_Not_Zero :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.JUMP_IF_NOT_ZERO;
        condition: *Val;
        target: string;

        new :: (condition: *Val, target: string) -> *Instruction_Jump_If_Not_Zero {
            i := New(Instruction_Jump_If_Not_Zero);
            i.condition = condition;
            i.target = copy_string(target);
            return i;
        }
    }

    Instruction_Jump_If_Zero :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.JUMP_IF_ZERO;
        condition: *Val;
        target: string;

        new :: (condition: *Val, target: string) -> *Instruction_Jump_If_Zero {
            i := New(Instruction_Jump_If_Zero);
            i.condition = condition;
            i.target = copy_string(target);
            return i;
        }
    }

    Instruction_Label :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.LABEL;
        name: string;

        new :: (name: string) -> *Instruction_Label {
            i := New(Instruction_Label);
            i.name = copy_string(name);
            return i;
        }
    }

    Instruction_Return :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.RETURN;
        val: *Val;

        new :: (val: *Val) -> *Instruction_Return {
            i := New(Instruction_Return);
            i.val = val;
            return i;
        }
    }

    Instruction_Unary :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.UNARY;
        op: Unary_Op;
        src: *Val;
        dst: *Val;

        new :: (op: Unary_Op, src: *Val, dst: *Val) -> *Instruction_Unary {
            i := New(Instruction_Unary);
            i.op = op;
            i.src = src;
            i.dst = dst;
            return i;
        }
    }

    Top_Level :: struct {
        kind: Top_Level_Kind;
    }

    Top_Level_Fn :: struct {
        #as using base: Top_Level;
        kind = Top_Level_Kind.FN;
        ident: string;
        global: bool;
        instructions: [..]*Instruction;

        new :: (ident: string, global: bool, instructions: [..]*Instruction) -> *Top_Level_Fn {
            fn := New(Top_Level_Fn);
            fn.ident = copy_string(ident);
            fn.global = global;
            fn.instructions = instructions;
            return fn;
        }
    }

    Top_Level_Static_Var :: struct {
        #as using base: Top_Level;
        kind = Top_Level_Kind.STATIC_VAR;
        ident: string;
        global: bool;
        init: int;

        new :: (ident: string, global: bool, init: int) -> *Top_Level_Static_Var {
            sv := New(Top_Level_Static_Var);
            sv.ident = copy_string(ident);
            sv.global = global;
            sv.init = init;
            return sv;
        }
    }

    Program :: struct {
        items: [..]*Top_Level;

        new :: (items: [..]*Top_Level) -> *Program {
            pg := New(Program);
            pg.items = items;
            return pg;
        }
    }
}

Tacky_Ctx :: struct {
    temp_var_index  : int = 0;
    label_index     : int = 0;
}
