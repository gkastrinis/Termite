package parser

import "core:fmt"
import "core:io"
import tokenizer "../tokenizer"

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
    tok: tokenizer.Tokenizer,
    has_ahead: bool,
    ahead: tokenizer.Token,

    rules: [dynamic]Rule,
    last_rule_id: u16,

    declared: map[string]Relation,
    inferred: map[string]Relation,
}

init :: proc(stream: io.Stream) -> Parser {
    return Parser{
        tok= tokenizer.init(stream),
        has_ahead= false,
        declared= make(map[string]Relation),
        inferred= make(map[string]Relation),
    }
}

destroy :: proc(parser: ^Parser) {
    delete(parser.inferred)
    delete(parser.declared)
    delete(parser.rules)
    tokenizer.destroy(&parser.tok)
}

parse :: proc(parser: ^Parser) {
    for {
        t := _next(parser)
        if t.Kind == tokenizer.TokenKind.EOF {
            fmt.printf("\x1b[33m<EOF>\x1b[0m\n")
            break
        } else if t.Kind == tokenizer.TokenKind.DECL {
            parse_decl(parser)
        } else if t.Kind == tokenizer.TokenKind.DEF {
            parse_def(parser)
        } else if t.Kind == tokenizer.TokenKind.ERROR {
            fmt.printf("%v\x1b[0m \x1b[31m<%v> \x1b[0m", t.Val, t.Kind)
            break
        } else {
            fmt.printf("%v\x1b[0m \x1b[30m<%v> \x1b[0m", t.Val, t.Kind)
        }
    }
}

///////////////////////////////////////////////////////////////

@(private)
_peek :: proc(parser: ^Parser) -> tokenizer.Token {
    if !parser.has_ahead {
        parser.ahead = _next(parser)
        parser.has_ahead = true
    }
    return parser.ahead
}

@(private)
_next :: proc(parser: ^Parser) -> tokenizer.Token {
    if parser.has_ahead {
        parser.has_ahead = false
        return parser.ahead
    }
    return tokenizer.next_token(&parser.tok)
}

parse_decl :: proc(parser: ^Parser) -> Relation {
    t := _next(parser)
    assert( t.Kind == .ID )

    assert(!(t.Val in parser.declared))

    rel := Relation{name=t.Val, arity=0}

    t = _next(parser)
    assert( t.Kind == tokenizer.TokenKind.LPAREN )

    for {
        name := _next(parser)
        if name.Kind == tokenizer.TokenKind.RPAREN {
            break
        } else if name.Kind == tokenizer.TokenKind.COMMA && rel.arity != 0 {
            continue
        } else if name.Kind != tokenizer.TokenKind.ID {
            fmt.println(t)
            unreachable()
        }
        t = _next(parser)
        assert( t.Kind == tokenizer.TokenKind.COLON )
        t = _next(parser)
        assert( t.Kind == tokenizer.TokenKind.ID )

        append(&rel.fields, name.Val)
        append(&rel.types, t.Val)
        rel.arity += 1
    }
    parser.declared[rel.name] = rel
    return rel
}

parse_expr :: proc(parser: ^Parser) -> Expr {
    t := _next(parser)
    if t.Kind == tokenizer.TokenKind.ID {
        t2 := _peek(parser)
        // atom
        if t2.Kind == tokenizer.TokenKind.LPAREN {
            _ = _next(parser)
            e := Expr{kind=.ATOM, op=t.Val}

            for {
                t = _peek(parser)
                if t.Kind == tokenizer.TokenKind.RPAREN {
                    _ = _next(parser)
                    break
                } else if t.Kind == tokenizer.TokenKind.COMMA {
                    assert( len(e.args) != 0 )
                    _ = _next(parser)
                } else {
                    append(&e.args, parse_expr(parser))
                }
            }
            return e
        } else {
            return Expr{kind=.VAR, op=t.Val}
        }
    } else if t.Kind == tokenizer.TokenKind.INT {
        return Expr{kind=.INT, op=t.Val, type="Int64"}
    } else if t.Kind == tokenizer.TokenKind.STRING {
        return Expr{kind=.STRING, op=t.Val, type="Str"}
    } else if t.Kind == tokenizer.TokenKind.TRUE || t.Kind == tokenizer.TokenKind.FALSE {
        return Expr{kind=.ATOM, op=t.Val}
    }
    return Expr{}
}

parse_def :: proc(parser: ^Parser) {
    rule := Rule{id=parser.last_rule_id}
    parser.last_rule_id += 1

    for {
        append(&rule.head, parse_expr(parser))
        t := _peek(parser)
        if t.Kind != tokenizer.TokenKind.COMMA { break }
        _ = _next(parser)
    }
    assert( _next(parser).Kind == tokenizer.TokenKind.COLON )
    for {
        append(&rule.body, parse_expr(parser))
        t := _peek(parser)
        if t.Kind != tokenizer.TokenKind.COMMA { break }
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
