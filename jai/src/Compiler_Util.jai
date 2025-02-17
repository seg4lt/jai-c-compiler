assember_and_linker :: (args: Cli_Args)  {
    command: [..] string;
    array_add(*command, "gcc");
    array_add(*command, tprint("%.i", args.source_file_path_without_ext));
    array_add(*command, "-o");
    array_add(*command, args.source_file_path_without_ext);
    result := Process.run_command(..command);
}

// pp:
	// $(CC) -E -P $(FILE_NAME).c -o $(FILE_NAME).i
preprocessor :: (args: Cli_Args) {
    command: [..] string;
    array_add(*command, "gcc");
    array_add(*command, "-E");
    array_add(*command, "-P");
    array_add(*command, tprint("%.c", args.source_file_path_without_ext));
    array_add(*command, "-o");
    array_add(*command, tprint("%.i", args.source_file_path_without_ext));
    result := Process.run_command(..command);
}
