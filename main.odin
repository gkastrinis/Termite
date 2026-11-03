package termite

import "core:fmt"
import "core:os"
import "core:strings"

import parser "./parser"
import tokenizer "./tokenizer"

main :: proc() {
    input := "decl bar(x:int, y:int) def foo(x): bar(x + 1)"

    reader := strings.Reader{s = input}
    // stream := strings.reader_to_stream(&reader)

    stream := os.to_stream(os.stdin)
    p := parser.init(stream, context.allocator)
    parser.parse(&p)
    // parser.print_program(&p)

    parser.normalize(&p)
    parser.print_program(&p)
}
