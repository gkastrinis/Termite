package termite

import "core:fmt"
import "core:os"
import "core:io"
import "core:unicode/utf8"

is_white :: proc(r: rune) -> bool {
    return r == ' ' || r == '\t' || r == '\t' || r == '\n'
}

is_sep :: proc(r: rune) -> bool {
    return r == '(' || r == ')' || r == ':' || r == ',' || r == '.' || r == '=' || is_white(r)
}

is_id_start :: proc(r: rune) -> bool {
    return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || r == '_'
}

is_num :: proc(r: rune) -> bool {
    return r >= '0' && r <= '9'
}

Kind :: enum {
    K_TRUE,
    K_FALSE,
    K_DEF,

    OP_LPAREN,
    OP_RPAREN,
    OP_COLON,
    OP_COMMA,
    OP_DOT,
    OP_EQ,

    ID,
    STRING,
}

State :: enum {
    CLEAN,

    COMMENT_START,
    COMMENT,
    STRING,
    STRING_ESC,

    D, DE, DEF,
    T, TR, TRU, TRUE,
    F, FA, FAL, FALS, FALSE,

    ID,

    ERROR,
}

is_idlike :: proc(s: State) -> bool {
    return s == State.D || s == State.DE || s == State.DEF ||
        s == State.T || s == State.TR || s == State.TRU || s == State.TRUE ||
        s == State.F || s == State.FA || s == State.FAL || s == State.FALS || s == State.FALSE ||
        s == State.ID
}

main :: proc() {
    s := State.CLEAN
    curr_id: [dynamic]rune
    tokens: [dynamic]Kind
    values: [dynamic]string

    stdin := os.to_stream(os.stdin)
    for {
        r, _, err := io.read_rune(stdin)
        if err != nil { break }

        // Skip comments
        if s == State.COMMENT_START && r == '/' {
            s = State.COMMENT
            continue
        } else if s == State.COMMENT {
            if r == '\n' { s = State.CLEAN }
            continue
        }


        // fmt.println(r, " -- ", s)

        if is_idlike(s) {
            if s == State.D && r == 'e' {
                s = State.DE
                append(&curr_id, r)
            } else if s == State.DE && r == 'f' {
                s = State.DEF
                append(&curr_id, r)
            } else if s == State.T && r == 'r' {
                s = State.TR
                append(&curr_id, r)
            } else if s == State.TR && r == 'u' {
                s = State.TRU
                append(&curr_id, r)
            } else if s == State.TRU && r == 'e' {
                s = State.TRUE
                append(&curr_id, r)
            } else if s == State.F && r == 'a' {
                s = State.FA
                append(&curr_id, r)
            } else if s == State.FA && r == 'l' {
                s = State.FAL
                append(&curr_id, r)
            } else if s == State.FAL && r == 's' {
                s = State.FALS
                append(&curr_id, r)
            } else if s == State.FALS && r == 'e' {
                s = State.FALSE
                append(&curr_id, r)
            }
        } else if s == State.STRING {
            if r == '"' {
                append(&tokens, Kind.STRING)
                str, _ := utf8.runes_to_string(curr_id[:])
                append(&values, str)
                clear(&curr_id)
                s = State.CLEAN
                continue
            } else if r == '\\' {
                s = State.STRING_ESC
            }
            append(&curr_id, r)
            continue
        } else if s == State.STRING_ESC {
            s = State.STRING
            append(&curr_id, r)
            continue
        }

        if is_sep(r) {
            if s == State.DEF {
                append(&tokens, Kind.K_DEF)
                clear(&curr_id)
                s = State.CLEAN
            } else if s == State.TRUE {
                append(&tokens, Kind.K_TRUE)
                clear(&curr_id)
                s = State.CLEAN
            } else if s == State.FALSE {
                append(&tokens, Kind.K_FALSE)
                clear(&curr_id)
                s = State.CLEAN
            } else if is_idlike(s) {
                append(&tokens, Kind.ID)
                str, _ := utf8.runes_to_string(curr_id[:])
                append(&values, str)
                clear(&curr_id)
                s = State.CLEAN
            }
        }


        if s == State.CLEAN {
            if is_white(r) {
                continue
            } else if r == '/' {
                s = State.COMMENT_START
                continue
            } else if r == '"' {
                s = State.STRING
                continue
            } else if r == '(' {
                append(&tokens, Kind.OP_LPAREN)
            } else if r == ')' {
                append(&tokens, Kind.OP_RPAREN)
            } else if r == ':' {
                append(&tokens, Kind.OP_COLON)
            } else if r == ',' {
                append(&tokens, Kind.OP_COMMA)
            } else if r == '.' {
                append(&tokens, Kind.OP_DOT)
            } else if r == '=' {
                append(&tokens, Kind.OP_EQ)
            } else if r == 'd' {
                s = State.D
                append(&curr_id, r)
            } else if r == 't' {
                s = State.T
                append(&curr_id, r)
            } else if r == 'f' {
                s = State.F
                append(&curr_id, r)
            } else if is_id_start(r) {
                s = State.ID
                append(&curr_id, r)
            } else {
                fmt.println("\x1b[31mERROR1\x1b[0m", r)
                break
            }
        } else if s == State.ID {
            if is_id_start(r) || is_num(r) {
                append(&curr_id, r)
            } else {
                fmt.println("\x1b[31mERROR2\x1b[0m")
                break
            }
        }
    }


    val_idx := 0
    for t in tokens {
        fmt.print("\x1b[32m", t, "\x1b[0m,")
        if t == Kind.ID || t == Kind.STRING {
            fmt.print("\x1b[34m", values[val_idx], "\x1b[0m,")
            val_idx += 1
        }
    }
}
