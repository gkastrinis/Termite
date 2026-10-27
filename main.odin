package termite

import "core:fmt"
import "core:os"
import "core:strings"

import parser "./parser"
import tokenizer "./tokenizer"

main :: proc() {
    input := `false def defa`
    reader := strings.Reader{s = input}
    stream := strings.reader_to_stream(&reader)
    tok := tokenizer.init(stream, context.allocator)
    for {
        t := tokenizer.next_token(&tok)
        fmt.println(t)
        if t.Kind == .EOF || t.Kind == .ERROR { break }
    }
}

// main :: proc() {
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
    // fmt.printf("\x1b[30m30\x1b[0m\n")
    // fmt.printf("\x1b[31m31\x1b[0m\n")
    // fmt.printf("\x1b[32m32\x1b[0m\n")
    // fmt.printf("\x1b[33m33\x1b[0m\n")
    // fmt.printf("\x1b[34m34\x1b[0m\n")
    // fmt.printf("\x1b[35m35\x1b[0m\n")
    // fmt.printf("\x1b[40m40\x1b[0m\n")
    // fmt.printf("\x1b[41m41\x1b[0m\n")
    //
    // fmt.print("\x1b[38;5;196mred ")
    // fmt.print("\x1b[38;5;208morange ")
    // fmt.print("\x1b[38;5;226myellow ")
    // fmt.print("\x1b[38;5;46mgreen ")
    // fmt.print("\x1b[38;5;51mblue ")
    // fmt.print("\x1b[38;5;57mindigo ")
    // fmt.print("\x1b[38;5;201mviolet\x1b[0m\n")
    // fmt.println()
    // type_inference(&parser)
    // fmt.println("----------------------------")
    // print_program(&parser)
// }

// Void :: struct{}
//
// type_inference :: proc(parser: ^Parser) {
//     IntSet :: map[u16]Void
//     rel_to_rules := make(map[string]IntSet)
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
