# Progressive blur

Read this reference when Figma shows a layer blur, background blur or progressive blur, or when
generated CSS reports `blur(0px)` while the screenshot is visibly blurred.

## Contents

- [Recover raw effects](#recover-raw-effects)
- [Keep the two effect roles apart](#keep-the-two-effect-roles-apart)
- [Do not duplicate Figma's blur-carrier fill](#do-not-duplicate-figmas-blur-carrier-fill)
- [Judge it in the capture](#judge-it-in-the-capture)
- [React Native](#react-native)
- [Web (React)](#web-react)

## Recover raw effects

Generated code cannot represent a Figma progressive blur and commonly emits only the end radius:

```css
filter: blur(0px);
backdrop-filter: blur(0px);
```

Treat any exported `backdrop-blur-[N]` or `blur(N)` as unverified. Figma has been seen to export a
progressive `0 → 12` background blur as a uniform `backdrop-blur-[6px]`, half the radius; take the
raw read's radius.

Run [`raw-node.js`](raw-node.js) (it reads effects for the whole subtree), or, for a single layer,
load the `figma-use` skill before any `use_figma` call and query it read-only:

```js
const node = await figma.getNodeByIdAsync("<nodeId>");
if (!node) throw new Error("Blur layer not found");

return {
  id: node.id,
  width: node.width,
  height: node.height,
  fills: node.fills,
  effects: node.effects,
};
```

A progressive effect contains:

```js
{
  type: "BACKGROUND_BLUR", // or "LAYER_BLUR"
  blurType: "PROGRESSIVE",
  startRadius: 0,
  radius: 18,
  startOffset: { x: 0.5, y: 0 },
  endOffset: { x: 0.5, y: 1 }
}
```

Offsets are normalized layer coordinates. This example is clear at the top and 18 at the bottom.
Read offsets and radii directly; never infer blur direction from the fill gradient.

Ledger fields: effect type, `blurType`, start and end radii, start and end offsets, fill, layer
bounds, clipping.

**Complete when:** every ledger field above is recorded from the raw node.

## Keep the two effect roles apart

| Figma effect      | Blurs                             |
| ----------------- | --------------------------------- |
| `BACKGROUND_BLUR` | the pixels behind the layer       |
| `LAYER_BLUR`      | the layer's own fill and content  |

Never turn a background blur into a content blur, or the reverse, to reach a working primitive.
The platform sections name the primitive for each role.

Figma's radius is a starting value. Figma and each renderer calibrate softness differently, so
compare the clear edge, midpoint and maximum-blur edge before changing it.

**Complete when:** each blurred layer has one primitive that matches its effect role.

## Do not duplicate Figma's blur-carrier fill

A Figma background blur shows only where its layer paints nonzero alpha. Designers therefore often
add a white or black linear gradient at very low opacity only to give the blur a compositing
region. Hiding that fill makes the whole Figma blur disappear; this does **not** prove the gradient
is a separate wash that code must stack on top. Neither native blur views nor CSS `backdrop-filter`
need a fill to activate.

1. Implement the blur alone.
2. Compare it with the Figma screenshot at the clear edge, midpoint and blurred edge.
3. Add a fill or overlay only when the design has an independently visible tint, or the blur-only
   capture is measurably missing that tint.
4. If a tint is needed, prefer the blur primitive's own tint control for a flat tint. Keep a
   gradient only when its spatial colour or opacity change is itself visible design intent.

Do not transcribe a `0% / 5% / 12%` white fill beside a `0 → 18` radius ramp. That
double-composites the lightening and turns the blur into fog. Do not delete a strong decorative
gradient merely because it shares a layer with a background blur either: the screenshot and a
blur-only capture decide its role. This exception covers blur-carrier fills only; a gradient that
stays part of the design follows [`gradients.md`](gradients.md).

**Complete when:** the result has one progressive blur pass and every remaining overlay has
independent visual evidence.

## Judge it in the capture

**Radius rule, both platforms.** Figma's blur radius `R` is not sigma, and the ratio is not settled:
`R / 3` treats visible spread as about three sigma, and `R / 2` follows the value Figma's CSS export
has been seen to write. Start in that range, calibrate against the Figma render at the
maximum-blur edge, and record the ratio that matched in the project notes so the next node starts
from it.

Capture the exact Figma variant and the matching app state with the project's verify tool (config
`verify`), on every platform or browser engine the project ships. Compare:

1. effect start and clear-edge readability;
2. midpoint softness;
3. maximum softness;
4. transition length and any unintended plateau;
5. tint or fog;
6. seams, banding and duplicated artwork.

Diagnose before tuning:

- wrong-side blur: direction or start and end radii were reversed;
- extra white fog: a Figma blur-carrier fill was duplicated as an overlay;
- ghosted artwork: a masked full-strength blur is cross-fading sharp and blurred copies;
- horizontal bands: too few stacked blur layers approximate a radius ramp;
- layer blur clipped into a line: expand its effect host.

The platform sections add their own causes. Use screenshots, element frames and pixel samples
before inventing curve corrections. Repeat per platform, because blur kernels and tint differ.

**Complete when:** all six regions match, or each remaining difference is measured and recorded as
a platform constraint.

## React Native

### Pick the primitive

| Figma effect      | Preferred mapping                                      |
| ----------------- | ------------------------------------------------------ |
| `BACKGROUND_BLUR` | native `ProgressiveBlurView`                           |
| `LAYER_BLUR`      | SVG `FeGaussianBlur`, Skia filter, or image blur pass  |

For a vertical background ramp with one clear edge and one maximum-blur edge, use
`ProgressiveBlurView` from `@sbaiahmed1/react-native-blur`. It is a native variable-radius blur on
iOS and Android; do not rebuild this shape with stacked `expo-blur` views or a masked
full-strength copy.

Before adding or upgrading the package:

1. Inspect `package.json`, the lockfile and the installed package API.
2. Query the current compatible release:
   `npm view @sbaiahmed1/react-native-blur version peerDependencies`.
3. Read the upstream migration notes and platform requirements for that release.
4. Install the latest project-compatible release, not a version copied from here. A native
   dependency needs a development-client rebuild; an Expo Go refresh does not load it.

The package currently requires the New Architecture. Verify the active release rather than
assuming its requirements are unchanged. Its iOS variable blur may rely on private Core Animation
behaviour; inspect the installed source and record the App Store risk when it matters.

### Map Figma to ProgressiveBlurView

For the common Figma `0 ↔ R` background blur:

```tsx
<ProgressiveBlurView
  blurType={isDark ? "dark" : "light"}
  blurAmount={18}
  direction="blurredBottomClearTop"
  startOffset={0}
  style={StyleSheet.absoluteFill}
/>
```

- `blurAmount`: the maximum Figma radius, as the first calibration value.
- `direction`: names the edge carrying the maximum radius and the edge that is clear.
- `startOffset`: the size of a fully blurred plateau measured from the blurred edge. It is **not**
  Figma's `startOffset` coordinate and not a curve correction.
- `startOffset={0}`: spreads the transition across the full view. Use it for Figma's ordinary
  full-height `0 → R` or `R → 0` effect.
- `startOffset>0`: only when the screenshot or raw effect has a real maximum-radius plateau.
  `0.25` holds maximum blur across 25% of the view before fading.
- `blurRounds`: Android smoothness and performance tuning, not Figma radius.
- `blurType`, `overlayColor`: tint controls. Compare them on device; do not add a second wash.

Never introduce offsets such as `0.583` to make the library's native easing look linear. That
compresses the transition into a large maximum-blur block with a harsh boundary. Tune the maximum
radius only after geometry, direction and plateau are correct.

Do not translate Figma's straight progressive control line into a straight iOS `CAFilter` mask.
Mask alpha is not a blur radius: even a small linear alpha smears high-contrast content and leaves
a harsh seam at the clear edge. Version 6.0.0 deliberately uses a cubic mask (`pow(t, 3)`) so the
result looks progressive. Keep the library curve unless a device comparison proves a library
defect; `0 → R` in Figma is not that proof.

### Handle unsupported shapes

`ProgressiveBlurView` covers vertical edge-to-clear and centre ramps. Do not force it onto
horizontal or diagonal vectors, two nonzero endpoint radii, multiple peaks, or `LAYER_BLUR`.

1. Keep `BACKGROUND_BLUR` and `LAYER_BLUR` as separate code paths.
2. Use Skia or a snapshot and image-filter pipeline when the artwork itself must follow a
   continuously varying radius.
3. Use a masked full-strength `BlurView` only as a recorded fallback. It cross-fades sharp and
   blurred copies, does not vary the radius, and can ghost.
4. Avoid stacked blur bands unless a measured platform limit leaves no better option; they add
   native views and visible banding.

For SVG layer blur, `FeGaussianBlur.stdDeviation` is sigma, not Figma's visual radius. Convert
with the radius rule in "Judge it in the capture" and verify the crop. Expand the effect host when a layer blur spills past its source bounds, or the host clips it
into a seam.

A fallback states exactly which effect shape the library did not support.

### Diagnose on device

Capture on iOS and Android.

- harsh transition plus a large fully blurred region: `startOffset` was mistaken for Figma's
  coordinate; use `0` unless a plateau is authored;
- harsh seam at the clear edge on iOS: the library's cubic mask was replaced with a linear one;
- no blur after adding or upgrading the package: rebuild the development client.

## Web (React)

### Pick the primitive

| Figma effect      | CSS                                                          |
| ----------------- | ------------------------------------------------------------ |
| `BACKGROUND_BLUR` | `backdrop-filter: blur()` plus `-webkit-backdrop-filter`     |
| `LAYER_BLUR`      | `filter: blur()` on the layer                                |

```css
.glass {
  -webkit-backdrop-filter: blur(9px);
  backdrop-filter: blur(9px);
}
.soft {
  filter: blur(9px);
}
```

Safari before 18 supports only `-webkit-backdrop-filter`; write both. With Tailwind
(`backdrop-blur-*`, `blur-*`), check the built CSS contains the prefixed declaration.

### Convert the radius

The CSS `blur()` argument is the Gaussian standard deviation (sigma), the same quantity as SVG
`stdDeviation`. Convert with the radius rule in "Judge it in the capture".

### Background blur traps

- `backdrop-filter` samples only up to the nearest Backdrop Root. An ancestor with `filter`,
  `opacity < 1`, `mask`, `clip-path`, `mix-blend-mode`, `backdrop-filter` or a `will-change` on
  one of those becomes one, and the blur then sees nothing behind that ancestor. If the blur does
  nothing, move the blurred element out from under such an ancestor.
- The element's own background paints over its blurred backdrop. An opaque background hides the
  blur; the tint must be translucent.
- The blur is clipped to the element's border box and `border-radius`.

### Build a progressive background blur

CSS has no variable-radius backdrop blur. Stack layers, each with a larger `backdrop-filter`
radius, and give each a `mask-image` `linear-gradient` so it appears further along the axis.
More layers make a smoother ramp and cost more.

```tsx
type ProgressiveBlurProps = {
  maxRadius: number;
  layers?: number;
  direction?: string;
};

export function ProgressiveBlur({
  maxRadius,
  layers = 6,
  direction = "to bottom",
}: ProgressiveBlurProps) {
  return (
    <div aria-hidden className="pointer-events-none absolute inset-0">
      {Array.from({ length: layers }, (_, index) => {
        const radius = maxRadius / 2 ** (layers - 1 - index);
        const start = (index / layers) * 100;
        const end = ((index + 1) / layers) * 100;
        const mask = `linear-gradient(${direction}, transparent ${start}%, black ${end}%)`;
        return (
          <div
            key={radius}
            className="absolute inset-0"
            style={{
              WebkitBackdropFilter: `blur(${radius}px)`,
              backdropFilter: `blur(${radius}px)`,
              WebkitMaskImage: mask,
              maskImage: mask,
            }}
          />
        );
      })}
    </div>
  );
}
```

- `maxRadius`: the Figma end radius converted to sigma (above), then calibrated. Later layers can
  blur what earlier layers already blurred, so the end can read stronger than `maxRadius`.
- `startRadius > 0`: add an unmasked base layer at that converted radius.
- A plateau: end the last layer's ramp before 100%.
- Direction: for a vertical or horizontal vector, use `to bottom` or `to right`, and map the start
  and end offsets to the first and last stop positions instead of 0% and 100%. For a diagonal
  vector, the CSS gradient line is not the offset line: with angle `θ = atan2(dx, -dy)` (pixel
  deltas, y down), the line has length `|w·sinθ| + |h·cosθ|` and is centred on the box, so project
  each offset onto it to get its percentage.
- Write both `mask-image` and `-webkit-mask-image`; older Safari and Chromium read only the
  prefixed one.

### Progressive layer blur

`filter` has no variable radius either. If the content is static, export the blurred artwork from
Figma as an image. Otherwise stack masked copies of the content with increasing `filter: blur()`,
and expect the same ghosting risk as a masked full-strength blur.

### Layer blur traps

- `filter: blur()` spills past the element. An ancestor with `overflow: hidden` clips it into a
  seam; give the host padding or move the clip.
- A blurred image fades to transparent at its edges because the kernel samples empty space. To
  keep solid edges, scale the image up slightly inside a clipping parent.

### Performance

- `backdrop-filter` recomputes whenever the content behind it changes, including every scroll
  frame. Cost grows with radius, area and layer count; a stacked progressive blur multiplies it.
- Keep the blurred area to the region Figma blurs, and use the fewest layers that pass the capture.
- Do not animate a blur radius. Fade a pre-blurred layer's `opacity` instead.
- Check on the slowest target the project supports, mobile Safari included.
- For browsers without support, write a translucent solid fallback under
  `@supports not ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px)))`.

### Diagnose in the browser

Capture in Chromium and in WebKit (Safari) at the config viewport.

- no blur at all: a Backdrop Root ancestor, an opaque background, or the missing `-webkit-` prefix
  in Safari;
- visible steps along the ramp: add layers or widen each mask ramp;
- blur stronger at the end than Figma: stacked layers compound; lower `maxRadius`.
