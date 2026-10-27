# Tokenizer

## Lexical rules

Whitespace and `//` line comments are skipped.

| Token | Lexical form |
| --- | --- |
| Identifier | `[A-Za-z_][A-Za-z0-9_]*` |
| Integer | `[0-9]+` |
| String | `"..."` (a backslash escapes the next rune) |
| Keywords | `def`, `decl`, `true`, `false` |
| Punctuation and operators | `(` `)` `,` `;` `:` `=` `!=` `<` `<=` `>` `>=` `+` `-` `*` `/` `%` `^` |

Keywords are recognized only when the whole identifier matches. For example,
`false` is a keyword, while `false123` is an identifier. String token values
retain their escape characters.

## Errors

After `next_token` returns an `ERROR` token, the tokenizer remains in an error
state: each subsequent call returns `ERROR:PREV_ERR`. `tokenize_input` stops at
the first error. Whether tokenization should continue after an error is still
to be decided.

## Planned additions

- Underscores in integers, such as `1_000_000`
- Hexadecimal and octal integers
- Floating-point numbers
- Raw strings
