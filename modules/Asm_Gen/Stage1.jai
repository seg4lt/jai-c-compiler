#scope_module

map_to_asm :: (pgt: *Tacky.Program, st: Symbol_Table) -> *Program {
    top_level_asms: [..]*Top_Level;
    for pgt.items {
        if #complete it.kind == {
            case .STATIC_VAR;
                sv := cast(*Tacky.Top_Level_Static_Var) it;
                array_add(*top_level_asms, top_level_static_var(sv.ident, sv.global, sv.init));
            case .FN;
                fn_tacky := cast(*Tacky.Top_Level_Fn) it;
                fn := map_fn(fn_tacky, st);
                array_add(*top_level_asms, top_level_fn(fn.ident, fn.instructions, fn.stack_size, fn.global));
        }
    }
    pg := New(Program);
    pg.top_level = top_level_asms;
    return pg;
}

#scope_file

map_fn :: (fn_tacky: *Tacky.Top_Level_Fn, st: Symbol_Table) -> *Top_Level_Fn {
    instructions : [..]*Instruction;

    found_sym, sym := table_find(*st, fn_tacky.ident);
    if !found_sym assert(false, "function % not found in symbol table", fn_tacky.ident);
    if sym.kind != .FN assert(false, "Symbol % is not a function", fn_tacky.ident);

    // fn args already has a name - but they don't have values
    // we need to move value as per System V calling convention to respective pseudo registers
    fn_sym := cast(*Symbol_Fn) sym;
    fn_params := fn_sym.params;

    register_args  := array_view(fn_params, 0, min(fn_params.count, COUNT_REGISTER_FOR_ARGS));
    stack_args     := ifx fn_params.count > COUNT_REGISTER_FOR_ARGS
                            array_view(fn_params, COUNT_REGISTER_FOR_ARGS, fn_params.count - COUNT_REGISTER_FOR_ARGS)
                      else  .[];

    for register_args {
        register_to_use := ARGS_REGISTERS[it_index];
        asm_arg         := pseudo(it.ident);
        array_add(*instructions, mov(reg(register_to_use, .DWORD), asm_arg));
    }
    for stack_args {
        asm_arg := pseudo(it.ident);
        src := stack(STACK_ALIGNMENT + (it_index * PUSH_SIZE));
        array_add(*instructions, mov(src, asm_arg));
    }

    for fn_tacky.instructions map_instructions(*instructions, it);

    INITIAL_STACK_SIZE :: 0; // this will be updated in later stages
    fn := New(Top_Level_Fn);
    fn.ident = copy_string(fn_tacky.ident);
    fn.instructions = instructions;
    fn.stack_size = INITIAL_STACK_SIZE;
    fn.global = fn_tacky.global;
    return fn;
}

