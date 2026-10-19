package termite

import "core:fmt"
import "core:io"
import "core:os"
import "core:unicode/utf8"

@(private)
is_white :: proc(r: rune) -> bool {
    return r == ' ' || r == '\t' || r == '\t' || r == '\n'
}

@(private)
is_boundary :: proc(r: rune) -> bool {
    return r == '(' || r == ')' || r == ':' || r == ',' || r == ';' ||
            r == '.' || r == '=' || r == '!' || is_white(r)
}

@(private)
is_id_start :: proc(r: rune) -> bool {
    return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || r == '_'
}

@(private)
is_num :: proc(r: rune) -> bool {
    return r >= '0' && r <= '9'
}

@(private)
is_id_like :: proc(s: TokenizerState) -> bool {
    return s == .D || s == .DE || s == .DEF || s == .DEC || s == .DECL ||
        s == .T || s == .TR || s == .TRU || s == .TRUE ||
        s == .F || s == .FA || s == .FAL || s == .FALS || s == .FALSE ||
        s == .S_ID
}

@(private)
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

@(private)
unread_rune :: proc(tok: ^Tokenizer, r: rune) {
    if tok.ahead1 == '\x00' {
        tok.ahead1 = r
    } else if tok.ahead2 == '\x00' {
        tok.ahead2 = r
    } else {
        assert(false)
    }
}

@(private)
to_new_state :: proc(tok: ^Tokenizer, new_state: TokenizerState, r: rune) {
    tok.s = new_state
    append(&tok.buffer, r)
}

///////////////////////////////////////////////////////////////

@(private)
on_id_or_kw :: proc(tok: ^Tokenizer, r: rune) {
    rr := r
    err: io.Error
    for {
        if tok.s == .CLEAN && rr == 'd' {
            to_new_state(tok, .D, rr)

        } else if tok.s == .D && rr == 'e' {
            to_new_state(tok, .DE, rr)
        } else if tok.s == .DE && rr == 'f' {
            to_new_state(tok, .DEF, rr)
        } else if tok.s == .DEF && is_boundary(rr) {
            tok.kind = .DEF
            break

        } else if tok.s == .DE && rr == 'c' {
            to_new_state(tok, .DEC, rr)
        } else if tok.s == .DEC && rr == 'l' {
            to_new_state(tok, .DECL, rr)
        } else if tok.s == .DECL && is_boundary(rr) {
            tok.kind = .DECL
            break

        } else if tok.s == .CLEAN && rr == 't' {
            to_new_state(tok, .T, rr)
        } else if tok.s == .T && rr == 'r' {
            to_new_state(tok, .TR, rr)
        } else if tok.s == .TR && rr == 'u' {
            to_new_state(tok, .TRU, rr)
        } else if tok.s == .TRU && rr == 'e' {
            to_new_state(tok, .TRUE, rr)
        } else if tok.s == .TRUE && is_boundary(rr) {
            tok.kind = .TRUE
            break

        } else if tok.s == .CLEAN && rr == 'f' {
            to_new_state(tok, .F, rr)
        } else if tok.s == .F && rr == 'a' {
            to_new_state(tok, .FA, rr)
        } else if tok.s == .FA && rr == 'l' {
            to_new_state(tok, .FAL, rr)
        } else if tok.s == .FAL && rr == 's' {
            to_new_state(tok, .FALS, rr)
        } else if tok.s == .FALS && rr == 'e' {
            to_new_state(tok, .FALSE, rr)
        } else if tok.s == .FALSE && is_boundary(rr) {
            tok.kind = .FALSE
            break

        } else if tok.s == .CLEAN && is_id_start(rr) {
            assert( len(tok.buffer) == 0 )
            to_new_state(tok, .S_ID, rr)
        } else if is_id_like(tok.s) {
            if (is_id_start(rr) || is_num(rr)) {
                append(&tok.buffer, rr)
            } else if is_boundary(rr) {
                tok.kind = .ID
                break
            } else {
                tok.kind = .ERROR
                return
            }
        }

        rr, err = read_rune(tok)
        if err != nil {
            tok.kind = .ERROR
            return
        }
    }
    tok.s = .CLEAN
    if is_boundary(rr) { unread_rune(tok, rr) }
    return
}

