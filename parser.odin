package termite

import "core:fmt"
import "core:io"

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
    assert( t.kind == .ID )

    assert(!(t.val in parser.relations))

    rel := Relation{name=t.val, arity=0}

    t = _next(parser)
    assert( t.kind == .LPAREN )

    for {
        name := _next(parser)
        if name.kind == .RPAREN {
            break
        } else if name.kind == .COMMA && rel.arity != 0 {
            continue
        } else if name.kind != .ID {
            fmt.println(t)
            assert(false)
        }
        t = _next(parser)
        assert( t.kind == .COLON )
        t = _next(parser)
        assert( t.kind == .ID )

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
    if t.kind == .ID {
        t2 := _peek(parser)
        // atom
        if t2.kind == .LPAREN {
            _ = _next(parser)
            e := Expr{kind=.ATOM, op=t.val}

            for {
                t = _peek(parser)
                if t.kind == .RPAREN {
                    _ = _next(parser)
                    break
                } else if t.kind == .COMMA {
                    assert( len(e.args) != 0 )
                    _ = _next(parser)
                } else {
                    append(&e.args, parse_expr(parser))
                }
            }
            return e
        } else {
            return Expr{kind=.VAR, op=t.val}
        }
    } else if t.kind == .INT {
        return Expr{kind=.INT, op=t.val}
    } else if t.kind == .STRING {
        return Expr{kind=.STRING, op=t.val}
    } else if t.kind == .TRUE {
        return Expr{kind=.TRUE, op=t.val}
    } else if t.kind == .FALSE {
        return Expr{kind=.FALSE, op=t.val}
    }
    return Expr{}
}

parse_head :: proc(parser: ^Parser) {
    atoms: [dynamic]Expr
    for {
        // TODO: parse_atom
        append(&atoms, parse_expr(parser))
        t := _peek(parser)
        if t.kind != .COMMA { break }
        _ = _next(parser)
    }
    for a in atoms {
        print_expr(a)
        fmt.println()
    }
    fmt.println("->")
}

parse_body :: proc(parser: ^Parser) {
    exprs: [dynamic]Expr
    for {
        append(&exprs, parse_expr(parser))
        t := _peek(parser)
        if t.kind != .COMMA { break }
        _ = _next(parser)
    }
    for e in exprs {
        fmt.print("    ")
        print_expr(e)
        fmt.println()
    }
}

parse_def :: proc(parser: ^Parser) {
    parse_head(parser)
    assert( _next(parser).kind == .COLON )
    parse_body(parser)
    fmt.println("----------------------------")
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
        t := _next(parser)
        if t.kind == .EOF {
            fmt.printf("\x1b[33m<EOF>\x1b[0m\n")
            break
        } else if t.kind == .DECL {
            parse_decl(parser)
        } else if t.kind == .DEF {
            parse_def(parser)
        } else if t.kind == .STRING {

        } else if t.kind == .ERROR {
            fmt.printf("%v\x1b[0m \x1b[31m<%v> \x1b[0m", t.val, t.kind)
            break
        } else {
            fmt.printf("%v\x1b[0m \x1b[30m<%v> \x1b[0m", t.val, t.kind)
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
    } else if e.kind == .STRING {
        fmt.printf("\x1b[36m\"%v\"\x1b[0m", e.op)
    } else if e.kind == .TRUE || e.kind == .FALSE {
        fmt.printf("\x1b[35m%v\x1b[0m", e.op)
    } else {
        fmt.print(e.op)
    }
}
