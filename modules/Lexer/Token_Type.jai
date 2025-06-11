Token_Type :: enum {
    LPAREN;
    RPAREN;
    LCURLY;
    RCURLY;
    SEMICOLON;

    IDENT;
    INT_LITERAL;
    // Keyword
    INT;
    VOID;
    RETURN;
    // Operator
    BITWISE_NOT;
    BITWISE_AND;
    BITWISE_OR;
    BITWISE_XOR;
    LEFT_SHIFT;
    RIGHT_SHIFT;
    MINUS;
    PLUS;
    DIVIDE;
    MULTIPLY;
    MOD;
    NOT;
    AND;
    OR;
    EQUAL_EQUAL;
    NOT_EQUAL;
    LESS;
    LESS_EQUAL;
    GREATER;
    GREATER_EQUAL;
    ASSIGN;

    PLUS_EQUAL;
    MINUS_EQUAL;
    MULTIPLY_EQUAL;
    DIVIDE_EQUAL;
    MOD_EQUAL;
    LEFT_SHIFT_EQUAL;
    RIGHT_SHIFT_EQUAL;
    BITWISE_AND_EQUAL;
    BITWISE_OR_EQUAL;
    BITWISE_XOR_EQUAL;

    MINUS_MINUS;
    PLUS_PLUS;

    IF;
    ELSE;
    QUESTION_MARK;
    COLON;

    GOTO;

    FOR;
    DO;
    WHILE;
    CONTINUE;
    BREAK;

    SWITCH;
    CASE;
    DEFAULT;

    COMMA;
}