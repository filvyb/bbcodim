## Lexer: turn a BBCode string into a flat sequence of tokens.
##
## Tags that fail to parse (no closing `]`, empty name, unterminated quote)
## are emitted as literal text - the parser never has to second-guess us.

import std/strutils

type
  TokenKind* = enum
    tkText
    tkOpenTag
    tkCloseTag

  Token* = object
    case kind*: TokenKind
    of tkText:
      text*: string
    of tkOpenTag:
      name*: string
      value*: string
      hasValue*: bool
    of tkCloseTag:
      closeName*: string

func isTagNameChar(c: char): bool {.inline.} =
  c.isAlphaNumeric() or c == '*'

proc tryParseTag(input: string, i: int, tok: var Token, newI: var int): bool =
  ## Attempts to parse a tag starting at `input[i] == '['`.
  ## Returns false if the bracket does not begin a well-formed tag; in that
  ## case the caller should treat the `[` as literal text.
  if i >= input.len or input[i] != '[': return false
  var p = i + 1
  if p >= input.len: return false

  let isClose = input[p] == '/'
  if isClose: inc p

  let nameStart = p
  while p < input.len and isTagNameChar(input[p]):
    inc p
  if p == nameStart: return false
  let name = input[nameStart ..< p].toLowerAscii()

  var value = ""
  var hasValue = false
  if not isClose and p < input.len and input[p] == '=':
    inc p
    hasValue = true
    if p < input.len and (input[p] == '"' or input[p] == '\''):
      let quote = input[p]
      inc p
      let qStart = p
      while p < input.len and input[p] != quote:
        inc p
      if p >= input.len: return false
      value = input[qStart ..< p]
      inc p
    else:
      let vStart = p
      while p < input.len and input[p] != ']':
        inc p
      value = input[vStart ..< p]

  if p >= input.len or input[p] != ']': return false

  if isClose:
    tok = Token(kind: tkCloseTag, closeName: name)
  else:
    tok = Token(kind: tkOpenTag, name: name, value: value, hasValue: hasValue)
  newI = p + 1
  return true

proc tokenize*(input: string): seq[Token] =
  ## Walk the input once, accumulating literal text between successfully
  ## parsed tags.
  result = @[]
  var i = 0
  var textStart = 0
  while i < input.len:
    if input[i] == '[':
      var tok: Token
      var newI = 0
      if tryParseTag(input, i, tok, newI):
        if i > textStart:
          result.add(Token(kind: tkText, text: input[textStart ..< i]))
        result.add(tok)
        i = newI
        textStart = i
      else:
        inc i
    else:
      inc i
  if textStart < input.len:
    result.add(Token(kind: tkText, text: input[textStart ..< input.len]))
