Symbol_Table :: struct {
    #as using map:     Table(string, Symbol);
    symbol_allocator:  Allocator;
}

Ident_Initial_Value :: struct {
    kind: enum { TENTATIVE; INITIAL; NO_INITIALIZER;};
    using data: union {
        initial: int;
        // no_initialized: *void
        // tentative: *void
    };
}

ident_initial_value_tentative :: () -> Ident_Initial_Value {
    return Ident_Initial_Value.{ kind = .TENTATIVE };
}
ident_initial_value_initial :: (value: int) -> Ident_Initial_Value {
    return Ident_Initial_Value.{ kind = .INITIAL, data = .{ initial = value } };
}
ident_initial_value_no_init :: () -> Ident_Initial_Value {
    return Ident_Initial_Value.{ kind = .NO_INITIALIZER };
}

Ident_Attr :: struct {
    kind: enum { FN; STATIC; LOCAL;};
    using data: union {
        fn: struct { defined: bool; global: bool;};
        static: struct {initial_value: Ident_Initial_Value; global: bool;};
        // local: *void; 
    };
}

ident_attr_local :: () -> Ident_Attr {
    return Ident_Attr.{ kind = .LOCAL };
}

ident_attr_fn :: (defined: bool, global: bool) -> Ident_Attr {
    return Ident_Attr.{
        kind = .FN,
        data = .{ fn = .{ defined = defined, global = global } }
    };
} 

ident_attr_static :: (init_value: Ident_Initial_Value, global: bool) -> Ident_Attr {
    return Ident_Attr.{
        kind = .STATIC,
        data = .{ static  = .{ initial_value = init_value , global = global } }
    };
}

init :: (using symbols: *Symbol_Table) {
    symbol_allocator = context.allocator;
    init(*map);
}

Symbol :: struct {
    type : enum { INT; FN ; };
    using as   : union {
        var : string;
        fn  : Symbol_Fn;
    };
    attr: Ident_Attr;
}

make_symbol_int :: (ident: string, attr: Ident_Attr) -> Symbol {
    return Symbol.{ 
        type = .INT, 
        as = .{ var = copy_string(ident) },
        attr = attr,
    };
}

Symbol_Fn :: struct {
    ident   : string;
    params  : [..]Symbol_Fn_Param;
    ret_type: string;
}

make_symbol_fn :: (ident: string, params: [..]Symbol_Fn_Param, ret_type: string, attr: Ident_Attr) -> Symbol {
    return Symbol.{ 
        type = .FN, 
        as = .{ fn = Symbol_Fn.{  copy_string(ident), params, ret_type} },
        attr = attr
    };
}

Symbol_Fn_Param :: struct {
    ident : string;
    type  : string;
}

#scope_module

#import "Basic";
#import "Hash_Table";
