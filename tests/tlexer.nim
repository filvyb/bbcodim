import unittest
import bbcodim/lexer

suite "lexer":
  test "plain text becomes a single text token":
    let toks = tokenize("hello world")
    check toks.len == 1
    check toks[0].kind == tkText
    check toks[0].text == "hello world"

  test "empty input yields no tokens":
    check tokenize("").len == 0

  test "simple open and close tag":
    let toks = tokenize("[b]hi[/b]")
    check toks.len == 3
    check toks[0].kind == tkOpenTag
    check toks[0].name == "b"
    check toks[0].hasValue == false
    check toks[1].kind == tkText
    check toks[1].text == "hi"
    check toks[2].kind == tkCloseTag
    check toks[2].closeName == "b"

  test "tag names are lowercased":
    let toks = tokenize("[B][/B]")
    check toks[0].kind == tkOpenTag and toks[0].name == "b"
    check toks[1].kind == tkCloseTag and toks[1].closeName == "b"

  test "attribute value, unquoted":
    let toks = tokenize("[url=https://example.com]x[/url]")
    check toks[0].kind == tkOpenTag
    check toks[0].name == "url"
    check toks[0].hasValue == true
    check toks[0].value == "https://example.com"

  test "attribute value, quoted, may contain ]":
    let toks = tokenize("""[url="a]b"]x[/url]""")
    check toks[0].kind == tkOpenTag
    check toks[0].value == "a]b"
    check toks[0].hasValue == true

  test "empty attribute (trailing =)":
    let toks = tokenize("[color=]x[/color]")
    check toks[0].kind == tkOpenTag
    check toks[0].name == "color"
    check toks[0].hasValue == true
    check toks[0].value == ""

  test "list-item star tag":
    let toks = tokenize("[*]item")
    check toks[0].kind == tkOpenTag
    check toks[0].name == "*"
    check toks[1].kind == tkText and toks[1].text == "item"

  test "unterminated tag is treated as literal text":
    let toks = tokenize("[b unterminated")
    check toks.len == 1
    check toks[0].kind == tkText
    check toks[0].text == "[b unterminated"

  test "lonely bracket and empty brackets":
    let toks = tokenize("a [ b [] c")
    check toks.len == 1
    check toks[0].kind == tkText
    check toks[0].text == "a [ b [] c"

  test "unterminated quoted attribute is literal":
    let toks = tokenize("""[url="oops]hi""")
    check toks.len == 1
    check toks[0].kind == tkText

  test "text around tags is preserved verbatim":
    let toks = tokenize("a[b]B[/b]c")
    check toks.len == 5
    check toks[0].kind == tkText and toks[0].text == "a"
    check toks[4].kind == tkText and toks[4].text == "c"

  test "numeric-only tag name is allowed":
    let toks = tokenize("[h1]x[/h1]")
    check toks[0].kind == tkOpenTag and toks[0].name == "h1"
    check toks[2].kind == tkCloseTag and toks[2].closeName == "h1"

  test "incidental bracket like arr[0] tokenizes as text + open":
    let toks = tokenize("arr[0]")
    check toks.len == 2
    check toks[0].kind == tkText and toks[0].text == "arr"
    check toks[1].kind == tkOpenTag and toks[1].name == "0"

  test "close tag with stray attribute is rejected":
    let toks = tokenize("[/b=foo]")
    check toks.len == 1
    check toks[0].kind == tkText
    check toks[0].text == "[/b=foo]"

  test "single-quoted attribute value":
    let toks = tokenize("[url='https://x.test']y[/url]")
    check toks[0].kind == tkOpenTag
    check toks[0].value == "https://x.test"

  test "attribute value containing = is preserved":
    let toks = tokenize("[url=https://x.test/?a=1&b=2]y[/url]")
    check toks[0].kind == tkOpenTag
    check toks[0].value == "https://x.test/?a=1&b=2"

  test "attribute name is lowercased but value keeps case":
    let toks = tokenize("[Color=Red]x[/COLOR]")
    check toks[0].name == "color"
    check toks[0].value == "Red"
    check toks[1].kind == tkText and toks[1].text == "x"
    check toks[2].closeName == "color"

  test "whitespace inside the tag bracket disqualifies it":
    let toks = tokenize("[ b ]")
    check toks.len == 1
    check toks[0].kind == tkText
    check toks[0].text == "[ b ]"
