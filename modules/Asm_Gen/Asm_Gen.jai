asm_gen :: (pgt: *Program_Tacky, st: Symbol_Table, do_print: bool = false) -> *Program_Asm {
    program_asm := map_to_asm(pgt, st);
    if do_print {
        writer := stdout_writer_new();
        print_asm(*writer, program_asm, 1);
    }
    asm_gen_stage_2(program_asm);
    if do_print {
        writer := stdout_writer_new();
        print_asm(*writer, program_asm, 2);
    }

    pg_stage_3 := asm_gen_stage_3(program_asm);
    if do_print {
        writer := stdout_writer_new();
        print_asm(*writer, pg_stage_3, 3);
    }
    return  pg_stage_3;
}

#scope_file

#load "Stage1.jai";
#load "Stage2.jai";

// Fix assembly instruction
asm_gen_stage_3 :: (pg: *Program_Asm) -> *Program_Asm {
    new_pg := New(Program_Asm);
    fns : [..]Fn_Asm;
    
    for fn: pg.fns {
        stack_size := fn.stack_size;
        old_insts := fn.instructions;
        new_insts := asm_gen_stage_3(old_insts, stack_size);
        array_add(*fns, .{fn.ident, new_insts, stack_size});
    }
    new_pg.* = .{fns};
    return new_pg;
}


asm_gen_stage_3 :: (old_insts: []Instruction_Asm, stack_size: int) -> [..]Instruction_Asm {
    insts : [..]Instruction_Asm;
    if stack_size % 16 != 0 {
        // stack size should be multiple of 16
        stack_size += (16 - (stack_size % 16));
    }
    array_add(*insts, .{.ALLOCATE_STACK, .{allocate_stack = stack_size}});

    for oi: old_insts {
        if #complete oi.type == {
            case .CALL; 
                array_add(*insts, oi);
            case .PUSH;
                array_add(*insts, oi);
            case .DEALLOCATE_STACK;
                array_add(*insts, oi);
            case .MOV;
                movi := oi.as.mov;
                if movi.src.type == .STACK && movi.dst.type == .STACK {
                    // both src and dst can't be memory address
                    ireg := reg(.R10, .DWORD);
                    array_add(*insts, mov(movi.src, ireg));
                    array_add(*insts, mov(ireg, movi.dst));
                } else {
                    array_add(*insts, oi);
                }
            case .IDIV;
                if oi.as.idiv.type == .IMM {
                    // idivl  $3
                    // -- to --
                    // movl   $3, %r10d
                    // idivl  %r10d
                    // idiv divisor can't be constant
                    intermediate_reg := reg(.R10, .DWORD);
                    array_add(*insts, .{.MOV, .{mov = .{oi.as.idiv, intermediate_reg}}});
                    array_add(*insts, .{.IDIV, .{idiv = intermediate_reg}});
                } else {
                    array_add(*insts, oi);
                }
            case .BINARY;
                if #complete oi.as.binary.op == {
                    case .LEFT_SHIFT; #through;
                    case .RIGHT_SHIFT;
                        ireg := reg(.CX, .DWORD);
                        array_add(*insts, .{.MOV, .{mov = .{oi.as.binary.src1, ireg }}});
                        array_add(*insts, .{.BINARY, .{binary = .{ oi.as.binary.op, ireg, oi.as.binary.src2}}});
                    case .BITWISE_AND; #through;
                    case .BITWISE_OR; #through;
                    case .BITWISE_XOR; #through;
                    case .ADD; #through;
                    case .SUB;
                        // both src and dst can't be memory address
                        // addl   -4(%rbp), -8(%rbp)
                        // -- to --
                        // movl   -4(%rbp), %r10d
                        // addl   %r10d, -8(%rbp)
                        ireg := reg(.R10, .DWORD);
                        array_add(*insts, .{.MOV, .{mov = .{oi.as.binary.src1, ireg }}});
                        array_add(*insts, .{.BINARY, .{binary = .{ oi.as.binary.op, ireg, oi.as.binary.src2}}});
                    case .MUL;
                        // imull  $3, -4(%rbp) // imull can't use memory address as its destination
                        // -- to --
                        // movl   -4(%rbp), %r11d
                        // imull  $3, %r11d
                        // movl   %r11d, -4(%rbp)
                        ireg := reg(.R11, .DWORD);
                        array_add(*insts, .{.MOV, .{mov = .{oi.as.binary.src2, ireg }}});
                        array_add(*insts, .{.BINARY, .{binary = .{oi.as.binary.op, oi.as.binary.src1, ireg }}});
                        array_add(*insts, .{.MOV, .{mov = .{ ireg, oi.as.binary.src2 }}});
                    case .EQUAL_EQUAL; assert(false, "unreachable");
                    case .NOT_EQUAL; assert(false, "unreachable");
                    case .GREATER; assert(false, "unreachable");
                    case .LESS; assert(false, "unreachable");
                    case .LESS_EQUAL; assert(false, "unreachable");
                    case .GREATER_EQUAL; assert(false, "unreachable");
                }
            case .UNARY; #through;
            case .ALLOCATE_STACK; #through;
            case .CDQ; #through;
            case .RET;
                array_add(*insts, oi);
            case .LABEL; array_add(*insts, oi);
            case .JMP; array_add(*insts, oi);
            case .JMP_CC; array_add(*insts, oi);
            case .SET_CC;
                array_add(*insts, oi);
            case .CMP;
                if oi.as.cmp.op1.type == .STACK && oi.as.cmp.op2.type == .STACK {
                    ireg := reg(.R10, .DWORD);
                    array_add(*insts, .{.MOV, .{mov = .{oi.as.cmp.op1, ireg }}});
                    array_add(*insts, .{.CMP, .{cmp = .{ ireg, oi.as.cmp.op2}}});
                }
                else if oi.as.cmp.op2.type == .IMM {
                    ireg := reg(.R11, .DWORD);
                    array_add(*insts, .{.MOV, .{mov = .{oi.as.cmp.op2, ireg }}});
                    array_add(*insts, .{.CMP, .{cmp = .{ oi.as.cmp.op1, ireg}}});
                }
                else {
                    array_add(*insts, oi);
                }
        }
    }
    return insts;
}





/* ADSL ASM_GEN
program              = Program(function_definition)
function_definition  = Function(identifier name, instruction* instructions)
instruction          = Mov(operand src, operand dst)
                       | Unary(unary_operator, operand)
                       | Binary(binary_operator, operand, operand)
                       | Cmp(operand, operand)
                       | Idiv(operand)
                       | Cdq
                       | Jmp(identifier)
                       | JmpCC(cond_code, identifier)
                       | SetCC(cond_code, identifier)
                       | Label(identifier)
                       | AllocateStack(int)
                       | Ret
unary_operator       = Neg | Not
operand              = Imm(int) | Reg(reg) | Pseudo(identifier) | Stack(int)
reg                  = AX | DX | R10 | R11 | RSP | RBP
cond_code            = EE | NE | G | GE | L | LE

*/
