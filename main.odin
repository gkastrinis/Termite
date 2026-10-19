package termite

import "core:fmt"
import "core:os"

main :: proc() {
    tok := Tokenizer{stream=os.to_stream(os.stdin), s=State.CLEAN}
    parser := Parser{tokenizer=&tok, relations= make(map[string]Relation)}

    for {
        t := tokenizer_next_token(&tok)
        if t.kind == Kind.EOF {
            fmt.printf("\x1b[33m<EOF>\x1b[0m\n")
            break

        } else if t.kind == .K_DECL {
            parser__decl(&parser)
        } else if t.kind == .K_DEF {
            parser__def(&parser)

        } else if t.kind == Kind.STRING {
            fmt.printf("\"%v\"\x1b[0m \x1b[30m<%v> \x1b[0m", t.val, t.kind)
        } else {
            fmt.printf("%v\x1b[0m \x1b[30m<%v> \x1b[0m", t.val, t.kind)
        }
    }
}
