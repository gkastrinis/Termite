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
    ahead_error: io.Error,
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
        ahead_error = nil,
        has_ahead = false,
        in_error = false,
    }
}

next_token :: proc(tok: ^Tokenizer) -> Token {
    if tok.in_error { return Token{kind = .Error, val = "PREV_ERR"} }

    for {
        r, err := peek_rune(tok)
        if err != nil { return Token{kind = .End_Of_File, val = ""} }
        if is_whitespace(r) {
            next_rune(tok)
            continue
        }
        if r == '/' {
            if tok_divide(tok) { return Token{kind = .Divide, val = "/"} }
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
peek_rune :: proc(tok: ^Tokenizer) -> (rune, io.Error) {
    if !tok.has_ahead {
        r, _, err := io.read_rune(tok.stream)
        tok.ahead = r
        tok.ahead_error = err
        tok.has_ahead = true
    }
    return tok.ahead, tok.ahead_error
}

@private
next_rune :: proc(tok: ^Tokenizer) -> (rune, io.Error) {
    if tok.has_ahead {
        r := tok.ahead
        err := tok.ahead_error
        tok.ahead_error = nil
        tok.has_ahead = false
        return r, err
    }
    r, _, err := io.read_rune(tok.stream)
    return r, err
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
            return Token{kind = .Error, val = buffer_to_str(tok)}
        } else if in_backslash {
            in_backslash = false
        } else if r == '\\' {
            in_backslash = true
        } else if r == '"' {
            next_rune(tok)
            return Token{kind = .Str, val = buffer_to_str(tok)}
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
    if tok.in_error { return Token{kind = .Error, val = str} }
    return Token{kind = .Int, val = str}
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
tok_boundary :: proc(tok: ^Tokenizer) -> Token {
    r, _ := next_rune(tok)
    switch r {
    case '(': return Token{kind = .Left_Paren, val = "("}
    case ')': return Token{kind = .Right_Paren, val = ")"}
    case ',': return Token{kind = .Comma, val = ","}
    case ':': return Token{kind = .Colon, val = ":"}
    case ';': return Token{kind = .Semicolon, val = ";"}
    case '+': return Token{kind = .Plus, val = "+"}
    case '-': return Token{kind = .Minus, val = "-"}
    case '*': return Token{kind = .Multiply, val = "*"}
    case '/': return Token{kind = .Divide, val = "/"}
    case '%': return Token{kind = .Modulo, val = "%"}
    case '^': return Token{kind = .Power, val = "^"}
    case '=': return Token{kind = .Equal, val = "="}
    case '!':
        rr, err := next_rune(tok)
        if err != nil {
            append(&tok.buffer, r)
        } else if rr != '=' {
            append(&tok.buffer, r)
            append(&tok.buffer, rr)
        } else {
            return Token{kind = .Not_Equal, val = "!="}
        }
    case '<':
        rr, err := peek_rune(tok)
        if err == nil && rr == '=' {
            next_rune(tok)
            return Token{kind = .Less_Than_Or_Equal, val = "<="}
        }
        return Token{kind = .Less_Than, val = "<"}
    case '>':
        rr, err := peek_rune(tok)
        if err == nil && rr == '=' {
            next_rune(tok)
            return Token{kind = .Greater_Than_Or_Equal, val = ">="}
        }
        return Token{kind = .Greater_Than, val = ">"}
    case:
        append(&tok.buffer, r)
    }

    tok.in_error = true
    return Token{kind = .Error, val = buffer_to_str(tok)}
}
