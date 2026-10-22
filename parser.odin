package termite

import "core:fmt"
import "core:io"

ExprKind :: enum {
    ATOM, VAR, STRING, INT,
}

Expr :: struct {
    kind: ExprKind,
    op: string,
    type: string,
    args: [dynamic]Expr,
}

Relation :: struct {
    name: string,
    arity: u8,
    fields: [dynamic]string,
    types: [dynamic]string,
}

Rule :: struct {
    id: u16,
    head: [dynamic]Expr,
    body: [dynamic]Expr
}

Parser :: struct {
    tokenizer: Tokenizer,
    has_ahead: bool,
    ahead: Token,

    rules: [dynamic]Rule,
    last_rule_id: u16,

    declared: map[string]Relation,
    inferred: map[string]Relation,
}

parser_init :: proc(stream: io.Stream) -> Parser {
    return Parser{
        tokenizer= tokenizer_init(stream),
        has_ahead= false,
        declared= make(map[string]Relation),
        inferred= make(map[string]Relation),
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
        } else if t.kind == .ERROR {
            fmt.printf("%v\x1b[0m \x1b[31m<%v> \x1b[0m", t.val, t.kind)
            break
        } else {
            fmt.printf("%v\x1b[0m \x1b[30m<%v> \x1b[0m", t.val, t.kind)
        }
    }
}

///////////////////////////////////////////////////////////////

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

    assert(!(t.val in parser.declared))

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
            unreachable()
        }
        t = _next(parser)
        assert( t.kind == .COLON )
        t = _next(parser)
        assert( t.kind == .ID )

        append(&rel.fields, name.val)
        append(&rel.types, t.val)
        rel.arity += 1
    }
    parser.declared[rel.name] = rel
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
        return Expr{kind=.INT, op=t.val, type="Int64"}
    } else if t.kind == .STRING {
        return Expr{kind=.STRING, op=t.val, type="Str"}
    } else if t.kind == .TRUE || t.kind == .FALSE {
        return Expr{kind=.ATOM, op=t.val}
    }
    return Expr{}
}

parse_def :: proc(parser: ^Parser) {
    rule := Rule{id=parser.last_rule_id}
    parser.last_rule_id += 1

    for {
        append(&rule.head, parse_expr(parser))
        t := _peek(parser)
        if t.kind != .COMMA { break }
        _ = _next(parser)
    }
    assert( _next(parser).kind == .COLON )
    for {
        append(&rule.body, parse_expr(parser))
        t := _peek(parser)
        if t.kind != .COMMA { break }
        _ = _next(parser)
    }
    append(&parser.rules, rule)
    update_relations(parser, rule)
}

update_relations :: proc(parser: ^Parser, rule: Rule) {
    for e in rule.head {
        assert( e.kind == .ATOM )
        if e.op in parser.declared {
            rel := parser.declared[e.op]
            assert( rel.arity == u8(len(e.args)) )
        } else if e.op in parser.inferred {
            rel := parser.inferred[e.op]
            assert( rel.arity == u8(len(e.args)) )
        } else {
            rel := Relation{name=e.op, arity=u8(len(e.args))}
            for i in 0..<rel.arity {
                append(&rel.fields, "?")
                append(&rel.types, "Any")
            }
            parser.inferred[e.op] = rel
        }
    }
}
