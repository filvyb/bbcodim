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
| `[b]...[/b]`, `[strong]...[/strong]` | `<strong>...</strong>` | `**...**` |
| `[i]...[/i]`, `[em]...[/em]` | `<em>...</em>` | `*...*` |
| `[u]...[/u]` | `<u>...</u>` | (wrapper dropped) |
| `[s]...[/s]`, `[strike]...[/strike]` | `<s>...</s>` | `~~...~~` |
| `[sub]...[/sub]` | `<sub>...</sub>` | (wrapper dropped) |
| `[sup]...[/sup]` | `<sup>...</sup>` | (wrapper dropped) |
| `[url]https://...[/url]` | `<a href="...">...</a>` | `<https://...>` |
| `[url=https://...]text[/url]` | `<a href="...">text</a>` | `[text](https://...)` |
| `[email]a@b.test[/email]` | `<a href="mailto:...">...</a>` | `<a@b.test>` |
| `[email=a@b.test]text[/email]` | `<a href="mailto:...">text</a>` | `[text](mailto:...)` |
| `[img]https://.../x.png[/img]` | `<img src="..." alt="">` | `![](https://.../x.png)` |
| `[img=WxH]https://.../x.png[/img]` | `<img src="..." width="W" height="H" alt="">` | `![](https://.../x.png)` (size dropped) |
| `[color=red]...[/color]` | `<span style="color:red">...</span>` | (wrapper dropped) |
| `[color=#abc]...[/color]` | `<span style="color:#abc">...</span>` | (wrapper dropped) |
| `[size=14]...[/size]` | `<span style="font-size:14px">...</span>` | (wrapper dropped) |
| `[blur]...[/blur]` | `<span style="filter:blur(2px)">...</span>` | (wrapper dropped) |
| `[blur=red]...[/blur]` | `<span style="color:red;filter:blur(2px)">...</span>` | (wrapper dropped) |
| `[quote]...[/quote]` | `<blockquote>...</blockquote>` | `> ...` per line |
| `[quote=Bob]...[/quote]` | `<blockquote><cite>Bob</cite>...</blockquote>` | `> **Bob:**` then `> ...` |
| `[code]...[/code]` | `<pre><code>...</code></pre>` (contents kept literal) | ` ```...``` ` fenced block |
| `[nfo]...[/nfo]` | `<pre class="nfo">...</pre>` (contents kept literal) | ` ```...``` ` fenced block |
| `[list]...[/list]` | `<ul>...</ul>` | `- item` lines |
| `[list=1]...[/list]` | `<ol>...</ol>` | `1. item` lines |
| `[*]item` | `<li>item</li>` (inside a `[list]`) | list-item marker |
| `[h1]...[/h1]` … `[h6]...[/h6]` | `<h1>...</h1>` … `<h6>...</h6>` | `# ...` … `###### ...` |
| `[hr]`, `[line]` | `<hr>` | `---` block |
| `[br]` | `<br>` | `\` + newline (CommonMark hard break) |
| `[center]...[/center]` (also `[left]`, `[right]`) | `<div style="text-align:center">...</div>` | (wrapper dropped) |
| `[align=left\|center\|right\|justify]...[/align]` | `<div style="text-align:...">...</div>` | (wrapper dropped) |
| `[spoiler]...[/spoiler]` | `<details><summary>Spoiler</summary>...</details>` | (wrapper dropped) |
| `[spoiler=Title]...[/spoiler]` | `<details><summary>Title</summary>...</details>` | (wrapper dropped, label discarded) |
| `[table]...[/table]` | `<table>...</table>` | (wrapper dropped) |
| `[row]...[/row]`, `[tr]...[/tr]` | `<tr>...</tr>` | (wrapper dropped) |
| `[cell]...[/cell]`, `[td]...[/td]` | `<td>...</td>` | (wrapper dropped) |
| `[th]...[/th]` | `<th>...</th>` | (wrapper dropped) |

Tag names are case-insensitive (`[B]` and `[b]` are the same).

The Markdown renderer drops the wrapper of tags that have no portable
CommonMark equivalent (`[u]`, `[color]`, `[size]`, `[sub]`, `[sup]`,
`[blur]`, alignment, `[spoiler]`, and the table family) and keeps
their text.

## Safety

User text is escaped on output for the active dialect (HTML-escaped for the
HTML renderer, backslash-escaped for the Markdown renderer). 
Attribute values flowing into URL targets are validated before
being inlined:

- **URLs** must be `http://`, `https://`, `mailto:`, protocol-relative
  (`//host/path`), or relative (no scheme). Anything else falls back to literal text.
- **Emails** must be a single `local@domain` token using letters, digits,
  `.`, `_`, `-`, `+`, with at least one `.` in the domain.
- **Colors** must be either an alphabetic name (`red`, `Blue`) or a 3- or
  6-digit hex code (`#abc`, `#aabbcc`). (HTML renderer only.)
- **Sizes** must be an integer 1..72; rendered as `font-size:Npx`. (HTML
  renderer only.)
- **Image dimensions** (`[img=WxH]`) must be two positive integers up to
  4 digits each otherwise the size is dropped.

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
