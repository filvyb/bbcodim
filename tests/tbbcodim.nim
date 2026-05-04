import unittest
import std/strutils
import bbcodim

suite "bbcodeToHtml: end-to-end":
  test "empty string":
    check bbcodeToHtml("") == ""

  test "plain text is escaped":
    check bbcodeToHtml("a < b") == "a &lt; b"

  test "kitchen sink":
    let bb = "Hello [b]world[/b]! See [url=https://example.com]this[/url]."
    check bbcodeToHtml(bb) ==
      "Hello <strong>world</strong>! See " &
      "<a href=\"https://example.com\">this</a>."

  test "deeply nested with attributes":
    let bb = "[quote=Alice][b]hi[/b] [color=#abcdef]friend[/color][/quote]"
    check bbcodeToHtml(bb) ==
      "<blockquote><cite>Alice</cite>" &
      "<strong>hi</strong> " &
      "<span style=\"color:#abcdef\">friend</span></blockquote>"

  test "list with mixed content":
    let bb = "[list][*]apples[*][b]bold pears[/b][*]grapes[/list]"
    check bbcodeToHtml(bb) ==
      "<ul><li>apples</li>" &
      "<li><strong>bold pears</strong></li>" &
      "<li>grapes</li></ul>"

  test "code block keeps bbcode literal":
    check bbcodeToHtml("[code]if x < 1 then [b]bold[/b][/code]") ==
      "<pre><code>if x &lt; 1 then [b]bold[/b]</code></pre>"

  test "malformed input degrades gracefully":
    # Unclosed [b], stray [/i], unknown tag — none of this should raise.
    let bb = "a [b] b [/i] c [foo]d[/foo] e"
    let h = bbcodeToHtml(bb)
    check h.len > 0
    check "<script" notin h

  test "no XSS via url, img, color, size, quote":
    # The renderer either produces sanitized HTML or falls back to literal
    # text where every `<`, `>`, `"`, `'`, `&` is escaped. Either way, no
    # *active* HTML attack surface should appear in the output.
    let attacks = @[
      "[url=javascript:alert(1)]x[/url]",
      "[url]javascript:alert(1)[/url]",
      "[img]javascript:alert(1)[/img]",
      "[img]\" onerror=\"alert(1)[/img]",
      "[color=red\" onmouseover=\"alert(1)]x[/color]",
      "[size=1\" onmouseover=\"alert(1)]x[/size]",
      "[quote=<script>alert(1)</script>]hi[/quote]",
    ]
    for atk in attacks:
      let h = bbcodeToHtml(atk)
      check "<script" notin h
      check "href=\"javascript" notin h.toLowerAscii()
      check "src=\"javascript" notin h.toLowerAscii()
      # An active event handler would require a literal `"` in the output.
      # Anything user-supplied should be `&quot;`-escaped instead.
      check "\" onerror=" notin h
      check "\" onmouseover=" notin h

  test "case-insensitive tag names":
    check bbcodeToHtml("[B][I]hi[/I][/B]") ==
      "<strong><em>hi</em></strong>"

  test "round-trip: nothing tag-shaped lost":
    # Unknown tags pass through as literal text - content must survive.
    let bb = "[foo]bar[/foo]"
    check bbcodeToHtml(bb) == "[foo]bar[/foo]"

  test "realistic forum post":
    let bb =
      "Hey [b]everyone[/b], check out " &
      "[url=https://example.com/page?q=1&r=2]this link[/url]!\n" &
      "[quote=Bob]I think [i]bbcode[/i] is neat.[/quote]\n" &
      "Pros:\n" &
      "[list][*]simple[*]safe[*]portable[/list]"
    let h = bbcodeToHtml(bb)
    check "<strong>everyone</strong>" in h
    check "<a href=\"https://example.com/page?q=1&amp;r=2\">this link</a>" in h
    check "<blockquote><cite>Bob</cite>" in h
    check "<em>bbcode</em>" in h
    check "<ul><li>simple</li><li>safe</li><li>portable</li></ul>" in h

  test "very long input does not crash and round-trips text":
    var bb = ""
    for i in 0 ..< 1000:
      bb.add("[b]x[/b]")
    let h = bbcodeToHtml(bb)
    check h.len > 0
    # 1000 <strong>x</strong> blocks
    check h.count("<strong>x</strong>") == 1000

  test "trailing unclosed tag does not lose its content":
    check bbcodeToHtml("hello [b]world") == "hello [b]world"

  test "stray attribute on close tag is literal":
    check bbcodeToHtml("[/b=foo]") == "[/b=foo]"

  test "single-quoted attribute value works end-to-end":
    check bbcodeToHtml("[url='https://x.test']y[/url]") ==
      "<a href=\"https://x.test\">y</a>"

  test "headings h1 through h6":
    check bbcodeToHtml("[h1]a[/h1]") == "<h1>a</h1>"
    check bbcodeToHtml("[h2]a[/h2]") == "<h2>a</h2>"
    check bbcodeToHtml("[h3]a[/h3]") == "<h3>a</h3>"
    check bbcodeToHtml("[h4]a[/h4]") == "<h4>a</h4>"
    check bbcodeToHtml("[h5]a[/h5]") == "<h5>a</h5>"
    check bbcodeToHtml("[h6]a[/h6]") == "<h6>a</h6>"

  test "heading content is escaped and may contain inline tags":
    check bbcodeToHtml("[h1]a < [b]b[/b][/h1]") ==
      "<h1>a &lt; <strong>b</strong></h1>"

  test "hr as void tag (no closing required)":
    check bbcodeToHtml("a[hr]b") == "a<hr>b"

  test "stray [/hr] is dropped silently":
    check bbcodeToHtml("a[/hr]b") == "ab"

  test "alignment tags":
    check bbcodeToHtml("[center]a[/center]") ==
      "<div style=\"text-align:center\">a</div>"
    check bbcodeToHtml("[left]a[/left]") ==
      "<div style=\"text-align:left\">a</div>"
    check bbcodeToHtml("[right]a[/right]") ==
      "<div style=\"text-align:right\">a</div>"
    check bbcodeToHtml("[align=justify]a[/align]") ==
      "<div style=\"text-align:justify\">a</div>"

  test "align with bogus value falls back to literal":
    check bbcodeToHtml("[align=evil\" onload=\"x]a[/align]") ==
      "[align=evil&quot; onload=&quot;x]a[/align]"

  test "sub and sup":
    check bbcodeToHtml("H[sub]2[/sub]O") == "H<sub>2</sub>O"
    check bbcodeToHtml("E=mc[sup]2[/sup]") == "E=mc<sup>2</sup>"

  test "spoiler with and without label":
    check bbcodeToHtml("[spoiler]boo[/spoiler]") ==
      "<details><summary>Spoiler</summary>boo</details>"
    check bbcodeToHtml("[spoiler=Ending]Bob dies[/spoiler]") ==
      "<details><summary>Ending</summary>Bob dies</details>"

  test "spoiler label is HTML-escaped":
    let h = bbcodeToHtml("[spoiler=<script>]x[/spoiler]")
    check "<script>" notin h
    check "&lt;script&gt;" in h

  test "aliases: strong/em/strike":
    check bbcodeToHtml("[strong]a[/strong]") == "<strong>a</strong>"
    check bbcodeToHtml("[em]a[/em]") == "<em>a</em>"
    check bbcodeToHtml("[strike]a[/strike]") == "<s>a</s>"

