package parser

import "core:fmt"
import "core:io"
import "core:mem"

import tokenizer "../tokenizer"

@private
Token :: tokenizer.Token
@private
TK :: tokenizer.Token_Kind

Expr_Kind :: enum {
    // Logical Expressions
    Or, And,
    Atom, Comparison,
    // Arithmetic Expressions
    Binary, Unary, Int, Str, Var,
}

Expr :: struct {
    kind: Expr_Kind,
    op: string,
    args: [dynamic]Expr,
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
        t := next_token(parser)
        if t.kind == TK.End_Of_File {
            break
        } else if t.kind == TK.Decl {
            panic("not yet")
            // parse_decl(parser)
        } else if t.kind == TK.Def {
            parse_rule(parser)
        } else if t.kind == TK.Error {
            fmt.printf("%v\x1b[0m \x1b[31m<%v> \x1b[0m", t.val, t.kind)
            break
        } else {
            fmt.printf("%v\x1b[0m \x1b[30m<%v> \x1b[0m", t.val, t.kind)
            panic("waaat")
        }
    }
}

parse_expr :: proc(parser: ^Parser) -> Expr {
    lhs := parse_operand(parser, .Any_Operand)
    return prec_climbing_parse(parser, lhs, 0, .Any_Operand)
}

///////////////////////////////////////////////////////////////

Paren_Color :: enum {
    White, Green, Magenta, Grey, Yellow, Cyan
}

@private
COLORS := [6]string{"0", "92", "95", "30", "93", "96"}

print_expr :: proc(e: Expr, color: Paren_Color = .White) {
    switch e.kind {
    case .Int:
        fmt.printf("\x1b[32m%v\x1b[0m", e.op)
    case .Str:
        fmt.printf("\x1b[32m\"%v\"\x1b[0m", e.op)
    case .Var:
        fmt.printf("\x1b[33m%v\x1b[0m", e.op)
    case .Binary, .Comparison, .Or, .And:
        fmt.printf("\x1b[%sm(\x1b[0m", COLORS[color])
        for arg, i in e.args {
            if i > 0 { fmt.printf(" %v ", e.op) }
            print_expr(arg, Paren_Color((int(color) + 1) % 6))
        }
        fmt.printf("\x1b[%sm)\x1b[0m", COLORS[color])
    case .Unary:
        assert( len(e.args) == 1 )
        fmt.print("-")
        print_expr(e.args[0], color)
    case .Atom:
        fmt.printf("\x1b[34m%v\x1b[0m(", e.op)
        for arg, i in e.args {
            if i > 0 { fmt.printf(", ") }
            print_expr(arg, Paren_Color((int(color) + 1) % 6))
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
peek_token :: proc(parser: ^Parser) -> Token {
    if !parser.has_ahead {
        parser.ahead = next_token(parser)
        parser.has_ahead = true
    }
    return parser.ahead
}

@private
next_token :: proc(parser: ^Parser) -> Token {
    if parser.has_ahead {
        parser.has_ahead = false
        return parser.ahead
    }
    return tokenizer.next_token(&parser.tok)
}

@private
make_expr :: proc(
    parser: ^Parser, kind: Expr_Kind, op: string, a: ^Expr = nil, b: ^Expr = nil
) -> Expr {
    e := Expr{kind = kind, op = op}
    sz := 0
    if a != nil { sz += 1 }
    if b != nil { sz += 1 }
    e.args = make([dynamic]Expr, 0, sz, parser.allocator)
    if a != nil { append(&e.args, a^) }
    if b != nil { append(&e.args, b^) }
    return e
}

@private
to_expr_kind :: proc(t: Token) -> Expr_Kind {
    #partial switch t.kind {
    case TK.Equal, TK.Not_Equal, TK.Less_Than, TK.Less_Than_Or_Equal, TK.Greater_Than, TK.Greater_Than_Or_Equal:
        return .Comparison
    case TK.Semicolon:
        return .Or
    case TK.Comma:
        return .And
    case TK.Plus, TK.Minus, TK.Multiply, TK.Divide, TK.Modulo, TK.Power:
        return .Binary
    case:
        panic("Unexpected token kind")
    }
}

@private
is_non_assoc :: proc(t: Token) -> bool {
    #partial switch t.kind {
    case TK.Equal, TK.Not_Equal, TK.Less_Than, TK.Less_Than_Or_Equal, TK.Greater_Than, TK.Greater_Than_Or_Equal:
        return true
    case:
        return false
    }
}

@private
is_right_assoc :: proc(t: Token) -> bool {
    return t.kind == TK.Power
}

@private
ARITHMETIC_PREC :: 4
@private
UNARY_PREC :: 6
@private
NO_PRECEDENCE :: -42

@private
precedence :: proc(t: Token) -> int {
    #partial switch t.kind {
    case TK.Semicolon:
        return 1
    case TK.Comma:
        return 2
    case TK.Equal, TK.Not_Equal, TK.Less_Than, TK.Less_Than_Or_Equal, TK.Greater_Than, TK.Greater_Than_Or_Equal:
        return 3
    case TK.Plus, TK.Minus:
        return 4
    case TK.Multiply, TK.Divide, TK.Modulo:
        return 5
    // Unary minus is at 6
    case TK.Power:
        return 7
    case:
        return NO_PRECEDENCE
    }
}

