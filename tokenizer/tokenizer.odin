package tokenizer

import "core:io"
import "core:fmt"
import "core:mem"
import "core:unicode/utf8"

import terminal "../terminal"

clr :: terminal

Token_Kind :: enum {
    Error, End_Of_File,
    True, False, Def, Decl,
    Left_Paren, Right_Paren,
    Comma, Semicolon, Colon,
    Equal, Not_Equal, Less_Than, Less_Than_Or_Equal, Greater_Than, Greater_Than_Or_Equal,
    Plus, Minus, Multiply, Divide, Modulo, Power,
    Identifier, Str, Int,
}

Token :: struct {
    kind: Token_Kind,
    val: string,
    range: Range,
}

Range :: struct {
    start_row: u32,
    start_col: u32,
    stop_row: u32,
    stop_col: u32,
}

Tokenizer :: struct {
    stream: io.Stream,
    allocator: mem.Allocator,

    ahead: rune,
    ahead_error: io.Error,
    has_ahead: bool,

    snap_row: u32,
    snap_col: u32,
    curr_row: u32,
    curr_col: u32,

    buffer: [dynamic]rune,
    in_error: bool,
}

init :: proc(stream: io.Stream, allocator: mem.Allocator) -> Tokenizer {
    return Tokenizer{
        stream = stream,
        allocator = allocator,
        buffer = make([dynamic]rune, 0, 64, allocator),
        has_ahead = false,
        ahead_error = nil,
        curr_row = 1,
        curr_col = 1,
        in_error = false,
    }
}

next_token :: proc(tok: ^Tokenizer) -> Token {
    snap_pos(tok)
    if tok.in_error { return register_token(tok, .Error, "PREV_ERR") }

    for {
        r, err := peek_rune(tok)
        if err != nil { return register_token(tok, .End_Of_File, "") }
        if is_whitespace(r) {
            next_rune(tok)
            snap_pos(tok)
            continue
        }
        if r == '/' {
            if tok_divide(tok) { return register_token(tok, .Divide, "/") }
            snap_pos(tok)
            continue
        }

        if r == '"' {
            next_rune(tok)
            return tok_string(tok)

        } else if is_num(r) {
            return tok_number(tok)

        } else if is_id_start(r) {
            return tok_id_like(tok)

        } else if is_boundary(r) {
            return tok_boundary(tok)

        } else {
            next_rune(tok)
            append(&tok.buffer, r)
            tok.in_error = true
            return register_token(tok, .Error, buffer_to_str(tok))
        }
    }
    unreachable()
}

print_token :: proc(t: Token) {
    fmt.printf(
        "%v%v %v<%v>%v %v:%v-%v:%v%v",
        clr.TOKEN_KIND,
        t.kind,
        clr.TOKEN_VALUE,
        t.val,
        clr.RESET,
        clr.LOCATION,
        t.range.start_row, t.range.start_col, t.range.stop_row, t.range.stop_col,
        clr.RESET,
    )
}

///////////////////////////////////////////////////////////////

@private
buffer_to_str ::proc(tok: ^Tokenizer) -> string {
    str, _ := utf8.runes_to_string(tok.buffer[:], tok.allocator)
    clear(&tok.buffer)
    return str
}

@private
is_whitespace :: proc(r: rune) -> bool {
    return r == ' ' || r == '\t' || r == '\r' || r == '\n'
}

@private
is_boundary :: proc(r: rune) -> bool {
    switch r {
    case '(', ')', ':', ',', ';', '=', '!', '<', '>', '+', '-', '*', '/', '%', '^', '\x00':
        return true
    case:
        return is_whitespace(r)
    }
}

@private
is_id_start :: proc(r: rune) -> bool {
    return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || r == '_'
}

@private
is_num :: proc(r: rune) -> bool {
    return r >= '0' && r <= '9'
}

@private
is_id_main :: proc(r: rune) -> bool {
    return is_id_start(r) || is_num(r)
}

@private
snap_pos :: proc(tok: ^Tokenizer) {
    tok.snap_row, tok.snap_col = tok.curr_row, tok.curr_col
}

@private
peek_rune :: proc(tok: ^Tokenizer) -> (rune, io.Error) {
    if !tok.has_ahead {
        tok.ahead, _, tok.ahead_error = io.read_rune(tok.stream)
        tok.has_ahead = true
    }
    return tok.ahead, tok.ahead_error
}

