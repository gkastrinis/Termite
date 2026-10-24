package tests

import "core:testing"
import "core:os"
import tokenizer ".."

@(test)
my_test :: proc(t: ^testing.T) {
    expected, err1 := os.read_entire_file_from_path(
        "tests/f1.tr.exp",
        context.allocator,
    )
    testing.expect_value(t, err1, os.ERROR_NONE)
    if err1 != os.ERROR_NONE { return }
    defer delete(expected)

    f, err2 := os.open("tests/f1.tr")
    testing.expect_value(t, err2, os.ERROR_NONE)
    if err2 != os.ERROR_NONE { return }
    defer os.close(f)

    tok := tokenizer.init(os.to_stream(f))
    defer tokenizer.destroy(&tok)
    actual := tokenizer.test(&tok)
    testing.expect_value(t, actual, string(expected))
    delete(actual)
}
