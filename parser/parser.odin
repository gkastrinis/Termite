package parser

import "core:fmt"
import "core:io"
import "core:mem"
import vmem "core:mem/virtual"
import "core:strings"

import tokenizer "../tokenizer"

Token :: tokenizer.Token
TK :: tokenizer.TokenKind

ExprKind :: enum {
    // Logical Expressions
    OR, AND,
    ATOM, COMPARISON,
    // Arithmetic Expressions
    BINARY, UNARY, INT, STR, VAR,
}

Expr :: struct {
    Kind: ExprKind,
    Op: string,
    Args: [dynamic]Expr,
}

// Relation :: struct {
//     name: string,
//     arity: u8,
//     fields: [dynamic]string,
//     types: [dynamic]string,
// }

Rule :: struct {
    id: u16,
    head: [dynamic]Expr,
    body: Expr,
}

Parser :: struct {
    allocator: mem.Allocator,

    tok: tokenizer.Tokenizer,
    has_ahead: bool,
    ahead: Token,

    // declared: map[string]Relation,
    // inferred: map[string]Relation,
    rules: [dynamic]Rule,
    last_rule_id: u16,
}

init :: proc(stream: io.Stream, allocator: mem.Allocator) -> Parser {
    return Parser {
        allocator = allocator,
        tok = tokenizer.init(stream, allocator),
        has_ahead = false,
        // declared = make(map[string]Relation),
        // inferred = make(map[string]Relation),
        rules = make([dynamic]Rule, 0, 32, allocator)
    }
}

parse :: proc(parser: ^Parser) {
    for {
        t := _next(parser)
        if t.Kind == TK.EOF {
            break
        } else if t.Kind == TK.DECL {
            panic("not yet")
            // parse_decl(parser)
        } else if t.Kind == TK.DEF {
            parse_rule(parser)
        } else if t.Kind == TK.ERROR {
            fmt.printf("%v\x1b[0m \x1b[31m<%v> \x1b[0m", t.Val, t.Kind)
            break
        } else {
            fmt.printf("%v\x1b[0m \x1b[30m<%v> \x1b[0m", t.Val, t.Kind)
            panic("waaat")
        }
    }
}

parse_expr :: proc(parser: ^Parser, min_prec: int = 0, opt: Operand_Mode = .ANY_OPERAND) -> Expr {
    lhs := parse_operand(parser, opt)
    return prec_climbing_parse(parser, lhs, min_prec, opt)
}

///////////////////////////////////////////////////////////////

ParenColor :: enum {
    WHITE, GREEN, MAGENTA, GREY, YELLOW, CYAN
}

COLORS := [6]string{"0", "92", "95", "30", "93", "96"}

print_expr :: proc(e: Expr, color: ParenColor = .WHITE) {
    switch e.Kind {
    case .INT:
        fmt.printf("\x1b[32m%v\x1b[0m", e.Op)
    case .STR:
        fmt.printf("\x1b[32m\"%v\"\x1b[0m", e.Op)
    case .VAR:
        fmt.printf("\x1b[33m%v\x1b[0m", e.Op)
    case .BINARY, .COMPARISON, .OR, .AND:
        fmt.printf("\x1b[%sm(\x1b[0m", COLORS[color])
        for arg, i in e.Args {
            if i > 0 { fmt.printf(" %v ", e.Op) }
            print_expr(arg, ParenColor((int(color) + 1) % 6))
        }
        fmt.printf("\x1b[%sm)\x1b[0m", COLORS[color])
    case .UNARY:
        assert( len(e.Args) == 1 )
        fmt.print("-")
        print_expr(e.Args[0], color)
    case .ATOM:
        fmt.printf("\x1b[34m%v\x1b[0m(", e.Op)
        for arg, i in e.Args {
            if i > 0 { fmt.printf(", ") }
            print_expr(arg, ParenColor((int(color) + 1) % 6))
        }
        fmt.print(")")
    }
}

print_program :: proc(parser: ^Parser) {
    for rule in parser.rules {
        fmt.printf("\x1b[40m#%v\x1b[0m\n", rule.id)
        for atom, i in rule.head {
            if i > 0 { fmt.print(", ") }
            print_expr(atom)
        }
        fmt.println(" <-")
        print_expr(rule.body)
    }
}

///////////////////////////////////////////////////////////////

@private
_peek :: proc(parser: ^Parser) -> Token {
    if !parser.has_ahead {
        parser.ahead = _next(parser)
        parser.has_ahead = true
    }
    return parser.ahead
}

@private
_next :: proc(parser: ^Parser) -> Token {
    if parser.has_ahead {
        parser.has_ahead = false
        return parser.ahead
    }
    return tokenizer.next_token(&parser.tok)
}

@private
make_expr :: proc(
    parser: ^Parser, kind: ExprKind, op: string, a: ^Expr = nil, b: ^Expr = nil
) -> Expr {
    e := Expr{Kind = kind, Op = op}
    e.Args = make([dynamic]Expr, 0, 8, parser.allocator)
    if a != nil { append(&e.Args, a^) }
    if b != nil { append(&e.Args, b^) }
    return e
}

@private
to_expr_kind :: proc(t: Token) -> ExprKind {
    #partial switch t.Kind {
    case TK.EQ, TK.NEQ, TK.LT, TK.LTEQ, TK.GT, TK.GTEQ:
        return .COMPARISON
    case TK.SEMICOLON:
        return .OR
    case TK.COMMA:
        return .AND
    case TK.PLUS, TK.MINUS, TK.MULT, TK.DIV, TK.MOD, TK.POW:
        return .BINARY
    case:
        panic("Unexpected token kind")
    }
}

