package termite

import "core:fmt"
import "core:io"

ExprKind :: enum {
    ATOM, VAR, STRING, INT,
    AND,
}

Expr :: struct {
    kind: ExprKind,
    op: string,
    args: [dynamic]Expr,
}

Relation :: struct {
    name: string,
    arity: u8,
    fields: [dynamic]string,
    types: [dynamic]string,
}

Parser :: struct {
    tokenizer: Tokenizer,
    has_ahead: bool,
    ahead: Token,

    relations: map[string]Relation,
}


@(private)
_peek :: proc(parser: ^Parser) -> Token {
    if !parser.has_ahead {
        parser.ahead = _next(parser)
        parser.has_ahead = true
    }
    return parser.ahead
}

@(private)
_next :: proc(parser: ^Parser) -> Token {
    if parser.has_ahead {
        parser.has_ahead = false
        return parser.ahead
    }
    return tokenizer_next_token(&parser.tokenizer)
}




parse_decl :: proc(parser: ^Parser) -> Relation {
    t := _next(parser)
    assert( t.kind == .T_ID )

    assert(!(t.val in parser.relations))

    rel := Relation{name=t.val, arity=0}

    t = _next(parser)
    assert( t.kind == .OP_LPAREN )

    for {
        name := _next(parser)
        if name.kind == .OP_RPAREN {
            break
        } else if name.kind == .OP_COMMA && rel.arity != 0 {
            continue
        } else if name.kind != .T_ID {
            fmt.println(t)
            assert(false)
        }
        t = _next(parser)
        assert( t.kind == .OP_COLON )
        t = _next(parser)
        assert( t.kind == .T_ID )

        append(&rel.fields, name.val)
        append(&rel.types, t.val)
        rel.arity += 1
    }
    parser.relations[rel.name] = rel
    print_relation(rel)
    return rel
}



parse_expr :: proc(parser: ^Parser) -> Expr {
    t := _next(parser)
    if t.kind == .T_ID {
        t2 := _peek(parser)
        // atom
        if t2.kind == .OP_LPAREN {
            _ = _next(parser)
            e := Expr{kind=.ATOM, op=t.val}

            t = _peek(parser)
            for {
                if t.kind == .OP_RPAREN {
                    _ = _next(parser)
                    break
                } else if t.kind == .OP_COMMA {
                    assert( len(e.args) != 0 )
                    _ = _next(parser)
                } else {
                    append(&e.args, parse_expr(parser))
                }
                t = _peek(parser)
            }
            return e
        } else {
            return Expr{kind=.VAR, op=t.val}
        }
    } else if t.kind == .T_INT {

    } else if t.kind == .T_STRING {

    } else if t.kind == .OP_COMMA {

    }
    return Expr{}
}

parse_def :: proc(parser: ^Parser) {
    head := parse_expr(parser)
    print_expr(head)
    // name := _next(parser)
    // assert( name.kind == .T_ID )
    // a := parse_atom(parser, name)
    // print_expr(a)
    // fmt.println("")
    // for {
    //     t := _next(parser)
    //     if t.kind == .OP_COMMA {
    //         t = _next(parser)
    //         a = parse_atom(parser, t)
    //         print_expr(a)
    //         fmt.println("")
    //     } else if t.kind == .OP_COLON { break }
    // }
}

parse_atom :: proc(parser: ^Parser, name: Token) -> Expr {
    t := _next(parser)
    assert( t.kind == .OP_LPAREN )
    t = _next(parser)

    atom := Expr{kind=.ATOM, op=name.val}
    for {
        if t.kind == .OP_RPAREN { break }
        else if t.kind == .OP_COMMA && len(atom.args) != 0 {
            t = _next(parser)
            continue
        }
        assert( t.kind == .T_ID )
        append(&atom.args, Expr{kind=.VAR, op=t.val})
        t = _next(parser)
    }
    return atom
}



///////////////////////////////////////////////////////////////

parser_init :: proc(stream: io.Stream) -> Parser {
    return Parser{
        tokenizer= tokenizer_init(stream),
        has_ahead= false,
        relations= make(map[string]Relation),
    }
}

parse :: proc(parser: ^Parser) {
    for {
        t := tokenizer_next_token(&parser.tokenizer)
        if t.kind == .EOF {
            fmt.printf("\x1b[33m<EOF>\x1b[0m\n")
            break

        } else if t.kind == .K_DECL {
            parse_decl(parser)
        } else if t.kind == .K_DEF {
            parse_def(parser)

        } else if t.kind == .T_STRING {
            // fmt.printf("\"%v\"\x1b[0m \x1b[30m<%v> \x1b[0m", t.val, t.kind)
        } else {
            // fmt.printf("%v\x1b[0m \x1b[30m<%v> \x1b[0m", t.val, t.kind)
        }
    }
}

print_relation :: proc(rel: Relation) {
    fmt.printf("\x1b[34m%v/\x1b[30m%v\x1b[0m ", rel.name, rel.arity)
    for i in 0..<len(rel.fields) {
        if i != 0 { fmt.printf("\x1b[30m x \x1b[0m") }
        fld, type := rel.fields[i], rel.types[i]
        fmt.printf("(\x1b[33m%v\x1b[0m \x1b[30m<%v>\x1b[0m)", fld, type)
    }
    fmt.println()
}

print_expr :: proc(e: Expr) {
    if e.kind == .ATOM {
        fmt.printf("\x1b[32m%v\x1b[0m(", e.op)
        for i in 0..<len(e.args) {
            if i != 0 { fmt.print(", ") }
            print_expr(e.args[i])
        }
        fmt.print(")")
    } else if e.kind == .VAR {
        fmt.print(e.op)
    }
}
