package tokenizer

import "core:fmt"
import "core:io"
import "core:mem"
import vmem "core:mem/virtual"
import "core:os"
import "core:strings"
import "core:unicode/utf8"

TokenKind :: enum {
    TRUE, FALSE, DEF, DECL,
    LPAREN, RPAREN,
    COMMA, SEMICOLON, COLON,
    EQ, NEQ,
    PLUS, MINUS, MULT, DIV, MOD, POW,
    ID, STRING, INT,
    ERROR, EOF,
}

Token :: struct {
    Kind: TokenKind,
    Val: string
}

tokenizerState :: enum {
    CLEAN,
    D, DE, DEF, DEC, DECL,
    T, TR, TRU, TRUE,
    F, FA, FAL, FALS, FALSE,
    ID,
}

Tokenizer :: struct {
    stream: io.Stream,
    allocator: mem.Allocator,

    s: tokenizerState,
    ahead: rune,
    buffer: [dynamic]rune,
    kind: TokenKind,
}

init :: proc(stream: io.Stream, allocator: mem.Allocator) -> Tokenizer {
    buffer := make([dynamic]rune, 0, 64, allocator)
    return Tokenizer{
        stream = stream,
        allocator = allocator,
        s = tokenizerState.CLEAN,
        buffer = buffer,
    }
}

next_token :: proc(tok: ^Tokenizer) -> Token {
    assert( tok.s == .CLEAN )
    for {
        r, err := read_rune(tok)
        if err != nil {
            tok.kind = .EOF
            break
        } else if is_whitespace(r) {
            continue
        } else if r == '/' {
            if on_slash(tok) { break }

        } else if r == '"' {
            on_double_quote(tok)
            break
        } else if is_num(r) {
            on_int(tok, r)
            break
        } else if is_id_start(r) {
            on_id_or_kw(tok, r)
            break
        } else if is_boundary(r) && !is_whitespace(r) {
            on_boundary(tok, r)
            break

        } else {
            append(&tok.buffer, r)
            tok.kind = .ERROR
            break
        }
    }
    assert( tok.s == .CLEAN )
    str, _ := utf8.runes_to_string(tok.buffer[:], tok.allocator)
    clear(&tok.buffer)
    return Token{tok.kind, str}
}

///////////////////////////////////////////////////////////////

tokenize_input :: proc(tok: ^Tokenizer) -> string {
    builder: strings.Builder
    _, err := strings.builder_init(&builder, tok.allocator)
    assert(err == nil)
    for {
        t := next_token(tok)
        if t.Kind == .EOF { break }
        strings.write_string(&builder, fmt.tprintf("%v:%v||", t.Kind, t.Val))
    }
    return strings.to_string(builder)
}

///////////////////////////////////////////////////////////////

@private
is_whitespace :: proc(r: rune) -> bool {
    return r == ' ' || r == '\t' || r == '\t' || r == '\n'
}

