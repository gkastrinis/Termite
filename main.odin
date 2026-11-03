package termite

import "core:fmt"
import "core:os"
import "core:strings"

import parser "./parser"
import tokenizer "./tokenizer"

main :: proc() {
    // input := "x > y > z"
    // input := "(x > 1) ; (x + 1)"
    // input := "normalize_expr(x, y), bar()"
    // input := "def normalize_expr(x, y), bar(x, y), baz(1, (x+1)) : bar(x, y)"

    // input := "def foo(x, y), bar(x*2) : (baaaar(x, a, b, c), wat(x, c/2), a+b-c > x+1) ; meh(x, y)"
    // input := "def foo(x, y), bar(x*2) : baaaar(x, a, b, c), wat(x, c/2), a+b-c > x+1"
    // input := "def foo(x, y), bar(x, y*2) : baaaar(x, a, b), wat(x, c/2)"
    // input := "def woo(x1, y1) : bar(x2, y2/2) ; baz(a3+1, z3)"

    input := "def foo(x, y*2) : bar(x, y/2) ; baz(a+1, z)"
    // input := "def foo(x, y) : (bar(x) ; baz(x)), x =1"

    reader := strings.Reader{s = input}
    stream := strings.reader_to_stream(&reader)

    p := parser.init(stream, context.allocator)
    parser.parse(&p)
    parser.print_program(&p)

    parser.normalize(&p)
    parser.print_program(&p)

    // tok := tokenizer.init(stream, context.allocator)
    // for {
    //     t := tokenizer.next_token(&tok)
    //     fmt.println(t)
    //     if t.kind == .End_Of_File || t.kind == .Error { break }
    // }
}
