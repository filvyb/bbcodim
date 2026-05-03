import unittest
import std/strutils
import bbcodim/lexer
import bbcodim/parser
import bbcodim/renderer

proc r(s: string): string = render(parse(tokenize(s)))

suite "renderer: basic formatting":
  test "plain text is escaped":
    check r("a < b & c > d") == "a &lt; b &amp; c &gt; d"

  test "bold/italic/underline/strike":
    check r("[b]a[/b]") == "<strong>a</strong>"
    check r("[i]a[/i]") == "<em>a</em>"
    check r("[u]a[/u]") == "<u>a</u>"
    check r("[s]a[/s]") == "<s>a</s>"

  test "nested formatting":
    check r("[b]hi [i]you[/i][/b]") ==
      "<strong>hi <em>you</em></strong>"

suite "renderer: links and images":
  test "url with attribute":
    check r("[url=https://example.com]click[/url]") ==
      "<a href=\"https://example.com\">click</a>"

  test "url without attribute uses inner text":
    check r("[url]https://example.com[/url]") ==
      "<a href=\"https://example.com\">https://example.com</a>"

  test "javascript: url is rejected and rendered as literal":
    let h = r("[url=javascript:alert(1)]x[/url]")
    check h == "[url=javascript:alert(1)]x[/url]"
    check "javascript:" notin h or "<a" notin h  # belt-and-suspenders

  test "url with attribute-breakout chars is rejected":
    let evil = "[url=\"x\" onclick=\"alert(1)]y[/url]"
    let h = r(evil)
    check "<a" notin h

  test "img with valid url":
    check r("[img]https://example.com/x.png[/img]") ==
      "<img src=\"https://example.com/x.png\" alt=\"\">"

  test "img with javascript url is rejected":
    let h = r("[img]javascript:alert(1)[/img]")
    check "<img" notin h

  test "img with HTML-injection content is rejected":
    let h = r("[img]\"><script>alert(1)</script>[/img]")
    check "<img" notin h
    check "<script" notin h

suite "renderer: color/size":
  test "named color":
    check r("[color=red]x[/color]") ==
      "<span style=\"color:red\">x</span>"

  test "hex color":
    check r("[color=#ff00aa]x[/color]") ==
      "<span style=\"color:#ff00aa\">x</span>"

  test "invalid color falls back to literal":
    let h = r("[color=red;background:url(javascript:1)]x[/color]")
    check "<span" notin h
    check "style=" notin h

  test "size in valid range":
    check r("[size=14]x[/size]") ==
      "<span style=\"font-size:14px\">x</span>"

  test "size out of range falls back":
    let h = r("[size=999]x[/size]")
    check "<span" notin h

  test "non-numeric size falls back":
    let h = r("[size=14px]x[/size]")
    check "<span" notin h

suite "renderer: quote and code":
  test "quote without attribution":
    check r("[quote]hi[/quote]") == "<blockquote>hi</blockquote>"

  test "quote with attribution":
    check r("[quote=Bob]hi[/quote]") ==
      "<blockquote><cite>Bob</cite>hi</blockquote>"

  test "quote attribution is escaped":
    check r("[quote=<x>]hi[/quote]") ==
      "<blockquote><cite>&lt;x&gt;</cite>hi</blockquote>"

  test "code preserves inner bbcode literally and escapes html":
    check r("[code][b]<hi>[/b][/code]") ==
      "<pre><code>[b]&lt;hi&gt;[/b]</code></pre>"

suite "renderer: lists":
  test "unordered list with star markers":
    check r("[list][*]a[*]b[/list]") ==
      "<ul><li>a</li><li>b</li></ul>"

  test "ordered list":
    check r("[list=1][*]a[*]b[/list]") ==
      "<ol><li>a</li><li>b</li></ol>"

  test "list items can contain formatting":
    check r("[list][*][b]a[/b][*]b[/list]") ==
      "<ul><li><strong>a</strong></li><li>b</li></ul>"

suite "renderer: unknown / mismatched":
  test "unknown tag rendered literally":
    check r("[foo]bar[/foo]") == "[foo]bar[/foo]"

  test "stray close tag":
    check r("a[/b]") == "a[/b]"

  test "literal angle brackets in text":
    check r("<script>") == "&lt;script&gt;"

  test "unknown tag with attribute is escaped":
    check r("[foo=<x>]y[/foo]") == "[foo=&lt;x&gt;]y[/foo]"

suite "renderer: edge cases":
  test "empty input renders as empty string":
    check r("") == ""

  test "whitespace-only input is preserved":
    check r("   \t\n ") == "   \t\n "

  test "empty element renders with empty body":
    check r("[b][/b]") == "<strong></strong>"

  test "empty list renders as empty <ul>":
    check r("[list][/list]") == "<ul></ul>"

  test "empty code renders as empty <pre><code>":
    check r("[code][/code]") == "<pre><code></code></pre>"

  test "short hex color (#abc)":
    check r("[color=#abc]x[/color]") ==
      "<span style=\"color:#abc\">x</span>"

  test "color with mixed case alpha is accepted":
    check r("[color=Red]x[/color]") ==
      "<span style=\"color:Red\">x</span>"

  test "mailto url":
    check r("[url=mailto:a@b.test]e[/url]") ==
      "<a href=\"mailto:a@b.test\">e</a>"

  test "protocol-relative url":
    check r("[url=//example.com/x]y[/url]") ==
      "<a href=\"//example.com/x\">y</a>"

  test "absolute path (relative URL)":
    check r("[url=/local/path]y[/url]") ==
      "<a href=\"/local/path\">y</a>"

  test "ampersand in url query is escaped":
    check r("[url=https://x.test/?a=1&b=2]q[/url]") ==
      "<a href=\"https://x.test/?a=1&amp;b=2\">q</a>"

  test "empty url attribute falls back to literal":
    check r("[url=]hi[/url]") == "[url=]hi[/url]"

  test "ftp scheme is rejected":
    check "<a" notin r("[url=ftp://x.test]y[/url]")

  test "data: scheme is rejected":
    check "<a" notin r("[url=data:text/html,<script>1</script>]y[/url]")

  test "code block with html and quotes inside":
    check r("[code]<div class=\"x\">hi</div>[/code]") ==
      "<pre><code>&lt;div class=&quot;x&quot;&gt;hi&lt;/div&gt;</code></pre>"

  test "nested lists":
    check r("[list][*][list][*]inner[/list][/list]") ==
      "<ul><li><ul><li>inner</li></ul></li></ul>"

  test "list content before first [*] is dropped":
    check r("[list]intro[*]a[*]b[/list]") ==
      "<ul><li>a</li><li>b</li></ul>"

  test "two sibling top-level elements":
    check r("[b]a[/b][i]b[/i]") ==
      "<strong>a</strong><em>b</em>"

  test "same tag nested in itself":
    check r("[b][b]hi[/b][/b]") ==
      "<strong><strong>hi</strong></strong>"

  test "unicode text passes through unchanged":
    check r("[b]héllo 你好 🎉[/b]") ==
      "<strong>héllo 你好 🎉</strong>"

  test "incidental [0] in text is preserved verbatim":
    check r("arr[0]") == "arr[0]"
