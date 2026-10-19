package termite

import "core:fmt"

Field :: struct {
    name: string,
    type: string
}

Relation :: struct {
    name: string,
    arity: u8,
    fields: [dynamic]Field,
}

Parser :: struct {
    tokenizer: ^Tokenizer,
    relations: map[string]Relation
}

// ExprKind :: enum {
//     VAR, STRING, INT
// }
//
// Expr :: struct {
//
// }
//
Atom :: struct {
    op: string,
    args: [dynamic]string
}


next_tok :: proc(parser: ^Parser) -> Token {
    return tokenizer_next_token(parser.tokenizer)
}

print_rel :: proc(rel: Relation) {
    fmt.printf("\x1b[34m%v/\x1b[30m%v\x1b[0m ", rel.name, rel.arity)
    is_first := true
    for fld in rel.fields {
        if !is_first { fmt.printf(" x ") }
        fmt.printf("(\x1b[33m%v\x1b[0m \x1b[30m<%v>\x1b[0m)", fld.type, fld.name)
        is_first = false
    }
    fmt.println()
}


parser__decl :: proc(parser: ^Parser) {
    t := next_tok(parser)
    assert( t.kind == Kind.ID )

    assert(!(t.val in parser.relations))

    rel := Relation{name=t.val, arity=0}

    t = next_tok(parser)
    assert( t.kind == Kind.OP_LPAREN )

    for {
        fld := Field{}

        t = next_tok(parser)
        if t.kind == Kind.OP_RPAREN {
            break
        } else if t.kind == Kind.ID {
            fld.name = t.val
        } else if t.kind == Kind.OP_COMMA && rel.arity != 0 {
            continue
        } else {
            fmt.println(t)
            assert(false)
        }
        t = next_tok(parser)
        assert( t.kind == Kind.OP_COLON )
        t = next_tok(parser)
        assert( t.kind == Kind.ID )
        fld.type = t.val

        append(&rel.fields, fld)
        rel.arity += 1
    }
    parser.relations[rel.name] = rel
    print_rel(rel)
}



parser__def :: proc(parser: ^Parser) {
    name := next_tok(parser)
    assert( name.kind == Kind.ID )
    parse__atom(parser, name)
}

parse__atom :: proc(parser: ^Parser, name: Token) {
    t := next_tok(parser)
    assert( t.kind == Kind.OP_LPAREN )

    argc: u8 = 0
    for {
        if t.kind == Kind.OP_RPAREN { break }
        t = next_tok(parser)
        assert( t.kind == Kind.ID )
    }
}
