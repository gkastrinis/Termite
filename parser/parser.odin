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
    COMPARISON,
    // Arithmetic Expressions
    BINARY, UNARY, INT, STR, VAR,
}

Expr :: struct {
    kind: ExprKind,
    op: string,
    args: [dynamic]Expr,
}

// Relation :: struct {
//     name: string,
//     arity: u8,
//     fields: [dynamic]string,
//     types: [dynamic]string,
// }
//
// Rule :: struct {
//     id: u16,
//     head: [dynamic]Expr,
//     body: [dynamic]Expr
// }

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
        // declared = make(map[string]Relation),
        // inferred = make(map[string]Relation),
    }
}

// parse :: proc(parser: ^Parser) { for {
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

to_string :: proc(parser: ^Parser, e: Expr) -> string {
    switch e.kind {
    case .INT, .STR, .VAR:
        return fmt.tprintf("%v", e.op)
    case .UNARY:
        assert( len(e.args) == 1 )
        return fmt.tprintf("-%v", to_string(parser, e.args[0]))
    case .BINARY, .COMPARISON:
        assert( len(e.args) == 2 )
        a := to_string(parser, e.args[0])
        b := to_string(parser, e.args[1])
        return fmt.tprintf("(%v %v %v)", a, e.op, b)
    case .OR, .AND:
        builder := strings.builder_make(allocator = parser.allocator)
        strings.write_byte(&builder, '(')
        for arg, i in e.args {
            if i > 0 { strings.write_string(&builder, fmt.tprintf(" %v ", e.op)) }
            strings.write_string(&builder, to_string(parser, arg))
        }
        strings.write_byte(&builder, ')')
        return strings.to_string(builder)
    }
    unreachable()
}

ParenColor :: enum {
    WHITE, GREEN, MAGENTA, GREY, YELLOW, CYAN
}

COLORS := [6]string{"0", "92", "95", "30", "93", "96"}

print_expr :: proc(e: Expr, color: ParenColor) {
    switch e.kind {
    case .INT:
        fmt.printf("\x1b[32m%v\x1b[0m", e.op)
    case .STR:
        fmt.printf("\x1b[32m\"%v\"\x1b[0m", e.op)
    case .VAR:
        fmt.printf("\x1b[38;5;208m%v\x1b[0m", e.op)
    case .BINARY, .COMPARISON, .OR, .AND:
        fmt.printf("\x1b[%sm(\x1b[0m", COLORS[color])
        is_first := true
        for arg in e.args {
            if !is_first {
                fmt.printf(" %v ", e.op)
            }
            is_first = false
            print_expr(arg, ParenColor((int(color) + 1) % 6))
        }
        fmt.printf("\x1b[%sm)\x1b[0m", COLORS[color])
    case .UNARY:
        assert( len(e.args) == 1 )
        fmt.print("-")
        print_expr(e.args[0], color)
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
    e := Expr{kind = kind, op = op}
    e.args = make([dynamic]Expr, 0, 8, parser.allocator)
    if a != nil { append(&e.args, a^) }
    if b != nil { append(&e.args, b^) }
    return e
}

UNARY_PREC :: 6

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
    unreachable()
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
//
// parse_def :: proc(parser: ^Parser) {
//     rule := Rule{id = parser.last_rule_id}
//     parser.last_rule_id += 1
//
//     for {
//         append(&rule.head, parse_expr(parser, 0))
//         t := _peek(parser)
//         if t.Kind != TK.COMMA { break }
//         _next(parser)
//     }
//     assert( _next(parser).Kind == TK.COLON )
//     for {
//         append(&rule.body, parse_expr(parser, 0))
//         t := _peek(parser)
//         if t.Kind != TK.COMMA { break }
//         _next(parser)
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

// @private
parse_expr :: proc(parser: ^Parser, min_prec: int) -> Expr {
    lhs := parse_leaf_expr(parser)
    return parse_expr_inner(parser, lhs, min_prec)
}

@private
parse_leaf_expr :: proc(parser: ^Parser) -> Expr {
    t := _next(parser)
    #partial switch t.Kind {
    case TK.INT:
        return make_expr(parser, .INT, t.Val)
    case TK.STR:
        return make_expr(parser, .STR, t.Val)
    case TK.ID:
        return make_expr(parser, .VAR, t.Val)
    case TK.LPAREN:
        e := parse_expr(parser, 0)
        assert( _next(parser).Kind == TK.RPAREN )
        return e
    case TK.MINUS:
        // The precedence level of the unary minus
        base := parse_expr(parser, UNARY_PREC + 1)
        return make_expr(parser, .UNARY, "--", &base)
    case:
        panic("Unexpected leaf kind")
    }
}

// Precedence climbing algorithm
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
        if non_assoc_found && is_non_assoc(ahead) { return lhs }
        if is_non_assoc(ahead) { non_assoc_found = true }

        op := _next(parser)
        rhs := parse_leaf_expr(parser)
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
        // Flatten AND, OR
        kind := to_expr_kind(op)
        if (lhs.kind == .AND || lhs.kind == .OR) && lhs.kind == kind {
            append(&lhs.args, rhs)
        } else {
            lhs = make_expr(parser, kind, op.Val, &lhs, &rhs)
        }
    }
    return lhs
}

///////////////////////////////////////////////////////////////

main :: proc() {
    // input := `(x > 1) ; (x + 1)`
    // input := "a * b / c"
    input := "x > 1, y > 2, z > 3"

    reader := strings.Reader{s = input}
    stream := strings.reader_to_stream(&reader)
    p := init(stream, context.allocator)
    print_expr(parse_expr(&p, 0), .WHITE)
}
