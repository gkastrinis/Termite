package tests

import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"
import "core:strings"
import "core:testing"

import parser ".."

to_string :: proc(p: ^parser.Parser, e: parser.Expr) -> string {
    switch e.Kind {
    case parser.ExprKind.INT, parser.ExprKind.STR, parser.ExprKind.VAR:
        return fmt.tprintf("%v", e.Op)
    case parser.ExprKind.UNARY:
        assert( len(e.Args) == 1 )
        return fmt.tprintf("-%v", to_string(p, e.Args[0]))
    case parser.ExprKind.BINARY, parser.ExprKind.COMPARISON:
        assert( len(e.Args) == 2 )
        a := to_string(p, e.Args[0])
        b := to_string(p, e.Args[1])
        return fmt.tprintf("(%v %v %v)", a, e.Op, b)
    case parser.ExprKind.OR, parser.ExprKind.AND:
        builder := strings.builder_make(allocator = p.allocator)
        strings.write_byte(&builder, '(')
        for arg, i in e.Args {
            if i > 0 { strings.write_string(&builder, fmt.tprintf(" %v ", e.Op)) }
            strings.write_string(&builder, to_string(p, arg))
        }
        strings.write_byte(&builder, ')')
        return strings.to_string(builder)
    }
}

@(test)
test_expressions :: proc(t: ^testing.T) {
    arena: vmem.Arena
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

    inputs["a = b"] = "(a = b)"
    inputs["a + 1 < b * 2"] = "((a + 1) < (b * 2))"
    inputs["a < b, c = d"] = "((a < b) , (c = d))"
    inputs["a = b ; c != d"] = "((a = b) ; (c != d))"
    inputs["a ; b, c"] = "(a ; (b , c))"
    inputs["a, b ; c, d"] = "((a , b) ; (c , d))"
    inputs["(a ; b), c"] = "((a ; b) , c)"
    inputs["a < b ; c < d, e >= f"] = "((a < b) ; ((c < d) , (e >= f)))"
    inputs["x > 1, y > 2, z > 3"] = "((x > 1) , (y > 2) , (z > 3))"
    inputs["x > 1, y > 2; z > 3"] = "(((x > 1) , (y > 2)) ; (z > 3))"

    // TODO: this should fail
    // inputs["(x > 1) ; (x + 1)"] = ..

    for input, expected in inputs {
        reader := strings.Reader{s = input}
        stream := strings.reader_to_stream(&reader)

        p := parser.init(stream, allocator)
        e := parser.parse_expr(&p, 0)
        actual := to_string(&p, e)
        testing.expect_value(t, actual, expected)
    }
}
