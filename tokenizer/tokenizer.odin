package tokenizer

import "core:io"
import "core:mem"
import "core:unicode/utf8"

Token_Kind :: enum {
    True, False, Def, Decl,
    Left_Paren, Right_Paren,
    Comma, Semicolon, Colon,
    Equal, Not_Equal, Less_Than, Less_Than_Or_Equal, Greater_Than, Greater_Than_Or_Equal,
    Plus, Minus, Multiply, Divide, Modulo, Power,
    Identifier, Str, Int,
    Error, End_Of_File,
}

Token :: struct {
    kind: Token_Kind,
    val: string
}

Tokenizer :: struct {
    stream: io.Stream,
    allocator: mem.Allocator,

    ahead: rune,
    has_ahead: bool,
    buffer: [dynamic]rune,
    in_error: bool
}

init :: proc(stream: io.Stream, allocator: mem.Allocator) -> Tokenizer {
    buffer := make([dynamic]rune, 0, 64, allocator)
    return Tokenizer{
        stream = stream,
        allocator = allocator,
        buffer = buffer,
        has_ahead = false,
        in_error = false,
    }
}

next_token :: proc(tok: ^Tokenizer) -> Token {
    if tok.in_error { return Token{kind = .Error, val = "PREV_ERR"} }

    for {
        r, err := read_rune(tok)
        if err != nil { return Token{kind = .End_Of_File, val = ""} }
        if is_whitespace(r) { continue }
        if r == '/' && maybe_consume_comment(tok) { continue }

        if r == '"' {
            return tok_string(tok)

        } else if is_num(r) {
            return tok_number(tok, r)

        } else if is_id_start(r) {
            return tok_id_like(tok, r)

        } else if is_boundary(r) {
            return tok_boundary(tok, r)

        } else {
            append(&tok.buffer, r)
            tok.in_error = true
            return Token{kind = .Error, val = buffer_to_str(tok)}
        }
    }
    unreachable()
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
read_rune :: proc(tok: ^Tokenizer) -> (rune, io.Error) {
    if tok.has_ahead {
        r := tok.ahead
        tok.has_ahead = false
        return r, nil
    } else {
        r, _, err := io.read_rune(tok.stream)
        return r, err
    }
}

@private
unread_rune :: proc(tok: ^Tokenizer, r: rune) {
    assert(!tok.has_ahead)
    tok.ahead = r
    tok.has_ahead = true
}

///////////////////////////////////////////////////////////////

@private
maybe_consume_comment :: proc(tok: ^Tokenizer) -> bool {
    r, err := read_rune(tok)
    if err != nil {
        return false
    }
    if r != '/' {
        unread_rune(tok, r)
        return false
    }
    for {
        if r == '\r' || r == '\n' { break }
        r, err = read_rune(tok)
        if err != nil { break }
    }
    return true
}

@private
tok_string :: proc(tok: ^Tokenizer) -> Token {
    in_backslash := false
    for {
        r, err := read_rune(tok)
        if err != nil {
            tok.in_error = true
            return Token{kind = .Error, val = buffer_to_str(tok)}
        } else if in_backslash {
            in_backslash = false
        } else if r == '\\' {
            in_backslash = true
        } else if r == '"' {
            return Token{kind = .Str, val = buffer_to_str(tok)}
        }
        append(&tok.buffer, r)
    }
}

@private
tok_number :: proc(tok: ^Tokenizer, r: rune) -> Token {
    append(&tok.buffer, r)
    for {
        rr, err := read_rune(tok)
        if err != nil {
            break

        } else if is_boundary(rr) {
            unread_rune(tok, rr)
            break
        }

        append(&tok.buffer, rr)

        if !is_num(rr) {
            tok.in_error = true
            break
        }
    }
    str := buffer_to_str(tok)
    if tok.in_error { return Token{kind = .Error, val = str} }
    return Token{kind = .Int, val = str}
}

@private
tok_id_like :: proc(tok: ^Tokenizer, r: rune) -> Token {
    append(&tok.buffer, r)
    for {
        rr, err := read_rune(tok)
        if err != nil {
            break

        } else if is_boundary(rr) {
            unread_rune(tok, rr)
            break
        }

        append(&tok.buffer, rr)

        if !is_id_main(rr) {
            tok.in_error = true
            break
        }
    }
    str := buffer_to_str(tok)
    if tok.in_error { return Token{kind = .Error, val = str} }
    switch str {
    case "def"  : return Token{kind = .Def, val = str}
    case "decl" : return Token{kind = .Decl, val = str}
    case "true" : return Token{kind = .True, val = str}
    case "false": return Token{kind = .False, val = str}
    case        : return Token{kind = .Identifier, val = str}
    }
}

@private
tok_boundary :: proc(tok: ^Tokenizer, r: rune) -> Token {
    kind: Token_Kind
    switch r {
    case '(': kind = .Left_Paren
    case ')': kind = .Right_Paren
    case ',': kind = .Comma
    case ':': kind = .Colon
    case ';': kind = .Semicolon
    case '+': kind = .Plus
    case '-': kind = .Minus
    case '*': kind = .Multiply
    case '/': kind = .Divide
    case '%': kind = .Modulo
    case '^': kind = .Power
    case '=': kind = .Equal
    case '!':
        rr, err := read_rune(tok)
        if err != nil {
            kind = .Error
        } else if rr != '=' {
            kind = .Error
            unread_rune(tok, rr)
        } else {
            return Token{kind = .Not_Equal, val = "!="}
        }
    case '<':
        rr, err := read_rune(tok)
        if err != nil {
            kind = .Less_Than
        } else if rr != '=' {
            kind = .Less_Than
            unread_rune(tok, rr)
        } else {
            return Token{kind = .Less_Than_Or_Equal, val = "<="}
        }
    case '>':
        rr, err := read_rune(tok)
        if err != nil {
            kind = .Greater_Than
        } else if rr != '=' {
            kind = .Greater_Than
            unread_rune(tok, rr)
        } else {
            return Token{kind = .Greater_Than_Or_Equal, val = ">="}
        }
    case : kind = .Error
    }
    if kind == .Error { tok.in_error = true }
    append(&tok.buffer, r)
    return Token{kind = kind, val = buffer_to_str(tok)}
}
