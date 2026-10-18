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
    INT,

    ERROR,
    EOF,
}

State :: enum {
    CLEAN,

    D, DE, DEF, DEC, DECL,
    T, TR, TRU, TRUE,
    F, FA, FAL, FALS, FALSE,
    ID,

    ERROR,
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

tokenizer_to_new_state :: proc(tok: ^Tokenizer, new_state: State, r: rune) {
    tok.s = new_state
    append(&tok.buffer, r)
}

tokenizer_on_id_or_kw :: proc(tok: ^Tokenizer, r: rune) {
    rr := r
    for {
        if tok.s == State.CLEAN && rr == 'd' {
            tokenizer_to_new_state(tok, State.D, rr)

        } else if tok.s == State.D && rr == 'e' {
            tokenizer_to_new_state(tok, State.DE, rr)
        } else if tok.s == State.DE && rr == 'f' {
            tokenizer_to_new_state(tok, State.DEF, rr)
        } else if tok.s == State.DEF && is_boundary(rr) {
            tok.kind = Kind.K_DEF
            break

        } else if tok.s == State.DE && rr == 'c' {
            tokenizer_to_new_state(tok, State.DEC, rr)
        } else if tok.s == State.DEC && rr == 'l' {
            tokenizer_to_new_state(tok, State.DECL, rr)
        } else if tok.s == State.DECL && is_boundary(rr) {
            tok.kind = Kind.K_DECL
            break

        } else if tok.s == State.CLEAN && rr == 't' {
            tokenizer_to_new_state(tok, State.T, rr)
        } else if tok.s == State.T && rr == 'r' {
            tokenizer_to_new_state(tok, State.TR, rr)
        } else if tok.s == State.TR && rr == 'u' {
            tokenizer_to_new_state(tok, State.TRU, rr)
        } else if tok.s == State.TRU && rr == 'e' {
            tokenizer_to_new_state(tok, State.TRUE, rr)
        } else if tok.s == State.TRUE && is_boundary(rr) {
            tok.kind = Kind.K_TRUE
            break

        } else if tok.s == State.CLEAN && rr == 'f' {
            tokenizer_to_new_state(tok, State.F, rr)
        } else if tok.s == State.F && rr == 'a' {
            tokenizer_to_new_state(tok, State.FA, rr)
        } else if tok.s == State.FA && rr == 'l' {
            tokenizer_to_new_state(tok, State.FAL, rr)
        } else if tok.s == State.FAL && rr == 's' {
            tokenizer_to_new_state(tok, State.FALS, rr)
        } else if tok.s == State.FALS && rr == 'e' {
            tokenizer_to_new_state(tok, State.FALSE, rr)
        } else if tok.s == State.FALSE && is_boundary(rr) {
            tok.kind = Kind.K_FALSE
            break

        } else if tok.s == State.CLEAN && is_id_start(rr) {
            assert( len(tok.buffer) == 0 )
            tokenizer_to_new_state(tok, State.ID, rr)
        } else if is_id_like(tok.s) {
            if (is_id_start(rr) || is_num(rr)) {
                append(&tok.buffer, rr)
            } else if is_boundary(rr) {
                tok.kind = Kind.ID
                break
            }
        }

        rr, _ = read_rune(tok)
    }
    tok.s = State.CLEAN
    if is_boundary(rr) { unread_rune(tok, rr) }
    return
}

tokenizer_on_int :: proc(tok: ^Tokenizer, r: rune) {
    append(&tok.buffer, r)
    for {
        rr, err := read_rune(tok)
        if err != nil {
            tok.kind = Kind.ERROR
            return
        } else if is_num(rr) {
            append(&tok.buffer, r)
            continue
        } else if is_boundary(rr) {
            tok.kind = Kind.INT
            tok.s = State.CLEAN
            unread_rune(tok, rr)
            return
        }
        tok.kind = Kind.ERROR
        return
    }
}

tokenizer_on_slash :: proc(tok: ^Tokenizer) {
    rr, err := read_rune(tok)
    if err != nil {
        tok.kind = Kind.ERROR
        return
    } else if rr != '/' {
        assert( len(tok.buffer) == 0 )
        unread_rune(tok, rr)
        tok.kind = Kind.OP_DIV
        append(&tok.buffer, '/')
        return
    }

    for {
        if rr == '\n' {
            return
        }
        rr, err = read_rune(tok)
        if err != nil {
            tok.kind = Kind.ERROR
            return
        }
    }
}

tokenizer_on_double_quote :: proc(tok: ^Tokenizer) {
    rr, err := read_rune(tok)
    if err != nil {
        tok.kind = Kind.ERROR
        return
    }

    for {
        if rr == '"' {
            tok.kind = Kind.STRING
            tok.s = State.CLEAN
            return
        } else if rr == '\\' {
            append(&tok.buffer, rr)
            rr, err = read_rune(tok)
        }
        append(&tok.buffer, rr)

        rr, err = read_rune(tok)
        if err != nil {
            tok.kind = Kind.ERROR
            return
        }
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
    append(&tok.buffer, r)
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

        if is_white(r) {
            continue
        } else if r == '/' {
            tokenizer_on_slash(tok)
            if tok.kind == Kind.OP_DIV { break }
        } else if r == '"' {
            tokenizer_on_double_quote(tok)
            break
        } else if is_id_start(r) {
            tokenizer_on_id_or_kw(tok, r)
            break
        } else if is_num(r) {
            tokenizer_on_int(tok, r)
            break
        } else if is_boundary(r) && !is_white(r) {
            tokenizer_on_boundary(tok, r)
            break
        }
    }
    assert( tok.s == State.CLEAN )
    k := tok.kind
    str, _ := utf8.runes_to_string(tok.buffer[:])
    clear(&tok.buffer)
    return Token{k, str}
}
