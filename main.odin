package termite

import "core:fmt"
import "core:os"

main :: proc() {
    parser := parser_init(os.to_stream(os.stdin))
    parse(&parser)
}
