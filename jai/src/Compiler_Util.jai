assember_and_linker :: (args: Cli_Args)  {
    command: [..] string;
    array_add(*command, "gcc");
    array_add(*command, tprint("%.c", args.source_file_path_without_ext));
    array_add(*command, "-o");
    array_add(*command, args.source_file_path_without_ext);
    result := Process.run_command(..command);
}
