
/* -- ADSL for TACKY IR -- 

program             = Program(function_definition)
function_definition = Function(identifier, instruction* body)
instruction         = Return(val) 
                    | Unary(unary_operator, val src, val dst)
                    | Binary(binary_operator, val src1, val src2, val dst)
                    | Copy(val src, val dst)
                    | Jump(identifier target)
                    | JumpIfZero(val condition, identifier target)
                    | JumpIfNotZero(val condition, identifier target)
                    | Label(identifier)
val                 = Constant(int) | Var(identifier)
unary_operator      = Complement | Negate | Not
binary_operator     = Add | Subtract | Multiply | Divide | Remainder 
                    | And | Or
                    | Equal | Not Equal
                    | LessThan | LessOrEqual 
                    | GreaterThan | GreaterOrEqual 

*/