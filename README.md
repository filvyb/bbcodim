# bbcodim

A small BBCode parser and HTML renderer written in Nim.

- Pure Nim, no runtime dependencies
- Always returns escaped, well-formed HTML, never raises on malformed input
- Ssanitization for URLs, colors, and sizes
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

For more control, the pipeline is exposed in three pieces:

```nim
import bbcodim

let tokens = tokenize("[b]hi[/b]")   # seq[Token]
let ast    = parse(tokens)            # seq[Node]
let html   = render(ast)              # string
```

## Supported tags

| BBCode | HTML |
| --- | --- |
| `[b]...[/b]` | `<strong>...</strong>` |
| `[i]...[/i]` | `<em>...</em>` |
| `[u]...[/u]` | `<u>...</u>` |
| `[s]...[/s]` | `<s>...</s>` |
| `[url]https://...[/url]` | `<a href="...">...</a>` |
| `[url=https://...]text[/url]` | `<a href="...">text</a>` |
| `[img]https://.../x.png[/img]` | `<img src="..." alt="">` |
| `[color=red]...[/color]` | `<span style="color:red">...</span>` |
| `[color=#abc]...[/color]` | `<span style="color:#abc">...</span>` |
| `[size=14]...[/size]` | `<span style="font-size:14px">...</span>` |
| `[quote]...[/quote]` | `<blockquote>...</blockquote>` |
| `[quote=Bob]...[/quote]` | `<blockquote><cite>Bob</cite>...</blockquote>` |
| `[code]...[/code]` | `<pre><code>...</code></pre>` (contents kept literal) |
| `[list]...[/list]` | `<ul>...</ul>` |
| `[list=1]...[/list]` | `<ol>...</ol>` |
| `[*]item` | `<li>item</li>` (inside a `[list]`) |

Tag names are case-insensitive (`[B]` and `[b]` are the same).

## Safety

All user text is HTML-escaped on output. Attribute values flowing into `href`,
`src`, or `style` are validated before being inlined:

- **URLs** must be `http://`, `https://`, `mailto:`, protocol-relative
  (`//host/path`), or relative (no scheme). Anything else falls back to literal text.
- **Colors** must be either an alphabetic name (`red`, `Blue`) or a 3- or
  6-digit hex code (`#abc`, `#aabbcc`).
- **Sizes** must be an integer 1..72; rendered as `font-size:Npx`.

Inputs that fail validation, plus unknown tags and orphan close tags, are
rendered as escaped literal BBCode so user content is preserved without
opening an injection vector.

## Limitations

- No `[noparse]` / no raw mode for arbitrary tags (only `[code]` keeps its
  body literal).
- `[*]` markers must already live inside a `[list]`; standalone `[*]` is
  rendered as literal text.
- No automatic `\n` → `<br>` conversion.

## License

MIT - see [LICENSE](LICENSE).
