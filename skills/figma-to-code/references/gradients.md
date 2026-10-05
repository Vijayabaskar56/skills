# Gradients

Read this reference when a node carries a gradient fill (`GRADIENT_LINEAR`,
`GRADIENT_RADIAL`, `GRADIENT_ANGULAR`, `GRADIENT_DIAMOND`), or when a rendered ramp does not
match the screenshot.

## Contents

- [Every stop, its alpha, and the layer's rotation](#every-stop-its-alpha-and-the-layers-rotation)
- [Take the stops from Figma's CSS or the transform](#take-the-stops-from-figmas-css-or-the-transform)
- [Stops outside the box](#stops-outside-the-box)
- [Transcribe direction and stops](#transcribe-direction-and-stops)
- [React Native](#react-native)
- [Web (React)](#web-react)
- [Visual verification](#visual-verification)

## Every stop, its alpha, and the layer's rotation

Designers build fades with four or five stops of one colour, each with its own opacity, to
shape the curve. A two or three stop copy is a different design: the endpoints and the
colour match, and only the ramp is off. Before writing any stop list:

1. **Count the stops from the raw read**, never from the picker panel or `get_design_context`.
   `fills[i].gradientStops` is the source.
2. **Keep each stop's own alpha.** A white fade is `#FFFFFF` at 100, 84, 45 and 0 percent,
   which is four colour-with-alpha values, not "white to transparent". Write a zero-alpha stop
   as the same colour at alpha 0, never `transparent`: `transparent` is black at alpha 0, and
   any renderer that interpolates without premultiplying draws a grey band through the fade.
3. **Multiply by the paint's `opacity`.** A fill at 60% opacity scales every stop's alpha by
   0.6.
4. **Apply the layer's rotation before reading positions.** A frame rotated 180 degrees
   flips the ramp: stop 0 sits at the visual bottom. Check `rotation` and
   `relativeTransform` on the layer and its parents.
5. **Size the layer to the frame.** The gradient spans the frame's height, not the whole card.
6. **Prove the fill varies inside the box.** Apply `gradientTransform` to the stops (first
   row, `t = a·x + b·y + c`) and check they land between 0 and 1 of the box. Stops that fall
   outside it mean the fill is one flat colour there, whatever the picker shows. Confirm by
   sampling the exported fill image down its centre column. On one search card the picker
   showed four stops at 72, 87, 92 and 100 percent, the transform put them past the frame,
   and the exported image was solid white.
7. **Look for a layer blur on the same frame.** When the fill is flat, a progressive layer
   blur is what draws the visible fade: a solid rectangle whose edge is blurred with a radius
   that grows along the blur axis. Model it as the blurred edge (a Gaussian step, sigma from
   the radius rule in [`progressive-blur.md`](progressive-blur.md), scaled by the blur ramp) and write the sampled alpha as gradient
   stops. Do not paint the picker's stops.

**Complete when:** the ledger row for the gradient lists the type, the transform-applied
stops with alpha, the paint opacity, the rotation, the frame size and any layer blur, and the
code's alpha profile is derived from those, not from the picker.

## Take the stops from Figma's CSS or the transform

Three sources disagree about where a gradient's stops sit. Rank them:

| Source                             | Trust                                                      |
| ---------------------------------- | ---------------------------------------------------------- |
| Figma UI → **copy as CSS**         | Authoritative. Box-relative, signed, ready to transcribe.  |
| Raw node (`fills[i]`)              | Authoritative, but needs `gradientTransform` applied.      |
| `get_design_context`               | Colours only. Positions are renormalised and lose sign.    |
| Gradient picker percentages        | Handle positions in the gradient's own space, not the box. |

One fill, as each source reports it:

```css
/* Figma copy as CSS, the design */
linear-gradient(180deg, #D2E9EF -43.92%, #F7F7F7 62.92%)

/* get_design_context: sign dropped, ramp inverted into the box */
linear-gradient(180.0212837209061deg, rgb(210,233,239) 43.916%, rgb(247,247,247) 62.917%)

/* gradient picker: the handles, not the box */
D2E9EF 13% · F7F7F7 78%
```

All three carry the same two colours, so comparing hex values proves nothing. Only the
first describes the ramp.

`gradientTransform` causes this. Figma stores stop positions in the gradient's own 0 to
1 space, plus a 2x3 matrix `[[a, b, c], [d, e, f]]` mapping a box point (0 to 1 in each
axis) into that space. The picker shows the first half. Code needs both composed. When the
Plugin API is the only route, read the fill read-only, and load the `figma-use` skill before
any `use_figma` call:

```js
const node = await figma.getNodeByIdAsync("NODE_ID");
return { width: node.width, height: node.height, fills: node.fills };
```

Colour channels come back as 0 to 1 floats. Multiply by 255. [`raw-node.js`](raw-node.js)
returns every gradient in the subtree already scaled, with its paint opacity, blend mode and
transform.

For a linear ramp the first row is enough: `t = a·x + b·y + c`. For a vertical ramp,
evaluate at the centre column (`x = 0.5`) and solve each stop for `y`. Worked on a header
band: row `[0.019, 0.9346, -0.0095]` gives `t = 0.9346·y`, so stops 0.2853 / 0.8144 /
0.9473 land at 0.3053 / 0.8714 / 1.0136 of the band, and the last stop sits off the edge.

Radial, angular and diamond fills need the handles, which are the inverse transform applied
to fixed gradient-space points: centre `(0.5, 0.5)`, first handle `(1, 0.5)`, second handle
`(0.5, 1)`. A linear ramp runs from `(0, 0.5)` to `(1, 0.5)`.

```js
function handles([[a, b, c], [d, e, f]]) {
  const det = a * e - b * d; // negative means the gradient is mirrored
  const box = (x, y) => [(e * (x - c) - b * (y - f)) / det, (a * (y - f) - d * (x - c)) / det];
  return { det, centre: box(0.5, 0.5), first: box(1, 0.5), second: box(0.5, 1) };
}
```

Results are box fractions. Multiply by the node's width and height before measuring any
angle or length: a non-square box stretches angles.

**Complete when:** every stop's position and colour comes from Figma's copied CSS or a
transform-applied raw node. Never from `get_design_context`, never from picker percentages.

## Stops outside the box

A stop position may be negative or above 100%. The ramp then starts before the box or
ends after it, so the visible edge is already partway through the blend. Above,
`-43.92%` puts the top edge `43.92 / (43.92 + 62.92) = 41.1%` of the way to `#F7F7F7`,
not at `#D2E9EF` at all. Whether you keep the stop or pre-mix it depends on the platform
(below).

Never record the authored CSS or the node id in a code comment beside the values. Figma
stays the source of truth: the next reader re-runs the raw read and re-derives them, rather
than trusting a note that can go stale.

**Complete when:** every off-box stop is either kept as authored (web) or pre-mixed (React
Native), derived from the raw read's authored stops.

## Transcribe direction and stops

CSS `0deg` points up and angles run clockwise, so `180deg` is `to bottom`. Figma angles
within a degree of an axis are noise from the handle positions. Snap them, and recompute the
positions for the snapped angle (see the web section). A snapped angle with positions taken
at the exact angle, or the reverse, shifts the ramp.

Preserve raw stops exactly, including repeated positions (a hard colour step) and
non-monotonic alpha. Both are authored intent that "tidying" the ramp destroys.

Figma interpolates between stops in gamma-encoded sRGB. Match that on every platform.

**Complete when:** type, direction, stop count and stop order match the raw node.

## React Native

**React Native clamps gradient stops to 0 to 100%, silently.** Passing `-43.92%` renders
as a full-strength first colour, which is a different design and raises no error. So pre-mix
the off-box stop into the colour the edge actually shows, and leave the in-box stop where it
is:

```ts
// linear-gradient(180deg, #D2E9EF -43.92%, #F7F7F7 62.92%)
const t = 43.92 / (43.92 + 62.92); // 0.411, blend already travelled at the top edge
const colors = ["#e1eff2", "#f7f7f7"];
const locations = [0, 0.6292];
```

Write each alpha stop through the project's colour-with-alpha helper (see the notes file,
config `notes`), reading the base colour from the token file (config `tokenFile`).

Pick what draws it:

| Gradient fills…                  | Use                                                                                 |
| -------------------------------- | ----------------------------------------------------------------------------------- |
| a box, linear                    | the project's linear gradient component, found in config `componentDirs` or `notes` |
| a shape, mask, path, or text     | `react-native-svg` `LinearGradient` / `RadialGradient`                              |
| a box, radial                    | `react-native-svg` `RadialGradient`                                                 |

A `View` with `experimental_backgroundImage: "linear-gradient(...)"` draws a box gradient
with no extra native host. Before choosing a wrapper, read its docstring rather than reaching
for `expo-linear-gradient`. Two consequences are worth knowing:

- SVG costs a whole `Svg` host per instance. A card with three tiles pays three.
- A `colors` / `locations` API takes `locations` as 0 to 1 fractions, matching Figma's
  `position` directly, with no conversion step to get wrong.

An SVG gradient with correct stops is not a bug. Migrate one only when the fill is a
plain box, and say so. The swap is a cleanup, not a fix.

Radial, angular and diamond gradients have no CSS equivalent in
`experimental_backgroundImage` (newer React Native releases may parse `radial-gradient()`;
check the installed version's docs before relying on it). They stay on `react-native-svg`,
where `gradientUnits="userSpaceOnUse"` lets you place the centre and radii in the layer's own
coordinates, and `gradientTransform` rotates or skews a radial ellipse. SVG has only linear
and radial gradients: draw an angular fill with `@shopify/react-native-skia`'s
`SweepGradient` if the project has Skia, otherwise export it as an image; draw a diamond as
four linear quadrants (see the web section for the geometry).

**Complete when:** no stop outside 0 to 1 reaches a React Native gradient, every pre-mixed
colour is derived from the authored stops, the renderer matches what the gradient fills, and
a migration is described as a migration.

## Web (React)

CSS keeps stops outside 0 to 100%, so transcribe Figma's copied CSS as is: no pre-mix. In
Tailwind, use an arbitrary value with underscores for spaces,
`bg-[linear-gradient(180deg,#D2E9EF_-43.92%,#F7F7F7_62.92%)]`, or the project's CSS file.
The `from-` / `via-` / `to-` utilities hold three stops; use the arbitrary value for more.
Figma paints `fills` bottom to top; CSS `background-image` lists the top layer first, so
reverse the order when a node has several fills.

**Linear.** CSS draws the gradient line through the box centre, sized so 0% and 100% touch
opposite corners, with isolines perpendicular to it in pixels. Figma's line runs between
its handles in box fractions. Convert from the first row of the transform and the node's
pixel size:

```js
function linearToCss([[a, b, c]], width, height, stops) {
  const gx = a / width, gy = b / height; // change of t per pixel
  const angle = ((Math.atan2(gx, -gy) * 180) / Math.PI + 360) % 360;
  const rad = (angle * Math.PI) / 180;
  const length = Math.abs(width * Math.sin(rad)) + Math.abs(height * Math.cos(rad));
  const atCentre = (a + b) / 2 + c;
  const at = (s) => 50 + ((s - atCentre) / Math.hypot(gx, gy) / length) * 100;
  const list = stops.map((s) => `${s.color} ${at(s.position).toFixed(2)}%`).join(", ");
  return `linear-gradient(${angle.toFixed(1)}deg, ${list})`;
}
```

To snap a near-vertical ramp, set `a` to 0 and add `a / 2` to `c` first, which keeps the
centre column's values. Worked on a band 393 by 120 with row `[0.0566, 0.9998, -0.0281]`:
the exact angle is `179.0deg` with stops at 2.66 / 49.31 / 72.93%, and snapped it is `180deg`
with stops at 0 / 49.27 / 74.22%. Both pairs draw the same ramp at the centre; mixing them
does not.

**Radial.** `t` is the distance from the centre in gradient space, reaching 1 at each
handle, and CSS's 100% is the ending ellipse, so stop positions carry over unchanged. With
`handles()` in pixels, `vx = first - centre` and `vy = second - centre`:

- If `vx` is horizontal and `vy` vertical (or swapped), write
  `radial-gradient(|vx|px |vy|px at <centre x>px <centre y>px, stops)`.
- Otherwise the ellipse is rotated or skewed, which `radial-gradient` cannot express. Draw
  `radial-gradient(closest-side, stops)` on a 200 by 200 px absolutely positioned child
  centred on `centre`, with `transform: matrix(vx.x/100, vx.y/100, vy.x/100, vy.y/100, 0, 0)`
  and the default centre origin, inside a parent with `overflow: hidden`. The matrix maps the
  child's circle onto the authored ellipse exactly.

**Angular.** Use `conic-gradient(from <angle> at <centre>, stops)`, with stop positions as
percentages of the turn. The ramp starts at the first handle and sweeps toward the second,
so `<angle>` is `atan2(vx.x, -vx.y)` in degrees. This is exact only when `vx` and `vy` are
perpendicular and equal in pixels; otherwise use the 200 px child and matrix trick above with
`conic-gradient(from 90deg, stops)`. A negative `det` mirrors the sweep, and the matrix
handles that too. Sample a point just past the start to confirm direction.

**Diamond.** CSS has no diamond gradient. `t` is linear inside each quadrant, so four linear
layers draw it exactly. On an element sized to the diamond's bounding box (or the 200 px
child and matrix when the handles are rotated), with every stop position halved:

```css
background:
  linear-gradient(to bottom right, STOPS) right bottom / 50% 50% no-repeat,
  linear-gradient(to bottom left, STOPS) left bottom / 50% 50% no-repeat,
  linear-gradient(to top right, STOPS) right top / 50% 50% no-repeat,
  linear-gradient(to top left, STOPS) left top / 50% 50% no-repeat;
```

Each quadrant's 0% sits at the centre and its 100% at the far corner, where `t` is 2, so
authored position `s` goes at `s × 50%`. Past the diamond's edge the last colour pads.

**Stop opacity.** Write alpha stops as `rgb(255 255 255 / 0.45)` or `#FFFFFF73`. CSS
interpolates in premultiplied alpha, which makes `transparent` safe in browsers, but writing
the same colour at alpha 0 keeps the ramp identical on every renderer.

**Colour interpolation.** Match Figma's sRGB:

- A gradient whose stops are all legacy colours (hex, `rgb()`, `hsl()`, named) interpolates
  in sRGB by default. Keep it that way.
- If any stop is a modern colour (`oklch()`, `lab()`, `color(display-p3 …)`), the default
  becomes Oklab. Tailwind v4's palette and many token files are `oklch()`, so a gradient
  built from tokens can drift mid-ramp. Add `in srgb` after the direction:
  `linear-gradient(180deg in srgb, …)`.
- Tailwind v4's `bg-linear-*`, `bg-radial` and `bg-conic` utilities interpolate in Oklab by
  default. Add the `/srgb` modifier (`bg-linear-to-b/srgb`) or use the arbitrary value.
- `in <colorspace>` needs a recent browser. One that cannot parse it drops the whole
  declaration, so put a plain declaration before it if the project supports older browsers.
- Never write `in oklab` or `in oklch` to "smooth" a Figma ramp. Same-hue alpha fades barely
  change; ramps between different hues visibly shift.

**Complete when:** off-box stops are kept, the angle and positions come from one computation
(exact or snapped), radial, angular and diamond fills use the construction above, alpha stops
repeat the colour, and every gradient interpolates in sRGB.

## Visual verification

Gradients are the standing exception to the visual loop's look-first rule. Everywhere else,
two images agreeing ends the check and measuring adds nothing. Here a wrong ramp looks
plausible: the endpoints match, the colours are right, and only the middle is off. A
gradient is fully specified, so compute the authored colour at each sample position and
diff it against the render. Checking endpoints alone passes a ramp that is wrong
everywhere between them.

Capture at scale 1 (device scale 1 on a simulator, device pixel ratio 1 in a browser), or let
the script divide by the capture's scale. Then walk a column:

```py
from PIL import Image

image = Image.open("<scratchpad>/figma-current.png").convert("RGB")
scale = image.width / DESIGN_WIDTH   # capture width / design frame width
column = int(31 * scale)             # clear of artwork and rounded corners
A, B = (210, 233, 239), (247, 247, 247)
START, END = -43.92, 62.92           # the authored stops, in percent

def authored(fraction):
    t = min(max((fraction * 100 - START) / (END - START), 0), 1)
    return tuple(round(A[i] + (B[i] - A[i]) * t) for i in range(3))

for fraction in (0.01, 0.10, 0.25, 0.45, 0.63, 0.85):
    y = int((TILE_TOP + fraction * TILE_HEIGHT) * scale)
    print(f"{fraction:.0%} {image.getpixel((column, y))} vs {authored(fraction)}")
```

Every pair should agree within a level or two. Anything further apart is a real
mismatch, not antialiasing. For radial, angular and diamond fills, walk a line out from the
centre instead of a column.

Pick the column with care. Artwork crossing it reads as a wild excursion mid-ramp. A
train's red track sampled at 55% returned `(219, 192, 190)` between two correct
readings. Sample a second column before believing a surprising value.

Diagnose before tuning:

- edge colour too saturated, ramp otherwise right: an off-box stop was clamped (React Native);
- band instead of a fade: positions came from `get_design_context`;
- ramp shifted along its axis: picker percentages used as box positions, or a snapped angle
  paired with exact-angle positions;
- ramp on the wrong axis: direction, not stops;
- colours off by a constant: 0 to 1 floats never scaled to 255;
- grey band in a fade to clear: a `transparent` stop on a renderer that does not premultiply;
- mid-ramp hue or lightness off, ends right (web): Oklab interpolation from `oklch()` stops or
  a Tailwind v4 gradient utility;
- no gradient at all (web): the declaration failed to parse and was dropped; read
  `getComputedStyle(el).backgroundImage`.

**Complete when:** rendered and authored colours are compared at a spread of positions
across the ramp, not only at its ends, and every pair agrees within antialiasing noise.
