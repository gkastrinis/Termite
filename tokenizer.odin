package termite

import "core:fmt"
import "core:os"
import "core:io"

is_white :: proc(r: rune) -> bool {
    return r == ' ' || r == '\t' || r == '\t' || r == '\n'
}

is_sep :: proc(r: rune) -> bool {
    return r == '(' || r == ')' || r == ':' || r == ',' || r == '.' || r == '=' || is_white(r)
}

is_letter :: proc(r: rune) -> bool {
    return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z')
}

Token :: enum {
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
    curr_id : [dynamic]rune

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


        fmt.println(r, " -- ", s)

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
                fmt.println("\x1b[32mK_DEF\x1b[0m")
                clear(&curr_id)
                s = State.CLEAN
            } else if is_idlike(s) {
                fmt.println("\x1b[32mID\x1b[0m")
                fmt.println("\x1b[32m", curr_id, "\x1b[0m")
                clear(&curr_id)
                s = State.CLEAN
            }
        }

        if s == State.CLEAN {
            if r == '/' {
                s = State.COMMENT_START
                continue
            } else if r == '(' {
                fmt.println("\x1b[32mOP_LPAREN\x1b[0m")
            } else if r == ')' {
                fmt.println("\x1b[32mOP_RPAREN\x1b[0m")
            } else if r == ':' {
                fmt.println("\x1b[32mOP_COLON\x1b[0m")
            } else if r == ',' {
                fmt.println("\x1b[32mOP_COMMA\x1b[0m")
            } else if r == '.' {
                fmt.println("\x1b[32mOP_DOT\x1b[0m")
            } else if r == '=' {
                fmt.println("\x1b[32mOP_EQ\x1b[0m")
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
}
