#module_parameters () (MEMORY_DEBUGGER := false) {}

///
/// Arrays
///

array_slice :: (arr: []$T, from: int = 0, to: int = 0) -> []T {
    assert(from >= 0, "array slice `from` has to be greater or equal to 0");
    assert(to >= 0, "array slice `to` has to be greater or equal to 0");
    assert(to <= str.count, "array slice `to` has to be less then array count");
    if to == 0 to = str.count;
    return array_view(arr, from, to - from);
}

///
/// String
///

str_slice :: (str: string, from: int = 0, to: int = 0) -> string {
    assert(from >= 0, "string slice `from` has to be greater or equal to 0");
    assert(to >= 0, "string slice `to` has to be greater or equal to 0");
    assert(to <= str.count, "string slice `to` has to be less then string count");
    if to == 0 to = str.count;
    return slice(str, from, to - from);
}

String_Format_Alignment :: enum_flags {
    LEFT;
    RIGHT;
    PAD_LEFT;
};

string_format :: (str: string, length: int, align: String_Format_Alignment = .LEFT) -> string {
    sb: String_Builder;
    if align == .PAD_LEFT {
        for 0..length-1 append(*sb, " ");
        append(*sb, str);
        return builder_to_string(*sb);
    }
    
    num_of_spaces := length - str.count;
    if align == .RIGHT for 0..num_of_spaces-1 append(*sb, " "); 
    append(*sb, str);
    if align == .LEFT for 0..num_of_spaces-1 append(*sb, " ");
    return builder_to_string(*sb);
}

///
/// Misc
///
unreachable :: ($message := "", args: .. Any, log: bool = true, exit_status_code: int = 1, loc := #caller_location) #no_debug #expand {
    if log log_error(message, .. args);
    print("\n=========== Stacktrace ============\n\n");
    print_stack_trace(context.stack_trace);
    print("\n===================================\n");
    my_panic();
    // TODO(Aman): make this macro return anything here, so on call site we don't have to return dumb value
}

New :: ($T: Type, value: T) -> *T #expand {
    ptr := New(T);
    ptr.* = value;
    return ptr;
}

#load "Writer.jai";
#load "Arena.jai";

#scope_module

#import "Basic";
#import "String";