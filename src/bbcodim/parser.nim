## Parser: fold a token stream into a node tree.
##
## Mismatch policy: a close tag with no matching open becomes literal text.
## An open tag still on the stack at EOF becomes literal text, and its
## already-collected children float up to the parent. This mirrors how most
## forum BBCode renderers behave and avoids losing user content.

import lexer

type
  NodeKind* = enum
    nkText
    nkElement

  Node* = ref object
    case kind*: NodeKind
    of nkText:
      text*: string
    of nkElement:
      name*: string
      value*: string
      hasValue*: bool
      children*: seq[Node]

  Frame = object
    name: string
    value: string
    hasValue: bool
    children: seq[Node]

const voidTags* = ["hr"]
  ## Tags that are emitted as standalone elements at the open token: they
  ## have no body and never wait for a matching close. A stray `[/hr]` is
  ## treated as a redundant marker (no content to lose) and dropped.

func reconstructOpen(name, value: string, hasValue: bool): string =
  result = "[" & name
  if hasValue:
    result.add('=')
    result.add(value)
  result.add(']')

proc parse*(tokens: seq[Token]): seq[Node] =
  ## The bottom frame is a synthetic root whose `children` becomes the result.
  var stack: seq[Frame] = @[Frame()]

  template top: untyped = stack[stack.high]

  proc unwindOne(stack: var seq[Frame]) =
    ## Pop the top frame, re-emit its open tag as literal text into the new
    ## top, then re-emit its children there too.
    let f = stack.pop()
    let parent = stack.high
    stack[parent].children.add(
      Node(kind: nkText,
           text: reconstructOpen(f.name, f.value, f.hasValue)))
    for c in f.children:
      stack[parent].children.add(c)

  for tok in tokens:
    case tok.kind
    of tkText:
      top.children.add(Node(kind: nkText, text: tok.text))
    of tkOpenTag:
      if tok.name in voidTags:
        top.children.add(Node(kind: nkElement,
          name: tok.name, value: tok.value, hasValue: tok.hasValue,
          children: @[]))
      else:
        stack.add(Frame(name: tok.name, value: tok.value, hasValue: tok.hasValue))
    of tkCloseTag:
      if tok.closeName in voidTags:
        continue
      var matchIdx = -1
      var i = stack.high
      while i > 0:
        if stack[i].name == tok.closeName:
          matchIdx = i
          break
        dec i
      if matchIdx == -1:
        top.children.add(
          Node(kind: nkText, text: "[/" & tok.closeName & "]"))
      else:
        while stack.high > matchIdx:
          unwindOne(stack)
        let f = stack.pop()
        top.children.add(
          Node(kind: nkElement,
               name: f.name, value: f.value, hasValue: f.hasValue,
               children: f.children))

  while stack.len > 1:
    unwindOne(stack)

  return stack[0].children
