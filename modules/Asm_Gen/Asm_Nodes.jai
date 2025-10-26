Asm :: struct {
    Instruction_Kind :: enum {
        ALLOCATE_STACK;
        BINARY;
        CALL;
        CDQ;
        CMP;
        DEALLOCATE_STACK;
        IDIV;
        JMP;
        JMP_CC;
        LABEL;
        MOV;
        PUSH;
        RET;
        SET_CC;
        UNARY;
    }

    Top_Level_Kind :: enum {
        STATIC;
        FN;
    }

    Operand_Kind :: enum {
        IMM;
        REG;
        PSEUDO;
        STACK;
        DATA;
    }

    Cond_Code :: enum { EE; NE; G; GE; L; LE; }

    Unary_Op :: enum { NEG; BITWISE_NOT; NNOT; }

    Bin_Op :: enum {
        ADD;
        BITWISE_AND;
        BITWISE_OR;
        BITWISE_XOR;
        EQUAL_EQUAL;
        GREATER;
        GREATER_EQUAL;
        LEFT_SHIFT;
        LESS;
        LESS_EQUAL;
        MUL;
        NOT_EQUAL;
        RIGHT_SHIFT;
        SUB;
    }

    Register_Size :: enum #specified {
        BYTE  :: 1;
        WORD  :: 2;
        DWORD :: 4;
        QWORD :: 8;
    }

    Register :: enum {
        AX;
        CX;
        DI;
        DX;
        R10;
        R11;
        R8;
        R9;
        RBP;
        RSP;
        SI;
        RIP;
    }

    Register_Asm :: struct {
        register: Register;
        size: Register_Size;
    }

    Operand :: struct {
        kind: Operand_Kind;
    }

    Operand_Imm :: struct {
        #as using base: Operand;
        kind = Operand_Kind.IMM;
        value: int;
    }

    Operand_Reg :: struct {
        #as using base: Operand;
        kind = Operand_Kind.REG;
        reg: Register_Asm;
    }

    Operand_Pseudo :: struct {
        #as using base: Operand;
        kind = Operand_Kind.PSEUDO;
        ident: string;
    }

    Operand_Stack :: struct {
        #as using base: Operand;
        kind = Operand_Kind.STACK;
        position: int;
    }

    Operand_Data :: struct {
        #as using base: Operand;
        kind = Operand_Kind.DATA;
        ident: string;
    }

    Instruction :: struct {
        kind: Instruction_Kind;
    }

    Instruction_Allocate_Stack :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.ALLOCATE_STACK;
        size: int;
    }

    Instruction_Binary :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.BINARY;
        op: Bin_Op;
        src1: *Operand;
        src2: *Operand;
    }

    Instruction_Call :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.CALL;
        ident: string;
    }

    Instruction_Cdq :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.CDQ;
    }

    Instruction_Cmp :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.CMP;
        op1: *Operand;
        op2: *Operand;
    }

    Instruction_Deallocate_Stack :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.DEALLOCATE_STACK;
        size: int;
    }

    Instruction_Idiv :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.IDIV;
        operand: *Operand;
    }

    Instruction_Jmp :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.JMP;
        target: string;
    }

    Instruction_Jmp_Cc :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.JMP_CC;
        cond_code: Cond_Code;
        target: string;
    }

    Instruction_Label :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.LABEL;
        ident: string;
    }

    Instruction_Mov :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.MOV;
        src: *Operand;
        dst: *Operand;
    }

    Instruction_Push :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.PUSH;
        operand: *Operand;
    }

    Instruction_Ret :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.RET;
    }

    Instruction_Set_Cc :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.SET_CC;
        cond_code: Cond_Code;
        operand: *Operand;
    }

    Instruction_Unary :: struct {
        #as using base: Instruction;
        kind = Instruction_Kind.UNARY;
        op: Unary_Op;
        operand: *Operand;
    }

    Top_Level :: struct {
        kind: Top_Level_Kind;
    }

    Top_Level_Static :: struct {
        #as using base: Top_Level;
        kind = Top_Level_Kind.STATIC;
        ident: string;
        global: bool;
        init: int;
    }

    Top_Level_Fn :: struct {
        #as using base: Top_Level;
        kind = Top_Level_Kind.FN;
        ident: string;
        instructions: [..]*Instruction;
        stack_size: int;
        global: bool;
    }

    Program :: struct {
        top_level: [..]*Top_Level;
    }
}

