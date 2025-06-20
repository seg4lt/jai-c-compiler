
#run build();

build :: () {
    set_build_options_dc(.{do_output=false, output_path="out", output_executable_name="target"});
    
    options := get_build_options();
    args := options.compile_time_command_line;
    
    docker := false;
    args   := "";
    
    for args {
        if it == {
            case "--docker"; docker = true;
            case; args = it;
        }
    }
}


#import "Basic";
#import "Compiler";
#import "Process";