map_instructions :: (insts: *[..]*Instruction, instt: *Tacky.Instruction) {
    if #complete instt.kind == {
        case .RETURN;
            ret_inst := cast(*Tacky.Instruction_Return) instt;
            src := to_operand(ret_inst.val);
            dst := reg(.AX, .DWORD);
            array_add(insts, mov(src, dst));
            array_add(insts, ret());
        case .UNARY;
            unary_i := cast(*Tacky.Instruction_Unary) instt;
            if unary_i.op == .NOT {
                zero := imm(0);
                src := to_operand(unary_i.src);
                dst := to_operand(unary_i.dst);
                array_add(insts, mov(zero, dst));
                array_add(insts, cmp(zero, src));
                array_add(insts, set_cc(.EE, dst));
            } else {
                src := to_operand(unary_i.src);
                dst := to_operand(unary_i.dst);
                array_add(insts, mov(src, dst));

                op: Unary_Op = ---;
                if #complete unary_i.op == {
                    case .BITWISE_NOT; op = .BITWISE_NOT;
                    case .NEGATE;      op = .NEG;
                    case .NOT; assert(false, "unreachable");
                }
                array_add(insts, unary(op, dst));
            }
        case .BINARY;
            binary_i := cast(*Tacky.Instruction_Binary) instt;
            if #complete binary_i.op == {
                case .ADD;          #through;
                case .BITWISE_AND;  #through;
                case .BITWISE_OR;   #through;
                case .BITWISE_XOR;  #through;
                case .LEFT_SHIFT;   #through;
                case .MUL;          #through;
                case .RIGHT_SHIFT;  #through;
                case .SUB;
                    src1 := to_operand(binary_i.src1);
                    dst := to_operand(binary_i.dst);
                    array_add(insts, mov(src1, dst));

                    op := map_binary_op(binary_i.op);
                    src2 := to_operand(binary_i.src2);
                    array_add(insts, binary(op, src2, dst));
                case .DIV; #through;
                case .MOD;
                    // load divident to AX register
                    src1           := to_operand(binary_i.src1);
                    first_move_dst := reg(.AX, .DWORD);
                    array_add(insts, mov(src1, first_move_dst));

                    // Sign-extend EAX into RDX;RAX
                    array_add(insts, cdq());

                    // perform IDIV with divident src2
                    src2 := to_operand(binary_i.src2);
                    array_add(insts, idiv(src2));

                    // move the result from specified register to dst
                    final_mov_src : *Operand = ---;
                    if binary_i.op == {
                        case .DIV; final_mov_src = reg(.AX, .DWORD);
                        case .MOD; final_mov_src = reg(.DX, .DWORD);
                        case;      assert(false, "Div shouldn't get any other operator: %", binary_i.op);
                    }
                    final_mov_dst := to_operand(binary_i.dst);
                    array_add(insts, mov(final_mov_src, final_mov_dst));
                case .EQUAL_EQUAL;   #through;
                case .GREATER;       #through;
                case .GREATER_EQUAL; #through;
                case .LESS;          #through;
                case .LESS_EQUAL;    #through;
                case .NOT_EQUAL;
                    dst := to_operand(binary_i.dst);
                    array_add(insts, mov(imm(0), dst));

                    src2 := to_operand(binary_i.src2);
                    if binary_i.src1.kind == {
                        case .CONSTANT;
                            src1 := to_operand(binary_i.src1);
                            ireg := reg(.R11, .DWORD);
                            array_add(insts, mov(src1, ireg));
                            array_add(insts, cmp(src2, ireg));
                        case .VARIABLE;
                            src1 := to_operand(binary_i.src1);
                            array_add(insts, cmp(src2, src1));
                    }
                    cc := to_condition_code(binary_i.op);
                    array_add(insts, set_cc(cc, dst));
            }
        case .LABEL;
            lbl := cast(*Tacky.Instruction_Label) instt;
            array_add(insts, label(lbl.name));
        case .JUMP_IF_NOT_ZERO;
            jnz := cast(*Tacky.Instruction_Jump_If_Not_Zero) instt;
            cond_var := to_operand(jnz.condition);
            zero := imm(0);
            array_add(insts, cmp(zero, cond_var));
            array_add(insts, jmp_cc(.NE, jnz.target));
        case .JUMP_IF_ZERO;
            jz := cast(*Tacky.Instruction_Jump_If_Zero) instt;
            cond_var := to_operand(jz.condition);
            zero := imm(0);
            array_add(insts, cmp(zero, cond_var));
            array_add(insts, jmp_cc(.EE, jz.target));
        case .COPY;
            copy_inst := cast(*Tacky.Instruction_Copy) instt;
            src := to_operand(copy_inst.src);
            dst := to_operand(copy_inst.dst);
            array_add(insts, mov(src, dst));
        case .JUMP;
            jmp_inst := cast(*Tacky.Instruction_Jump) instt;
            array_add(insts, jmp(jmp_inst.target));
        case .FN_CALL;
            fn_call := cast(*Tacky.Instruction_Fn_Call) instt;
            register_args := array_view(fn_call.args, 0, min(fn_call.args.count, COUNT_REGISTER_FOR_ARGS));
            stack_args    := ifx fn_call.args.count > COUNT_REGISTER_FOR_ARGS
                                    array_view(fn_call.args, COUNT_REGISTER_FOR_ARGS, fn_call.args.count - COUNT_REGISTER_FOR_ARGS)
                             else   .[];

            stack_padding := ifx stack_args.count % 2 == 0 then 0 else PUSH_SIZE;
            if stack_padding != 0 array_add(insts, allocate_stack(stack_padding));

            for register_args {
                register_to_use := ARGS_REGISTERS[it_index];
                assembly_arg := to_operand(it);
                array_add(insts, mov(assembly_arg, reg(register_to_use, .DWORD)));
            }

            for < stack_args {
                asm_arg := to_operand(it);
                if asm_arg.kind == .REG || asm_arg.kind == .IMM {
                    array_add(insts, push(asm_arg));
                } else {
                    array_add(insts, mov(asm_arg, reg(.AX, .DWORD)));
                    array_add(insts, push(reg(.AX, .QWORD)));
                }
            }

            array_add(insts, call(fn_call.ident));
            bytes_to_remove := (stack_args.count * PUSH_SIZE) + stack_padding;
            if bytes_to_remove > 0 {
                array_add(insts, deallocate_stack(bytes_to_remove));
            }

            assembly_dst := to_operand(fn_call.dst);
            array_add(insts, mov(reg(.AX, .DWORD), assembly_dst));
    }
}

to_condition_code :: (op: Tacky.Bin_Op) -> Cond_Code {
    if op == {
        case .EQUAL_EQUAL;   return .EE;
        case .GREATER;       return .G;
        case .GREATER_EQUAL; return .GE;
        case .LESS;          return .L;
        case .LESS_EQUAL;    return .LE;
        case .NOT_EQUAL;     return .NE;
    }
    assert(false, "not relational operator: %", op);
    return .EE; // unreachable
}

map_binary_op :: (tacky_op: Tacky.Bin_Op) -> Bin_Op {
    if #complete tacky_op == {
        case .ADD;           return .ADD;
        case .SUB;           return .SUB;
        case .MUL;           return .MUL;
        case .BITWISE_OR;    return .BITWISE_OR;
        case .BITWISE_XOR;   return .BITWISE_XOR;
        case .BITWISE_AND;   return .BITWISE_AND;
        case .LEFT_SHIFT;    return .LEFT_SHIFT;
        case .RIGHT_SHIFT;   return .RIGHT_SHIFT;
        case .GREATER;       return .GREATER;
        case .GREATER_EQUAL; return .GREATER_EQUAL;
        case .LESS;          return .LESS;
        case .LESS_EQUAL;    return .LESS_EQUAL;
        case .EQUAL_EQUAL;   return .EQUAL_EQUAL;
        case .NOT_EQUAL;     return .NOT_EQUAL;

        case .DIV; #through;
        case .MOD;
            assert(false, "Other binary operator are either handled differently, or not supported: %", tacky_op);
            return .MUL; // unreachable;
    }
}

to_operand :: (val: *Tacky.Val) -> *Operand {
    if #complete val.kind == {
        case .CONSTANT; 
            constant := cast(*Tacky.Val_Constant) val;
            return imm(constant.constant);
        case .VARIABLE; 
            variable := cast(*Tacky.Val_Variable) val;
            return pseudo(variable.variable);
    }
}

#scope_file
using Symbol_Table;