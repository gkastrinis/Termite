package termite

import "core:fmt"
import "core:os"
import tokenizer "./tokenizer"
import parser "./parser"

main :: proc() {
    parser_ := parser.init(os.to_stream(os.stdin))
    for {
        e := parser.parse_expr(&parser_, 0)
        // parser.print_expr(e)
        // fmt.println()
        s := parser.to_S_expression(e)
        fmt.println(s)
        if parser._peek(&parser_).Kind == tokenizer.TokenKind.EOF { break }
    }

    // parser.parse(&parser_)
    // parser.print_program(&parser_)
    // fmt.println("----------------------------")
    // fmt.printf("\x1b[30m30\x1b[0m\n")
    // fmt.printf("\x1b[31m31\x1b[0m\n")
    // fmt.printf("\x1b[32m32\x1b[0m\n")
    // fmt.printf("\x1b[33m33\x1b[0m\n")
    // fmt.printf("\x1b[34m34\x1b[0m\n")
    // fmt.printf("\x1b[35m35\x1b[0m\n")
    // fmt.printf("\x1b[40m40\x1b[0m\n")
    // fmt.printf("\x1b[41m41\x1b[0m\n")
    // fmt.println()
    // type_inference(&parser)
    // fmt.println("----------------------------")
    // print_program(&parser)
}

// Void :: struct{}
//
// type_inference :: proc(parser: ^Parser) {
//     IntSet :: map[u16]Void
//     rel_to_rules := make(map[string]IntSet)
//     defer delete(rel_to_rules)
//
//     for rule in parser.rules {
//         for e in rule.head {
//             assert(e.kind == .ATOM)
//             s := rel_to_rules[e.op] or_else make(IntSet)
//             s[rule.id] = Void{}
//             rel_to_rules[e.op] = s
//         }
//         for e in rule.body {
//             if e.kind != .ATOM { continue }
//             s := rel_to_rules[e.op] or_else make(IntSet)
//             s[rule.id] = Void{}
//             rel_to_rules[e.op] = s
//         }
//     }
//     for _, rel in parser.declared {
//         rules := rel_to_rules[rel.name]
//         for rule_id in rules {
//             rule := parser.rules[rule_id]
//             for atom in rule.head {
//                 if atom.op != rel.name { continue }
//                 for i in 0..<len(atom.args) {
//                     atom.args[i].type = rel.types[i]
//                 }
//             }
//             for atom in rule.body {
//                 if atom.op != rel.name { continue }
//                 for i in 0..<len(atom.args) {
//                     atom.args[i].type = rel.types[i]
//                 }
//             }
//         }
//     }
// }
