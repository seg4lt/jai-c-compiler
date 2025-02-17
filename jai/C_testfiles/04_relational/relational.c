int main(void) {
    return 1 && (1 / 0);
}

/*



-- Tacky --
    .program
.main:
    JumpIfZero(condition: Constant(1), label: label_cond_false.0)
    Binary(op: DIV, src1: Constant(1), src2: Constant(0), dst: Var(tmp.0))
    JumpIfZero(condition: Var(tmp.0), label: label_cond_false.0)
    Copy(src: Constant(1), dst: Var(tmp.1))
    Jump(label_logical_cmp_end.1)
    Label(label_cond_false.0)
    Copy(src: Constant(0), dst: Var(tmp.1))
    Label(label_logical_cmp_end.1)
    Return(Var(tmp.1))


*/