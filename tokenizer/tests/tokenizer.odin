package tests

import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"
import "core:strings"
import "core:testing"

import tokenizer ".."

tokenize_input :: proc(tok: ^tokenizer.Tokenizer) -> string {
    builder: strings.Builder
    _, err := strings.builder_init(&builder, tok.allocator)
    assert(err == nil)
    for {
        t := tokenizer.next_token(tok)
        if t.kind == .End_Of_File { break }
        strings.write_string(&builder, fmt.tprintf("%v:%v||", t.kind, t.val))
        if t.kind == .Error { break }
    }
    return strings.to_string(builder)
}

@(test)
test_tokens :: proc(t: ^testing.T) {
    arena: vmem.Arena
    err := vmem.arena_init_growing(&arena)
    assert(err == nil)
    defer vmem.arena_destroy(&arena)
    allocator := vmem.arena_allocator(&arena)

    inputs := make(map[string]string, allocator)

    inputs[`// hello world 1+2/3`] = ""
    inputs[`/`] = "Divide:/||"
    inputs[`"1" "" "asfds//by\"\\\xe"`] =
        `Str:1||Str:||Str:asfds//by\"\\\xe||`
    inputs[`123 67889 0`] = "Int:123||Int:67889||Int:0||"
    inputs[`xyz`] = "Identifier:xyz||"
    inputs[`// hello world 1+2/3
x y 123 x123`] = `Identifier:x||Identifier:y||Int:123||Identifier:x123||`
    inputs[`def`] = `Def:def||`
    inputs[`decl`] = `Decl:decl||`
    inputs[`true`] = `True:true||`
    inputs[`false`] = `False:false||`
    inputs[`false123`] = `Identifier:false123||`
    inputs[`false12 def32 decla truea _x1q2 _`] =
        `Identifier:false12||Identifier:def32||Identifier:decla||Identifier:truea||Identifier:_x1q2||Identifier:_||`
    inputs[`1/2//noooo`] = "Int:1||Divide:/||Int:2||"
    inputs[`1+2-3*4^5%54/3//1000`] =
        "Int:1||Plus:+||Int:2||Minus:-||Int:3||Multiply:*||Int:4||Power:^||Int:5||Modulo:%||Int:54||Divide:/||Int:3||"
    inputs[`=!=<<=>>=():,;`] = "Equal:=||Not_Equal:!=||Less_Than:<||Less_Than_Or_Equal:<=||Greater_Than:>||Greater_Than_Or_Equal:>=||Left_Paren:(||Right_Paren:)||Colon::||Comma:,||Semicolon:;||"
    inputs[`+-*/%^`] = "Plus:+||Minus:-||Multiply:*||Divide:/||Modulo:%||Power:^||"

    inputs[`123 456abc`] = "Int:123||Error:456a||"
    inputs[`123 456$$`] = "Int:123||Error:456$||"
    inputs[`123 abc$123`] = "Int:123||Error:abc$||"
    inputs[`123 false$123`] = "Int:123||Error:false$||"
    inputs[`"`] = "Error:||"
    inputs[`"hello ther`] = "Error:hello ther||"
    inputs[`"hello there\"`] = `Error:hello there\"||`
    inputs[`"hello there\`] = `Error:hello there\||`
    inputs[`abc!`] = "Identifier:abc||Error:!||"

    for input, expected in inputs {
        reader := strings.Reader{s = input}
        stream := strings.reader_to_stream(&reader)
        tok := tokenizer.init(stream, allocator)
        actual := tokenize_input(&tok)
        testing.expect_value(t, actual, expected)
    }
}
