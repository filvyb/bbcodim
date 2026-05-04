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

proc isValidSize*(s: string): bool =
  if s.len == 0 or s.len > 3: return false
  for c in s:
    if c notin Digits: return false
  let n = parseInt(s)
  return n >= 1 and n <= 72

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
  ## path — only the wrapper is degraded.
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
    of "b":
      sb.add("<strong>"); renderChildren(n.children, sb); sb.add("</strong>")
    of "i":
      sb.add("<em>"); renderChildren(n.children, sb); sb.add("</em>")
    of "u":
      sb.add("<u>"); renderChildren(n.children, sb); sb.add("</u>")
    of "s":
      sb.add("<s>"); renderChildren(n.children, sb); sb.add("</s>")
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
        sb.add("\" alt=\"\">")
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
    of "list":
      let ordered = n.hasValue and n.value == "1"
      renderList(n, ordered, sb)
    else:
      renderUnknown(n, sb)

proc render*(nodes: seq[Node]): string =
  result = ""
  for n in nodes:
    renderNode(n, result)
