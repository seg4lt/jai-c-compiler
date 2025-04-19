#import "Not_Basic";
#import "Basic";
#import "String";

Error_Reporter :: struct {
    error_items: [..]Error_Item;
    writer: Writer;
}

Error_Item :: struct {
    msg: string;
    file    : string;
    line    : int;
    column  : int;
}

print_errors :: (error_reporter: *Error_Reporter, panic: bool = true) {
    if error_reporter.error_items.count == 0 return;
    for error_item: error_reporter.error_items {
        log_error("%", error_item.msg);
    }
    if panic exit(1);
}

error_report :: (error_reporter: *Error_Reporter, src: string, src_path: string, line: int, start: int, detail_msg_fmt: string, args: .. Any, start_msg: string = "", panic: bool = true) {
    error_item := get_error_item(src,src_path, line,start, detail_msg_fmt, .. 
    args, start_msg);
    array_add(*error_reporter.error_items, error_item);
    if panic print_errors(error_reporter, panic);
}

#scope_module


get_error_item :: (src: string, src_path: string, line: int, start: int, detail_msg_fmt: string, args: .. Any, start_msg: string = "") -> Error_Item {
    previous_line_start, current_line_start := find_line_start(src, start);
    current_line_end := start;
    for start..src.count-1 {
        if src.data[it] == #char "\n" {
            current_line_end = it;
            break;
        }
    }
    column := start - current_line_start;
    sb : String_Builder;
    append(*sb, sprint("Error in %:%,% : %", src_path, line, column, start_msg));
    append(*sb, "\n");
    append(*sb, sprint("%", slice(src, previous_line_start, current_line_start-previous_line_start)));
    append(*sb, sprint("%\n", slice(src, current_line_start, current_line_end-current_line_start)));
    d_msg := sprint(detail_msg_fmt, .. args);
    append(*sb, sprint("%----%", format_string("^", padding_left = column), d_msg));
    error_item := New(Error_Item);
    error_item.* = .{  msg = builder_to_string(*sb), file = "", line = line, column = column };
    return error_item;
}

find_line_start :: (src: string, start: int) -> int, int {
    previous_line_start := start;
    current_line_start := start;
    cur := start;
    count := 0;
    while cur >= 0 && count <= 2 {
        if src.data[cur] == #char "\n" {
            if count == 0 current_line_start = cur + 1;
            count += 1;
            previous_line_start = cur + 1;
        } 
        cur -= 1;
    }
    return previous_line_start, current_line_start;
}

#scope_file


#scope_export