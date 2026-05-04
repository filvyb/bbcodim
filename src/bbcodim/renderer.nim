## Renderer: AST -> HTML.
##
## Security stance: all text is HTML-escaped on the way out, attribute values
## injected into href/src must pass a safe-URL check, and color/size values
## must pass strict validators before being inlined into a `style` attribute.
## Unknown or unsafe tags fall back to a literal `[tag]...[/tag]` rendering
## so user content is never silently dropped.

import std/strutils
import parser

proc htmlEscape*(s: string, sb: var string) =
  for c in s:
    case c
    of '&': sb.add "&amp;"
    of '<': sb.add "&lt;"
    of '>': sb.add "&gt;"
    of '"': sb.add "&quot;"
    of '\'': sb.add "&#39;"
    else: sb.add c

proc htmlEscape*(s: string): string =
  result = newStringOfCap(s.len)
  htmlEscape(s, result)

proc isSafeUrl*(s: string): bool =
  ## Reject anything that could break out of an href/src attribute, then only
  ## permit http/https/mailto schemes (or scheme-less relative URLs).
  if s.len == 0: return false
  for c in s:
    if c in {'<', '>', '"', '\'', ' ', '\t', '\n', '\r', '\\'}:
      return false
  var i = 0
  while i < s.len:
    let c = s[i]
    if c == ':':
      let scheme = s[0 ..< i].toLowerAscii()
      return scheme in ["http", "https", "mailto"]
    if c == '/' or c == '?' or c == '#':
      return true
    inc i
  return true

proc isValidColor*(s: string): bool =
  if s.len == 0: return false
  if s[0] == '#':
    if s.len != 4 and s.len != 7: return false
    for i in 1 ..< s.len:
      if s[i] notin HexDigits: return false
    return true
  for c in s:
    if not c.isAlphaAscii(): return false
  return true

proc isValidAlign*(s: string): bool =
  s.toLowerAscii() in ["left", "center", "right", "justify"]

proc isValidSize*(s: string): bool =
  if s.len == 0 or s.len > 3: return false
  for c in s:
    if c notin Digits: return false
  let n = parseInt(s)
  return n >= 1 and n <= 72

proc isValidEmail*(s: string): bool =
  ## Permissive but injection-safe: only an LDH-style local/domain charset
  ## (letters, digits, dot, underscore, hyphen, plus) plus exactly one `@`,
  ## and the domain must contain a dot. Anything fancier should use the `mailto:` form of `[url]`.
  if s.len == 0 or s.len > 254: return false
  var atCount = 0
  var atPos = -1
  for i, c in s:
    case c
    of '@':
      inc atCount
      atPos = i
    of 'a'..'z', 'A'..'Z', '0'..'9', '.', '_', '-', '+':
      discard
    else:
      return false
  if atCount != 1: return false
  if atPos == 0 or atPos == s.len - 1: return false
  return '.' in s[atPos + 1 ..< s.len]

proc parseImgSize*(s: string, width, height: var string): bool =
  ## `[img=WxH]` - both dimensions must be 1..4 digit positive integers.
  let parts = s.split('x')
  if parts.len != 2: return false
  if parts[0].len == 0 or parts[1].len == 0: return false
  if parts[0].len > 4 or parts[1].len > 4: return false
  for c in parts[0]:
    if c notin Digits: return false
  for c in parts[1]:
    if c notin Digits: return false
  width = parts[0]
  height = parts[1]
  return true

proc flattenToText*(n: Node, sb: var string) =
  ## Re-serialize a subtree to its BBCode-ish source, used for `[code]`
  ## bodies and for extracting the implicit href of `[url]raw[/url]`.
  case n.kind
  of nkText:
    sb.add(n.text)
  of nkElement:
    sb.add('[')
    sb.add(n.name)
    if n.hasValue:
      sb.add('=')
      sb.add(n.value)
    sb.add(']')
    for c in n.children:
      flattenToText(c, sb)
    sb.add("[/")
    sb.add(n.name)
    sb.add(']')

