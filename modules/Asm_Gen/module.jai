#load "Asm_Nodes.jai";

#scope_module

get_size :: (type: *Ast.Builtin_Type) -> Size {
    assert(type != null, "type cannot be null");
    if type.kind == .INT return .LONGWORD;
    if type.kind == .LONG return .QUADWORD;

    unreachable("unsupported type: %", type.kind);
    return .LONGWORD;
}


using Asm;

#load "Asm_Gen.jai";
#load "Asm_Gen_Printer.jai";

#import "Hash_Table";
#import "Basic";
#import "Tacky_IR";
#import "Not_Basic";
#import "Symbol_Table";
#import "Parser";
