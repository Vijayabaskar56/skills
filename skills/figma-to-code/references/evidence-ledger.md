# Evidence ledger

Read this in SKILL.md's "Build the evidence ledger" step. It is the full procedure behind the
ledger (`<scratchpad>/figma-<nodeId>/ledger.md`); SKILL.md keeps the minimum.

## Account for every visible layer

- bounds and clipping;
- ordering and overlap;
- typography;
- fills and gradients;
- shadows and effects;
- image source and crop;
- fixed versus flexible layout;
- state-specific visibility.

## Evidence roles

| Evidence | Trust for |
| --- | --- |
| `get_metadata` | ids, names, x/y/width/height, hierarchy |
| `get_design_context` | typography, flat fills, radii, shadows, generated asset sources |
| `get_screenshot` | final appearance, overlap, clipping, exporter contradictions |
| Raw read (`raw-node.js`) | blur type and radii, gradient stops and transforms, visible text, anything flattened |

Generated CSS has been seen to export a progressive blur as a uniform blur at half its radius, and
it renormalises gradient stops, so take both from the raw read only.

## Gradient stops

Generated CSS renormalises stop positions, so a gradient can export with the right colours and the
wrong ramp. Comparing hex values will never catch that. Count the stops too, from the raw read.
Fades are often four or five stops of one colour with different alphas, sometimes on a rotated
frame, and the picker percentages can sit outside the box entirely, leaving a flat fill whose fade
comes from a layer blur. Reproduce every stop that lands inside the box. [`gradients.md`](gradients.md)
has the checklist.

## Components with more than one state

When the element has two or more Figma frames (collapsed and expanded, idle and pressed, card and
sheet), the ledger is a table with one column per frame and one row per property: every text size,
tracking, position, opacity, blur, gradient transform and handle. Fill every cell from that frame's
own design context and raw read, then write the interpolation for each row. A property filled for
one frame only blocks the build.

Never build one frame and stretch it to the other. One sheet built that way shipped a 36px wordmark
where the expanded frame is 32px, the collapsed key halo and handle in both states, and a stretched
glow whose edges ran 10 to 15 levels dark.

Position a moving element from the edge it stays attached to. A button pinned to the bottom
interpolates its distance from the visible bottom edge, not an offset from the sheet top, or it
drifts mid-transition.

## Audit every descendant text node

The steps below are the minimum for a single node. For a full per-section type audit, every text
node and the dividers that ride along with it, [`typography-pass.md`](typography-pass.md) is the
procedure. For a full per-section shadow audit, every drop-shadow, box-shadow, inset ring and
blur-backed wash, [`shadow-pass.md`](shadow-pass.md) is the procedure, and no recipe is guessed,
nearest-neighboured, or silently substituted.

For every `<text>` descendant returned by `get_metadata`:

1. Record its node id and visible text.
2. Find the same `data-node-id` in `get_design_context`.
3. Record its font family, weight or static font instance, style, size, authored line height,
   letter spacing, alignment, colour, width, wrapping, truncation, and line count. Resolve the
   weight against the fonts the project ships (typography-pass "Weight availability"); a weight
   with no font file is a blocking question to the user, never a silent substitution.
4. Expand the proposed typography token, text component variant (config `textComponent`) or
   class into its effective values. Never accept a token from its semantic name alone.
5. Compare every effective value with Figma before implementation. Add a local override when a
   shared token differs. Change the shared token only when all its consumers should change.

If `get_design_context` omits a text node that metadata found, because its output was truncated or
simplified, call `get_design_context` again with that text node's exact id. Typography extraction
is incomplete until every visible text descendant has a complete record.

## Colours

Resolve every fill and stroke to a token by exact value: from the repo root run
`scripts/find-color-token.sh <colour> <tokenFile>` (in this skill's folder), with the authored hex
or rgba and the token file from config `tokenFile`. An exact match is the token. With no exact
match, add a token or ask. Never take the nearest-looking token: pin, status, divider and badge
colours were repeatedly shipped one shade off that way. Record alpha separately from colour.

## Icons and vector art

Take icons from the node: export the vector (`get_design_context` asset or remote
`download_assets`) and render it as SVG at the authored frame size. Do not substitute a library
glyph or a placeholder while the node has one. Record the icon's frame size and the glyph's size
separately; a 24pt frame holding an 18pt glyph is two values, not one. Only when Figma has no icon
for a slot, say so and use a placeholder.

## React Native

- Record sizes in points. Figma units map 1:1 to pt.
- Record the bottom offset of anything in a phone frame as authored; the frame already includes
  the physical bottom edge, so note whether the element sits in the safe area.
- Record font weight as the bundled static font file that will render it.
- Record pressed and disabled frames as states. There is no hover.
- Render icons as components through `react-native-svg`.

## Web (React)

- Record sizes in CSS px (Figma units map 1:1 at 1x), then the rem value if the project sizes type
  or spacing in rem.
- Record hover, focus-visible, pressed (`:active`) and disabled frames as states when Figma has
  them. Record a missing hover or focus frame as a question, not as "same as idle".
- Record the frame width the design was drawn at and the breakpoint it belongs to; a desktop
  frame and a mobile frame of one component are two states.
- Record font weight as the `@font-face` weight the project loads. A weight that is not loaded is
  faux-bolded or falls back, the same blocking question as a missing file.
- Render icons as inline SVG or an SVG component when colour follows `currentColor`, and as
  `<img>` only for fixed-colour art.
