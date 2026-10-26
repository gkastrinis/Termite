package tests

import "core:testing"
import "core:strings"
import parser ".."

@(test)
test_expressions :: proc(t: ^testing.T) {
    inputs := make(map[string]string)
    defer delete(inputs)

    inputs["truexyz + 113 * (1 - 1234)\n"] =
        "(truexyz + (113 * (1 - 1234)))"
    inputs["truexyz + 113 * 1 - 1234\n"] =
        "((truexyz + (113 * 1)) - 1234)"
    inputs["defa + decla * falsea\n"] =
        "(defa + (decla * falsea))"
    inputs["x % 2 ^ 123 - 3\n"] =
        "((x % (2 ^ 123)) - 3)"
    inputs["x ^ 2 ^ 10"] =
        "(x ^ (2 ^ 10))"
    inputs["a - b - c"] =
        "((a - b) - c)"
    inputs["a / b * c"] =
        "((a / b) * c)"
    inputs["a ^ b ^ c"] =
        "(a ^ (b ^ c))"
    inputs["a + b % c"] =
        "(a + (b % c))"
    inputs["a + b % c ^ d % e + f"] =
        "((a + ((b % (c ^ d)) % e)) + f)"
    inputs["a + 1 = b / 2"] =
        "((a + 1) = (b / 2))"
    inputs["a = b"] =
        "(a = b)"
    inputs["a + 1 = c + d"] =
        "((a + 1) = (c + d))"
    inputs["a + -2 = c"] =
        "((a + -(2)) = c)"
    inputs["a + ----b = c"] =
        "((a + -(-(-(-(b))))) = c)"
    inputs["a-b-c"] =
        "((a - b) - c)"
    inputs["-a ^ b"] =
        "-((a ^ b))"
    inputs["a ^ -b"] =
        "(a ^ -(b))"

    for input, expected in inputs {
        reader := strings.Reader{s=input}
        stream := strings.reader_to_stream(&reader)
        parser_ := parser.init(stream)
        defer parser.destroy(parser_)
        e := parser.parse_expr(parser_, 0)
        actual := parser.to_S_expression(e)
        testing.expect_value(t, actual, expected)
    }
}
