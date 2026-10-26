package tests

import "core:testing"
import "core:os"
import "core:strings"
import tokenizer ".."

@(test)
test_tokens :: proc(t: ^testing.T) {
    inputs := make(map[string]string)
    defer delete(inputs)

    inputs[`// hello world 1+2/3`] = ""
    inputs[`// hello world 1+2/3
x y 123 x123
`] = `ID:x||ID:y||INT:123||ID:x123||`
    inputs[`"1" "" "asfds//by\"\\\xe" def
`] = `STRING:1||STRING:||STRING:asfds//by\"\\\xe||DEF:def||`
    inputs[`def decl true false
`] = `DEF:def||DECL:decl||TRUE:true||FALSE:false||`
    inputs[`false12 def32 decla truea _x1q2 _
`] = `ID:false12||ID:def32||ID:decla||ID:truea||ID:_x1q2||ID:_||`
    inputs[`1/2//noooo
`] = "INT:1||DIV:/||INT:2||"
    inputs[`1+2-3*4^5%54/3//1000
`] =
    "INT:1||PLUS:+||INT:2||MINUS:-||INT:3||MULT:*||INT:4||POW:^||INT:5||MOD:%||INT:54||DIV:/||INT:3||"
    inputs[``] = ""
    inputs[``] = ""

    for input, expected in inputs {
        reader := strings.Reader{s=input}
        stream := strings.reader_to_stream(&reader)
        tok := tokenizer.init(stream)
        defer tokenizer.destroy(&tok)
        actual := tokenizer.to_string(&tok)
        testing.expect_value(t, actual, expected)
        delete(actual)
    }
}
