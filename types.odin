package termite

import "core:io"

TokenKind :: enum {
    K_TRUE, K_FALSE, K_DEF, K_DECL,

    OP_LPAREN, OP_RPAREN,
    OP_COLON, OP_COMMA, OP_SEMICOLON,
    OP_EQ, OP_DIV,

    T_ID, T_STRING, T_INT,

    ERROR, EOF,
}

Token :: struct {
    kind: TokenKind,
    val: string
}

TokenizerState :: enum {
    CLEAN,
    D, DE, DEF, DEC, DECL,
    T, TR, TRU, TRUE,
    F, FA, FAL, FALS, FALSE,
    S_ID,
}

Tokenizer :: struct {
    stream: io.Stream,
    ahead1: rune,
    ahead2: rune,

    s: TokenizerState,

    kind: TokenKind,
    buffer: [dynamic]rune,
}