@(private)
on_int :: proc(tok: ^Tokenizer, r: rune) {
    append(&tok.buffer, r)
    for {
        rr, err := read_rune(tok)
        if err != nil {
            tok.kind = .ERROR
            return
        } else if is_num(rr) {
            append(&tok.buffer, r)
            continue
        } else if is_boundary(rr) {
            tok.kind = .INT
            tok.s = .CLEAN
            unread_rune(tok, rr)
            return
        }
        tok.kind = .ERROR
        return
    }
}

@(private)
on_slash :: proc(tok: ^Tokenizer) {
    rr, err := read_rune(tok)
    if err != nil {
        tok.kind = .ERROR
        return
    } else if rr != '/' {
        assert( len(tok.buffer) == 0 )
        unread_rune(tok, rr)
        tok.kind = .DIV
        append(&tok.buffer, '/')
        return
    }

    for {
        if rr == '\n' {
            return
        }
        rr, err = read_rune(tok)
        if err != nil {
            tok.kind = .ERROR
            return
        }
    }
}

@(private)
on_double_quote :: proc(tok: ^Tokenizer) {
    rr, err := read_rune(tok)
    if err != nil {
        tok.kind = .ERROR
        return
    }

    for {
        if rr == '"' {
            tok.kind = .STRING
            tok.s = .CLEAN
            return
        } else if rr == '\\' {
            append(&tok.buffer, rr)
            rr, err = read_rune(tok)
        }
        append(&tok.buffer, rr)

        rr, err = read_rune(tok)
        if err != nil {
            tok.kind = .ERROR
            return
        }
    }
}

@(private)
on_boundary :: proc(tok: ^Tokenizer, r: rune) {
    if r == '(' {
        tok.kind = .LPAREN
    } else if r == ')' {
        tok.kind = .RPAREN
    } else if r == ':' {
        tok.kind = .COLON
    } else if r == ',' {
        tok.kind = .COMMA
    } else if r == ';' {
        tok.kind = .SEMICOLON
    } else if r == '=' {
        tok.kind = .EQ
    } else if r == '!' {
        r2, _ := read_rune(tok)
        if r2 == '=' {
            tok.kind = .NEQ
            append(&tok.buffer, r)
            append(&tok.buffer, r2)
        } else {
            unread_rune(tok, r2)
            tok.kind = .ERROR
        }
    }
    append(&tok.buffer, r)
}

///////////////////////////////////////////////////////////////

tokenizer_init :: proc(stream: io.Stream) -> Tokenizer {
    return Tokenizer{stream=os.to_stream(os.stdin), s=TokenizerState.CLEAN}
}

tokenizer_next_token :: proc(tok: ^Tokenizer) -> Token {
    assert( tok.s == .CLEAN )
    for {
        r, err := read_rune(tok)
        if err != nil {
            tok.kind = .EOF
            break
        }

        if is_white(r) {
            continue
        } else if r == '/' {
            on_slash(tok)
            if tok.kind == .DIV { break }
        } else if r == '"' {
            on_double_quote(tok)
            break
        } else if is_id_start(r) {
            on_id_or_kw(tok, r)
            break
        } else if is_num(r) {
            on_int(tok, r)
            break
        } else if is_boundary(r) && !is_white(r) {
            on_boundary(tok, r)
            break
        } else {
            append(&tok.buffer, r)
            tok.kind = .ERROR
            break
        }
    }
    assert( tok.s == .CLEAN )
    k := tok.kind
    str, _ := utf8.runes_to_string(tok.buffer[:])
    clear(&tok.buffer)
    return Token{k, str}
}