@private
is_non_assoc :: proc(t: Token) -> bool {
    #partial switch t.Kind {
    case TK.EQ, TK.NEQ, TK.LT, TK.LTEQ, TK.GT, TK.GTEQ:
        return true
    case:
        return false
    }
}

@private
is_right_assoc :: proc(t: Token) -> bool {
    return t.Kind == TK.POW
}

ARITHMETIC_PREC :: 4
UNARY_PREC :: 6

@private
precedence :: proc(t: Token) -> int {
    #partial switch t.Kind {
    case TK.SEMICOLON:
        return 1
    case TK.COMMA:
        return 2
    case TK.EQ, TK.NEQ, TK.LT, TK.LTEQ, TK.GT, TK.GTEQ:
        return 3
    case TK.PLUS, TK.MINUS:
        return 4
    case TK.MULT, TK.DIV, TK.MOD:
        return 5
    // Unary minus is at 6
    case TK.POW:
        return 7
    case:
        return -42
    }
}

///////////////////////////////////////////////////////////////

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

@private
parse_rule :: proc(parser: ^Parser) {
    parser.last_rule_id += 1
    rule := Rule{id = parser.last_rule_id}
    rule.head = make([dynamic]Expr, 0, 1, parser.allocator)

    for {
        atom := parse_operand(parser, .ATOM_ONLY)
        assert( atom.Kind == .ATOM )
        append(&rule.head, atom)
        t := _peek(parser)
        if t.Kind != TK.COMMA { break }
        _next(parser)
    }
    assert( _next(parser).Kind == TK.COLON )
    rule.body = parse_expr(parser)

    append(&parser.rules, rule)
}

// @private
// update_relations :: proc(parser: ^Parser, rule: Rule) {
//     for e in rule.head {
//         assert( e.Kind == .ATOM )
//         if e.Op in parser.declared {
//             rel := parser.declared[e.Op]
//             assert( rel.arity == u8(len(e.Args)) )
//         } else if e.Op in parser.inferred {
//             rel := parser.inferred[e.Op]
//             assert( rel.arity == u8(len(e.Args)) )
//         } else {
//             rel := Relation{name = e.Op, arity = u8(len(e.Args))}
//             for i in 0..<rel.arity {
//                 append(&rel.fields, "?")
//                 append(&rel.types, T_ANY)
//             }
//             parser.inferred[e.Op] = rel
//         }
//     }
// }

@private
Operand_Mode :: enum {
    ATOM_ONLY, NO_ATOM, ANY_OPERAND
}

@private
parse_operand :: proc(parser: ^Parser, opt: Operand_Mode) -> Expr {
    t := _next(parser)
    #partial switch t.Kind {
    case TK.INT:
        assert( opt != .ATOM_ONLY )
        return make_expr(parser, .INT, t.Val)
    case TK.STR:
        assert( opt != .ATOM_ONLY )
        return make_expr(parser, .STR, t.Val)
    case TK.ID:
        if _peek(parser).Kind != TK.LPAREN {
            assert( opt != .ATOM_ONLY )
            return make_expr(parser, .VAR, t.Val)
        }
        assert( opt != .NO_ATOM )
        _next(parser)
        atom := make_expr(parser, .ATOM, t.Val)
        for {
            if _peek(parser).Kind == TK.RPAREN {
                _next(parser)
                break
            }
            e := parse_expr(parser, ARITHMETIC_PREC, .NO_ATOM)
            append(&atom.Args, e)
            if _peek(parser).Kind == TK.COMMA { _next(parser) }
        }
        return atom
    case TK.LPAREN:
        assert( opt != .ATOM_ONLY )
        e := parse_expr(parser, 0)
        assert( _next(parser).Kind == TK.RPAREN )
        return e
    case TK.MINUS:
        assert( opt != .ATOM_ONLY )
        // The precedence level of the unary minus
        base := parse_expr(parser, UNARY_PREC + 1)
        return make_expr(parser, .UNARY, "--", &base)
    case:
        panic("Unexpected leaf kind")
    }
}

@private
prec_climbing_parse :: proc(parser: ^Parser, lhs_: Expr, min_prec: int, opt: Operand_Mode) -> Expr {
    lhs := lhs_
    non_assoc_found := false
    ahead := _peek(parser)
    for {
        ahead_prec := precedence(ahead)
        if !((is_non_assoc(ahead) && ahead_prec > min_prec) || ahead_prec >= min_prec ) {
            return lhs
        }
        if non_assoc_found && is_non_assoc(ahead) { return lhs }
        if is_non_assoc(ahead) { non_assoc_found = true }

        op := _next(parser)
        rhs := parse_operand(parser, opt)
        ahead = _peek(parser)
        for {
            op_prec := precedence(op)
            ahead_prec = precedence(ahead)
            if !((is_right_assoc(ahead) && ahead_prec == op_prec) || ahead_prec > op_prec) {
                break
            }
            new_prec := op_prec + (ahead_prec > op_prec ? 1 : 0)
            rhs = prec_climbing_parse(parser, rhs, new_prec, opt)
            ahead = _peek(parser)
        }
        // Flatten AND, OR
        kind := to_expr_kind(op)
        if (lhs.Kind == .AND || lhs.Kind == .OR) && lhs.Kind == kind {
            append(&lhs.Args, rhs)
        } else {
            lhs = make_expr(parser, kind, op.Val, &lhs, &rhs)
        }
    }
    return lhs
}
