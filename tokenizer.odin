package termite

import "core:fmt"
import "core:bufio"
import "core:unicode/utf8"

Kind :: enum {
    K_TRUE,
    K_FALSE,
    K_DEF,
    K_DECL,

    OP_LPAREN,
    OP_RPAREN,
    OP_COLON,
    OP_COMMA,
    OP_SEMICOLON,
    OP_DOT,
    OP_EQ,

    ID,
    STRING,

    UNDEF,
    ERROR,
    EOF,
}

State :: enum {
    CLEAN,

    COMMENT_START,
    COMMENT,
    STRING,
    STRING_ESC,

    D, DE, DEF, DEC, DECL,
    T, TR, TRU, TRUE,
    F, FA, FAL, FALS, FALSE,
    ID,

    ERROR,
}

Tokenizer :: struct {
    reader: bufio.Reader,
    s: State,

    kind: Kind,
    buffer: [dynamic]rune,
}

Token :: struct {
    kind: Kind,
    val: string
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

// fail :: proc(s: State, r: rune) {
//     fmt.println("\x1b[31mERROR\x1b[0m ", r)
// }


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
    // fmt.println("tokenizer_on_clean: ", r)

    if is_white(r) {}
    else if r == '/' {
        tok.s = State.COMMENT_START
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
    // fmt.println("tokenizer_on_id_like: ", r)

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

tokenizer_on_comment_start :: proc(tok: ^Tokenizer, r: rune) {
    // fmt.println("tokenizer_on_comment_start: ", r)

    if r == '/' {
        tok.s = State.COMMENT
    }
}

tokenizer_on_string :: proc(tok: ^Tokenizer, r: rune) {
    if r == '"' {
        tok.kind = Kind.STRING
        tok.s = State.CLEAN
    } else if r == '\\' {
        tokenizer_add_to_buffer(tok, State.STRING_ESC, r)
    } else {
        tokenizer_add_to_buffer(tok, State.STRING, r)
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

tokenizer_next_token :: proc(tok: ^Tokenizer) -> Token {
    assert( tok.s == State.CLEAN )
    for {
        bytes, err := bufio.reader_peek(&tok.reader, 1)
        if err != nil {
            tok.kind = Kind.EOF
            break
        }
        r, _, _ := bufio.reader_read_rune(&tok.reader)
        // fmt.println(tok.s, tok.kind, "!!!", tok.buffer, r)

        if tok.s == State.CLEAN { tokenizer_on_clean(tok, r) }
        else if is_id_like(tok.s) { tokenizer_on_id_like(tok, r) }
        else if tok.s == State.COMMENT_START { tokenizer_on_comment_start(tok, r) }
        else if tok.s == State.COMMENT {
            if r == '\n' { tok.s = State.CLEAN }
            else { continue }
        }
        else if tok.s == State.STRING { tokenizer_on_string(tok, r) }
        else if tok.s == State.STRING_ESC { tokenizer_add_to_buffer(tok, State.STRING, r) }

        if is_boundary(r) && !is_white(r) {
            if tok.kind != Kind.UNDEF {
                bufio.reader_unread_rune(&tok.reader)
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
