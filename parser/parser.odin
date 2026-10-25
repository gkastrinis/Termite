package parser

import "core:fmt"
import "core:io"
import tokenizer "../tokenizer"

Token :: tokenizer.Token
TKind :: tokenizer.TokenKind

// 0 Expr       := EqExpr
// 1 EqExpr     := AddExpr (("=" | "!=") AddExpr)?
// 2 AddExpr    := MultExpr (("+" | "-") MultExpr)*
// 3 MultExpr   := UnaryExpr (("*" | "/" | "%") UnaryExpr)*
// 4 UnaryExpr  := ("+" | "-") UnaryExpr
//              | ExpExpr
// 5 ExpExpr    := Primary ("^" UnaryExpr)?
// 6 Primary    := "(" Expr ")"
//              | Literal
//              | Variable

ExprKind :: enum {
    ATOM,
    COMPOUND, INT, STRING, VAR,
}

Expr :: struct {
    kind: ExprKind,
    op: string,
    type: string,
    args: [dynamic]Expr,
    // lhs: ^Expr,
    // rhs: ^Expr,
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
    ahead: Token,

    rules: [dynamic]Rule,
    last_rule_id: u16,

    declared: map[string]Relation,
    inferred: map[string]Relation,
}

T_INT :: "Int64"
T_STR :: "Str"
T_ANY :: "Any"

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
        if t.Kind == TKind.EOF {
            fmt.printf("\x1b[33m<EOF>\x1b[0m\n")
            break
        } else if t.Kind == TKind.DECL {
            parse_decl(parser)
        } else if t.Kind == TKind.DEF {
            parse_def(parser)
        } else if t.Kind == TKind.ERROR {
            fmt.printf("%v\x1b[0m \x1b[31m<%v> \x1b[0m", t.Val, t.Kind)
            break
        } else {
            fmt.printf("%v\x1b[0m \x1b[30m<%v> \x1b[0m", t.Val, t.Kind)
        }
    }
}

///////////////////////////////////////////////////////////////

// @private
_peek :: proc(parser: ^Parser) -> Token {
    if !parser.has_ahead {
        parser.ahead = _next(parser)
        parser.has_ahead = true
    }
    return parser.ahead
}

// @private
_next :: proc(parser: ^Parser) -> Token {
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
    assert( t.Kind == TKind.LPAREN )

    for {
        name := _next(parser)
        if name.Kind == TKind.RPAREN {
            break
        } else if name.Kind == TKind.COMMA && rel.arity != 0 {
            continue
        } else if name.Kind != TKind.ID {
            fmt.println(t)
            unreachable()
        }
        t = _next(parser)
        assert( t.Kind == TKind.COLON )
        t = _next(parser)
        assert( t.Kind == TKind.ID )

        append(&rel.fields, name.Val)
        append(&rel.types, t.Val)
        rel.arity += 1
    }
    parser.declared[rel.name] = rel
    return rel
}

parse_def :: proc(parser: ^Parser) {
    rule := Rule{id=parser.last_rule_id}
    parser.last_rule_id += 1

    for {
        append(&rule.head, parse_expr(parser, 0))
        t := _peek(parser)
        if t.Kind != TKind.COMMA { break }
        _ = _next(parser)
    }
    assert( _next(parser).Kind == TKind.COLON )
    for {
        append(&rule.body, parse_expr(parser, 0))
        t := _peek(parser)
        if t.Kind != TKind.COMMA { break }
        _ = _next(parser)
    }
    append(&parser.rules, rule)
    update_relations(parser, rule)
}

@private
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
                append(&rel.types, T_ANY)
            }
            parser.inferred[e.op] = rel
        }
    }
}


///////////////////////////////////////////////////////////////

parse_expr :: proc(parser: ^Parser, min_prec: int) -> Expr {
    lhs := parse_primary(parser)
    return parse_expr_inner(parser, lhs, min_prec)
}

@private
parse_primary :: proc(parser: ^Parser) -> Expr {
    t := _next(parser)
    if t.Kind == TKind.MINUS {
        // The precedence level of the unary minus
        base := parse_expr(parser, 4)
        e := Expr{kind=.COMPOUND, op="--", type=T_ANY}
        append(&e.args, base)
        return e
    } else if t.Kind == TKind.INT {
        return Expr{kind=.INT, op=t.Val, type=T_INT}
    } else if t.Kind == TKind.STRING {
        return Expr{kind=.STRING, op=t.Val, type=T_STR}
    } else if t.Kind == TKind.ID {
        return Expr{kind=.VAR, op=t.Val, type=T_ANY}
    } else if t.Kind == TKind.LPAREN {
        e := parse_expr(parser, 0)
        assert( _peek(parser).Kind == TKind.RPAREN )
        _next(parser)
        return e
    }
    unreachable()
}

// Precedence climbing method
@private
parse_expr_inner :: proc(parser: ^Parser, lhs_: Expr, min_prec: int) -> Expr {
    lhs := lhs_
    non_assoc_found := false
    ahead := _peek(parser)
    for {
        ahead_prec := precedence(ahead)
        if !((is_non_assoc(ahead) && ahead_prec > min_prec) || ahead_prec >= min_prec ) {
            return lhs
        }
        if non_assoc_found { return lhs }
        if is_non_assoc(ahead) { non_assoc_found = true }

        op := _next(parser)
        rhs := parse_primary(parser)
        ahead = _peek(parser)
        for {
            op_prec := precedence(op)
            ahead_prec = precedence(ahead)
            if !((is_right_assoc(ahead) && ahead_prec == op_prec) || ahead_prec > op_prec) {
                break
            }
            new_prec := op_prec + (ahead_prec > op_prec ? 1 : 0)
            rhs = parse_expr_inner(parser, rhs, new_prec)
            ahead = _peek(parser)
        }
        lhs = make_bin_expr(op, lhs, rhs)
    }
    return lhs
}

@private
make_bin_expr :: proc(op: Token, lhs: Expr, rhs: Expr) -> Expr {
    e := Expr{kind=.COMPOUND, op=op.Val}
    append(&e.args, lhs)
    append(&e.args, rhs)
    return e
}

@private
is_non_assoc :: proc(t: Token) -> bool {
    return t.Kind == TKind.EQ || t.Kind == TKind.NEQ
}

@private
is_right_assoc :: proc(t: Token) -> bool {
    return t.Kind == TKind.POW
}

@private
precedence :: proc(t: Token) -> int {
    if t.Kind == TKind.EQ || t.Kind == TKind.NEQ { return 1 }
    if t.Kind == TKind.PLUS || t.Kind == TKind.MINUS { return 2 }
    if t.Kind == TKind.MULT || t.Kind == TKind.DIV || t.Kind == TKind.MOD { return 3 }
    if t.Kind == TKind.POW { return 5 }
    return -100
}
