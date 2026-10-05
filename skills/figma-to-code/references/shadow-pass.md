# Shadow pass

A numeric, per-surface audit of one section's shadows, and the inset rings and
blur-backed washes that ride along with it, against Figma. Run it once per section
node, not per screen. The verdict comes from comparing authored recipes to effective
recipes field by field (x / y / blur / spread / alpha, per layer). Pixels cannot tell
`0/2/8 @3%` from `0/2/8 @5%`, a 7px blur from a 3.5px blur at 2% alpha, or a shadow
from a ring at hairline sizes; screenshots close the loop, they never produce the
verdict.

**Complete when:** every shadow-bearing surface in the section has a ledger row, every
row names its slot, and every row is ✓ equal, fixed, or recorded as a named platform
constraint.

## The three columns

| Column            | Source                                                                    | Produces                                              |
| ----------------- | ------------------------------------------------------------------------- | ----------------------------------------------------- |
| A. Figma authored | `get_design_context` on the **section** node id; `raw-node.js` for raw effects | per `data-node-id`: every `shadow-[…]`, `drop-shadow-[…]`, inset, blur |
| B. Repo effective | the token file (config `tokenFile`), shadow-carrying wrappers in `componentDirs`, local styles | the same layers, fully expanded                    |
| C. Render         | the visual loop (capture cropped to the section, critic subagent)          | proof the shadow renders and nothing clips; nothing else |

## Read the recipe from Figma (column A)

- A full screen is too large for `get_design_context`: the tool falls back to
  metadata and tells you to split up. Fetch **per-section sublayer ids** instead;
  the pass runs per section anyway.
- If the context output truncates a node that `get_metadata` listed, re-call
  `get_design_context` with that node's own id. The pass is incomplete until every
  visible shadow-bearing surface has a record.
- If a generated class looks wrong or a field is missing, read the raw `effects` with
  `raw-node.js`. Each entry carries `type` (`DROP_SHADOW` / `INNER_SHADOW`),
  `offset.x` / `offset.y`, `radius` (blur), `spread`, `color` (r/g/b/a in 0 to 1),
  `blendMode` and `showShadowBehindNode`. The raw read wins over the generated class.
- Circular buttons and pins usually export as **baked bitmaps** (the generated code
  shows an `<img>` with negative-bleed insets like `-13%/-18%/-22%`). There are no
  vector values to transcribe; read the recipe off the Figma Effects panel
  (the user can screenshot it) and record the node as `baked-asset`, never invent a
  recipe.
- `backdrop-blur-[…]` next to a shadow is authored evidence, not noise. A translucent
  disc without its blur is a different design; record a missing blur as its own row.
  Blur radius conversion lives in [`progressive-blur.md`](progressive-blur.md).
- An explicit `bg-[#f7f7f7]` / `bg-white` wash under a blur carrier is part of the
  effect. Record fill + blur + shadow as one recipe, not three rows.
- A Figma shadow follows the alpha of what the node renders. A frame with a fill casts
  a box; a frame or group with no fill, a text node, or a vector casts the shape of its
  content. Record the cast shape in the row: `box` or `content`.
- `showShadowBehindNode: false` (the default) hides the shadow under the node's own
  area, so a translucent fill does not show it. `true` lets it show through. Record
  `true` in the row; it changes the implementation.
- A `blendMode` other than `NORMAL` on a shadow is part of the recipe. Record it.

## Expand the repo recipe (column B)

- Expand the effective recipe completely: a utility class to its token in the token
  file, a wrapper prop (`shadow="…"`) to the map it resolves through, down to the
  literal. An inline style literal is already the value; an arbitrary `shadow-[…]`
  class is already the value, and a candidate for a slot.
- A matching slot *name* is not evidence. A prop value is a claim; `0/1/7 @2%` is a
  value.
- Check the component library's base styles: some components ship their own shadow
  that a wrapper must clear (`shadow-none`) before its own slot can win. An un-cleared
  base shadow is a second recipe on the element; record it.
- Audit under the theme in question. If the project routes some shadows through
  theme variables that go transparent in dark mode while static shadow tokens persist,
  a shadow that vanishes in dark is intended; do not "fix" it. The project notes
  (config `notes`) name which is which.

## Normalise the spelling

- Generated `shadow-[0px_1px_7px_0px_rgba(0,0,0,0.02)]` transcribes literally to
  `0 1px 7px rgba(0, 0, 0, 0.02)`. Figma's blur radius is the CSS blur radius, one to
  one. When the only export is an SVG `feDropShadow`, its `stdDeviation` is **half**
  the box-shadow blur; double it.
- `drop-shadow-[…]` on a pill and `shadow-[…]` with the same numbers are the same
  recipe. Normalise the spelling before comparing, or every chip reads as a mismatch.
- `shadow-[inset_…]` layers, `0_0_0_1px` rings and edge glows (`inset 0 0 29px white`)
  are **rings, not shadows**. They never take a shadow slot; record them as rings
  and keep them out of the slot inventory.

## Take the slot inventory

Run it once per pass, before any row is filled. The app renders only slots that exist:
the shadow tokens in the token file plus the wrapper maps that name them.

```bash
grep -nE '^\s*--shadow-' <tokenFile>           # token → recipe (CSS-variable token files)
rg -n 'shadow' <componentDirs>                  # slot → token, per wrapper
rg -n 'shadow-\[|boxShadow' <source dirs>       # one-off candidates
```

