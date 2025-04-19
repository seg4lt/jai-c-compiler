#import "Basic";
#import "String";

assember_and_linker :: (src_path_without_ext: string)  {
    command: [..] string;
    array_add(*command, "gcc");
    array_add(*command, tprint("%.i", src_path_without_ext));
    array_add(*command, "-o");
    array_add(*command, src_path_without_ext);
    result := Process.run_command(..command);
}

// pp:
	// $(CC) -E -P $(FILE_NAME).c -o $(FILE_NAME).i
preprocessor :: (src_path: string) {
    path := ifx ends_with(src_path, ".c") slice(src_path, 0, src_path.count - 2) else src_path;
    command: [..] string;
    array_add(*command, "gcc");
    array_add(*command, "-E");
    array_add(*command, "-P");
    array_add(*command, tprint("%.c", path));
    array_add(*command, "-o");
    array_add(*command, tprint("%.i", path));
    result := Process.run_command(..command);
}


unreachable:: (message := "", args: .. Any, log: bool = true, exit_status_code: int = 1, loc := #caller_location) #no_debug #expand {
    if log log_error(message, .. args);
    assert(false, message, .. args);
    exit(xx exit_status_code);
}

#scope_module
Process :: #import "Process";