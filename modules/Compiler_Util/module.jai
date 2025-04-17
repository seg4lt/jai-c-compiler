#import "Basic";

unreachable:: (message := "", args: .. Any, log: bool = true, exit_status_code: int = 1, loc := #caller_location) #no_debug #expand {
    if log log_error(message, args);
    assert(false, message, args);
    exit(xx exit_status_code);
}
