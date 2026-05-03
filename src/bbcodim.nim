## bbcodim - BBCode parser and HTML renderer.
##
## Quick start:
## ```
## import bbcodim
## echo bbcodeToHtml("[b]hello[/b]")  # -> <strong>hello</strong>
## ```

import bbcodim/lexer
import bbcodim/parser
import bbcodim/renderer

export lexer, parser, renderer

proc bbcodeToHtml*(input: string): string =
  ## End-to-end transform: lex, parse, render. Always returns valid, 
  ## escaped HTML, never raises on malformed input.
  render(parse(tokenize(input)))

