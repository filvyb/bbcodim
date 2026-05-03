import unittest
import bbcodim/lexer
import bbcodim/parser

proc parseStr(s: string): seq[Node] = parse(tokenize(s))

suite "parser":
  test "plain text -> single text node":
    let nodes = parseStr("hello")
    check nodes.len == 1
    check nodes[0].kind == nkText
    check nodes[0].text == "hello"

  test "simple element with text child":
    let nodes = parseStr("[b]hi[/b]")
    check nodes.len == 1
    check nodes[0].kind == nkElement
    check nodes[0].name == "b"
    check nodes[0].children.len == 1
    check nodes[0].children[0].kind == nkText
    check nodes[0].children[0].text == "hi"

  test "nested elements":
    let nodes = parseStr("[b]hi [i]there[/i][/b]")
    check nodes.len == 1
    let b = nodes[0]
    check b.kind == nkElement and b.name == "b"
    check b.children.len == 2
    check b.children[0].kind == nkText
    check b.children[1].kind == nkElement
    check b.children[1].name == "i"
    check b.children[1].children[0].text == "there"

  test "attribute is preserved on element":
    let nodes = parseStr("[url=https://x.test]y[/url]")
    check nodes[0].kind == nkElement
    check nodes[0].name == "url"
    check nodes[0].hasValue == true
    check nodes[0].value == "https://x.test"

  test "stray close tag becomes literal text":
    let nodes = parseStr("a[/b]c")
    check nodes.len == 3
    check nodes[0].kind == nkText and nodes[0].text == "a"
    check nodes[1].kind == nkText and nodes[1].text == "[/b]"
    check nodes[2].kind == nkText and nodes[2].text == "c"

  test "unclosed open tag at EOF: tag becomes literal, children float up":
    let nodes = parseStr("[b]hi")
    check nodes.len == 2
    check nodes[0].kind == nkText and nodes[0].text == "[b]"
    check nodes[1].kind == nkText and nodes[1].text == "hi"

  test "interleaved mismatch: outer close found, inner open becomes literal":
    # [b][i]hi[/b]  -> b is the matched close; i is unwound as literal "[i]"
    # ending result: b element containing literal "[i]" then "hi"
    let nodes = parseStr("[b][i]hi[/b]")
    check nodes.len == 1
    let b = nodes[0]
    check b.kind == nkElement and b.name == "b"
    check b.children.len == 2
    check b.children[0].kind == nkText and b.children[0].text == "[i]"
    check b.children[1].kind == nkText and b.children[1].text == "hi"

  test "empty tag has no children":
    let nodes = parseStr("[b][/b]")
    check nodes.len == 1
    check nodes[0].kind == nkElement and nodes[0].name == "b"
    check nodes[0].children.len == 0

  test "same tag nested in itself":
    let nodes = parseStr("[b][b]hi[/b][/b]")
    check nodes.len == 1
    let outer = nodes[0]
    check outer.kind == nkElement and outer.name == "b"
    check outer.children.len == 1
    let inner = outer.children[0]
    check inner.kind == nkElement and inner.name == "b"
    check inner.children[0].kind == nkText and inner.children[0].text == "hi"

  test "multiple sibling top-level elements":
    let nodes = parseStr("[b]a[/b][i]b[/i]")
    check nodes.len == 2
    check nodes[0].kind == nkElement and nodes[0].name == "b"
    check nodes[1].kind == nkElement and nodes[1].name == "i"

  test "many stray closes all degrade to literal text":
    let nodes = parseStr("[/x][/y][/z]")
    check nodes.len == 3
    for n in nodes:
      check n.kind == nkText
    check nodes[0].text == "[/x]"
    check nodes[1].text == "[/y]"
    check nodes[2].text == "[/z]"

  test "deeply nested elements (50 levels)":
    var bb = ""
    for i in 0 ..< 50: bb.add("[b]")
    bb.add("x")
    for i in 0 ..< 50: bb.add("[/b]")
    let nodes = parseStr(bb)
    check nodes.len == 1
    var depth = 0
    var cur = nodes[0]
    while cur.kind == nkElement and cur.children.len == 1 and
          cur.children[0].kind == nkElement:
      cur = cur.children[0]
      inc depth
    check depth == 49  # 50 elements means 49 nesting steps

  test "list with star items parses as nested elements":
    # No structural rewriting in the parser; renderer will normalize list items.
    let nodes = parseStr("[list][*]a[*]b[/list]")
    check nodes.len == 1
    let lst = nodes[0]
    check lst.kind == nkElement and lst.name == "list"
    # The bare `[*]` tags don't have closes, so they'll be unwound as literal
    # text plus their children when [/list] closes.
    var sawStar = false
    for c in lst.children:
      if c.kind == nkText and c.text == "[*]":
        sawStar = true
    check sawStar
