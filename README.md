# bbcodim

A small BBCode parser with HTML and Markdown renderers, written in Nim.

- Pure Nim, no runtime dependencies
- Always returns escaped, well-formed output, never raises on malformed input
- Same sanitization rules for URLs, colors, and sizes across both renderers
- Unknown or mismatched tags assumed to be literal text rather than dropping content

## Install

```sh
nimble install bbcodim
```

Or add it to your `.nimble` file:

```nim
requires "bbcodim >= 1.0.0"
```

## Usage

```nim
import bbcodim

echo bbcodeToHtml("[b]hello[/b]")
# <strong>hello</strong>

echo bbcodeToHtml("[url=https://example.com]click[/url]")
# <a href="https://example.com">click</a>

echo bbcodeToHtml("[list][*]a[*]b[/list]")
# <ul><li>a</li><li>b</li></ul>
```

Or render to Markdown:

```nim
import bbcodim

echo bbcodeToMarkdown("[b]hello[/b]")
# **hello**

echo bbcodeToMarkdown("[url=https://example.com]click[/url]")
# [click](https://example.com)

echo bbcodeToMarkdown("[quote=Bob]hi[/quote]")
# > **Bob:**
# > hi
```

For more control, the pipeline is exposed in pieces:

```nim
import bbcodim

let tokens = tokenize("[b]hi[/b]")    # seq[Token]
let ast    = parse(tokens)             # seq[Node]
let html   = render(ast)               # string (HTML)
let md     = renderMarkdown(ast)       # string (Markdown)
```

## Supported tags

| BBCode | HTML | Markdown |
| --- | --- | --- |
| `[b]...[/b]` | `<strong>...</strong>` | `**...**` |
| `[i]...[/i]` | `<em>...</em>` | `*...*` |
| `[u]...[/u]` | `<u>...</u>` | (wrapper dropped) |
| `[s]...[/s]` | `<s>...</s>` | `~~...~~` |
| `[url]https://...[/url]` | `<a href="...">...</a>` | `<https://...>` |
| `[url=https://...]text[/url]` | `<a href="...">text</a>` | `[text](https://...)` |
| `[img]https://.../x.png[/img]` | `<img src="..." alt="">` | `![](https://.../x.png)` |
| `[color=red]...[/color]` | `<span style="color:red">...</span>` | (wrapper dropped) |
| `[color=#abc]...[/color]` | `<span style="color:#abc">...</span>` | (wrapper dropped) |
| `[size=14]...[/size]` | `<span style="font-size:14px">...</span>` | (wrapper dropped) |
| `[quote]...[/quote]` | `<blockquote>...</blockquote>` | `> ...` per line |
| `[quote=Bob]...[/quote]` | `<blockquote><cite>Bob</cite>...</blockquote>` | `> **Bob:**` then `> ...` |
| `[code]...[/code]` | `<pre><code>...</code></pre>` (contents kept literal) | ` ```...``` ` fenced block |
| `[list]...[/list]` | `<ul>...</ul>` | `- item` lines |
| `[list=1]...[/list]` | `<ol>...</ol>` | `1. item` lines |
| `[*]item` | `<li>item</li>` (inside a `[list]`) | list-item marker |

Tag names are case-insensitive (`[B]` and `[b]` are the same).

The Markdown renderer drops the wrapper of tags that have no portable
CommonMark equivalent (`[u]`, `[color]`, `[size]`) and keeps their text.

## Safety

User text is escaped on output for the active dialect (HTML-escaped for the
HTML renderer, backslash-escaped for the Markdown renderer). 
Attribute values flowing into URL targets are validated before
being inlined:

- **URLs** must be `http://`, `https://`, `mailto:`, protocol-relative
  (`//host/path`), or relative (no scheme). Anything else falls back to literal text.
- **Colors** must be either an alphabetic name (`red`, `Blue`) or a 3- or
  6-digit hex code (`#abc`, `#aabbcc`). (HTML renderer only.)
- **Sizes** must be an integer 1..72; rendered as `font-size:Npx`. (HTML
  renderer only.)

Inputs that fail validation, plus unknown tags and orphan close tags, are
rendered as escaped literal BBCode so user content is preserved without
opening an injection vector.

## Limitations

- No `[noparse]` / no raw mode for arbitrary tags (only `[code]` keeps its
  body literal).
- `[*]` markers must already live inside a `[list]`; standalone `[*]` is
  rendered as literal text.
- No automatic `\n` → `<br>` conversion.
- The Markdown renderer targets CommonMark; tags without a portable
  equivalent (`[u]`, `[color]`, `[size]`) drop their wrapper rather than
  emit inline HTML.

## License

MIT - see [LICENSE](LICENSE).
