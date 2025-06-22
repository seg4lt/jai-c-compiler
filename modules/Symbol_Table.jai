Symbol_Table :: Table(string, Symbol);

Symbol :: struct {
    type : enum { INT; FN ; };
    as   : union {
        var : string;
        fn  : Symbol_Fn;
    };
}

make_symbol_int :: (ident: string) -> Symbol {
    return Symbol.{ 
        type = .INT, 
        as = .{ var = ident } 
    };
}

Symbol_Fn :: struct {
    ident   : string;
    params  : [..]Symbol_Fn_Param;
    ret_type: string;
    defined : bool;
}

make_symbol_fn :: (ident: string, params: [..]Symbol_Fn_Param, ret_type: string, defined: bool) -> Symbol {
    return Symbol.{ 
        type = .FN, 
        as = .{ fn = Symbol_Fn.{  ident, params, ret_type, defined  } } 
    };
}

Symbol_Fn_Param :: struct {
    ident : string;
    type  : string;
}

#scope_module

#import "Basic";
#import "Hash_Table";
