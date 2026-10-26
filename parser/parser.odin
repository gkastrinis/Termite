package parser

import "core:fmt"
import "core:io"
import "core:mem"
import vmem "core:mem/virtual"
import "core:strings"

import tokenizer "../tokenizer"

Token :: tokenizer.Token
TK :: tokenizer.TokenKind

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
    BINARY, UNARY, INT, STRING, VAR,
}

Expr :: struct {
    kind: ExprKind,
    op: string,
    lhs: ^Expr,
    rhs: ^Expr,

    type: string,
}

T_INT :: "Int64"
T_STR :: "Str"
T_ANY :: "Any"

Parser :: struct {
    allocator: mem.Allocator,

    tok: tokenizer.Tokenizer,
    has_ahead: bool,
    ahead: Token,

    // declared: map[string]Relation,
    // inferred: map[string]Relation,
    // rules: [dynamic]Rule,
    // last_rule_id: u16,
}

init :: proc(stream: io.Stream, allocator: mem.Allocator) -> Parser {
    return Parser {
        allocator = allocator,
        tok = tokenizer.init(stream, allocator),
        has_ahead = false,
    }
    //     // declared = make(map[string]Relation),
    //     // inferred = make(map[string]Relation),
}

// parse :: proc(parser: ^Parser) {
//     for {
//         t := _next(parser)
//         if t.Kind == TK.EOF {
//             fmt.printf("\x1b[33m<EOF>\x1b[0m\n")
//             break
//         } else if t.Kind == TK.DECL {
//             parse_decl(parser)
//         } else if t.Kind == TK.DEF {
//             parse_def(parser)
//         } else if t.Kind == TK.ERROR {
//             fmt.printf("%v\x1b[0m \x1b[31m<%v> \x1b[0m", t.Val, t.Kind)
//             break
//         } else {
//             fmt.printf("%v\x1b[0m \x1b[30m<%v> \x1b[0m", t.Val, t.Kind)
//         }
//     }
// }

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

// parse_decl :: proc(parser: ^Parser) -> Relation {
//     t := _next(parser)
//     assert( t.Kind == .ID )
//
//     assert(!(t.Val in parser.declared))
//
//     rel := Relation{name = t.Val, arity = 0}
//
//     t = _next(parser)
//     assert( t.Kind == TK.LPAREN )
//
//     for {
//         name := _next(parser)
//         if name.Kind == TK.RPAREN {
//             break
//         } else if name.Kind == TK.COMMA && rel.arity != 0 {
//             continue
//         } else if name.Kind != TK.ID {
//             fmt.println(t)
//             unreachable()
//         }
//         t = _next(parser)
//         assert( t.Kind == TK.COLON )
//         t = _next(parser)
//         assert( t.Kind == TK.ID )
//
//         append(&rel.fields, name.Val)
//         append(&rel.types, t.Val)
//         rel.arity += 1
//     }
//     parser.declared[rel.name] = rel
//     return rel
// }
//
// parse_def :: proc(parser: ^Parser) {
//     rule := Rule{id = parser.last_rule_id}
//     parser.last_rule_id += 1
//
//     for {
//         append(&rule.head, parse_expr(parser, 0))
//         t := _peek(parser)
//         if t.Kind != TK.COMMA { break }
//         _ = _next(parser)
//     }
//     assert( _next(parser).Kind == TK.COLON )
//     for {
//         append(&rule.body, parse_expr(parser, 0))
//         t := _peek(parser)
//         if t.Kind != TK.COMMA { break }
//         _ = _next(parser)
//     }
//     append(&parser.rules, rule)
//     update_relations(parser, rule)
// }
//
// @private
// update_relations :: proc(parser: ^Parser, rule: Rule) {
//     for e in rule.head {
//         assert( e.kind == .ATOM )
//         if e.op in parser.declared {
//             rel := parser.declared[e.op]
//             assert( rel.arity == u8(len(e.args)) )
//         } else if e.op in parser.inferred {
//             rel := parser.inferred[e.op]
//             assert( rel.arity == u8(len(e.args)) )
//         } else {
//             rel := Relation{name = e.op, arity = u8(len(e.args))}
//             for i in 0..<rel.arity {
//                 append(&rel.fields, "?")
//                 append(&rel.types, T_ANY)
//             }
//             parser.inferred[e.op] = rel
//         }
//     }
// }

///////////////////////////////////////////////////////////////

@private
alloc_expr :: proc(parser: ^Parser, value: Expr) -> ^Expr {
    ptr := new(Expr, parser.allocator)
    ptr^ = value
    return ptr
}

// @private
parse_expr :: proc(parser: ^Parser, min_prec: int) -> ^Expr {
    lhs := parse_primary(parser)
    return parse_expr_inner(parser, lhs, min_prec)
}

@private
parse_primary :: proc(parser: ^Parser) -> ^Expr {
    t := _next(parser)
    if t.Kind == TK.MINUS {
        // The precedence level of the unary minus
        base := parse_expr(parser, 4)
        return alloc_expr(parser, Expr{kind = .UNARY, op = "--", lhs = base})
    } else if t.Kind == TK.INT {
        return alloc_expr(parser, Expr{kind = .INT, op = t.Val})
    } else if t.Kind == TK.STRING {
        return alloc_expr(parser, Expr{kind = .STRING, op = t.Val})
    } else if t.Kind == TK.ID {
        return alloc_expr(parser, Expr{kind = .VAR, op = t.Val})
    } else if t.Kind == TK.LPAREN {
        e := parse_expr(parser, 0)
        assert( _peek(parser).Kind == TK.RPAREN )
        _next(parser)
        return e
    }
    unreachable()
}

// Precedence climbing method
@private
parse_expr_inner :: proc(parser: ^Parser, lhs_: ^Expr, min_prec: int) -> ^Expr {
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
        lhs = alloc_expr(parser, Expr{kind = .BINARY, op = op.Val, lhs = lhs, rhs = rhs})
    }
    return lhs
}

@private
is_non_assoc :: proc(t: Token) -> bool {
    return t.Kind == TK.EQ || t.Kind == TK.NEQ
}

@private
is_right_assoc :: proc(t: Token) -> bool {
    return t.Kind == TK.POW
}

@private
precedence :: proc(t: Token) -> int {
    if t.Kind == TK.EQ || t.Kind == TK.NEQ { return 1 }
    if t.Kind == TK.PLUS || t.Kind == TK.MINUS { return 2 }
    if t.Kind == TK.MULT || t.Kind == TK.DIV || t.Kind == TK.MOD { return 3 }
    if t.Kind == TK.POW { return 5 }
    return -100
}

///////////////////////////////////////////////////////////////

main :: proc() {
    arena: vmem.Arena
    err := vmem.arena_init_growing(&arena)
    assert(err == nil)
    defer vmem.arena_destroy(&arena)
    allocator := vmem.arena_allocator(&arena)

    input := "a + b"
    reader := strings.Reader{s = input}
    stream := strings.reader_to_stream(&reader)

    parser_ := init(stream, allocator)
    e := parse_expr(&parser_, 0)
    fmt.println(to_S_expression(e))
}
