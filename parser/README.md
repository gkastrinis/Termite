# Parser

## Expression grammar

The expression grammar uses the precedence levels below. Higher levels bind
more tightly.

| Precedence | Rule |
| ---: | --- |
| 0 | `Expr = EqExpr` |
| 1 | `EqExpr = AddExpr, [ ("=" \| "!="), AddExpr ]` |
| 2 | `AddExpr = MultExpr, { ("+" \| "-"), MultExpr }` |
| 3 | `MultExpr = UnaryExpr, { ("*" \| "/" \| "%"), UnaryExpr }` |
| 4 | `UnaryExpr = ("+" \| "-"), UnaryExpr \| ExpExpr` |
| 5 | `ExpExpr = Primary, [ "^", UnaryExpr ]` |
| 6 | `Primary = "(", Expr, ")" \| Literal \| Variable` |

Here, `Literal` is an integer or string, and `Variable` is an identifier.
The grammar records unary `+` and `-`, though the current parser implements
unary `-` only.
