# Tokenizer

The tokenizer reads an `io.Stream` and returns one `Token` at a time. Each token
has a `kind` from `Token_Kind` and a string `val`. It skips spaces, tabs, CR,
LF, and `//` line comments.

## Lexical rules

| Token | Lexical form |
| --- | --- |
| Identifier | `[A-Za-z_][A-Za-z0-9_]*` |
| Integer | `[0-9]+` |
| String | `"..."` (a backslash escapes the next rune) |
| Keywords | `def`, `decl`, `true`, `false` |
| Punctuation and operators | `(` `)` `,` `;` `:` `=` `!=` `<` `<=` `>` `>=` `+` `-` `*` `/` `%` `^` |

Identifiers and integers use ASCII characters. Keywords are recognized only
when the complete identifier matches: `false` is a keyword, while `false123` is
an identifier.

A string token's `val` excludes the surrounding quotes and retains its escape
characters. The backslash only controls whether the next quote closes the
string; escape sequences are not decoded.

## Errors and end of input

An invalid character or malformed token produces an `Error` token. After an
error, the tokenizer stays in an error state: subsequent calls return
`Error` with the value `PREV_ERR`. Callers should stop reading at the first
error.

A read error currently produces `End_Of_File`; the tokenizer does not yet
distinguish ordinary end of input from other stream errors.

## Parser compatibility

The tokenizer recognizes `true` and `false` as keyword tokens. The parser does
not currently accept them as expression operands. It also recognizes `decl`,
but declaration parsing has not been implemented.

## Planned additions

- Underscores in integers, such as `1_000_000`
- Hexadecimal and octal integers
- Floating-point numbers
- Raw strings
