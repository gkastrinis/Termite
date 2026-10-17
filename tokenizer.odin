package termite

import "core:fmt"
import "core:io"
import "core:unicode/utf8"

Kind :: enum {
    K_TRUE, K_FALSE, K_DEF, K_DECL,

    OP_LPAREN,
    OP_RPAREN,
    OP_COLON,
    OP_COMMA,
    OP_SEMICOLON,
    OP_DOT,
    OP_EQ,
    OP_DIV,

    ID,
    STRING,

    UNDEF,
    ERROR,
    EOF,
}

State :: enum {
    CLEAN,

    D, DE, DEF, DEC, DECL,
    T, TR, TRU, TRUE,
    F, FA, FAL, FALS, FALSE,
    ID,
    STRING,

    COMMENT,
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

read_rune :: proc(tok: ^Tokenizer) -> (rune, io.Error) {
    if tok.ahead2 != '\x00' {
        r := tok.ahead2
        tok.ahead2 = '\x00'
        return r, nil
    } else if tok.ahead1 != '\x00' {
        r := tok.ahead1
        tok.ahead1 = '\x00'
        return r, nil
    } else {
        r, _, err := io.read_rune(tok.stream)
        return r, err
    }
}

unread_rune :: proc(tok: ^Tokenizer, r: rune) {
    if tok.ahead1 == '\x00' {
        tok.ahead1 = r
    } else if tok.ahead2 == '\x00' {
        tok.ahead2 = r
    } else {
        assert(false)
    }
}

is_white :: proc(r: rune) -> bool {
    return r == ' ' || r == '\t' || r == '\t' || r == '\n'
}

is_boundary :: proc(r: rune) -> bool {
    return r == '(' || r == ')' || r == ':' || r == ',' || r == ';' || r == '.' || r == '=' || is_white(r)
}

is_id_start :: proc(r: rune) -> bool {
    return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || r == '_'
}

is_num :: proc(r: rune) -> bool {
    return r >= '0' && r <= '9'
}

is_id_like :: proc(s: State) -> bool {
    return s == State.D || s == State.DE || s == State.DEF || s == State.DEC || s == State.DECL ||
        s == State.T || s == State.TR || s == State.TRU || s == State.TRUE ||
        s == State.F || s == State.FA || s == State.FAL || s == State.FALS || s == State.FALSE ||
        s == State.ID
}

tokenizer_add_to_buffer :: proc(tok: ^Tokenizer, new_state: State, r: rune) {
    tok.s = new_state
    append(&tok.buffer, r)
}

tokenizer_val_from_buffer :: proc(tok: ^Tokenizer) -> string {
    if len(tok.buffer) == 0 { return "" }
    str, _ := utf8.runes_to_string(tok.buffer[:])
    clear(&tok.buffer)
    return str
}

tokenizer_on_clean :: proc(tok: ^Tokenizer, r: rune) {
    if is_white(r) {
        // just consume it
    } else if r == '/' {
        ahead, err := read_rune(tok)
        if err == nil && ahead == '/' {
            tok.s = State.COMMENT
        } else {
            unread_rune(tok, ahead)
            tok.kind = Kind.OP_DIV
            tokenizer_add_to_buffer(tok, State.ID, r)
        }
    } else if r == 'd' {
        tokenizer_add_to_buffer(tok, State.D, r)
    } else if r == 't' {
        tokenizer_add_to_buffer(tok, State.T, r)
    } else if r == 'f' {
        tokenizer_add_to_buffer(tok, State.F, r)
    } else if is_id_start(r) {
        assert( len(tok.buffer) == 0 )
        tokenizer_add_to_buffer(tok, State.ID, r)
    } else if r == '"' {
        tok.s = State.STRING
    }
}

tokenizer_on_id_like :: proc(tok: ^Tokenizer, r: rune) {
    if tok.s == State.D && r == 'e' {
        tokenizer_add_to_buffer(tok, State.DE, r)
    } else if tok.s == State.DE && r == 'f' {
        tokenizer_add_to_buffer(tok, State.DEF, r)
    } else if tok.s == State.DEF && is_boundary(r) {
        tok.kind = Kind.K_DEF
        tok.s = State.CLEAN

    } else if tok.s == State.DE && r == 'c' {
        tokenizer_add_to_buffer(tok, State.DEC, r)
    } else if tok.s == State.DEC && r == 'l' {
        tokenizer_add_to_buffer(tok, State.DECL, r)
    } else if tok.s == State.DECL && is_boundary(r) {
        tok.kind = Kind.K_DECL
        tok.s = State.CLEAN

    } else if tok.s == State.T && r == 'r' {
        tokenizer_add_to_buffer(tok, State.TR, r)
    } else if tok.s == State.TR && r == 'u' {
        tokenizer_add_to_buffer(tok, State.TRU, r)
    } else if tok.s == State.TRU && r == 'e' {
        tokenizer_add_to_buffer(tok, State.TRUE, r)
    } else if tok.s == State.TRUE && is_boundary(r) {
        tok.kind = Kind.K_TRUE
        tok.s = State.CLEAN

    } else if tok.s == State.F && r == 'a' {
        tokenizer_add_to_buffer(tok, State.FA, r)
    } else if tok.s == State.FA && r == 'l' {
        tokenizer_add_to_buffer(tok, State.FAL, r)
    } else if tok.s == State.FAL && r == 's' {
        tokenizer_add_to_buffer(tok, State.FALS, r)
    } else if tok.s == State.FALS && r == 'e' {
        tokenizer_add_to_buffer(tok, State.FALSE, r)
    } else if tok.s == State.FALSE && is_boundary(r) {
        tok.kind = Kind.K_FALSE
        tok.s = State.CLEAN

    } else if is_id_start(r) || is_num(r) {
        append(&tok.buffer, r)
    } else if is_boundary(r) {
        tok.kind = Kind.ID
        tok.s = State.CLEAN
    }
}

tokenizer_on_comment :: proc(tok: ^Tokenizer, r: rune) {
    rr := r
    for {
        if rr == '\n' {
            tok.s = State.CLEAN
            return
        }
        rr, _ = read_rune(tok)
    }
}

tokenizer_on_string :: proc(tok: ^Tokenizer, r: rune) {
    rr := r
    err: io.Error
    for {
        if rr == '"' {
            tok.kind = Kind.STRING
            tok.s = State.CLEAN
            return
        } else if rr == '\\' {
            tokenizer_add_to_buffer(tok, tok.s, rr)
            rr, err = read_rune(tok)
        }
        tokenizer_add_to_buffer(tok, tok.s, rr)
        rr, _ = read_rune(tok)
    }
}

tokenizer_on_boundary :: proc(tok: ^Tokenizer, r: rune) {
    if r == '(' {
        tok.kind = Kind.OP_LPAREN
    } else if r == ')' {
        tok.kind = Kind.OP_RPAREN
    } else if r == ':' {
        tok.kind = Kind.OP_COLON
    } else if r == ',' {
        tok.kind = Kind.OP_COMMA
    } else if r == ';' {
        tok.kind = Kind.OP_SEMICOLON
    } else if r == '.' {
        tok.kind = Kind.OP_DOT
    } else if r == '=' {
        tok.kind = Kind.OP_EQ
    }
    tokenizer_add_to_buffer(tok, tok.s, r)
}


Token :: struct {
    kind: Kind,
    val: string
}

tokenizer_next_token :: proc(tok: ^Tokenizer) -> Token {
    assert( tok.s == State.CLEAN )
    for {
        r, err := read_rune(tok)
        if err != nil {
            tok.kind = Kind.EOF
            break
        }

        if tok.s == State.CLEAN { tokenizer_on_clean(tok, r) }
        else if is_id_like(tok.s) { tokenizer_on_id_like(tok, r) }
        else if tok.s == State.COMMENT { tokenizer_on_comment(tok, r) }
        else if tok.s == State.STRING { tokenizer_on_string(tok, r) }

        if is_boundary(r) && !is_white(r) {
            if tok.kind != Kind.UNDEF {
                unread_rune(tok, r)
                break
            }
            tokenizer_on_boundary(tok, r)
        }

        if tok.kind != Kind.UNDEF { break }
    }
    k := tok.kind
    tok.kind = Kind.UNDEF
    return Token{k, tokenizer_val_from_buffer(tok)}
}
