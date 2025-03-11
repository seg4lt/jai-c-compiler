```
/* -- ADSL AST -- 

program              = Program(function_definition)
function_definition  = Function(identifier name, block body)
block                = Block(block_item*)
block_item           = S(stmt) | D(decleration)
declaration          = Declaration(identifier name, exp? init)
for_init             = InitDecl(declaration) | InitExp(exp?)
statement            = Return(exp)
                     | Expression(exp)
                     | Compound(block)
                     | If(exp condition, statement then, statement? else)
                     | Label(ident)
                     | Goto(ident)
                     | Break(ident)
                     | Continue(ident)
                     | While(exp condition, statement body)
                     | DoWhile(statement body, exp condition)
                     | For(for_init init, exp? condition, exp? post, statement body)
                     | Null                 # like ";" on while and for which signifies empty body
exp                  = Constant(int) 
                     | Var(identifier)
                     | Unary(unary_operator, exp)
                     | Binary(binary_operator, exp, exp)
                     | Assignment(exp, exp)
                     | Conditional(exp condition, true_block exp, false_block exp)
unary_operator       = Complement | Negate | Not
binary_operator      = Add | Subtract | Multiply | Divide | Remainder
                     | And | Or
                     | Less | LessOrEqual
                     | Greater | GreaterOrEqual
                     | Not | NotEqual
                     | BitwiseAnd | BitwiseOr | BitwiseXor
                     | BitwiseAndEqual | BitwiseOrEqual | BitwiseXorEqual
                     | AddEqual | SubtractEqual | MultiplyEqual | DivideEqual | RemainderEqual


*/

/* E-BNF production rule

<program>         ::= <function>
<function>        ::= "int" <identifier> "(" "void" ")" "{" <block-item> "}"
<block>           ::= "{" { <block_item> } "}"
<block-item>      ::= <statement> | <decleration>
<decleration>     ::= "int" <identifier> [ "=" <exp> ] ";"
<statement>       ::= "return" <exp> ";" | <exp> ";" | ";"
                    | "if" "(" <exp> ")" <statement> ["else" <statement>]
                    | <identifier> ":"
                    | <block>
                    | "goto" <identifier> ";"
<exp>             ::= <factor> 
                    | <exp> <binop> <exp>
                    | <exp> "?" <exp> ":" <exp>
<factor>          ::= <int> | <identifier> | <unop> <factor> | "(" <exp> ")"
<unop>            ::= "-" | "~" | "!"
<binop>           ::= "-" | "+" | "*" | "/" | "%" 
                    | "&&" | "||" | "==" | "!="
                    | ">" | ">=" | "<" | "<=" 
                    | "+=" | "-=" | "/=" | "%=" | "*="
                    | "&"  | "|" | "^"
                    | "&=" | "|=" | "^=" 
<identifier>      ::= ? An identifier token ?
<int>             ::= ? A constant token ?
*/
```