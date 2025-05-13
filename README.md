# C Compiler in Jai

Simple implementation of c-compiler using Jai


# TODO
- [ ] SETCC needs only 1 byte, but today we are using 4 bytes. Need to fix this
- [ ] Parse typedef - Read more on context sentitive grammer.
- [ ] Update to support arm64 assembly
- [ ] Revamp output printer and add tests
- [ ] Function pointers
    - Implement after arrays are added


# Notes
- Run on docker - `docker-compose exec box bash -c 'jai build.jai && ./out/jaicc -- ./c/main.c && ./c/main && echo $?'`

# Run on Mac - (ld doesn't work on M1)
- `arch -x86_64` - run x86_64 binaries on M1 mac
- `arch -x86_64 fish` - run x86_64 binaries on M1 mac

# Test Flags
Command: `./test_compiler ../out/jaicc --chapter 1 --stage lex`
- Lex: `--stage lex` - for lex
- Parse: `--stage parse` ,  
- Validate: `--stage validate`
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
- https://www.onlinegdb.com/online_c_compiler
- https://docs.oracle.com/cd/E19695-01/802-1948/802-1948.pdf
- https://www.felixcloutier.com/x86/
- https://web.stanford.edu/class/cs107/guide/x86-64.html
- Reference book: https://nostarch.com/writing-c-compiler
- Test was copied from : https://github.com/nlsandler/writing-a-c-compiler-tests