///////////////////////////////////////////////////////////////

// parse_decl :: proc(parser: ^Parser) -> Relation {
//     t := next_token(parser)
//     assert( t.kind == .Identifier )
//
//     assert(!(t.val in parser.declared))
//
//     rel := Relation{name = t.val, arity = 0}
//
//     t = next_token(parser)
//     assert( t.kind == TK.Left_Paren )
//
//     for {
//         name := next_token(parser)
//         if name.kind == TK.Right_Paren {
//             break
//         } else if name.kind == TK.Comma && rel.arity != 0 {
//             continue
//         } else if name.kind != TK.Identifier {
//             fmt.println(t)
//         }
//         t = next_token(parser)
//         assert( t.kind == TK.Colon )
//         t = next_token(parser)
//         assert( t.kind == TK.Identifier )
//
//         append(&rel.fields, name.val)
//         append(&rel.types, t.val)
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
        atom := parse_operand(parser, .Atom_Only)
        assert( atom.kind == .Atom )
        append(&rule.head, atom)
        t := peek_token(parser)
        if t.kind != TK.Comma { break }
        next_token(parser)
    }
    assert( next_token(parser).kind == TK.Colon )
    rule.body = parse_expr(parser)

    append(&parser.rules, rule)
}

// @private
// update_relations :: proc(parser: ^Parser, rule: Rule) {
//     for e in rule.head {
//         assert( e.kind == .Atom )
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

@private
Operand_Mode :: enum {
    Atom_Only, No_Atom, Any_Operand
}

@private
parse_operand :: proc(parser: ^Parser, opt: Operand_Mode) -> Expr {
    t := next_token(parser)
    #partial switch t.kind {
    case TK.Int:
        assert( opt != .Atom_Only )
        return make_expr(parser, .Int, t.val)
    case TK.Str:
        assert( opt != .Atom_Only )
        return make_expr(parser, .Str, t.val)
    case TK.Identifier:
        if peek_token(parser).kind != TK.Left_Paren {
            assert( opt != .Atom_Only )
            return make_expr(parser, .Var, t.val)
        }
        assert( opt != .No_Atom )
        next_token(parser)
        atom := make_expr(parser, .Atom, t.val)
        for {
            if peek_token(parser).kind == TK.Right_Paren {
                next_token(parser)
                break
            }
            e := parse_expr_inner(parser, ARITHMETIC_PREC, .No_Atom)
            append(&atom.args, e)
            if peek_token(parser).kind == TK.Comma { next_token(parser) }
        }
        return atom
    case TK.Left_Paren:
        assert( opt != .Atom_Only )
        e := parse_expr_inner(parser, 0, opt)
        assert( next_token(parser).kind == TK.Right_Paren )
        return e
    case TK.Minus:
        assert( opt != .Atom_Only )
        // The precedence level of the unary minus
        base := parse_expr_inner(parser, UNARY_PREC + 1, opt)
        return make_expr(parser, .Unary, "--", &base)
    case:
        panic("Unexpected leaf kind")
    }
}

@private
parse_expr_inner :: proc(parser: ^Parser, min_prec: int, opt: Operand_Mode) -> Expr {
    lhs := parse_operand(parser, opt)
    return prec_climbing_parse(parser, lhs, min_prec, opt)
}

@private
prec_climbing_parse :: proc(parser: ^Parser, lhs_: Expr, min_prec: int, opt: Operand_Mode) -> Expr {
    lhs := lhs_
    non_assoc_found := false
    ahead := peek_token(parser)
    for {
        ahead_prec := precedence(ahead)
        if !((is_non_assoc(ahead) && ahead_prec > min_prec) || ahead_prec >= min_prec ) {
            return lhs
        }
        if non_assoc_found && is_non_assoc(ahead) { return lhs }
        if is_non_assoc(ahead) { non_assoc_found = true }

        op := next_token(parser)
        rhs := parse_operand(parser, opt)
        ahead = peek_token(parser)
        for {
            op_prec := precedence(op)
            ahead_prec = precedence(ahead)
            if !((is_right_assoc(ahead) && ahead_prec == op_prec) || ahead_prec > op_prec) {
                break
            }
            new_prec := op_prec + (ahead_prec > op_prec ? 1 : 0)
            rhs = prec_climbing_parse(parser, rhs, new_prec, opt)
            ahead = peek_token(parser)
        }
        // Flatten And, Or
        kind := to_expr_kind(op)
        if (lhs.kind == .And || lhs.kind == .Or) && lhs.kind == kind {
            append(&lhs.args, rhs)
        } else {
            lhs = make_expr(parser, kind, op.val, &lhs, &rhs)
        }
    }
    return lhs
}
