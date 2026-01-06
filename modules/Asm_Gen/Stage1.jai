#scope_module

map_to_asm :: (pgt: *Tacky.Program, st: Symbol_Table) -> *Program {
    top_asm: [..]*Top_Level;
    for pgt.items {
        if #complete it.kind == {
            case .STATIC_VAR;
                sv := cast(*Tacky.Top_Level_Static_Var) it;
                alignment := get_size(sv.type);
                array_add(*top_asm, top_level_static_var(sv.ident, sv.global, xx alignment, sv.init));
            case .FN;
                fn_tacky := cast(*Tacky.Top_Level_Fn) it;
                fn := map_fn(fn_tacky, st);
                array_add(*top_asm, top_level_fn(fn.ident, fn.instructions, fn.stack_size, fn.global));
        }
    }
    pg := New(Program);
    pg.top_level = top_asm;
    return pg;
}

#scope_file

map_fn :: (fn_tacky: *Tacky.Top_Level_Fn, st: Symbol_Table) -> *Top_Level_Fn {
    instructions : [..]*Instruction;

    found_symbol, symbol := table_find(*st, fn_tacky.ident);
    if !found_symbol && symbol.kind != .FN assert(false, "function % not found in symbol table", fn_tacky.ident);

    // fn args already has a name - but they don't have values
    // we need to move value as per System V calling convention to respective pseudo registers
    symbol_fn       := symbol.(*Symbol_Fn);
    fn_params       := symbol_fn.params;
    fn_params_types := symbol_fn.type.params;

    register_args  := array_view(fn_params, 0, min(fn_params.count, COUNT_REGISTER_FOR_ARGS));
    stack_args     := ifx fn_params.count > COUNT_REGISTER_FOR_ARGS
                            array_view(fn_params, COUNT_REGISTER_FOR_ARGS, fn_params.count - COUNT_REGISTER_FOR_ARGS)
                      else  .[];

    for register_args {
        register_to_use := ARGS_REGISTERS[it_index];
        asm_arg         := pseudo(it);
        size            := get_size(fn_params_types[it_index]);
        array_add(*instructions, mov(reg(register_to_use, size), asm_arg, size));
    }
    for stack_args {
        asm_arg := pseudo(it);
        src := stack(STACK_ALIGNMENT + (it_index * PUSH_SIZE));
        // Question: Do I need to set instruction size based on type here? 
        array_add(*instructions, mov(src, asm_arg, .QUADWORD));
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
        case .SIGNED_EXTEND;
            se := instt.(*Tacky.Instruction_Signed_Extend);
            src := to_operand(se.src);
            dst := to_operand(se.dst);
            size := get_size(se.dst.type);
            array_add(insts, movsx(src, dst, size));
        case .TRUNCATE;
            tr := instt.(*Tacky.Instruction_Truncate);
            src := to_operand(tr.src);
            dst := to_operand(tr.dst);
            size := get_size(tr.dst.type);
            array_add(insts, mov(src, dst, size));
        case .RETURN;
            ret_inst := cast(*Tacky.Instruction_Return) instt;
            src := to_operand(ret_inst.val);
            size := get_size(ret_inst.val.type);
            dst := reg(.AX, size);
            array_add(insts, mov(src, dst, size));
            array_add(insts, ret());
        case .UNARY;
            unary_inst := cast(*Tacky.Instruction_Unary) instt;
            src := to_operand(unary_inst.src);
            dst := to_operand(unary_inst.dst);
            if unary_inst.op == .NOT {
                zero := imm(0);
                array_add(insts, mov(zero, dst, get_size(unary_inst.dst.type)));
                array_add(insts, cmp(zero, src, get_size(unary_inst.src.type)));
                array_add(insts, set_cc(.EE, dst));
            } else {
                array_add(insts, mov(src, dst, get_size(unary_inst.src.type)));
                op: Unary_Op = ---;
                if #complete unary_inst.op == {
                    case .BITWISE_NOT; op = .BITWISE_NOT;
                    case .NEGATE;      op = .NEG;
                    case .NOT; assert(false, "unreachable");
                }
                array_add(insts, unary(op, dst, get_size(unary_inst.dst.type)));
            }
        case .BINARY;
            binary_i := cast(*Tacky.Instruction_Binary) instt;
            src1 := to_operand(binary_i.src1);
            src2 := to_operand(binary_i.src2);
            dst  := to_operand(binary_i.dst);
            op := map_binary_op(binary_i.op);

            size_src1 := get_size(binary_i.src1.type);
            size_src2 := get_size(binary_i.src2.type);
            size_dst  := get_size(binary_i.dst.type);

            if #complete binary_i.op == {
                case .ADD;          #through;
                case .BITWISE_AND;  #through;
                case .BITWISE_OR;   #through;
                case .BITWISE_XOR;  #through;
                case .LEFT_SHIFT;   #through;
                case .MUL;          #through;
                case .RIGHT_SHIFT;  #through;
                case .SUB;
                    array_add(insts, mov(src1, dst, size_src1));
                    array_add(insts, binary(op, src2, dst, size_src2));
                case .DIV; #through;
                case .MOD;
                    // load divident to AX register
                    first_move_dst := reg(.AX, size_src1);
                    array_add(insts, mov(src1, first_move_dst, size_src1));

                    // Sign-extend EAX into RDX;RAX
                    array_add(insts, cdq(size_src1));

                    // perform IDIV with divident src2
                    array_add(insts, idiv(src2, size_src2));

                    // move the result from specified register to dst
                    final_mov_src : *Operand = ---;
                    if binary_i.op == {
                        case .DIV; final_mov_src = reg(.AX, size_dst);
                        case .MOD; final_mov_src = reg(.DX, size_dst);
                        case;      assert(false, "Div shouldn't get any other operator: %", binary_i.op);
                    }
                    final_mov_dst := to_operand(binary_i.dst);
                    array_add(insts, mov(final_mov_src, final_mov_dst, size_dst));
                case .EQUAL_EQUAL;   #through;
                case .GREATER;       #through;
                case .GREATER_EQUAL; #through;
                case .LESS;          #through;
                case .LESS_EQUAL;    #through;
                case .NOT_EQUAL;
                    dst := to_operand(binary_i.dst);
                    array_add(insts, mov(imm(0), dst, size_dst));

                    src2 := to_operand(binary_i.src2);
                    if binary_i.src1.kind == {
                        case .CONSTANT;
                            src1 := to_operand(binary_i.src1);
                            ireg := reg(.R11, size_src1);
                            array_add(insts, mov(src1, ireg, size_src1));
                            array_add(insts, cmp(src2, ireg, size_src2));
                        case .VARIABLE;
                            src1 := to_operand(binary_i.src1);
                            array_add(insts, cmp(src2, src1, size_src2));
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
            size := get_size(jnz.condition.type);
            zero := imm(0);
            array_add(insts, cmp(zero, cond_var, size));
            array_add(insts, jmp_cc(.NE, jnz.target));
        case .JUMP_IF_ZERO;
            jz := cast(*Tacky.Instruction_Jump_If_Zero) instt;
            cond_var := to_operand(jz.condition);
            size := get_size(jz.condition.type);
            zero := imm(0);
            array_add(insts, cmp(zero, cond_var, size));
            array_add(insts, jmp_cc(.EE, jz.target));
        case .COPY;
            copy_inst := cast(*Tacky.Instruction_Copy) instt;
            src := to_operand(copy_inst.src);
            dst := to_operand(copy_inst.dst);
            size := get_size(copy_inst.src.type);
            array_add(insts, mov(src, dst, size));
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
            if stack_padding != 0 
                array_add(insts, binary(.SUB, imm(stack_padding), reg(.RSP, .QUADWORD), .QUADWORD));

            for register_args {
                register_to_use := ARGS_REGISTERS[it_index];
                assembly_arg := to_operand(it);
                size := get_size(it.type);
                array_add(insts, mov(assembly_arg, reg(register_to_use, size), size));
            }

            for < stack_args {
                asm_arg := to_operand(it);
                size := get_size(it.type);

                if asm_arg.kind == .REG || asm_arg.kind == .IMM || size == .QUADWORD  {
                    array_add(insts, push(asm_arg));
                } else {
                    array_add(insts, mov(asm_arg, reg(.AX, .LONGWORD), .LONGWORD));
                    array_add(insts, push(reg(.AX, size)));
                }
            }

            array_add(insts, call(fn_call.ident));
            bytes_to_remove := (stack_args.count * PUSH_SIZE) + stack_padding;
            if bytes_to_remove > 0 {
                array_add(insts, binary(.ADD, imm(bytes_to_remove), reg(.RSP, .QUADWORD), .QUADWORD));
            }

            assembly_dst := to_operand(fn_call.dst);
            size := get_size(fn_call.dst.type);
            array_add(insts, mov(reg(.AX, size), assembly_dst, size));
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
            constant_value : s64 = ---;
            if #complete constant.constant.kind == {
                case .INT; constant_value = constant.constant.(*Ast.Constant_Int).value;
                case .LONG; constant_value = constant.constant.(*Ast.Constant_Long).value;
            }
            return imm(constant_value);
        case .VARIABLE; 
            variable := cast(*Tacky.Val_Variable) val;
            return pseudo(variable.variable);
    }
}


#scope_file
using Symbol_Table;