proc renderNode(n: Node, sb: var string)

proc renderChildren(children: seq[Node], sb: var string) =
  for c in children:
    renderNode(c, sb)

proc renderUnknown(n: Node, sb: var string) =
  ## Render the tag literally. Children are still rendered through the normal
  ## path.
  sb.add('[')
  htmlEscape(n.name, sb)
  if n.hasValue:
    sb.add('=')
    htmlEscape(n.value, sb)
  sb.add(']')
  renderChildren(n.children, sb)
  sb.add("[/")
  htmlEscape(n.name, sb)
  sb.add(']')

proc renderList(elem: Node, ordered: bool, sb: var string) =
  ## Split children at `[*]` markers (whether they survived as elements or as
  ## literal text after parser unwinding). Drop anything before the first
  ## marker; whitespace there is just layout, not list content.
  var items: seq[seq[Node]] = @[]
  var current: seq[Node] = @[]
  var seenMarker = false
  for c in elem.children:
    let isMarker =
      (c.kind == nkText and c.text == "[*]") or
      (c.kind == nkElement and c.name == "*")
    if isMarker:
      if seenMarker:
        items.add(current)
        current = @[]
      seenMarker = true
      if c.kind == nkElement:
        for cc in c.children:
          current.add(cc)
    elif seenMarker:
      current.add(c)
  if seenMarker:
    items.add(current)

  let tag = if ordered: "ol" else: "ul"
  sb.add('<'); sb.add(tag); sb.add('>')
  for item in items:
    sb.add("<li>")
    for n in item:
      renderNode(n, sb)
    sb.add("</li>")
  sb.add("</"); sb.add(tag); sb.add('>')

