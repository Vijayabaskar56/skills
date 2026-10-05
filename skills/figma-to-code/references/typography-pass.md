# Typography pass

A numeric, per-text-node audit of one section's type, and the divider/hairline strokes that ride
along with it, against Figma. Run it once per section node, not per screen. The verdict comes from
comparing authored values to effective values field by field. Pixels cannot tell Medium from
SemiBold at 15px, 0.28 from 0.3 tracking, or `#757575` from `#7a7a7a`; captures close the loop,
they never produce the verdict.

**Complete when:** every visible text descendant and every divider in the section has a ledger
row, and every row is ✓ equal, fixed, or recorded as a named platform constraint.

## The three columns

| Column             | Source                                                              | Produces                                                     |
| ------------------ | ------------------------------------------------------------------- | ------------------------------------------------------------ |
| A. Figma authored  | `get_design_context` on the **section** node id                     | per `data-node-id`: instance, size, leading, tracking, hex, features, alignment, case, wrap, truncation |
| B. Repo effective  | component source + the text component (config `textComponent`) + the token file (config `tokenFile`) | the same fields, fully expanded                              |
| C. Render          | the visual loop (capture cropped to the section, `figma-critic`)    | proof the fonts loaded and the fix rendered; nothing else    |

## Read column A

- If the context output truncates or simplifies a text node that `get_metadata` listed, re-call
  `get_design_context` with that text node's own id. The pass is incomplete until every visible
  text descendant has a record.
- Call `get_variable_defs` once per section. `{}` means the design authors **raw hexes**: resolve
  every colour against the token file **by value**, never by assuming a semantic token was meant.
- `style={{ fontFeatureSettings: … }}` on a `<p>` is authored evidence, not noise.
- If the design context leaves a unit ambiguous, a line height `normal`, or a node with mixed
  styles, read the text node through `use_figma` (load `figma-use` first). The raw fields:
  `fontName` {family, style}, `fontWeight`, `fontSize`, `letterSpacing` {value, unit: `PIXELS` or
  `PERCENT`}, `lineHeight` {value, unit: `PIXELS` or `PERCENT`} or {unit: `AUTO`}, `textCase`,
  `textDecoration`, `textAlignHorizontal`, `textAutoResize`, `textTruncation`, `maxLines`,
  `leadingTrim`, `paragraphSpacing`, `openTypeFeatures`. A field that returns `figma.mixed` needs
  `getStyledTextSegments([...fields])`, one ledger row per segment.

## Traps in the authored value

- **Text bounds are never line height.** A fixed-height text box says nothing about leading.
- **Line height `AUTO`** is the font's own metrics, not a number in the file. On a single-line,
  auto-height text node the node height is that line box; record it as the explicit value.
- **Figma percent line height is a percent of font size.** 120% on 15px is 18px.
- **Figma percent letter spacing is a percent of font size.** -2% on 16px is -0.32px.
- **`textCase`** renders uppercase while `characters` holds the typed case. Keep the typed string
  and apply the case in style, so copy diffs still match.
- **`leadingTrim: CAP_HEIGHT`** trims the box to cap height and baseline, so every gap around that
  node in auto layout is measured from the glyphs, not from the line box.
- **Truncation** is `textTruncation: ENDING` plus `maxLines`. A node that merely overflows its
  frame in the render is not truncated; record which one it is.
- **Colour matches by exact hex.** Run `scripts/find-color-token.sh <hex> <tokenFile>`. The right
  token may live under another surface's role name; reuse it only when the role genuinely fits,
  otherwise add a role token or keep a named local constant. **Never substitute the
  nearest-looking token.** Near-miss greys (`#757575` / `#7a7a7a` / `#6b6b6b`) and ambers
  (`#d67d01` / `#d89015` / `#c98a1a`) are exactly the bug class this pass exists to catch.

## Weight availability

Run once per pass, before any row is filled. Read the instance exactly as Figma names it
(`Family:SemiBold`, `Family Variable:Weight 440`, or a family with a numeric `font-weight`), then
map it to the project's font inventory **by value**, never by resemblance. The platform sections
below say where the inventory lives. Config `notes` holds the project's family-to-token table.

If the exact weight is **not** available: **stop**. Do not pick the closest cut, do not fall back
to Medium, do not add a synthetic weight. Record the row as `✗ missing font` and ask the user
before writing any code, in this shape:

> Figma uses **<Family> Weight <N>** on nodes `<id>`, `<id>` ("<text>", "<text>"). The project
> has no <Family> <N> (inventory: <command you ran>). Options: (a) I add it from the variable font
> and register it; (b) you approve substituting **<nearer named weight>** or **<other>** for these
> nodes and I record it in the ledger as a deliberate deviation. Which?

