package tokenizer

import "core:io"
import "core:mem"
import "core:unicode/utf8"

TokenKind :: enum {
    TRUE, FALSE, DEF, DECL,
    LPAREN, RPAREN,
    COMMA, SEMICOLON, COLON,
    EQ, NEQ, LT, LTEQ, GT, GTEQ,
    PLUS, MINUS, MULT, DIV, MOD, POW,
    ID, STRING, INT,
    ERROR, EOF,
}

Token :: struct {
    Kind: TokenKind,
    Val: string
}

Tokenizer :: struct {
    stream: io.Stream,
    allocator: mem.Allocator,

    ahead: rune,
    buffer: [dynamic]rune,
    in_error: bool
}

init :: proc(stream: io.Stream, allocator: mem.Allocator) -> Tokenizer {
    buffer := make([dynamic]rune, 0, 64, allocator)
    return Tokenizer{
        stream = stream,
        allocator = allocator,
        buffer = buffer,
        in_error = false,
    }
}

next_token :: proc(tok: ^Tokenizer) -> Token {
    if tok.in_error { return Token{.ERROR, "PREV_ERR"} }

    for {
        r, err := read_rune(tok)
        if err != nil { return Token{.EOF, ""} }
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
            return Token{.ERROR, buffer_to_str(tok)}
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
    return r == '(' || r == ')' || r == ':' || r == ',' || r == ';' ||
            r == '=' || r == '!' || r == '<' || r == '>' ||
            r == '+' || r == '-' || r == '*' || r == '/' || r == '%' || r == '^' ||
            is_whitespace(r) || r == '\x00'
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
    if tok.ahead != '\x00' {
        r := tok.ahead
        tok.ahead = '\x00'
        return r, nil
    } else {
        r, _, err := io.read_rune(tok.stream)
        return r, err
    }
}

@private
unread_rune :: proc(tok: ^Tokenizer, r: rune) {
    assert( tok.ahead == '\x00' )
    tok.ahead = r
}

///////////////////////////////////////////////////////////////

@private
maybe_consume_comment :: proc(tok: ^Tokenizer) -> bool {
    r, err := read_rune(tok)
    if err != nil || r != '/' {
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
            return Token{.ERROR, buffer_to_str(tok)}
        } else if in_backslash {
            in_backslash = false
        } else if r == '\\' {
            in_backslash = true
        } else if r == '"' {
            return Token{.STRING, buffer_to_str(tok)}
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
    if tok.in_error { return Token{.ERROR, str} }
    return Token{.INT, str}
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
    if tok.in_error { return Token{.ERROR, str} }
    switch str {
    case "def"  : return Token{.DEF, str}
    case "decl" : return Token{.DECL, str}
    case "true" : return Token{.TRUE, str}
    case "false": return Token{.FALSE, str}
    case        : return Token{.ID, str}
    }
}

@private
tok_boundary :: proc(tok: ^Tokenizer, r: rune) -> Token {
    kind: TokenKind
    switch r {
    case '(': kind = .LPAREN
    case ')': kind = .RPAREN
    case ',': kind = .COMMA
    case ':': kind = .COLON
    case ';': kind = .SEMICOLON
    case '+': kind = .PLUS
    case '-': kind = .MINUS
    case '*': kind = .MULT
    case '/': kind = .DIV
    case '%': kind = .MOD
    case '^': kind = .POW
    case '=': kind = .EQ
    case '!':
        rr, err := read_rune(tok)
        if err != nil {
            kind = .ERROR
        } else if rr != '=' {
            kind = .ERROR
            unread_rune(tok, rr)
        } else {
            return Token{.NEQ, "!="}
        }
    case '<':
        rr, err := read_rune(tok)
        if err != nil {
            kind = .LT
        } else if rr != '=' {
            kind = .LT
            unread_rune(tok, rr)
        } else {
            return Token{.LTEQ, "<="}
        }
    case '>':
        rr, err := read_rune(tok)
        if err != nil {
            kind = .GT
        } else if rr != '=' {
            kind = .GT
            unread_rune(tok, rr)
        } else {
            return Token{.GTEQ, ">="}
        }
    case : kind = .ERROR
    }
    if kind == .ERROR { tok.in_error = true }
    append(&tok.buffer, r)
    return Token{kind, buffer_to_str(tok)}
}
