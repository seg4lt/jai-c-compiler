Symbol_Table :: struct {
    #as using map:     Table(string, *Symbol);
    symbol_allocator:  Allocator;

    Ident_Initial_Value_Kind :: enum { TENTATIVE; INITIAL; NO_INITIALIZER; };

    Ident_Initial_Value :: struct {
        kind: Ident_Initial_Value_Kind;
    }

    Ident_Initial_Value_Tentative :: struct {
        #as using base: Ident_Initial_Value;
        kind = .TENTATIVE;

        new :: () -> *Ident_Initial_Value #expand {
            result := New(Ident_Initial_Value_Tentative);
            return result;
        }
    }

    Ident_Initial_Value_Initial :: struct {
        #as using base: Ident_Initial_Value;
        kind = .INITIAL;
        value: int;

        new :: (val: int) -> *Ident_Initial_Value #expand {
            result := New(Ident_Initial_Value_Initial);
            result.value = val;
            return result;
        }
    }

    Ident_Initial_Value_No_Init :: struct {
        #as using base: Ident_Initial_Value;
        kind = .NO_INITIALIZER;

        new :: () -> *Ident_Initial_Value #expand {
            result := New(Ident_Initial_Value_No_Init);
            return result;
        }
    }

    Ident_Attr_Kind :: enum { FN; STATIC; LOCAL; };

    Ident_Attr :: struct {
        kind: Ident_Attr_Kind;
    }

    Ident_Attr_Fn :: struct {
        #as using base: Ident_Attr;
        kind = .FN;
        defined: bool;
        global: bool;

        new :: (defined: bool, global: bool) -> *Ident_Attr #expand {
            result := New(Ident_Attr_Fn);
            result.defined = defined;
            result.global = global;
            return result;
        }
    }

    Ident_Attr_Static :: struct {
        #as using base: Ident_Attr;
        kind = .STATIC;
        initial_value: *Ident_Initial_Value;
        global: bool;

        new :: (init_value: *Ident_Initial_Value, global: bool) -> *Ident_Attr #expand {
            result := New(Ident_Attr_Static);
            result.initial_value = init_value;
            result.global = global;
            return result;
        }
    }

    Ident_Attr_Local :: struct {
        #as using base: Ident_Attr;
        kind = .LOCAL;

        new :: () -> *Ident_Attr #expand {
            result := New(Ident_Attr_Local);
            return result;
        }
    }

    Symbol_Kind :: enum { INT; FN; };

    Symbol :: struct {
        kind: Symbol_Kind;
        attr: *Ident_Attr;
    }

    Symbol_Int :: struct {
        #as using base: Symbol;
        kind = .INT;
        ident: string;

        new :: (ident: string, attr: *Ident_Attr) -> *Symbol #expand {
            result := New(Symbol_Int);
            result.attr = attr;
            result.ident = copy_string(ident);
            return result;
        }
    }

    Symbol_Fn :: struct {
        #as using base: Symbol;
        kind = .FN;
        ident: string;
        params: [..]Symbol_Fn_Param;
        ret_type: string;

        new :: (ident: string, params: [..]Symbol_Fn_Param, ret_type: string, attr: *Ident_Attr) -> *Symbol #expand {
            result := New(Symbol_Fn);
            result.attr = attr;
            result.ident = copy_string(ident);
            result.params = params;
            result.ret_type = ret_type;
            return result;
        }

        Symbol_Fn_Param :: struct {
            ident: string;
            type: string;
        }
    }

    init :: (using symbols: *Symbol_Table) {
        symbol_allocator = context.allocator;
        init(*map);
    }
}

#scope_module

#import "Basic";
#import "Hash_Table";