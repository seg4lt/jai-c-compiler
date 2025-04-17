assember_and_linker :: (args: Cli_Args)  {
    command: [..] string;
    array_add(*command, "gcc");
    array_add(*command, tprint("%.i", args.src_path_without_ext));
    array_add(*command, "-o");
    array_add(*command, args.src_path_without_ext);
    result := Process.run_command(..command);
}

// pp:
	// $(CC) -E -P $(FILE_NAME).c -o $(FILE_NAME).i
preprocessor :: (using args: Cli_Args) {
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