@private
is_boundary :: proc(r: rune) -> bool {
    return r == '(' || r == ')' || r == ':' || r == ',' || r == ';' ||
            r == '.' || r == '=' || r == '!' || r == '+' || r == '-' ||
            r == '*' || r == '/' || r == '%' || r == '^' || is_whitespace(r)
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
is_id_like :: proc(s: tokenizerState) -> bool {
    return s == .D || s == .DE || s == .DEF || s == .DEC || s == .DECL ||
        s == .T || s == .TR || s == .TRU || s == .TRUE ||
        s == .F || s == .FA || s == .FAL || s == .FALS || s == .FALSE ||
        s == .ID
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

@private
to_new_state :: proc(tok: ^Tokenizer, new_state: tokenizerState, r: rune) {
    tok.s = new_state
    append(&tok.buffer, r)
}

///////////////////////////////////////////////////////////////

@private
on_slash :: proc(tok: ^Tokenizer) -> bool {
    r, err := read_rune(tok)
    if err != nil || r != '/' {
        assert( len(tok.buffer) == 0 )
        unread_rune(tok, r)
        tok.kind = .DIV
        append(&tok.buffer, '/')
        return true
    }
    for {
        if r == '\n' { break }
        r, err = read_rune(tok)
        if err != nil { break }
    }
    return false
}

@private
on_double_quote :: proc(tok: ^Tokenizer) {
    r, err := read_rune(tok)
    if err != nil {
        tok.kind = .ERROR
        return
    }
    for {
        if r == '"' {
            tok.kind = .STRING
            tok.s = .CLEAN
            return
        } else if r == '\\' {
            append(&tok.buffer, r)
            r, err = read_rune(tok)
        }
        append(&tok.buffer, r)

        r, err = read_rune(tok)
        if err != nil {
            tok.kind = .ERROR
            return
        }
    }
}

@private
on_int :: proc(tok: ^Tokenizer, r: rune) {
    append(&tok.buffer, r)
    for {
        rr, err := read_rune(tok)
        if err != nil || is_boundary(rr) {
            tok.kind = .INT
            tok.s = .CLEAN
            unread_rune(tok, rr)
            return
        } else if is_num(rr) {
            append(&tok.buffer, rr)
            continue
        }
        tok.kind = .ERROR
        return
    }
}

@private
token_found :: proc(tok: ^Tokenizer, kind: TokenKind, r: rune) {
    tok.kind = kind
    tok.s = .CLEAN
    if is_boundary(r) { unread_rune(tok, r) }
}

@private
on_id_or_kw :: proc(tok: ^Tokenizer, r: rune) {
    rr := r
    err: io.Error
    for {
        // def, decl
        if tok.s == .CLEAN && rr == 'd' {
            to_new_state(tok, .D, rr)

        } else if tok.s == .D && rr == 'e' {
            to_new_state(tok, .DE, rr)
        } else if tok.s == .DE && rr == 'f' {
            to_new_state(tok, .DEF, rr)
        } else if tok.s == .DEF {
            if !is_id_main(rr) { token_found(tok, .DEF, rr) ; break }
            to_new_state(tok, .ID, rr)

        } else if tok.s == .DE && rr == 'c' {
            to_new_state(tok, .DEC, rr)
        } else if tok.s == .DEC && rr == 'l' {
            to_new_state(tok, .DECL, rr)
        } else if tok.s == .DECL {
            if !is_id_main(rr) { token_found(tok, .DECL, rr) ;  break }
            to_new_state(tok, .ID, rr)

        // true
        } else if tok.s == .CLEAN && rr == 't' {
            to_new_state(tok, .T, rr)
        } else if tok.s == .T && rr == 'r' {
            to_new_state(tok, .TR, rr)
        } else if tok.s == .TR && rr == 'u' {
            to_new_state(tok, .TRU, rr)
        } else if tok.s == .TRU && rr == 'e' {
            to_new_state(tok, .TRUE, rr)
        } else if tok.s == .TRUE {
            if !is_id_main(rr) { token_found(tok, .TRUE, rr) ; break }
            to_new_state(tok, .ID, rr)

        // false
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
        } else if tok.s == .FALSE {
            if !is_id_main(rr) { token_found(tok, .FALSE, rr) ; break }
            to_new_state(tok, .ID, rr)

        // <id>
        } else if tok.s == .CLEAN && is_id_start(rr) {
            assert( len(tok.buffer) == 0 )
            to_new_state(tok, .ID, rr)

        } else if is_id_like(tok.s) {
            if !is_id_main(rr) { token_found(tok, .ID, rr) ; break }
            append(&tok.buffer, rr)
        }

        rr, err = read_rune(tok)
        if err != nil {
            k: TokenKind
            #partial switch tok.s {
                case .DEF  : k = .DEF
                case .DECL : k = .DECL
                case .TRUE : k = .TRUE
                case .FALSE: k = .FALSE
                case       : k = .ID
            }
            token_found(tok, k, '\x00') ;
            break
        }
    }
}

@private
on_boundary :: proc(tok: ^Tokenizer, r: rune) {
    if r == '(' {
        tok.kind = .LPAREN
    } else if r == ')' {
        tok.kind = .RPAREN
    } else if r == ',' {
        tok.kind = .COMMA
    } else if r == ';' {
        tok.kind = .SEMICOLON
    } else if r == ':' {
        tok.kind = .COLON
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
    } else if r == '+' {
        tok.kind = .PLUS
    } else if r == '-' {
        tok.kind = .MINUS
    } else if r == '*' {
        tok.kind = .MULT
    } else if r == '%' {
        tok.kind = .MOD
    } else if r == '^' {
        tok.kind = .POW
    }
    append(&tok.buffer, r)
}

///////////////////////////////////////////////////////////////

main :: proc() {
    arena: vmem.Arena
    err := vmem.arena_init_growing(&arena)
    assert(err == nil)
    defer vmem.arena_destroy(&arena)
    allocator := vmem.arena_allocator(&arena)

    input := `false123`
    reader := strings.Reader{s = input}
    stream := strings.reader_to_stream(&reader)
    tok := init(stream, allocator)
    fmt.println(tokenize_input(&tok))
}
