# TODO
- [ ] SETCC needs only 1 byte, but today we are using 4 bytes. Need to fix this
- [ ] Parse typedef - Read more on context sentitive grammer.


References;
- https://cs.brown.edu/courses/cs033/docs/guides/x64_cheatsheet.pdf
- https://web.stanford.edu/class/cs107/resources/x86-64-reference.pdf
- https://docs.oracle.com/cd/E19253-01/817-5477/index.html
- https://www.jdoodle.com/compile-assembler-gcc-online

# Notes
`arch -x86_64` - run x86_64 binaries on M1 mac
`arch -x86_64 fish` - run x86_64 binaries on M1 mac

Chap 1:
- Lex: `./test_compiler ../jai/out/target --chapter 1 --stage lex`
- Parse: `./test_compiler /path/to/your_compiler --chapter 1 --stage parse`
- Asm Gen: `./test_compiler /path/to/your_compiler --chapter 1 --stage codegen`
- Full: `./test_compiler /path/to/your_compiler --chapter 1`

Chap 2:
- `--stage tacky for tacky IR test`

Chap 3:
- Bitwise: `./test_compiler /path/to/your_compiler --chapter 3 --stage bitwise`

Chap 5:
- Tacky: `./test_compiler /path/to/your_compiler --chapter 1 --stage tacky`

- $ ./test_compiler /path/to/your_compiler --chapter 5 --extra-credit
- $ ./test_compiler /path/to/your_compiler --chapter 5 --bitwise --compound --increment



