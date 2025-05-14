#load "Writer.jai";

format_string:: (str: string, padding_left: int = 0) -> string {
    sb: String_Builder;

    for 0..padding_left-1 append(*sb, " ");
    append(*sb, str);
    return builder_to_string(*sb);
}

unreachable:: (message := "", args: .. Any, log: bool = true, exit_status_code: int = 1, loc := #caller_location) #no_debug #expand {
    if log log_error(message, .. args);
    assert(false, message, .. args);
    exit(xx exit_status_code);
}

#scope_module

#import "Basic";