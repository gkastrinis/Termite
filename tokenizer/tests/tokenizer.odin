package tests

import "core:mem"
import vmem "core:mem/virtual"
import "core:strings"
import "core:testing"

import tokenizer ".."

@(test)
test_tokens :: proc(t: ^testing.T) {
    arena: vmem.Arena
    err := vmem.arena_init_growing(&arena)
    assert(err == nil)
    defer vmem.arena_destroy(&arena)
    allocator := vmem.arena_allocator(&arena)

    inputs := make(map[string]string, allocator)

    inputs[`// hello world 1+2/3`] = ""
    inputs[`/`] = "DIV:/||"
    inputs[`"1" "" "asfds//by\"\\\xe"`] =
        `STRING:1||STRING:||STRING:asfds//by\"\\\xe||`
    inputs[`123 67889 0`] = "INT:123||INT:67889||INT:0||"
    inputs[`xyz`] = "ID:xyz||"
    inputs[`// hello world 1+2/3
x y 123 x123`] = `ID:x||ID:y||INT:123||ID:x123||`
    inputs[`def`] = `DEF:def||`
    inputs[`decl`] = `DECL:decl||`
    inputs[`true`] = `TRUE:true||`
    inputs[`false`] = `FALSE:false||`
    inputs[`false123`] = `ID:false123||`
    inputs[`false12 def32 decla truea _x1q2 _`] =
        `ID:false12||ID:def32||ID:decla||ID:truea||ID:_x1q2||ID:_||`
    inputs[`1/2//noooo`] = "INT:1||DIV:/||INT:2||"
    inputs[`1+2-3*4^5%54/3//1000`] =
        "INT:1||PLUS:+||INT:2||MINUS:-||INT:3||MULT:*||INT:4||POW:^||INT:5||MOD:%||INT:54||DIV:/||INT:3||"
    inputs[``] = ""
    inputs[``] = ""
    inputs[``] = ""
    inputs[``] = ""

    for input, expected in inputs {
        reader := strings.Reader{s = input}
        stream := strings.reader_to_stream(&reader)
        tok := tokenizer.init(stream, allocator)
        actual := tokenizer.tokenize_input(&tok)
        testing.expect_value(t, actual, expected)
    }
}
