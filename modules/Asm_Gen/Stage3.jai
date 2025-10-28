#scope_module

// Fix assembly instruction
fix_asm :: (pg: *Program) -> *Program {
    fixed_top_level: [..]*Top_Level;

    for pg.top_level {
        if #complete it.kind == {
            case .FN;
                fn := cast(*Top_Level_Fn) it;
                stack_size := fn.stack_size;
                old_instructions  := fn.instructions;

                new_insts  := fix_instructions(old_instructions, stack_size);
                array_add(*fixed_top_level, top_level_fn(fn.ident, new_insts, stack_size, fn.global));
            case .STATIC;
                array_add(*fixed_top_level, it);
        }
    }
    pg_result := New(Program);
    pg_result.top_level = fixed_top_level;
    return pg_result;
}

#scope_file

is_memory_addr :: (op: *Operand) -> bool {
    return op.kind == .STACK || op.kind == .DATA;
}

fix_instructions :: (old_instructions: []*Instruction, stack_size: int) -> [..]*Instruction {
    insts : [..]*Instruction;

    aligned_stack_size := (stack_size + STACK_ALIGNMENT - 1) & ~(STACK_ALIGNMENT - 1);
    array_add(*insts, allocate_stack(aligned_stack_size));

    for oi: old_instructions {
        if #complete oi.kind == {
            case .MOV;
                movi := cast(*Instruction_Mov) oi;
                if is_memory_addr(movi.src) && is_memory_addr(movi.dst) {
                    ireg := reg(.R10, .DWORD);
                    array_add(*insts, mov(movi.src, ireg));
                    array_add(*insts, mov(ireg, movi.dst));
                } else {
                    array_add(*insts, oi);
                }
            case .IDIV;
                idiv_inst := cast(*Instruction_Idiv) oi;
                if idiv_inst.operand.kind == .IMM {
                    intermediate_reg := reg(.R10, .DWORD);
                    array_add(*insts, mov(idiv_inst.operand, intermediate_reg));
                    array_add(*insts, idiv(intermediate_reg));
                } else {
                    array_add(*insts, oi);
                }
            case .BINARY;
                bins := cast(*Instruction_Binary) oi;
                if #complete bins.op == {
                    case .LEFT_SHIFT; #through;
                    case .RIGHT_SHIFT;
                        count_reg_dword := reg(.CX, .DWORD);
                        array_add(*insts, mov(bins.src1, count_reg_dword));
                        dest_reg := reg(.R10, .DWORD);
                        array_add(*insts, mov(bins.src2, dest_reg));
                        count_reg_byte := reg(.CX, .BYTE);
                        array_add(*insts, binary(bins.op, count_reg_byte, dest_reg));
                        array_add(*insts, mov(dest_reg, bins.src2));
                    case .ADD;         #through;
                    case .BITWISE_AND; #through;
                    case .BITWISE_OR;  #through;
                    case .BITWISE_XOR; #through;
                    case .SUB;
                        ireg := reg(.R10, .DWORD);
                        array_add(*insts, mov(bins.src1, ireg));
                        array_add(*insts, binary(bins.op, ireg, bins.src2));
                    case .MUL;
                        ireg := reg(.R11, .DWORD);
                        array_add(*insts, mov(bins.src2, ireg));
                        array_add(*insts, binary(bins.op, bins.src1, ireg));
                        array_add(*insts, mov(ireg, bins.src2));
                    case .EQUAL_EQUAL;   #through;
                    case .GREATER;       #through;
                    case .GREATER_EQUAL; #through; 
                    case .LESS;          #through;
                    case .LESS_EQUAL;    #through;
                    case .NOT_EQUAL;     assert(false, "unreachable");
                }
            case .CMP;
                cmpi := cast(*Instruction_Cmp) oi;
                if is_memory_addr(cmpi.op1) && is_memory_addr(cmpi.op2) {
                    ireg := reg(.R10, .DWORD);
                    array_add(*insts, mov(cmpi.op1, ireg));
                    array_add(*insts, cmp(ireg, cmpi.op2));
                } else if cmpi.op2.kind == .IMM {
                    ireg := reg(.R11, .DWORD);
                    array_add(*insts, mov(cmpi.op2, ireg));
                    array_add(*insts, cmp(cmpi.op1, ireg));
                } else {
                    array_add(*insts, oi);
                }
            case .CALL;             #through;
            case .PUSH;             #through;
            case .DEALLOCATE_STACK; #through;
            case .UNARY;            #through;
            case .ALLOCATE_STACK;   #through;
            case .CDQ;              #through;
            case .LABEL;            #through;
            case .JMP;              #through;
            case .JMP_CC;           #through;
            case .SET_CC;           #through;
            case .RET;              array_add(*insts, oi);
        }
    }
    return insts;
}