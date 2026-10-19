package termite

import "core:io"

Kind :: enum {
    K_TRUE, K_FALSE, K_DEF, K_DECL,

    OP_LPAREN, OP_RPAREN,
    OP_COLON, OP_COMMA, OP_SEMICOLON,
    OP_EQ, OP_DIV,

    ID, STRING, INT,

    ERROR, EOF,
}

Token :: struct {
    kind: Kind,
    val: string
}

State :: enum {
    CLEAN,

    D, DE, DEF, DEC, DECL,
    T, TR, TRU, TRUE,
    F, FA, FAL, FALS, FALSE,
    ID,

    ERROR,
}

Tokenizer :: struct {
    stream: io.Stream,
    ahead1: rune,
    ahead2: rune,

    s: State,

    kind: Kind,
    buffer: [dynamic]rune,
}