#scope_module

COUNT_REGISTER_FOR_ARGS :: 6;
STACK_ALIGNMENT         :: 16;
PUSH_SIZE               :: 8; // we use push and it only works with 8 bytes
ARGS_REGISTERS          : [COUNT_REGISTER_FOR_ARGS]Register : .[.DI, .SI, .DX, .CX, .R8, .R9];

reg :: (register: Register, size: Register_Size) -> *Operand #expand {
    r := New(Operand_Reg);
    r.reg = .{ register, size };
    return r;
}

pseudo :: (ident: string) -> *Operand #expand {
    p := New(Operand_Pseudo);
    p.ident = copy_string(ident);
    return p;
}

stack :: (position: int) -> *Operand #expand {
    s := New(Operand_Stack);
    s.position = position;
    return s;
}

data :: (ident: string) -> *Operand #expand {
    d := New(Operand_Data);
    d.ident = ident;
    return d;
}

imm :: (value: int) -> *Operand #expand {
    i := New(Operand_Imm);
    i.value = value;
    return i;
}

ret :: () -> *Instruction #expand {
    return New(Instruction_Ret);
}

mov :: (src: *Operand, dst: *Operand) -> *Instruction #expand {
    m := New(Instruction_Mov);
    m.src = src;
    m.dst = dst;
    return m;
}

cmp :: (op1: *Operand, op2: *Operand) -> *Instruction #expand {
    c := New(Instruction_Cmp);
    c.op1 = op1;
    c.op2 = op2;
    return c;
}

set_cc :: (cond_code: Cond_Code, operand: *Operand) -> *Instruction #expand {
    s := New(Instruction_Set_Cc);
    s.cond_code = cond_code;
    s.operand = operand;
    return s;
}

unary :: (op: Unary_Op, operand: *Operand) -> *Instruction #expand {
    u := New(Instruction_Unary);
    u.op = op;
    u.operand = operand;
    return u;
}

binary :: (op: Bin_Op, src1: *Operand, src2: *Operand) -> *Instruction #expand {
    b := New(Instruction_Binary);
    b.op = op;
    b.src1 = src1;
    b.src2 = src2;
    return b;
}

cdq :: () -> *Instruction #expand {
    return New(Instruction_Cdq);
}

idiv :: (operand: *Operand) -> *Instruction #expand {
    i := New(Instruction_Idiv);
    i.operand = operand;
    return i;
}

label :: (ident: string) -> *Instruction #expand {
    l := New(Instruction_Label);
    l.ident = copy_string(ident);
    return l;
}

jmp_cc :: (cond_code: Cond_Code, target: string) -> *Instruction #expand {
    j := New(Instruction_Jmp_Cc);
    j.cond_code = cond_code;
    j.target = copy_string(target);
    return j;
}

jmp :: (target: string) -> *Instruction #expand {
    j := New(Instruction_Jmp);
    j.target = copy_string(target);
    return j;
}

allocate_stack :: (size: int) -> *Instruction #expand {
    a := New(Instruction_Allocate_Stack);
    a.size = size;
    return a;
}

push :: (operand: *Operand) -> *Instruction #expand {
    p := New(Instruction_Push);
    p.operand = operand;
    return p;
}

call :: (ident: string) -> *Instruction #expand {
    c := New(Instruction_Call);
    c.ident = copy_string(ident);
    return c;
}

deallocate_stack :: (size: int) -> *Instruction #expand {
    d := New(Instruction_Deallocate_Stack);
    d.size = size;
    return d;
}

top_level_static_var :: (ident: string, global: bool, init: int) -> *Top_Level #expand {
    s := New(Top_Level_Static);
    s.ident = ident;
    s.global = global;
    s.init = init;
    return s;
}

top_level_fn :: (ident: string, instructions: [..]*Instruction, stack_size: int, global: bool) -> *Top_Level #expand {
    f := New(Top_Level_Fn);
    f.ident = ident;
    f.instructions = instructions;
    f.stack_size = stack_size;
    f.global = global;
    return f;
}