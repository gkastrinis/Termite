package termite

import "core:fmt"
import "core:os"
import "core:strings"

import parser "./parser"
import tokenizer "./tokenizer"

main :: proc() {
    args := os.args
    if len(args) == 1 {
        fmt.printf("usage: %v <file>", args[0])
        return
    }
    source := parser.file_source_init(args[1], context.allocator)
    if source.failed { return }

    // input := "def foo(): bar(), x > 1 < 2"
    // reader := strings.Reader{s = input}
    // stream := strings.reader_to_stream(&reader)
    // stream := os.to_stream(os.stdin)

    p := parser.init(source, context.allocator)
    parser.parse(&p)
    // parser.print_program(&p)

    // parser.normalize(&p)
    // parser.print_program(&p)
}
