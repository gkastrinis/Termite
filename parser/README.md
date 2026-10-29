# Parser

This package parses expressions and rule definitions using tokens from the
`tokenizer` package. `parse_expr` parses one expression into an `Expr` tree.
`parse` reads a program made of rule definitions and stores them in `Parser`.
An expression has a `kind`, an operator or value in `op`, and child expressions
in `args`.

## Expression operators

Higher precedence levels bind more tightly.

| Precedence | Operators | Associativity |
| ---: | --- | --- |
| 1 | OR (`;`) | left |
| 2 | AND (`,`) | left |
| 3 | `=`, `!=`, `<`, `<=`, `>`, `>=` | non-associative |
| 4 | `+`, `-` | left |
| 5 | `*`, `/`, `%` | left |
| 6 | unary `-` | prefix |
| 7 | `^` | right |

The expression grammar is:

```text
Expr           = Or_Expr ;
Or_Expr        = And_Expr, { ";", And_Expr } ;
And_Expr       = Comparison_Expr, { ",", Comparison_Expr } ;
Comparison_Expr = Arithmetic_Expr, [ Compare_Op, Arithmetic_Expr ] ;
Arithmetic_Expr = Add_Expr ;
Add_Expr       = Multiply_Expr, { ("+" | "-"), Multiply_Expr } ;
Multiply_Expr  = Unary_Expr, { ("*" | "/" | "%"), Unary_Expr } ;
Unary_Expr     = "-", Unary_Expr | Power_Expr ;
Power_Expr     = Primary, [ "^", Unary_Expr ] ;
Primary        = "(", Expr, ")"
               | Lookup
               | Integer
               | String
               | Identifier ;
Lookup         = Identifier, "(", [ Arithmetic_Expr, { ",", Arithmetic_Expr } ], ")" ;
Compare_Op     = "=" | "!=" | "<" | "<=" | ">" | ">=" ;
```

In this language, `;` means OR and `,` means AND. Unparenthesized lookup
arguments parse at arithmetic precedence, with commas separating arguments.
Parentheses can enclose a full expression. Nested lookups are currently
disallowed, including inside parentheses. `true` and `false` are recognized by
the tokenizer, but are not currently accepted as expressions by the parser.

The parser flattens repeated same-kind AND and OR operators into one expression
node with multiple `args`. Precedence and parentheses preserve nested groups.

## Rule definitions

The program parser currently accepts definitions in this form:

```text
Program       = { Rule } ;
Rule          = "def", Atom, { ",", Atom }, ":", Expr ;
Atom          = Identifier, "(", [ Arithmetic_Expr, { ",", Arithmetic_Expr } ], ")" ;
```

For example:

```text
def parent(x, y), ancestor(x, z) : parent(x, y), ancestor(y, z)
```

`decl` is tokenized, but declaration parsing is not implemented. Syntax errors
currently use assertions or panics, and chained comparisons or trailing input
are not yet reported as structured parse errors. `parse_expr` parses one
expression; it does not expose a full-input validation result.

`print_expr` and `print_program` are debug-oriented colored printers.
