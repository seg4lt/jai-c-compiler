print_tacky :: (program: *Program_Tacky, writer: *Writer) {
    write(writer, "\n\n-- Tacky --\n");
    write(writer, "    .program\n");
    for fn: program.fns {
        print_tacky_fn(*fn, writer);
        write(writer, "\n");
    }
}

print_tacky_fn :: (fn: *Fn_Tacky, writer: *Writer) {
    write(writer, ".%:", fn.ident);
    for fn.instructions print_tacky_inst(*it, writer);
}

print_tacky_inst :: (inst: *Instruction_Tacky, writer: *Writer) {
    write(writer, "\n    ");
    if #complete inst.type == {
        case .FN_CALL;
            write(writer, "FnCall(ident: %, args: [", inst.as.fn_call.ident);
            for arg: inst.as.fn_call.args {
                print_tacky_val(*arg, writer);
                if it_index != inst.as.fn_call.args.count - 1 write(writer, ", ");
            }
            write(writer, "], dst: ");
            print_tacky_val(*inst.as.fn_call.dst, writer);
            write(writer, ")");
        case .RETURN;
            write(writer, "Return(");
            print_tacky_val(*inst.as.ret, writer);
            write(writer, ")");
        case .UNARY;
            write(writer, "Unary(op: %", inst.as.unary.op);
            write(writer, ", src: ");
            print_tacky_val(*inst.as.unary.src, writer);
            write(writer, ", dst: ");
            print_tacky_val(*inst.as.unary.dst, writer);
            write(writer, ")");
        case .BINARY;
            write(writer, "Binary(op: %", inst.as.binary.op);
            write(writer, ", src1: ");
            print_tacky_val(*inst.as.binary.src1, writer);
            write(writer, ", src2: ");
            print_tacky_val(*inst.as.binary.src2, writer);
            write(writer, ", dst: ");
            print_tacky_val(*inst.as.binary.dst, writer);
            write(writer, ")");
        case .LABEL;
            write(writer, "Label(%)", inst.as.label);
        case .JUMP_IF_NOT_ZERO; 
            write(writer, "JumpIfNotZero(condition: ");
            print_tacky_val(*inst.as.jump_if_zero.condition, writer);
            write(writer, ", label: %", inst.as.jump_if_zero.ident);
            write(writer, ")");
        case .JUMP_IF_ZERO; 
            write(writer, "JumpIfZero(condition: ");
            print_tacky_val(*inst.as.jump_if_zero.condition, writer);
            write(writer, ", label: %", inst.as.jump_if_zero.ident);
            write(writer, ")");
        case .COPY; 
            write(writer, "Copy(src: ");
            print_tacky_val(*inst.as.copy.src, writer);
            write(writer, ", dst: ");
            print_tacky_val(*inst.as.copy.dst, writer);
            write(writer, ")");
        case .JUMP;
            write(writer, "Jump(%)", inst.as.jump);
    }
}

print_tacky_val :: (val: *Val_Tacky, writer: *Writer) {
    if #complete val.type == {
        case .CONSTANT; write(writer, "Constant(%)", val.as.constant);
        case .VARIABLE; write(writer, "Var(%)", val.as.variable);
    }
}