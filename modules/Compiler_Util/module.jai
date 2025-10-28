Output_Type :: enum {
    EXE;
    OBJ;
}

COMPILER_BACKEND :: "gcc";

run_preprocessor :: (src_path: string) -> src_content: string = "", success: bool = true, msg: string = "" {
    preprocessor(src_path);
    path := ifx ends_with(src_path, ".c") slice(src_path, 0, src_path.count - 2) else src_path;

    src_content, success := read_entire_file(tprint("%.i", path));
    if !success return success=false, msg=tprint("Unable to read file: %", path);
    return src_content = src_content;
}

assember_and_linker :: (src_path_without_ext: string, output_type: Output_Type)  {
    push_allocator(temp);
    if #complete output_type == {
        case .EXE;
            command: [..] string;
            array_add(*command, COMPILER_BACKEND);
            array_add(*command, "-g");
            array_add(*command, tprint("%.s", src_path_without_ext));
            array_add(*command, "-o");
            array_add(*command, src_path_without_ext);
            result := Process.run_command(..command);
        case .OBJ;
            command: [..] string;
            array_add(*command, COMPILER_BACKEND);
            array_add(*command, "-c");
            array_add(*command, tprint("%.s", src_path_without_ext));
            array_add(*command, "-o");
            array_add(*command, tprint("%.o", src_path_without_ext));
            result := Process.run_command(..command);
    }
}

preprocessor :: (src_path: string) {
    path := ifx ends_with(src_path, ".c") slice(src_path, 0, src_path.count - 2) else src_path;
    command: [..] string;
    array_add(*command, COMPILER_BACKEND);
    array_add(*command, "-E");
    array_add(*command, "-P");
    array_add(*command, tprint("%.c", path));
    array_add(*command, "-o");
    array_add(*command, tprint("%.i", path));
    result := Process.run_command(..command);
}



#scope_module
Process :: #import "Process";
#import "Basic";
#import "String";
#import "File";