@private
next_rune :: proc(tok: ^Tokenizer) -> (rune, io.Error) {
    r: rune
    err: io.Error
    if tok.has_ahead {
        r, err = tok.ahead, tok.ahead_error
        tok.has_ahead = false
    } else {
        r, _, err = io.read_rune(tok.stream)
    }

    if r == '\n' {
        tok.curr_row += 1
        tok.curr_col = 1
    } else {
        tok.curr_col += 1
    }
    return r, err
}

@private
register_token :: proc(tok: ^Tokenizer, kind: Token_Kind, val: string) -> Token {
    return Token{
        kind = kind,
        val = val,
        range = Range{
            start_row = tok.snap_row,
            start_col = tok.snap_col,
            stop_row = tok.curr_row,
            stop_col = tok.curr_col,
        }
    }
}

///////////////////////////////////////////////////////////////

@private
tok_divide :: proc(tok: ^Tokenizer) -> bool {
    next_rune(tok)

    r, err := peek_rune(tok)
    if err != nil || r != '/' { return true }
    next_rune(tok)
    for {
        r, err = next_rune(tok)
        if err != nil || r == '\r' || r == '\n' { break }
    }
    return false
}

@private
tok_string :: proc(tok: ^Tokenizer) -> Token {
    in_backslash := false
    for {
        r, err := peek_rune(tok)
        if err != nil {
            tok.in_error = true
            return register_token(tok, .Error, buffer_to_str(tok))
        } else if in_backslash {
            in_backslash = false
        } else if r == '\\' {
            in_backslash = true
        } else if r == '"' {
            next_rune(tok)
            return register_token(tok, .Str, buffer_to_str(tok))
        }
        next_rune(tok)
        append(&tok.buffer, r)
    }
}

@private
tok_number :: proc(tok: ^Tokenizer) -> Token {
    for {
        r, err := peek_rune(tok)
        if err != nil || is_boundary(r) { break }
        next_rune(tok)
        append(&tok.buffer, r)

        if !is_num(r) {
            tok.in_error = true
            break
        }
    }
    str := buffer_to_str(tok)
    if tok.in_error { return register_token(tok, .Error, str) }
    return register_token(tok, .Int, str)
}

@private
tok_id_like :: proc(tok: ^Tokenizer) -> Token {
    for {
        r, err := peek_rune(tok)
        if err != nil || is_boundary(r) { break }
        next_rune(tok)
        append(&tok.buffer, r)

        if !is_id_main(r) {
            tok.in_error = true
            break
        }
    }
    str := buffer_to_str(tok)
    if tok.in_error { return register_token(tok, .Error, str) }
    switch str {
    case "def"  : return register_token(tok, .Def, str)
    case "decl" : return register_token(tok, .Decl, str)
    case "true" : return register_token(tok, .True, str)
    case "false": return register_token(tok, .False, str)
    case        : return register_token(tok, .Identifier, str)
    }
}

@private
tok_boundary :: proc(tok: ^Tokenizer) -> Token {
    r, _ := next_rune(tok)
    switch r {
    case '(': return register_token(tok, .Left_Paren, "(")
    case ')': return register_token(tok, .Right_Paren, ")")
    case ',': return register_token(tok, .Comma, ",")
    case ':': return register_token(tok, .Colon, ":")
    case ';': return register_token(tok, .Semicolon, ";")
    case '+': return register_token(tok, .Plus, "+")
    case '-': return register_token(tok, .Minus, "-")
    case '*': return register_token(tok, .Multiply, "*")
    case '/': return register_token(tok, .Divide, "/")
    case '%': return register_token(tok, .Modulo, "%")
    case '^': return register_token(tok, .Power, "^")
    case '=': return register_token(tok, .Equal, "=")
    case '!':
        rr, err := next_rune(tok)
        if err != nil {
            append(&tok.buffer, r)
        } else if rr != '=' {
            append(&tok.buffer, r)
            append(&tok.buffer, rr)
        } else {
            return register_token(tok, .Not_Equal, "!=")
        }
    case '<':
        rr, err := peek_rune(tok)
        if err == nil && rr == '=' {
            next_rune(tok)
            return register_token(tok, .Less_Than_Or_Equal, "<=")
        }
        return register_token(tok, .Less_Than, "<")
    case '>':
        rr, err := peek_rune(tok)
        if err == nil && rr == '=' {
            next_rune(tok)
            return register_token(tok, .Greater_Than_Or_Equal, ">=")
        }
        return register_token(tok, .Greater_Than, ">")
    case:
        append(&tok.buffer, r)
    }

    tok.in_error = true
    return register_token(tok, .Error, buffer_to_str(tok))
}
