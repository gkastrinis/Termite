package termite

import "core:fmt"
import "core:os"

main :: proc() {
    parser := parser_init(os.to_stream(os.stdin))
    parse(&parser)
    for rule in parser.rules {
        print_rule(rule)
        fmt.println("----------------------------")
    }
    for _, rel in parser.relations {
        print_relation(rel)
    }
    fmt.println("----------------------------")
    fmt.printf("\x1b[30m30\x1b[0m\n")
    fmt.printf("\x1b[31m31\x1b[0m\n")
    fmt.printf("\x1b[32m32\x1b[0m\n")
    fmt.printf("\x1b[33m33\x1b[0m\n")
    fmt.printf("\x1b[34m34\x1b[0m\n")
    fmt.printf("\x1b[35m35\x1b[0m\n")
    fmt.printf("\x1b[36m36\x1b[0m\n")
    fmt.printf("\x1b[40m40\x1b[0m\n")
    fmt.printf("\x1b[41m41\x1b[0m\n")
    type_inference(&parser)
    fmt.println("----------------------------")
    for _, rel in parser.relations {
        print_relation(rel)
    }
}

type_inference :: proc(parser: ^Parser) {

}
