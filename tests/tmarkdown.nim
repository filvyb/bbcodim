import unittest
import std/strutils
import bbcodim/lexer
import bbcodim/parser
import bbcodim/markdown

proc m(s: string): string = renderMarkdown(parse(tokenize(s)))

suite "markdown: basic formatting":
  test "plain text passes through":
    check m("hello world") == "hello world"

  test "markdown specials in plain text are escaped":
    check m("a *b* _c_ `d` [e]") ==
      "a \\*b\\* \\_c\\_ \\`d\\` \\[e\\]"

  test "backslash in plain text is escaped":
    check m("a\\b") == "a\\\\b"

  test "bold / italic / strike":
    check m("[b]a[/b]") == "**a**"
    check m("[i]a[/i]") == "*a*"
    check m("[s]a[/s]") == "~~a~~"

  test "underline drops the wrapper (no portable Markdown for it)":
    check m("[u]a[/u]") == "a"

  test "color drops the wrapper":
    check m("[color=red]hi[/color]") == "hi"

  test "size drops the wrapper":
    check m("[size=14]hi[/size]") == "hi"

  test "nested formatting":
    check m("[b]hi [i]you[/i][/b]") == "**hi *you***"

suite "markdown: links and images":
  test "url with attribute":
    check m("[url=https://example.com]click[/url]") ==
      "[click](https://example.com)"

  test "url without attribute autolinks":
    check m("[url]https://example.com[/url]") ==
      "<https://example.com>"

  test "url text is markdown-escaped":
    check m("[url=https://x.test]see [more][/url]") ==
      "[see \\[more\\]](https://x.test)"

  test "parens in url target are percent-encoded":
    check m("[url=https://x.test/a(b)c]p[/url]") ==
      "[p](https://x.test/a%28b%29c)"

  test "javascript: url is rejected and rendered as literal":
    let md = m("[url=javascript:alert(1)]x[/url]")
    check "javascript:" in md
    check md.startsWith("\\[url=") # literal fallback uses escaped brackets

  test "ampersand in url passes through unmangled":
    check m("[url=https://x.test/?a=1&b=2]q[/url]") ==
      "[q](https://x.test/?a=1&b=2)"

  test "img with valid url":
    check m("[img]https://example.com/x.png[/img]") ==
      "![](https://example.com/x.png)"

  test "img with javascript url falls back to literal":
    let md = m("[img]javascript:alert(1)[/img]")
    check "![" notin md
    check md.startsWith("\\[img\\]")

  test "mailto url":
    check m("[url=mailto:a@b.test]e[/url]") ==
      "[e](mailto:a@b.test)"

  test "empty url attribute falls back to literal":
    check m("[url=]hi[/url]") == "\\[url=\\]hi\\[/url\\]"

suite "markdown: quote":
  test "simple quote":
    check m("[quote]hi[/quote]") == "> hi"

  test "multi-line quote prefixes every line":
    check m("[quote]a\nb\nc[/quote]") == "> a\n> b\n> c"

  test "quote with attribution":
    check m("[quote=Bob]hi[/quote]") == "> **Bob:**\n> hi"

  test "quote attribution is markdown-escaped":
    check m("[quote=*hax*]hi[/quote]") == "> **\\*hax\\*:**\n> hi"

  test "nested quotes get nested prefixes":
    check m("[quote][quote]hi[/quote][/quote]") == "> > hi"

suite "markdown: code":
  test "code preserves bbcode literally":
    check m("[code][b]<hi>[/b][/code]") ==
      "```\n[b]<hi>[/b]\n```"

  test "code with no markdown escaping inside":
    check m("[code]a *b* _c_[/code]") ==
      "```\na *b* _c_\n```"

  test "code with embedded triple backticks bumps the fence":
    check m("[code]```\nhi\n```[/code]") ==
      "````\n```\nhi\n```\n````"

  test "empty code":
    check m("[code][/code]") == "```\n\n```"