Substitute only after an explicit answer, and write the answer into the ledger row so the next
audit does not reopen it.

## Dividers ride along

- A Figma `line` node exports as an SVG asset. Read the stroke hex from the exported file in the
  download directory (config `figmaDownloadDir`); the generated JSX shows only an `<img>`.
- Row separators usually arrive as `border-[#hex] border-b` classes on row frames. Border-bottom on
  rows 1…n-1 is the same visual as border-top on rows 2…n; compare colour, not attachment.
- Compare stroke colour the same exact-hex way as text colour.
- **Thickness is a decision, not a default.** Figma authors 1 logical px; render 1pt or 1px.
  Anything else (a hairline) is a deviation the user approves and the ledger records.

## Ledger format

One table per section. One row per text node (or styled segment) and per divider:

| Node | Element | Field | Figma (A) | Repo (B) | Verdict |
| ---- | ------- | ----- | --------- | -------- | ------- |

Verdicts: `✓` equal · `✗ fix` with the exact change · `constraint` with the named platform limit.
A row with an unresolved field is not a row; it is a missing record.

## Close the pass

Apply `✗` fixes (shared-token changes only when every consumer should change), run the config
`validate` command, then run the visual loop (`visual-loop.md`) on the section crop with a
`figma-critic` subagent. The critic proves rendering; the ledger proved the values.

## React Native

### Expand column B

Expand the text component's variant into px values, then apply `className` overrides on top (they
win over the variant), then the `style` prop (it wins over both for the fields it sets), then the
colour prop to its hex for the theme under audit, then any figures prop to `fontVariant`. A
matching variant *name* is not evidence: `bodySm` is a claim, `Family-Regular 15/17.25/0.3` is a
value.

### Normalise

- **Family + weight.** Each static cut is its own `fontFamily`. Never pair a custom `fontFamily`
  with `fontWeight`: Android synthesizes a fake bold and iOS silently falls back.
- **Line height** is absolute px. Unitless `leading-[1.15]` is size × 1.15, `leading-none` is
  size × 1.0, a Figma percentage is size × pct/100. Round to 2dp.
