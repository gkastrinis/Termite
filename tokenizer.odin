package termite

import "core:fmt"
import "core:os"
import "core:io"
import "core:unicode/utf8"

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

Ctx :: struct {
    s: State,
    curr_id: [dynamic]rune,
    tokens: [dynamic]Kind,
    values: [dynamic]string,
}

is_id_like :: proc(s: State) -> bool {
    return s == State.D || s == State.DE || s == State.DEF || s == State.DEC || s == State.DECL ||
        s == State.T || s == State.TR || s == State.TRU || s == State.TRUE ||
        s == State.F || s == State.FA || s == State.FAL || s == State.FALS || s == State.FALSE ||
        s == State.ID
}

fail :: proc(s: State, r: rune) {
    fmt.println("\x1b[31mERROR\x1b[0m ", r)
}


add_to_id :: proc(ctx: ^Ctx, new_state: State, r: rune) {
    ctx.s = new_state
    append(&ctx.curr_id, r)
}


on_clean :: proc(ctx: ^Ctx, r: rune) {
    fmt.println("on_clean: ", r)

    if is_white(r) {}
    else if r == '/' {
        ctx.s = State.COMMENT_START
    } else if r == 'd' {
        add_to_id(ctx, State.D, r)
    } else if r == 't' {
        add_to_id(ctx, State.T, r)
    } else if r == 'f' {
        add_to_id(ctx, State.F, r)
    } else if is_id_start(r) {
        clear(&ctx.curr_id)
        add_to_id(ctx, State.ID, r)

    } else if r == '"' {
        ctx.s = State.STRING
    }
}

on_id_like :: proc(ctx: ^Ctx, r: rune) {
    fmt.println("on_id_like: ", r)

    if ctx.s == State.D && r == 'e' {
        add_to_id(ctx, State.DE, r)
    } else if ctx.s == State.DE && r == 'f' {
        add_to_id(ctx, State.DEF, r)
    } else if ctx.s == State.DEF && is_boundary(r) {
        append(&ctx.tokens, Kind.K_DEF)
        clear(&ctx.curr_id)
        ctx.s = State.CLEAN

    } else if ctx.s == State.DE && r == 'c' {
        add_to_id(ctx, State.DEC, r)
    } else if ctx.s == State.DEC && r == 'l' {
        add_to_id(ctx, State.DECL, r)
    } else if ctx.s == State.DECL && is_boundary(r) {
        append(&ctx.tokens, Kind.K_DECL)
        clear(&ctx.curr_id)
        ctx.s = State.CLEAN

    } else if ctx.s == State.T && r == 'r' {
        add_to_id(ctx, State.TR, r)
    } else if ctx.s == State.TR && r == 'u' {
        add_to_id(ctx, State.TRU, r)
    } else if ctx.s == State.TRU && r == 'e' {
        add_to_id(ctx, State.TRUE, r)
    } else if ctx.s == State.TRUE && is_boundary(r) {
        append(&ctx.tokens, Kind.K_TRUE)
        clear(&ctx.curr_id)
        ctx.s = State.CLEAN

    } else if ctx.s == State.F && r == 'a' {
        add_to_id(ctx, State.FA, r)
    } else if ctx.s == State.FA && r == 'l' {
        add_to_id(ctx, State.FAL, r)
    } else if ctx.s == State.FAL && r == 's' {
        add_to_id(ctx, State.FALS, r)
    } else if ctx.s == State.FALS && r == 'e' {
        add_to_id(ctx, State.FALSE, r)
    } else if ctx.s == State.FALSE && is_boundary(r) {
        append(&ctx.tokens, Kind.K_FALSE)
        clear(&ctx.curr_id)
        ctx.s = State.CLEAN

    } else if is_id_start(r) || is_num(r) {
        append(&ctx.curr_id, r)
    } else if is_boundary(r) {
        append(&ctx.tokens, Kind.ID)
        str, _ := utf8.runes_to_string(ctx.curr_id[:])
        append(&ctx.values, str)
        clear(&ctx.curr_id)
        ctx.s = State.CLEAN
    }
}

on_comment_start :: proc(ctx: ^Ctx, r: rune) {
    fmt.println("on_comment_start: ", r)

    if r == '/' {
        ctx.s = State.COMMENT
    }
}

on_string :: proc(ctx: ^Ctx, r: rune) {
    if r == '"' {
        append(&ctx.tokens, Kind.STRING)
        str, _ := utf8.runes_to_string(ctx.curr_id[:])
        append(&ctx.values, str)
        clear(&ctx.curr_id)
        ctx.s = State.CLEAN
        return
    } else if r == '\\' {
        add_to_id(ctx, State.STRING_ESC, r)
    } else {
        add_to_id(ctx, State.STRING, r)
    }
}

on_boundary :: proc(ctx: ^Ctx, r: rune) {
    if r == '(' {
        append(&ctx.tokens, Kind.OP_LPAREN)
    } else if r == ')' {
        append(&ctx.tokens, Kind.OP_RPAREN)
    } else if r == ':' {
        append(&ctx.tokens, Kind.OP_COLON)
    } else if r == ',' {
        append(&ctx.tokens, Kind.OP_COMMA)
    } else if r == ';' {
        append(&ctx.tokens, Kind.OP_SEMICOLON)
    } else if r == '.' {
        append(&ctx.tokens, Kind.OP_DOT)
    } else if r == '=' {
        append(&ctx.tokens, Kind.OP_EQ)
    }
}


main :: proc() {
    ctx := Ctx{s = State.CLEAN}

    stdin := os.to_stream(os.stdin)
    for {
        r, _, err := io.read_rune(stdin)
        if err != nil { break }


        if ctx.s == State.CLEAN { on_clean(&ctx, r) }
        else if is_id_like(ctx.s) { on_id_like(&ctx, r) }
        else if ctx.s == State.COMMENT_START { on_comment_start(&ctx, r) }
        else if ctx.s == State.COMMENT {
            if r == '\n' { ctx.s = State.CLEAN }
            else { continue }
        }
        else if ctx.s == State.STRING { on_string(&ctx, r) }
        else if ctx.s == State.STRING_ESC { add_to_id(&ctx, State.STRING, r) }

        if is_boundary(r) { on_boundary(&ctx, r) }

    }

    val_idx := 0
    for t in ctx.tokens {
        if t == Kind.ID || t == Kind.STRING {
            fmt.print(" (\x1b[32m", t, "\x1b[0m, \x1b[34m", ctx.values[val_idx], "\x1b[0m ),")
            val_idx += 1
        } else {
            fmt.print("\x1b[32m", t, "\x1b[0m,")
        }
    }
}
