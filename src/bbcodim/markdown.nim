## Markdown renderer: AST -> CommonMark.
##
## Mirrors the safety stance of the HTML renderer: text is escaped on the way
## out, URLs are validated against the same `isSafeUrl` predicate, and any
## tag that fails validation falls back to a literal (escaped) BBCode form so
## user content is preserved verbatim.
##
## Tags without a clean Markdown equivalent (`[u]`, `[color]`, `[size]`)
## drop their wrapper and render their children inline.

import std/strutils
import parser
import renderer  # isSafeUrl, flattenToText

proc mdEscape*(s: string, sb: var string) =
  ## Escape the CommonMark inline metacharacters that would otherwise be
  ## interpreted as formatting
  for c in s:
    case c
    of '\\', '*', '_', '`', '[', ']', '<', '>':
      sb.add('\\'); sb.add(c)
    else: sb.add c

proc mdEscape*(s: string): string =
  result = newStringOfCap(s.len)
  mdEscape(s, result)

proc urlEscapeParens(s: string, sb: var string) =
  ## Inside a `[text](url)` link target, parens close the URL early. Percent-
  ## encode them so the link survives.
  for c in s:
    case c
    of '(': sb.add("%28")
    of ')': sb.add("%29")
    else: sb.add c

proc ensureBlankLine(sb: var string) =
  ## Block elements need to start on their own line, separated from the
  ## preceding content by a blank line. No-op if we're already at the start
  ## of a fresh block boundary.
  if sb.len == 0: return
  if sb.endsWith("\n\n"): return
  if sb.endsWith("\n"):
    sb.add("\n")
  else:
    sb.add("\n\n")

proc renderMdNode(n: Node, sb: var string)

proc renderMdChildren(children: seq[Node], sb: var string) =
  for c in children:
    renderMdNode(c, sb)

proc renderMdBlock(content: string, sb: var string) =
  ## Insert `content` as a standalone block: blank line before, blank line
  ## after, no leading or trailing whitespace inside.
  ensureBlankLine(sb)
  sb.add(content.strip(leading = false, trailing = true, chars = {'\n'}))
  sb.add("\n\n")

proc renderMdLiteral(n: Node, sb: var string) =
  ## Render a tag literally (escaped) so unknown or unsafe tags keep the
  ## user's text intact in the output.
  sb.add('\\'); sb.add('[')
  mdEscape(n.name, sb)
  if n.hasValue:
    sb.add('=')
    mdEscape(n.value, sb)
  sb.add('\\'); sb.add(']')
  renderMdChildren(n.children, sb)
  sb.add('\\'); sb.add('[')
  sb.add('/')
  mdEscape(n.name, sb)
  sb.add('\\'); sb.add(']')

proc prefixLines(content: string,
                 firstPrefix, contPrefix, blankPrefix: string,
                 sb: var string) =
  ## Emit `content` with `firstPrefix` on its first line, `contPrefix` on
  ## every non-empty subsequent line, and `blankPrefix` on empty lines.
  ## (Lists want blank lines truly blank to avoid trailing-whitespace
  ## artefacts; quotes want `>` on blank lines so a single quote with a
  ## paragraph break doesn't split into two adjacent quotes.)
  let trimmed = content.strip(leading = false, trailing = true, chars = {'\n'})
  var first = true
  for line in trimmed.splitLines:
    if first:
      sb.add(firstPrefix); first = false
    elif line.len == 0:
      sb.add(blankPrefix)
    else:
      sb.add(contPrefix)
    sb.add(line)
    sb.add('\n')

proc renderMdQuote(elem: Node, sb: var string) =
  var inner = ""
  if elem.hasValue:
    inner.add("**")
    mdEscape(elem.value, inner)
    inner.add(":**\n")
  for c in elem.children:
    renderMdNode(c, inner)

  var content = ""
  prefixLines(inner, "> ", "> ", ">", content)
  renderMdBlock(content, sb)

proc renderMdList(elem: Node, ordered: bool, sb: var string) =
  ## Same item-splitting as the HTML renderer: ignore content before the
  ## first `[*]`, then group children into items.
  var items: seq[seq[Node]] = @[]
  var current: seq[Node] = @[]
  var seenMarker = false
  for c in elem.children:
    let isMarker =
      (c.kind == nkText and c.text == "[*]") or
      (c.kind == nkElement and c.name == "*")
    if isMarker:
      if seenMarker:
        items.add(current); current = @[]
      seenMarker = true
      if c.kind == nkElement:
        for cc in c.children: current.add(cc)
    elif seenMarker:
      current.add(c)
  if seenMarker:
    items.add(current)

  var content = ""
  for i, item in items:
    var inner = ""
    for n in item:
      renderMdNode(n, inner)
    let bullet = if ordered: $(i + 1) & ". " else: "- "
    let pad = " ".repeat(bullet.len)
    prefixLines(inner, bullet, pad, "", content)

  renderMdBlock(content, sb)

proc renderMdCode(elem: Node, sb: var string) =
  var raw = ""
  for c in elem.children:
    flattenToText(c, raw)
  ## Bump the fence length until it's longer than any backtick run inside
  ## the body, so a stray ``` in user text can't end the block early.
  var fence = "```"
  while fence in raw:
    fence.add('`')
  var content = fence
  content.add('\n')
  content.add(raw)
  if raw.len == 0 or raw[^1] != '\n':
    content.add('\n')
  content.add(fence)
  renderMdBlock(content, sb)

proc renderMdNode(n: Node, sb: var string) =
  case n.kind
  of nkText:
    mdEscape(n.text, sb)
  of nkElement:
    case n.name
    of "b":
      sb.add("**"); renderMdChildren(n.children, sb); sb.add("**")
    of "i":
      sb.add('*'); renderMdChildren(n.children, sb); sb.add('*')
    of "s":
      sb.add("~~"); renderMdChildren(n.children, sb); sb.add("~~")
    of "u", "color", "size":
      # No portable Markdown equivalent — drop the wrapper, keep content.
      renderMdChildren(n.children, sb)
    of "url":
      if n.hasValue:
        if isSafeUrl(n.value):
          sb.add('[')
          renderMdChildren(n.children, sb)
          sb.add("](")
          urlEscapeParens(n.value, sb)
          sb.add(')')
        else:
          renderMdLiteral(n, sb)
      else:
        var raw = ""
        for c in n.children:
          flattenToText(c, raw)
        if isSafeUrl(raw):
          sb.add('<')
          sb.add(raw)
          sb.add('>')
        else:
          renderMdLiteral(n, sb)
    of "img":
      var src = ""
      for c in n.children:
        flattenToText(c, src)
      if isSafeUrl(src):
        sb.add("![](")
        urlEscapeParens(src, sb)
        sb.add(')')
      else:
        renderMdLiteral(n, sb)
    of "quote":
      renderMdQuote(n, sb)
    of "code":
      renderMdCode(n, sb)
    of "list":
      renderMdList(n, n.hasValue and n.value == "1", sb)
    else:
      renderMdLiteral(n, sb)

proc renderMarkdown*(nodes: seq[Node]): string =
  ## Trim leading/trailing newlines so single-block inputs round-trip
  ## without surrounding whitespace.
  var raw = ""
  for n in nodes:
    renderMdNode(n, raw)
  result = raw.strip(chars = {'\n'})
