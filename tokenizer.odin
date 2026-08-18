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

is_letter :: proc(r: rune) -> bool {
    return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z')
}

Kind :: enum {
    K_DEF,

    OP_LPAREN,
    OP_RPAREN,
    OP_COLON,
    OP_COMMA,
    OP_DOT,
    OP_EQ,

    ID,
}

State :: enum {
    CLEAN,

    COMMENT_START,
    COMMENT,

    D, DE, DEF,
    ID,

    ERROR,
}

is_idlike :: proc(s: State) -> bool {
    return s == State.D || s == State.DE || s == State.DEF || s == State.ID
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
            if s == State.D {
                if r == 'e' {
                    s = State.DE
                    append(&curr_id, 'e')
                }
            } else if s == State.DE {
                if r == 'f' {
                    s = State.DEF
                    append(&curr_id, 'f')
                }
            }
        }

        if is_sep(r) {
            if s == State.DEF {
                append(&tokens, Kind.K_DEF)
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
            if r == '/' {
                s = State.COMMENT_START
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
                append(&curr_id, 'd')
            } else if is_letter(r) {
                s = State.ID
                append(&curr_id, r)
            }
        } else if s == State.ID {
            append(&curr_id, r)
        }
    }

    val_idx := 0
    for t in tokens {
        fmt.print("\x1b[32m", t, "\x1b[0m,")
        if t == Kind.ID {
            fmt.print("\x1b[31m", values[val_idx], "\x1b[0m,")
            val_idx += 1
        }
    }
}
