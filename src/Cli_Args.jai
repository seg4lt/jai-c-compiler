
#scope_export

Cli_Args :: struct {
    src_path: string;
    src_path_without_ext: string;
    flags: Cli_Args_Flags = .LEX | .PARSE | .SEMA | .TACKY | .CODE_GEN | .ALL;
}

Cli_Args_Flags :: enum_flags {
    LEX;
    PARSE;
    SEMA;
    TACKY;
    CODE_GEN;
    ALL;
}

get_cli_args :: () -> Cli_Args {
    args := get_command_line_arguments();
    args = array_view(args, 1);

    using cli_args := Cli_Args.{};

    for args {
        if it == {
            case "--lex";          flags = .LEX;
            case "--parse";        flags = .LEX & .PARSE;
            case "--validate";     flags = .LEX & .PARSE & .SEMA;
            case "--tacky";        flags = .LEX & .PARSE & .TACKY;
            case "--code-gen";     flags = .LEX & .PARSE & .TACKY & .CODE_GEN; 
            // case "--lex";          flags &= ~(.PARSE | .SEMA | .TACKY | .CODE_GEN | .ALL);
            // case "--parse";        flags &= ~(         .SEMA | .TACKY | .CODE_GEN | .ALL);
            // case "--validate";     flags &= ~(                 .TACKY | .CODE_GEN | .ALL);
            // case "--tacky";        flags &= ~(                          .CODE_GEN | .ALL);
            // case "--code-gen";     flags &= ~                                       .ALL;
            case; src_path = it;
        }
    }
    if src_path == "" unreachable("No source file specified");
    if slice(src_path, src_path.count - 2, 2) != ".c" unreachable("Source file must have an .c extension");
    src_path_without_ext = slice(src_path, 0, src_path.count - 2);
    return cli_args;
}

#scope_file
#import "String";
#import "Compiler_Util";
#import "Basic";
