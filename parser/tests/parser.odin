package tests

import "core:testing"
import "core:os"
import "core:strings"
import "core:fmt"
import parser ".."

@(test)
test_expressions :: proc(t: ^testing.T) {
    inputs := make(map[string]string)
    inputs["truexyz + 113 * (1 - 1234)\n"] =
        "(truexyz:Any + (113:Int64 * (1:Int64 - 1234:Int64)))"
    inputs["truexyz + 113 * 1 - 1234\n"] =
        "((truexyz:Any + (113:Int64 * 1:Int64)) - 1234:Int64)"
    inputs["defa + decla * falsea\n"] =
        "(defa:Any + (decla:Any * falsea:Any))"
    inputs["x % 2 ^ 123 - 3\n"] =
        "((x:Any % (2:Int64 ^ 123:Int64)) - 3:Int64)"
    inputs["x ^ 2 ^ 10"] =
        "(x:Any ^ (2:Int64 ^ 10:Int64))"
    inputs["a - b - c"] =
        "((a:Any - b:Any) - c:Any)"
    inputs["a / b * c"] =
        "((a:Any / b:Any) * c:Any)"
    inputs["a ^ b ^ c"] =
        "(a:Any ^ (b:Any ^ c:Any))"
    inputs["a + b % c"] =
        "(a:Any + (b:Any % c:Any))"
    inputs["a + b % c ^ d % e + f"] =
        "((a:Any + ((b:Any % (c:Any ^ d:Any)) % e:Any)) + f:Any)"
    inputs["-a ^ b"] =
        "-(a:Any ^ b:Any)"
    inputs["a ^ -b"] =
        "(a:Any ^ -(b:Any))"
    inputs["a + 1 = b / 2"] =
        "((a:Any + 1:Int64) = (b:Any / 2:Int64))"
    inputs["a = b"] =
        "(a:Any = b:Any)"
    inputs["a + 1 = c + d"] =
        "((a:Any + 1:Int64) = (c:Any + d:Any))"
    inputs["a + -2 = c"] =
        "((a:Any + -(2:Int64)) = c:Any)"
    inputs["a + ----b = c"] =
        "((a:Any + -(-(-(-(b:Any))))) = c:Any)"
    inputs["a-b-c"] =
        "((a:Any - b:Any) - c:Any)"

    for input, expected in inputs {
        fmt.eprintf("Running: %s vs %s\n", input, expected)
        reader := strings.Reader{s=input,}
        stream := strings.reader_to_stream(&reader)
        parser_ := parser.init(stream)
        defer parser.destroy(&parser_)
        e := parser.parse_expr(&parser_, 0)
        actual := parser.to_S_expression(e)
        testing.expect_value(t, actual, expected)
    }
}