proc renderNode(n: Node, sb: var string) =
  case n.kind
  of nkText:
    htmlEscape(n.text, sb)
  of nkElement:
    case n.name
    of "b", "strong":
      sb.add("<strong>"); renderChildren(n.children, sb); sb.add("</strong>")
    of "i", "em":
      sb.add("<em>"); renderChildren(n.children, sb); sb.add("</em>")
    of "u":
      sb.add("<u>"); renderChildren(n.children, sb); sb.add("</u>")
    of "s", "strike":
      sb.add("<s>"); renderChildren(n.children, sb); sb.add("</s>")
    of "sub":
      sb.add("<sub>"); renderChildren(n.children, sb); sb.add("</sub>")
    of "sup":
      sb.add("<sup>"); renderChildren(n.children, sb); sb.add("</sup>")
    of "hr", "line":
      sb.add("<hr>")
    of "br":
      sb.add("<br>")
    of "center":
      sb.add("<div style=\"text-align:center\">")
      renderChildren(n.children, sb)
      sb.add("</div>")
    of "left":
      sb.add("<div style=\"text-align:left\">")
      renderChildren(n.children, sb)
      sb.add("</div>")
    of "right":
      sb.add("<div style=\"text-align:right\">")
      renderChildren(n.children, sb)
      sb.add("</div>")
    of "align":
      if n.hasValue and isValidAlign(n.value):
        sb.add("<div style=\"text-align:")
        sb.add(n.value.toLowerAscii())
        sb.add("\">")
        renderChildren(n.children, sb)
        sb.add("</div>")
      else:
        renderUnknown(n, sb)
    of "spoiler":
      sb.add("<details><summary>")
      if n.hasValue:
        htmlEscape(n.value, sb)
      else:
        sb.add("Spoiler")
      sb.add("</summary>")
      renderChildren(n.children, sb)
      sb.add("</details>")
    of "url":
      var href = ""
      var ok = false
      if n.hasValue:
        if isSafeUrl(n.value):
          href = n.value
          ok = true
      else:
        var raw = ""
        for c in n.children:
          flattenToText(c, raw)
        if isSafeUrl(raw):
          href = raw
          ok = true
      if ok:
        sb.add("<a href=\"")
        htmlEscape(href, sb)
        sb.add("\">")
        renderChildren(n.children, sb)
        sb.add("</a>")
      else:
        renderUnknown(n, sb)
    of "img":
      var src = ""
      for c in n.children:
        flattenToText(c, src)
      if isSafeUrl(src):
        sb.add("<img src=\"")
        htmlEscape(src, sb)
        sb.add('"')
        if n.hasValue:
          var w, h: string
          if parseImgSize(n.value, w, h):
            sb.add(" width=\""); sb.add(w); sb.add('"')
            sb.add(" height=\""); sb.add(h); sb.add('"')
        sb.add(" alt=\"\">")
      else:
        renderUnknown(n, sb)
    of "email":
      var address = ""
      if n.hasValue:
        address = n.value
      else:
        for c in n.children:
          flattenToText(c, address)
      if isValidEmail(address):
        sb.add("<a href=\"mailto:")
        htmlEscape(address, sb)
        sb.add("\">")
        if n.hasValue:
          renderChildren(n.children, sb)
        else:
          htmlEscape(address, sb)
        sb.add("</a>")
      else:
        renderUnknown(n, sb)
    of "color":
      if n.hasValue and isValidColor(n.value):
        sb.add("<span style=\"color:")
        sb.add(n.value)
        sb.add("\">")
        renderChildren(n.children, sb)
        sb.add("</span>")
      else:
        renderUnknown(n, sb)
    of "size":
      if n.hasValue and isValidSize(n.value):
        sb.add("<span style=\"font-size:")
        sb.add(n.value)
        sb.add("px\">")
        renderChildren(n.children, sb)
        sb.add("</span>")
      else:
        renderUnknown(n, sb)
    of "quote":
      sb.add("<blockquote>")
      if n.hasValue:
        sb.add("<cite>")
        htmlEscape(n.value, sb)
        sb.add("</cite>")
      renderChildren(n.children, sb)
      sb.add("</blockquote>")
    of "code":
      sb.add("<pre><code>")
      var raw = ""
      for c in n.children:
        flattenToText(c, raw)
      htmlEscape(raw, sb)
      sb.add("</code></pre>")
    of "nfo":
      ## Same literal-body treatment as [code]: the whole point is to keep
      ## monospace ASCII art untouched, including any `[...]`-shaped runs.
      sb.add("<pre class=\"nfo\">")
      var raw = ""
      for c in n.children:
        flattenToText(c, raw)
      htmlEscape(raw, sb)
      sb.add("</pre>")
    of "blur":
      if n.hasValue:
        if isValidColor(n.value):
          sb.add("<span style=\"color:")
          sb.add(n.value)
          sb.add(";filter:blur(2px)\">")
          renderChildren(n.children, sb)
          sb.add("</span>")
        else:
          renderUnknown(n, sb)
      else:
        sb.add("<span style=\"filter:blur(2px)\">")
        renderChildren(n.children, sb)
        sb.add("</span>")
    of "table":
      sb.add("<table>"); renderChildren(n.children, sb); sb.add("</table>")
    of "row", "tr":
      sb.add("<tr>"); renderChildren(n.children, sb); sb.add("</tr>")
    of "cell", "td":
      sb.add("<td>"); renderChildren(n.children, sb); sb.add("</td>")
    of "th":
      sb.add("<th>"); renderChildren(n.children, sb); sb.add("</th>")
    of "list":
      let ordered = n.hasValue and n.value == "1"
      renderList(n, ordered, sb)
    of "h1", "h2", "h3", "h4", "h5", "h6":
      sb.add('<'); sb.add(n.name); sb.add('>')
      renderChildren(n.children, sb)
      sb.add("</"); sb.add(n.name); sb.add('>')
    else:
      renderUnknown(n, sb)

proc render*(nodes: seq[Node]): string =
  result = ""
  for n in nodes:
    renderNode(n, result)