suite "markdown: lists":
  test "unordered list":
    check m("[list][*]a[*]b[/list]") == "- a\n- b"

  test "ordered list":
    check m("[list=1][*]a[*]b[/list]") == "1. a\n2. b"

  test "list items can contain formatting":
    check m("[list][*][b]a[/b][*]b[/list]") == "- **a**\n- b"

  test "content before first marker is dropped":
    check m("[list]intro[*]a[*]b[/list]") == "- a\n- b"

  test "empty list":
    check m("[list][/list]") == ""

  test "nested lists indent under their parent item":
    let md = m("[list][*]outer[list][*]inner[/list][/list]")
    check md == "- outer\n\n  - inner"

  test "ordered list continuation uses three-space pad":
    let md = m("[list=1][*]a[list][*]b[/list][/list]")
    check md == "1. a\n\n   - b"

suite "markdown: headings":
  test "h1 through h6":
    check m("[h1]a[/h1]") == "# a"
    check m("[h2]a[/h2]") == "## a"
    check m("[h3]a[/h3]") == "### a"
    check m("[h4]a[/h4]") == "#### a"
    check m("[h5]a[/h5]") == "##### a"
    check m("[h6]a[/h6]") == "###### a"

  test "heading content is markdown-escaped and supports inline tags":
    check m("[h1][b]hi[/b] *raw*[/h1]") == "# **hi** \\*raw\\*"

  test "heading is a block: blank line separates from neighbours":
    check m("intro[h1]title[/h1]after") == "intro\n\n# title\n\nafter"

  test "two adjacent headings get a blank line between":
    check m("[h1]a[/h1][h2]b[/h2]") == "# a\n\n## b"

suite "markdown: hr / alignment / sub / sup / spoiler / aliases":
  test "hr as void tag becomes thematic break":
    check m("a[hr]b") == "a\n\n---\n\nb"

  test "hr without surrounding content":
    check m("[hr]") == "---"

  test "alignment tags drop wrapper":
    check m("[center]hi[/center]") == "hi"
    check m("[left]hi[/left]") == "hi"
    check m("[right]hi[/right]") == "hi"
    check m("[align=center]hi[/align]") == "hi"

  test "sub and sup drop wrapper":
    check m("H[sub]2[/sub]O") == "H2O"
    check m("E=mc[sup]2[/sup]") == "E=mc2"

  test "spoiler drops wrapper (and label)":
    check m("[spoiler]boo[/spoiler]") == "boo"
    check m("[spoiler=Ending]Bob dies[/spoiler]") == "Bob dies"

  test "aliases: strong/em/strike":
    check m("[strong]a[/strong]") == "**a**"
    check m("[em]a[/em]") == "*a*"
    check m("[strike]a[/strike]") == "~~a~~"

suite "markdown: unknown / mismatched":
  test "unknown tag rendered literally with markdown escapes":
    check m("[foo]bar[/foo]") == "\\[foo\\]bar\\[/foo\\]"

  test "stray close tag":
    check m("a[/b]") == "a\\[/b\\]"

  test "unclosed tag becomes literal":
    check m("hello [b]world") == "hello \\[b\\]world"

  test "unknown tag with attribute":
    check m("[foo=x]y[/foo]") == "\\[foo=x\\]y\\[/foo\\]"

suite "markdown: edge cases":
  test "empty input":
    check m("") == ""

  test "whitespace-only input is preserved":
    check m("   \t ") == "   \t "

  test "case-insensitive tag names":
    check m("[B][I]hi[/I][/B]") == "***hi***"

  test "unicode text passes through":
    check m("[b]héllo 你好 🎉[/b]") == "**héllo 你好 🎉**"

  test "two sibling block elements get a blank line between":
    check m("[quote]a[/quote][quote]b[/quote]") == "> a\n\n> b"

  test "inline before and after a block":
    let md = m("before [quote]q[/quote] after")
    # The block must start on its own line and be separated by a blank line.
    check "\n\n> q\n\n" in md

  test "no XSS: every `<` in attack output is backslash-escaped":
    let attacks = @[
      "[url=javascript:alert(1)]x[/url]",
      "[url]javascript:alert(1)[/url]",
      "[img]javascript:alert(1)[/img]",
      "[img]\" onerror=\"alert(1)[/img]",
      "[color=red\" onmouseover=\"alert(1)]x[/color]",
      "[quote=<script>alert(1)</script>]hi[/quote]",
    ]
    for atk in attacks:
      let md = m(atk)
      for i in 0 ..< md.len:
        if md[i] == '<':
          check i > 0 and md[i - 1] == '\\'
      check "<javascript:" notin md
