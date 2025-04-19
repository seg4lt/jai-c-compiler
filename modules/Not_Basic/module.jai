#load "Writer.jai";

format_string:: (str: string, padding_left: int = 0) -> string {
    sb: String_Builder;

    for 0..padding_left-1 append(*sb, " ");
    append(*sb, str);
    return builder_to_string(*sb);
}

#scope_module

#import "Basic";