# Parser

## Expression grammar

Higher precedence levels bind more tightly.

| Precedence | Operators |
| ---: | --- |
| 1 | OR (`;`) |
| 2 | AND (`,`) |
| 3 | Comparisons: `=`, `!=`, `<`, `<=`, `>`, `>=` |
| 4 | `+`, `-` |
| 5 | `*`, `/`, `%` |
| 6 | Unary `-` |
| 7 | `^` |

The grammar can be written by precedence level:

```text
Expr        = OrExpr ;
OrExpr      = AndExpr, { OR, AndExpr } ;
AndExpr     = CompareExpr, { AND, CompareExpr } ;
CompareExpr = AddExpr, [ CompareOp, AddExpr ] ;
AddExpr     = MultExpr, { ("+" | "-"), MultExpr } ;
MultExpr    = UnaryExpr, { ("*" | "/" | "%"), UnaryExpr } ;
UnaryExpr   = "-", UnaryExpr | PowerExpr ;
PowerExpr   = Primary, [ "^", UnaryExpr ] ;
Primary     = "(", Expr, ")"
            | Lookup
            | Literal
            | Variable ;
Lookup      = ID, "(", [ Expr, { ",", Expr } ], ")" ;
```

`Literal` is an integer or string, and `Variable` is an identifier. `OR` is
written `;` and `AND` is written `,` in the input language.
