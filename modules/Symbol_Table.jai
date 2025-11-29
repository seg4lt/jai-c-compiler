Symbol_Table :: struct {
    #as using map:     Table(string, *Symbol);
    symbol_allocator:  Allocator;
}

init :: (using symbols: *Symbol_Table) {
    symbol_allocator = context.allocator;
    init(*map,, symbol_allocator);
}


Var_Attr_Kind :: enum { STATIC; LOCAL; };

Var_Attr :: struct {
    kind: Var_Attr_Kind;
    initial_value: Initial_Value;
    global: bool;
}

static_var :: (init_value: Initial_Value, global: bool) -> Var_Attr #expand {
    result: Var_Attr;
    result.kind = .STATIC;
    result.initial_value = init_value;
    result.global = global;
    return result;
}

local_var :: () -> Var_Attr #expand {
    result: Var_Attr;
    result.kind = .LOCAL;
    return result;
}

Symbol_Kind :: enum { VAR; FN; };

Symbol :: struct {
    kind: Symbol_Kind;
}

Symbol_Var :: struct {
    #as using base: Symbol;
    kind = Symbol_Kind.VAR;
    ident: string;
    attr: Var_Attr;

    new :: (ident: string, attr: Var_Attr) -> *Symbol #expand {
        result := New(Symbol_Var);
        result.attr = attr;
        result.ident = copy_string(ident);
        return result;
    }
}

Symbol_Fn :: struct {
    #as using base: Symbol;
    kind = Symbol_Kind.FN;
    ident: string;
    params: [..]Symbol_Fn_Param;
    ret_type: string;
    defined: bool;
    global: bool;

    new :: (ident: string, params: [..]Symbol_Fn_Param, ret_type: string, defined: bool, global: bool) -> *Symbol #expand {
        result := New(Symbol_Fn);
        result.ident = copy_string(ident);
        result.params = params;
        result.ret_type = ret_type;
        result.defined = defined;
        result.global = global;
        return result;
    }

    Symbol_Fn_Param :: struct {
        ident: string;
        type: string;
    }
}

Initial_Value_Kind :: enum { TENTATIVE; INITIAL; NO_INITIALIZER; };

Initial_Value :: struct {
    kind: Initial_Value_Kind;
    value: int;
}

tentative :: () -> Initial_Value #expand {
    result: Initial_Value;
    result.kind = .TENTATIVE;
    return result;
}

initial :: (val: int) -> Initial_Value #expand {
    result: Initial_Value;
    result.kind = .INITIAL;
    result.value = val;
    return result;
}

no_initializer :: () -> Initial_Value #expand {
    result: Initial_Value;
    result.kind = .NO_INITIALIZER;
    return result;
}

#scope_module

#import "Basic";
#import "Hash_Table";