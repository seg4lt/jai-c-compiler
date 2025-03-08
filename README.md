# writing-c-compiler implementation in Zig and Jai

Simple implementation of c-compiler using Zig and Jai. Currently only Jai


# TODO (jai)
- [ ] Better reporting - error reporting as separate concern
- [ ] SETCC needs only 1 byte, but today we are using 4 bytes. Need to fix this
- [ ] Parse typedef - Read more on context sentitive grammer.
- [ ] Postfix unary operator are not working properly. Need to fix this.
- [ ] Update to support arm64 assembly



# Notes
`arch -x86_64` - run x86_64 binaries on M1 mac
`arch -x86_64 fish` - run x86_64 binaries on M1 mac

# Test Flags
Command: `./test_compiler ../jai/out/target --chapter 1 --stage lex`
- Lex: `--stage lex` - for lex
- Parse: `--stage parse`
- Asm Gen: `--stage codegen`
- Tacky IR: `--stage tacky`
- Full: `--chapter <n>`
Extras
- Bitwise: `./test_compiler /path/to/your_compiler --chapter 3 --stage bitwise`
- Run all extra credit stuff: `--extra-credit`
- `--bitwise --compound --increment`


# References;
- https://cs.brown.edu/courses/cs033/docs/guides/x64_cheatsheet.pdf
- https://web.stanford.edu/class/cs107/resources/x86-64-reference.pdf
- https://docs.oracle.com/cd/E19253-01/817-5477/index.html
- https://www.jdoodle.com/compile-assembler-gcc-online
- Reference book: https://nostarch.com/writing-c-compiler
- Test was copied from : https://github.com/nlsandler/writing-a-c-compiler-tests


