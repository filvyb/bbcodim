## bbcodim - BBCode parser, HTML renderer, and Markdown renderer.
##
## Quick start:
## ```
## import bbcodim
## echo bbcodeToHtml("[b]hello[/b]")      # -> <strong>hello</strong>
## echo bbcodeToMarkdown("[b]hello[/b]")  # -> **hello**
## ```

import bbcodim/lexer
import bbcodim/parser
import bbcodim/renderer
import bbcodim/markdown

export lexer, parser, renderer, markdown

proc bbcodeToHtml*(input: string): string =
  ## End-to-end transform: lex, parse, render. Always returns valid,
  ## escaped HTML, never raises on malformed input.
  render(parse(tokenize(input)))

proc bbcodeToMarkdown*(input: string): string =
  ## End-to-end transform to CommonMark Markdown. Always returns valid,
  ## escaped Markdown, never raises on malformed input.
  renderMarkdown(parse(tokenize(input)))

