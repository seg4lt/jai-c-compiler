// TODO: need to simplify this, to much nested types
Symbol_Table :: struct {
    #as using map:     Table(string, *Symbol);
    symbol_allocator:  Allocator;
}

init :: (using symbols: *Symbol_Table) {
    symbol_allocator = context.allocator;
    init(*map,, symbol_allocator);
}

Symbol :: struct {
    kind: Kind;

    Kind :: enum { VAR; FN; };
}

Symbol_Var :: struct {
    #as using base: Symbol;
    kind = .VAR;

    ident : string;
    type  : *Ast.Decl_Type;
    attr  : Var_Attr;

    new :: (ident: string, type: *Ast.Decl_Type, attr: Var_Attr) -> *Symbol #expand {
        assert(type.kind != .FN, "var cannot have fn type");
        result := New(Symbol_Var);
        result.attr = attr;
        result.ident = copy_string(ident);
        result.type = type;
        return result;
    }
}

Symbol_Fn :: struct {
    #as using base: Symbol;
    kind = .FN;

    ident    : string;
    params   : [..]string; // just identifiers for params
    type     : *Ast.Decl_Type_Fn;
    defined  : bool;
    global   : bool;

    new :: (ident: string, type: *Ast.Decl_Type_Fn, params: [..]string, defined: bool, global: bool) -> *Symbol #expand {
        result := New(Symbol_Fn);
        result.ident = copy_string(ident);
        result.params = params;
        result.type = type;
        result.defined = defined;
        result.global = global;
        return result;
    }
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


Initial_Value_Kind :: enum { TENTATIVE; INITIAL; NO_INITIALIZER; };

Initial_Value :: struct {
    kind: Initial_Value_Kind;
    value: *Ast.Constant;
}

tentative :: () -> Initial_Value #expand {
    result: Initial_Value;
    result.kind = .TENTATIVE;
    return result;
}

initial :: (val: *Ast.Constant) -> Initial_Value #expand {
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
#import "Parser";