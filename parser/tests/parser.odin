package tests

import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"
import "core:strings"
import "core:testing"

import parser ".."

to_string :: proc(p: ^parser.Parser, e: parser.Expr) -> string {
    switch e.kind {
    case parser.Expr_Kind.Int, parser.Expr_Kind.Str, parser.Expr_Kind.Var:
        return fmt.tprintf("%v", e.op)
    case parser.Expr_Kind.Unary:
        assert( len(e.args) == 1 )
        return fmt.tprintf("-%v", to_string(p, e.args[0]))
    case parser.Expr_Kind.Binary:
        assert( len(e.args) == 2 )
        a := to_string(p, e.args[0])
        b := to_string(p, e.args[1])
        return fmt.tprintf("(%v %v %v)", a, e.op, b)
    case parser.Expr_Kind.Or, parser.Expr_Kind.And:
        builder := strings.builder_make(allocator = p.allocator)
        strings.write_byte(&builder, '(')
        for arg, i in e.args {
            if i > 0 { strings.write_string(&builder, fmt.tprintf(" %v ", e.op)) }
            strings.write_string(&builder, to_string(p, arg))
        }
        strings.write_byte(&builder, ')')
        return strings.to_string(builder)
    case parser.Expr_Kind.Atom:
        builder := strings.builder_make(allocator = p.allocator)
        strings.write_string(&builder, e.op)
        strings.write_byte(&builder, '(')
        for arg, i in e.args {
            if i > 0 { strings.write_string(&builder, ", ") }
            strings.write_string(&builder, to_string(p, arg))
        }
        strings.write_byte(&builder, ')')
        return strings.to_string(builder)
    }
    unreachable()
}

@(test)
test_expressions :: proc(t: ^testing.T) { arena: vmem.Arena
    err := vmem.arena_init_growing(&arena)
    assert(err == nil)
    defer vmem.arena_destroy(&arena)
    allocator := vmem.arena_allocator(&arena)

    inputs := make(map[string]string, allocator)

    inputs["truexyz + 113 * (1 - 1234)\n"] = "(truexyz + (113 * (1 - 1234)))"
    inputs["truexyz + 113 * 1 - 1234\n"] = "((truexyz + (113 * 1)) - 1234)"
    inputs["defa + decla * falsea\n"] = "(defa + (decla * falsea))"
    inputs["x % 2 ^ 123 - 3\n"] = "((x % (2 ^ 123)) - 3)"
    inputs["x ^ 2 ^ 10"] = "(x ^ (2 ^ 10))"
    inputs["a - b - c"] = "((a - b) - c)"
    inputs["a / b * c"] = "((a / b) * c)"
    inputs["a * b / c"] = "((a * b) / c)"
    inputs["a ^ b ^ c"] = "(a ^ (b ^ c))"
    inputs["a + b % c"] = "(a + (b % c))"
    inputs["a + b % c ^ d % e + f"] = "((a + ((b % (c ^ d)) % e)) + f)"
    inputs["a-b-c"] = "((a - b) - c)"
    inputs["-a ^ b"] = "-(a ^ b)"
    inputs["a ^ -b"] = "(a ^ -b)"

    inputs["a = b"] = "=(a, b)"
    inputs["a + 1 < b * 2"] = "<((a + 1), (b * 2))"
    inputs["a < b, c = d"] = "(<(a, b) , =(c, d))"
    inputs["a = b ; c != d"] = "(=(a, b) ; !=(c, d))"
    inputs["a ; b, c"] = "(a ; (b , c))"
    inputs["a, b ; c, d"] = "((a , b) ; (c , d))"
    inputs["(a ; b), c"] = "((a ; b) , c)"
    inputs["a < b ; c < d, e >= f"] = "(<(a, b) ; (<(c, d) , >=(e, f)))"
    inputs["x > 1, y > 2, z > 3"] = "(>(x, 1) , >(y, 2) , >(z, 3))"
    inputs["x > 1, y > 2; z > 3"] = "((>(x, 1) , >(y, 2)) ; >(z, 3))"

    // TODO: this should fail
    // inputs["(x > 1) ; (x + 1)"] = ..

    for input, expected in inputs {
        reader := strings.Reader{s = input}
        stream := strings.reader_to_stream(&reader)

        p := parser.init(stream, allocator)
        e := parser.parse_expr(&p)
        actual := to_string(&p, e)
        testing.expect_value(t, actual, expected)
    }
}

rule_to_string :: proc(p: ^parser.Parser, rule: parser.Rule) -> string {
    builder := strings.builder_make(allocator = p.allocator)
    for arg, i in rule.head {
        if i > 0 { strings.write_string(&builder, ", ") }
        strings.write_string(&builder, to_string(p, arg))
    }
    strings.write_string(&builder, ": ")
    strings.write_string(&builder, to_string(p, rule.body))
    return strings.to_string(builder)
}

@(test)
test_rules :: proc(t: ^testing.T) {
    arena: vmem.Arena
    err := vmem.arena_init_growing(&arena)
    assert(err == nil)
    defer vmem.arena_destroy(&arena)
    allocator := vmem.arena_allocator(&arena)

    inputs := make(map[string]string, allocator)

    inputs["def foo(x, y): bar(x, y)"] = "foo(x, y): bar(x, y)"
    inputs["def foo(x): bar(x + 1)"] = "foo(x): (bar($1) , +(x, 1, $1))"
    inputs["def foo(x * 2): bar(x)"] = "foo($1): (bar(x) , *(x, 2, $1))"
    inputs["def foo(x): bar(x + 1), baz(x * 2)"] = "foo(x): (bar($1) , +(x, 1, $1) , baz($2) , *(x, 2, $2))"
    inputs["def foo(x, y), bar(x, y): baz(x, y)"] = "foo(x, y), bar(x, y): baz(x, y)"
    inputs["def foo(x, y): (bar(x) ; baz(y / 2))"] = "foo(x, y): (bar(x) ; (baz($1) , /(y, 2, $1)))"
    inputs["def foo(x, y): (bar(x), baz(y / 2)) ; (qux(x), quux(y))"] = "foo(x, y): ((bar(x) , baz($1) , /(y, 2, $1)) ; (qux(x) , quux(y)))"

    for input, expected in inputs {
        reader := strings.Reader{s = input}
        stream := strings.reader_to_stream(&reader)

        p := parser.init(stream, allocator)
        parser.parse(&p)
        parser.normalize(&p)

        testing.expect_value(t, len(p.rules), 1)
        rule := p.rules[0]

        actual := rule_to_string(&p, rule)
        testing.expect_value(t, actual, expected)
    }
}