- **Tracking** is absolute px. `tracking-[0.16px]` is literal; a percentage is size × pct/100.
- **Features.** `"lnum" 1, "tnum" 1` is `fontVariant: ["lining-nums", "tabular-nums"]` (or the
  text component's figures prop). `"case" 1` has no React Native mapping; record it as a platform
  constraint. Do not fake it with a different family or manual baseline nudges.
- **Case** is `textTransform: "uppercase"`. **Truncation** is `numberOfLines={maxLines}` with the
  default tail `ellipsizeMode`.
- **Leading trim** has no React Native equivalent. Record `CAP_HEIGHT` as a constraint, or
  reproduce the gaps with explicit margins and say which in the ledger.

### Weight inventory

The app renders only weights that exist as static files. The inventory is the font tokens in the
token file; each must also be registered where the app loads fonts (expo-font `useFonts` or the
expo-font config plugin) and exist on disk:

```bash
grep -nE '^\s*--font-' <tokenFile>          # token -> file
grep -rn 'useFonts\|expo-font' <app root>   # registration
```

A numeric weight that equals a named cut (400, 500, 600) maps to the named token.

### Add a weight (user picked option a)

1. Source: the family's variable font. Never hand-edit a static.
2. Cut a static instance with fontTools (`varLib.instancer`, pin `wght=<N>`), rename the `name`
   table to the project's convention (family, PostScript name, `usWeightClass` = the weight), drop
   `fvar`/`STAT`/`gvar`, and subset (`pyftsubset`) to the same unicode ranges the existing files
   use. Dropping unused scripts (a CJK block the app never renders) is most of the size.
3. Save as `<fonts dir>/<PostScriptName>.ttf` and register the same name, so iOS and Android
   resolve one string. Add the token to the token file, run the config `validate` command, then
   reload the JS bundle: fonts load at startup and Fast Refresh does not re-register them. A font
   added through the expo-font config plugin needs a native rebuild. Confirm via column C.

### Dividers

Render a divider at 1pt (`width: 1`, `h-px`). `StyleSheet.hairlineWidth` is ⅓ pt on 3x devices
and all but disappears; keep it only when the user approved it and the ledger records the
deviation from Figma's 1pt.

## Web (React)

### Expand column B

Expand the text component's variant, then the utility classes in cascade order, then inline
`style`. In Tailwind a `text-<size>` class also sets a line height; a `leading-*` class overrides
it, and without one the size class's default leading is the effective value. To confirm in the
render, read `getComputedStyle(el)` through the config `verify` tool: `fontFamily`, `fontWeight`,
`fontSize`, `lineHeight`, `letterSpacing` and `color` come back resolved to px and `rgb()`.

### Letter spacing

- Figma percent: `letter-spacing: <pct/100>em` (`-2%` is `-0.02em`, Tailwind `tracking-[-0.02em]`).
  Use em so the value follows the font size; px (size × pct/100) is equal at one size only.
- Figma px: the same px.
- Browsers add the spacing after the last character too, so centred text with wide tracking sits
  left by half the tracking. Record it if the critic names it.

### Line height

- Figma px: `line-height: <px>px`, or the unitless ratio px/size.
- Figma percent: unitless `pct/100` (`120%` is `line-height: 1.2`). Do not write CSS `120%`: a
  percentage computes to px on the element and children inherit that px, not the ratio.
- Figma `AUTO`: set the measured value explicitly. CSS `normal` also uses font metrics, but which
  metrics differs by browser and OS.
- CSS and Figma both split extra leading equally above and below the glyphs, so a correct line
  height places the first baseline where Figma does.

### Weight availability and synthetic bold

- The inventory is the `@font-face` rules (or the `next/font` / fontsource config) for the family.
  List what the page actually has with
  `[...document.fonts].map(f => [f.family, f.weight, f.style, f.status])`.
- A requested weight with no face falls back to the nearest face by the CSS font-matching rules,
  and a bold request against a lighter face may be synthesized. Set `font-synthesis-weight: none`
  (or `font-synthesis: none`) so a missing weight shows as wrong instead of faked.
- On the web one family holds many weights: add a face under the same `font-family` with its
  `font-weight`, instead of a new family name per cut.

### Variable fonts

- Declare the axis range: `@font-face { font-family: X; src: url(x.woff2) format("woff2");
  font-weight: 100 900; }`. Without the range the face is a single 400 and other weights are
  clamped or synthesized.
- Then any authored weight works directly: Figma `Weight 440` is `font-weight: 440` (Tailwind
  `font-[440]`). No static cut is needed, so option (a) is usually adding the variable file.
- Set other axes with their high-level properties first (`font-stretch`, `font-optical-sizing`);
  `font-variation-settings` overrides them and does not merge through inheritance.
- If the project ships only statics, cut an instance as in the React Native recipe and ship it as
  woff2 (`pyftsubset --flavor=woff2`).

### Font loading

- `font-display: swap` paints the fallback first, then swaps. Capture only after
  `document.fonts.ready` resolves, or column C shows the fallback.
- Preloaded fonts need `<link rel="preload" as="font" type="font/woff2" crossorigin>`;
  `crossorigin` is required even for same-origin files.
- Layout shift on swap comes from fallback metrics. `size-adjust`, `ascent-override`,
  `descent-override` and `line-gap-override` on a fallback `@font-face` fix it; `next/font` writes
  these itself.

### Rendering

On macOS, Chrome and Safari render text heavier by default than Figma's canvas.
`-webkit-font-smoothing: antialiased` with `-moz-osx-font-smoothing: grayscale` (Tailwind
`antialiased`) render thinner and closer to Figma. Both are macOS only. If a capture looks a weight
too heavy, check smoothing and the computed `font-weight` before changing any weight.

### Leading trim

`leadingTrim: CAP_HEIGHT` is `text-box: trim-both cap alphabetic` (`text-box-trim` +
`text-box-edge`). Supported in Chrome 133+ and Safari 18.2+, not yet in Firefox. Where Firefox
matters, trim with negative margins computed from the font's cap height and line height (the
Capsize method), and record which you used.

### Case, features, truncation

- Case: `text-transform: uppercase` (Tailwind `uppercase`).
- Features: `"lnum" 1, "tnum" 1` is `font-variant-numeric: lining-nums tabular-nums`; `"case" 1`
  is `font-feature-settings: "case" 1` and works when the font has the feature. Prefer
  `font-variant-*`: `font-feature-settings` replaces the whole list rather than merging.
- One line: `overflow: hidden; text-overflow: ellipsis; white-space: nowrap` (Tailwind
  `truncate`). It needs a bounded width; inside a flex row add `min-width: 0` to the item.
- N lines: `display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: N;
  overflow: hidden` (Tailwind `line-clamp-N`). The unprefixed `line-clamp` is not yet usable
  across browsers.

### Dividers

1 CSS px is Figma's 1 logical px. A `0.5px` border draws a device hairline on 2x and 3x screens;
it is the same deviation, kept only when the user approved it and the ledger records it. A bare `<hr>` carries browser margins and an inset
border; reset them or use a bordered element.