suite "bbcodeToMarkdown: end-to-end":
  test "empty string":
    check bbcodeToMarkdown("") == ""

  test "kitchen sink":
    let bb = "Hello [b]world[/b]! See [url=https://example.com]this[/url]."
    check bbcodeToMarkdown(bb) ==
      "Hello **world**! See [this](https://example.com)."

  test "realistic forum post round-trips key elements":
    let bb =
      "Hey [b]everyone[/b], check out " &
      "[url=https://example.com/page?q=1]this link[/url]!\n" &
      "[quote=Bob]I think [i]bbcode[/i] is neat.[/quote]\n" &
      "Pros:\n" &
      "[list][*]simple[*]safe[*]portable[/list]"
    let md = bbcodeToMarkdown(bb)
    check "**everyone**" in md
    check "[this link](https://example.com/page?q=1)" in md
    check "> **Bob:**" in md
    check "*bbcode*" in md
    check "- simple\n- safe\n- portable" in md

  test "malformed input degrades gracefully":
    let bb = "a [b] b [/i] c [foo]d[/foo] e"
    let md = bbcodeToMarkdown(bb)
    check md.len > 0
    check "<script" notin md

  test "case-insensitive tag names":
    check bbcodeToMarkdown("[B][I]hi[/I][/B]") == "***hi***"
