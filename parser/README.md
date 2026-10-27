# Parser

## Expression grammar

The expression grammar uses the precedence levels below. Higher levels bind
more tightly. Unary minus is parsed separately from the binary operators;
level 3 describes its binding strength between multiplication and exponentiation.

| Precedence | Rule |
| ---: | --- |
| 0 | `Expr = AddExpr` |
| 1 | `AddExpr = MultExpr, { ("+" \| "-"), MultExpr }` |
| 2 | `MultExpr = UnaryExpr, { ("*" \| "/" \| "%"), UnaryExpr }` |
| 3 | `UnaryExpr = "-", UnaryExpr \| ExpExpr` |
| 4 | `ExpExpr = Primary, [ "^", UnaryExpr ]` |
| 5 | `Primary = "(", Expr, ")" \| Literal \| Variable` |

Here, `Literal` is an integer or string, and `Variable` is an identifier.
The parser implements unary `-` only. The gap in `precedence` values reserves
level 3 for unary minus; parsing its operand with minimum precedence 4 lets
exponentiation bind more tightly, so `-a ^ b` parses as `-(a ^ b)`.
