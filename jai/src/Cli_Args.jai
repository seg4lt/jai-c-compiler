Cli_Args :: struct {
    source_file_path: string;
    source_file_path_without_ext: string;
    flags: Cli_Args_Flags = .LEX | .PARSE | .CODE_GEN | .ALL;
}

Cli_Args_Flags :: enum_flags {
    LEX;
    PARSE;
    CODE_GEN;
    ALL;
}

get_cli_args :: () -> Cli_Args {
    args := get_command_line_arguments();
    args = array_view(args, 1);

    using cli_args := Cli_Args.{};

    for args {
        if it == {
            case "--lex"; flags &= ~(.PARSE | .CODE_GEN | .ALL);
            case "--parse"; flags &= ~(.CODE_GEN | .ALL);
            case "--code-gen"; flags &= ~.ALL;
            case; source_file_path = it;
        }
    }
    if source_file_path == "" {
        log_error("No source file specified");
        exit(1);
    }
    found, path_no_ext, ext := String.split_from_right(source_file_path, ".");
    if !found || ext != "c" {
        log_error("Source file must have an .c extension");
        exit(1);
    }
    source_file_path_without_ext = path_no_ext;
    return cli_args;
}

#scope_file

#import "Basic";
String :: #import "String";

#scope_export

