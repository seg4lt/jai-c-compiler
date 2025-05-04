#import "Basic";

Writer :: struct {
    ctx   : *void;
    write : (ctx: *void, format_string: string, args: .. Any) -> success: bool;
}

write :: (writer: *Writer, format_string: string, args: .. Any) -> success: bool {
    if !writer return success=false;
    return writer.write(writer.ctx, format_string, .. args);
}

make_stdout_writer :: () -> Writer {
    writer: Writer;
    writer.ctx = null;
    writer.write = stdout_write;
    return writer;
}

make_sb_writer :: (sb: *String_Builder) -> Writer {
    writer: Writer;
    writer.ctx = sb;
    writer.write = sb_write;
    return writer;
}

#scope_module

stdout_write :: (ctx: *void, format_string: string, args: .. Any) -> success: bool {
    print(format_string, .. args);
    return success=true;
}

sb_write :: (ctx: *void, format_string: string, args: .. Any) -> success: bool {
    if !ctx return success=false;

    sb := cast(*String_Builder) ctx;
    string_to_append := sprint(format_string, .. args);
    append(sb, string_to_append);

    return success=true;
}

