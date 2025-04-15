#import "Basic";

unreachable:: (arg: bool, message := "", args: .. Any, exit_status_code: int = 1, loc := #caller_location) #no_debug #expand {
    assert(false, message, args);
    exit(exit_status_code);
}