Map each authored recipe to a slot **by value**: same x/y/blur/spread/alpha (normalised
above) or it is not the slot. Near-misses (`@3%` vs `@5%`, 7px vs 3.5px blur at 2%
alpha) are exactly the bug class this pass exists to catch; they become merge
proposals, never silent substitutions.

Each shadow family has one owner (a surface or card wrapper, a button lookup, a chip
token). The project notes name them. A one-off recipe stays local with a named constant
**only** while single-use; a second use promotes it to a slot.

If Figma authors a recipe with **no slot**: **stop**. Do not pick the closest slot,
do not mint a token. Record the ledger row as `✗ missing slot` and put the question
to the user before writing any code, in this shape:

> Figma authors **0/2/4 @4%** on nodes `<id>`, `<id>` (gray wells on white cards). The
> inventory has no gray-well slot (`grep -- --shadow- <tokenFile>`). Options: (a) I add
> `--shadow-well` with this recipe and use it in both wells; (b) you approve mapping
> them to **`<nearest slot>`** (0/1/3.5 @2%) and I record it in the ledger as a
> deliberate deviation. Which?

The mapping only happens after an explicit answer, and the answer is written into the
ledger row so the next audit does not reopen it.

## Ledger format

One table per section. One row per shadow-bearing surface (rings ride along as
`ring` rows, never verdicts on their own):

| Node | Element | Background | Figma (A) | Repo (B) | Slot | Verdict |
| ---- | ------- | ---------- | --------- | -------- | ---- | ------- |

Figma (A) lists every layer as `type x/y/blur/spread @alpha`, plus cast shape, a
non-`NORMAL` blend and `behind` when set. Verdicts: `✓` equal · `✗ fix` with the exact
change · `constraint` with the named platform limit · `merge?` for a near-miss pair
awaiting the designer. A row with an unresolved field is not a row; it is a missing
record.

## Close the pass

Apply `✗` fixes (shared-slot changes only when every consumer should change; a slot
rename touches the token, the maps, and every call site together), run the config
`validate` command, then run the visual loop on the section crop with a critic
subagent. The critic proves rendering, and specifically that no clip eats the new
shadow; the ledger proved the values.

## React Native

- Write shadows as the `boxShadow` style (CSS string or array), which takes `inset`
  and spread. It needs the New Architecture. The normalised string from above is the
  value.
- Normalise `drop-shadow-[…]` on a box to `boxShadow` with the same numbers.
- A `content` cast shape (text, vector, fill-less frame) or `showShadowBehindNode:
  true` has no `boxShadow` equivalent. Use a baked asset or record a `constraint`.
- If a shadow is driven by a worklet (an animated `boxShadow` style), opacity on a
  shadow-carrying view is fine; driving `boxShadow` itself per frame routes every frame
  through a shadow-tree commit. Record it as a constraint and move the shadow to a
  static underlay whose opacity animates.
- An ancestor with `overflow: hidden` clips an outer shadow. The capture in column C is
  where this shows.

## Web (React)

- `DROP_SHADOW` maps to `box-shadow: x y blur spread color`; `INNER_SHADOW` to the
  same with `inset`. Figma's radius is the CSS blur value; spread carries over.
  Tailwind: `shadow-[0_1px_7px_0_rgba(0,0,0,0.02)]`, or a `--shadow-*` theme token
  for a slot; v4 also has `inset-shadow-*` and `--inset-shadow-*` tokens.
- Several layers go in one comma-separated `box-shadow`; the first listed paints on
  top. Keep the order the generated class gives. It only shows when layers of
  different colour overlap.
- Outer `box-shadow` is drawn only outside the border box and follows
  `border-radius`, which matches Figma's `showShadowBehindNode: false` on a filled
  box.
- For a `content` cast shape (text, SVG, transparent PNG, fill-less wrapper) use
  `filter: drop-shadow(x y blur color)`, Tailwind `drop-shadow-[…]`. It follows the
  rendered alpha, takes no spread and no `inset`, and does not hide under translucent
  areas, so it also covers `showShadowBehindNode: true` when spread is 0. With spread
  on a `content` shape, record a `constraint`.
- A `filter` creates a stacking context and a containing block for fixed-position
  descendants. Put it on the element that casts, not on a page-level wrapper.
- Write a ring as `box-shadow: 0 0 0 Npx color` (outer) or `inset 0 0 0 Npx color`. It
  takes no layout space and follows `border-radius`. Tailwind `ring-N` / `inset-ring-N`
  set it through variables that compose with `shadow-*` on the same element; two
  arbitrary `shadow-[…]` classes do not compose, the later one wins. `outline` with
  `outline-offset` also follows `border-radius` in current browsers, but is usually
  reserved for focus.
- A shadow with a non-`NORMAL` blend has no per-shadow equivalent: `mix-blend-mode`
  blends the whole element. Put the shadow on a separate underlay element with
  `mix-blend-mode`, or record a `constraint`.
- For a blur-backed wash use `backdrop-filter: blur(…)` with the authored translucent
  background on the same element. Safari before 18 needs `-webkit-backdrop-filter`;
  check the built CSS carries it.
- An ancestor with `overflow: hidden` / `clip` clips an outer shadow. If the capture
  shows a cut edge, add padding to the clipping ancestor or move the clip.
- Dark mode: define the shadow token per theme, as the colour tokens are, when the
  design changes or drops it in dark.
