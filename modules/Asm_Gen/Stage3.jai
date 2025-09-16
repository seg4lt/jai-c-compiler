#scope_module

// Fix assembly instruction
fix_asm :: (pg: *Program_Asm) -> *Program_Asm {
    fixed_top_level: [..]Top_Level_Asm;
    
    for pg.top_level {
        if #complete it.kind == {
            case .FN;
                fn := it.top_level_fn;
                stack_size := fn.stack_size;
                old_instructions  := fn.instructions;
                
                new_insts  := fix_instructions(old_instructions, stack_size);
                fn_inst := Fn_Asm.{fn.ident, new_insts, stack_size, fn.global};
                array_add(*fixed_top_level, .{ .FN, .{ top_level_fn = fn_inst }});
            case .STATIC;
                array_add(*fixed_top_level, it);
        }
    }
    return New(Program_Asm, .{ fixed_top_level });
}

#scope_file

is_memory_addr :: (using op: Operand_Asm) -> bool {
    return type == .STACK || type == .DATA;
}

fix_instructions :: (old_instructions: []Instruction_Asm, stack_size: int) -> [..]Instruction_Asm {
    insts : [..]Instruction_Asm;
    
    aligned_stack_size := (stack_size + STACK_ALIGNMENT - 1) & ~(STACK_ALIGNMENT - 1);
    array_add(*insts, allocate_stack(aligned_stack_size));

    for oi: old_instructions {
        if #complete oi.type == {
            case .MOV;
                movi := oi.as.mov;
                if is_memory_addr(movi.src) && is_memory_addr(movi.dst) {
                    ireg := reg(.R10, .DWORD);
                    array_add(*insts, mov(movi.src, ireg));
                    array_add(*insts, mov(ireg, movi.dst));
                } else {
                    array_add(*insts, oi);
                }
            case .IDIV;
                if oi.as.idiv.type == .IMM {
                    intermediate_reg := reg(.R10, .DWORD);
                    array_add(*insts, .{.MOV, .{mov = .{oi.as.idiv, intermediate_reg}}});
                    array_add(*insts, .{.IDIV, .{idiv = intermediate_reg}});
                } else {
                    array_add(*insts, oi);
                }
            case .BINARY;
                bins := oi.as.binary;
                if #complete bins.op == {
                    case .LEFT_SHIFT; #through;
                    case .RIGHT_SHIFT;
                        ireg := reg(.CX, .DWORD);
                        array_add(*insts, mov(bins.src1, ireg));
                        array_add(*insts, binary(bins.op, ireg, bins.src2));
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
                cmpi := oi.as.cmp;
                if is_memory_addr(cmpi.op1) && is_memory_addr(cmpi.op2) {
                    ireg := reg(.R10, .DWORD);
                    array_add(*insts, mov(cmpi.op1, ireg));
                    array_add(*insts, cmp(ireg, cmpi.op2));
                } else if cmpi.op2.type == .IMM {
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