package tests

import "core:mem"
import vmem "core:mem/virtual"
import "core:strings"
import "core:testing"

import parser ".."

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

    // TODO: this should fail
    // inputs["(x > 1) ; (x + 1)"] = ..

    for input, expected in inputs {
        reader := strings.Reader{s = input}
        stream := strings.reader_to_stream(&reader)

        p := parser.init(stream, allocator)
        e := parser.parse_expr(&p, 0)
        actual := parser.to_S_expression(e)
        testing.expect_value(t, actual, expected)
    }
}
