package termite

import "core:io"

TokenKind :: enum {
    TRUE, FALSE, DEF, DECL,

    LPAREN, RPAREN,
    COMMA, COLON, SEMICOLON,
    EQ, NEQ, DIV,

    ID, STRING, INT,

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

ExprKind :: enum {
    ATOM, VAR,
    STRING, INT, TRUE, FALSE,
    AND,
}

Expr :: struct {
    kind: ExprKind,
    op: string,
    args: [dynamic]Expr,
}

Relation :: struct {
    name: string,
    arity: u8,
    fields: [dynamic]string,
    types: [dynamic]string,
}

Parser :: struct {
    tokenizer: Tokenizer,
    has_ahead: bool,
    ahead: Token,

    relations: map[string]Relation,
}
