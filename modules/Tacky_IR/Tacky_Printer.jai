print_tacky :: (program: *Program, writer: *Writer) {
    write(writer, "\n\n-- Tacky --\n");
    write(writer, "    .program\n");
    
    
    for item: program.items {
        if #complete item.kind == {
            case .FN; 
                fn := cast(*Top_Level_Fn) item;
                print_tacky_fn(fn, writer);
            case .STATIC_VAR; 
                sv := cast(*Top_Level_Static_Var) item;
                print_static_var(sv, writer);
        }
        write(writer, "\n");
    }
}

print_static_var:: (var: *Top_Level_Static_Var, writer: *Writer) {
    write(writer, "    StaticVar(ident: %, global: %, init: %)", var.ident, var.global, var.init);
}

print_tacky_fn :: (fn: *Top_Level_Fn, writer: *Writer) {
    write(writer, ".%:", fn.ident);
    for fn.instructions print_tacky_inst(it, writer);
}

print_tacky_inst :: (inst: *Instruction, writer: *Writer) {
    write(writer, "\n    ");
    if #complete inst.kind == {
        case .FN_CALL;
            fn_call := cast(*Instruction_Fn_Call) inst;
            write(writer, "FnCall(ident: %, args: [", fn_call.ident);
            for arg: fn_call.args {
                print_tacky_val(arg, writer);
                if it_index != fn_call.args.count - 1 write(writer, ", ");
            }
            write(writer, "], dst: ");
            print_tacky_val(fn_call.dst, writer);
            write(writer, ")");
        case .RETURN;
            ret := cast(*Instruction_Return) inst;
            write(writer, "Return(");
            print_tacky_val(ret.val, writer);
            write(writer, ")");
        case .UNARY;
            unary := cast(*Instruction_Unary) inst;
            write(writer, "Unary(op: %", unary.op);
            write(writer, ", src: ");
            print_tacky_val(unary.src, writer);
            write(writer, ", dst: ");
            print_tacky_val(unary.dst, writer);
            write(writer, ")");
        case .BINARY;
            binary := cast(*Instruction_Binary) inst;
            write(writer, "Binary(op: %", binary.op);
            write(writer, ", src1: ");
            print_tacky_val(binary.src1, writer);
            write(writer, ", src2: ");
            print_tacky_val(binary.src2, writer);
            write(writer, ", dst: ");
            print_tacky_val(binary.dst, writer);
            write(writer, ")");
        case .LABEL;
            lbl := cast(*Instruction_Label) inst;
            write(writer, "Label(%)", lbl.name);
        case .JUMP_IF_NOT_ZERO; 
            jnz := cast(*Instruction_Jump_If_Not_Zero) inst;
            write(writer, "JumpIfNotZero(condition: ");
            print_tacky_val(jnz.condition, writer);
            write(writer, ", label: %", jnz.target);
            write(writer, ")");
        case .JUMP_IF_ZERO; 
            jz := cast(*Instruction_Jump_If_Zero) inst;
            write(writer, "JumpIfZero(condition: ");
            print_tacky_val(jz.condition, writer);
            write(writer, ", label: %", jz.target);
            write(writer, ")");
        case .COPY; 
            copy := cast(*Instruction_Copy) inst;
            write(writer, "Copy(src: ");
            print_tacky_val(copy.src, writer);
            write(writer, ", dst: ");
            print_tacky_val(copy.dst, writer);
            write(writer, ")");
        case .JUMP;
            jmp := cast(*Instruction_Jump) inst;
            write(writer, "Jump(%)", jmp.target);
    }
}

print_tacky_val :: (val: *Val, writer: *Writer) {
    if #complete val.kind == {
        case .CONSTANT; 
            constant := cast(*Val_Constant) val;
            write(writer, "Constant(%)", constant.constant);
        case .VARIABLE; 
            variable := cast(*Val_Variable) val;
            write(writer, "Var(%)", variable.variable);
    }
}