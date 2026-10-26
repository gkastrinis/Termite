package parser

import "core:fmt"

// print_relation :: proc(rel: Relation) {
//     fmt.printf("   \x1b[34m%v\x1b[30m/%v\x1b[0m (", rel.name, rel.arity)
//     for i in 0..<len(rel.fields) {
//         if i != 0 { fmt.printf("\x1b[30m, \x1b[0m") }
//         fld, type := rel.fields[i], rel.types[i]
//         fmt.printf("\x1b[30m%v\x1b[0m:", fld)
//         if type == "Any" {
//             fmt.printf("\x1b[45m%v\x1b[0m", type)
//         } else {
//             fmt.printf("\x1b[35m%v\x1b[0m", type)
//         }
//     }
//     fmt.println(")")
// }
//
// print_rule :: proc(rule: Rule) {
//     for e in rule.head {
//         fmt.printf("   -> ")
//         print_expr(e)
//         fmt.println()
//     }
//     for e in rule.body {
//         fmt.print("   ")
//         print_expr(e)
//         fmt.println()
//     }
// }
//
// print_program :: proc(parser: ^Parser) {
//     for rule in parser.rules {
//         fmt.printf("\x1b[30m#%v\x1b[0m\n", rule.id)
//         print_rule(rule)
//     }
//     fmt.printf("\x1b[30m\nRelations\x1b[0m\n")
//     for _, rel in parser.declared {
//         print_relation(rel)
//     }
//     for _, rel in parser.inferred {
//         print_relation(rel)
//     }
// }
    // if e.kind == .ATOM {
    //     fmt.printf("\x1b[32m%v\x1b[0m(", e.op)
    //     for i in 0..<len(e.args) {
    //         if i != 0 { fmt.print(", ") }
    //         print_expr(e.args[i])
    //     }
    //     fmt.print(")")


// print_expr :: proc(e: ^Expr) {
//     if e.kind == .INT {
//         fmt.printf("\x1b[32m%v\x1b[30m:%v\x1b[0m", e.op, e.type)
//     } else if e.kind == .STRING {
//         fmt.printf("\x1b[32m\"%v\"\x1b[30m:%v\x1b[0m", e.op, e.type)
//     } else if e.kind == .VAR {
//         fmt.printf("\x1b[33m%v\x1b[30m:%v\x1b[0m", e.op, e.type)
//     } else if e.kind == .BINARY {
//         fmt.print("(")
//         print_expr(e.lhs)
//         fmt.printf(" %v ", e.op)
//         print_expr(e.rhs)
//         fmt.print(")")
//     } else if e.kind == .UNARY {
//         fmt.print("-(")
//         print_expr(e.lhs)
//         fmt.print(")")
//     }
// }

to_S_expression :: proc(e: ^Expr) -> string {
    if e.kind == .INT || e.kind == .STRING || e.kind == .VAR {
        return fmt.tprintf("%v", e.op)
    } else if e.kind == .BINARY {
        return fmt.tprintf("(%v %v %v)", to_S_expression(e.lhs), e.op, to_S_expression(e.rhs))
    } else if e.kind == .UNARY {
        return fmt.tprintf("-(%v)", to_S_expression(e.lhs))
    }
    unreachable()
}
