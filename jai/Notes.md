# Formal grammer

```
<program> ::= <function>
<function> ::= "int" <identifier> "(" "void" ")" "{" <statement> "}"
<statement> ::= "return" <exp> ";"
<exp> ::= <int>
<identifier> ::= ? An identifier token ?
<int> ::= ? A constant token ?
```


# ADSL

```
program = Program(function_definition)
function_definition = Function(identifier name, statement body)
statement = Return(exp)
exp = Constant(int)
```






# Notes
`arch -x86_64` - run x86_64 binaries on M1 mac
`arch -x86_64 fish` - run x86_64 binaries on M1 mac

Chap 1:
- Lex: `./test_compiler ../jai/out/target --chapter 1 --stage lex`
- Parse: `./test_compiler /path/to/your_compiler --chapter 1 --stage parse`

