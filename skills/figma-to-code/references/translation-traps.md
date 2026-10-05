# Translation traps

Read this in step 4 before writing code, and again in step 5 when a gap has no obvious cause.
Each trap shipped at least once. Read the neutral list, then the section for config `platform`.

## Every platform

- **Text bounds are not line height.** Read line height from `get_design_context`.
- **Padding is two-sided.** A `py-*` class or `paddingVertical` adds its value above and below.
- **Figma device frames include the physical screen edges.** An authored bottom offset in a phone
  frame already counts the home indicator area. Do not add the safe-area inset on top of it.
- **Layered backgrounds are cumulative.** Dropping the radial fill because the linear fill looks
  close removes the authored glow.
- **A Figma blur-carrier gradient is not automatically a wash.** Figma needs painted alpha to
  reveal background blur. A code blur (a native progressive blur view, or CSS `backdrop-filter`
  under a `mask-image`) does not. Add the gradient only when it contributes visible tint of its own.
- **A squeezed photo is a fit problem.** Stretch-to-fill is right only for exported Figma art
  inside a transcribed crop box, where the authored box supplies the aspect. An API photo has an
  unknown aspect, so it takes cover in the authored frame, with the Figma focal point as the
  position.
- **Nested radii are concentric.** An inner surface inset by `p` inside an outer radius `R` takes
  radius `R - p`, not the outer value. Figma often authors it that way; copying the outer radius
  makes the inner corners look fat.
- **Design width is not screen width.** A 380-unit element stays 380 on a 402-unit screen unless
  the design specifies proportional sizing.
- **Fixed artwork stages can starve content.** Keep the design maximum while letting the stage
  yield space to the content below it on shorter screens.
- **Your own side-by-side is not a review.** You wrote the code and have been looking at the Figma
  render all task, so you will see the match you expect. A fresh critic finds what you stopped
  being able to see.
- **Measuring a match you can already see proves nothing.** It spends reloads to re-derive what
  the diff and the two images already say.
- **An exported blur value is never the authored one.** Generated CSS writes a progressive `0 → 12`
  background blur as `backdrop-blur-[6px]`: half the radius, and uniform. Two sheet footers
  shipped wrong from that line. The raw read's `blurType`, `radius` and `startRadius` are the
  values.
- **Figma's default stroke is 1 unit.** Render it as 1pt or 1px, never as a hairline utility.
- **No Figma notes in code.** Never cite a node id, "Figma says" or an authored value in a comment,
  and never explain a workaround in one. Name the value with a constant or token; Figma stays the
  source of truth and this skill re-reads it before every fix.
- **Judge colour from capture pixels, never from a live window by eye.** Compare authored values
  against pixels sampled from the capture file (see [`gradients.md`](gradients.md) for the
  sampling loop).
- **A corner that renders square is a frame problem, not a radius problem.** A view extending past
  its clipping ancestor has its far corners sheared flat while its near corners round normally, so
  the radius looks half-applied. Check the element's on-screen frame against the clip before
  touching the radius value.
- **Figma corner smoothing has no plain radius equivalent.** A smoothed corner is a squircle; a
  radius draws a circular arc, which reads slightly sharper at the same value. Record the
  smoothing and pick a platform technique below, or accept the arc and say so.

## React Native

- **A hairline utility is not 1pt.** `StyleSheet.hairlineWidth` (and any `hairline` class built on
  it) is a third of a point on a 3x screen and all but disappears. A 1pt line is `w-px` / `h-px`
  or `width: 1`.
- **A native progressive blur view needs no carrier gradient.** `ProgressiveBlurView` (from
  `@sbaiahmed1/react-native-blur`, see [`progressive-blur.md`](progressive-blur.md)) reveals the
  blur without painted alpha.
- **`contentFit` decides the squeeze.** In `expo-image`, `contentFit="fill"` only for exported
  Figma art in a transcribed crop box; an API photo takes `contentFit="cover"` with the Figma
  focal point as `contentPosition`.
- **Judge colour from the capture PNG, never the Simulator window.** The Simulator shows sRGB
  content on a Display P3 Mac screen unconverted, so it looks darker and more saturated than Figma
  beside it, while the capture PNG matches the authored values and a real iPhone matches Figma.
- **Sheets invite sheared corners.** Sheet libraries size their container to the tallest detent
  and translate it into place, so part of it sits off screen. Check `windowFrame` before touching
  the radius value.
- **Corner smoothing on iOS is `borderCurve: 'continuous'`.** Android ignores it and draws a
  circular arc.

## Web (React)

- **Auto layout is flexbox.** Direction is `flex-direction`, item spacing is `gap`, padding is
  `padding`, "space between" is `justify-content: space-between`, and counter-axis alignment is
  `align-items`. Wrap is `flex-wrap: wrap` with the row gap as `row-gap`. Never rebuild auto
  layout spacing with margins on children.
- **Hug, fill and fixed are three flex settings.** Hug is `width: auto` / `fit-content` with
  `flex: none`. Fill on the main axis is `flex: 1 1 0` plus `min-width: 0` (or `min-height: 0`), so
  long text truncates instead of pushing siblings. Fill on the cross axis is
  `align-self: stretch`. Fixed is the width plus `flex-shrink: 0`, since flex items shrink by
  default and a fixed Figma box will not.
- **Absolute inside auto layout leaves the flow.** The child takes `position: absolute` and the
  frame takes `position: relative`. CSS offsets start at the padding box, inside any border, while
  Figma x/y start at the frame's outer edge, so subtract the border width.
- **Clip content is `overflow: hidden`.** It clips children's shadows as Figma does, and also
  their focus rings, which Figma never draws; pull a clipped child's ring inside with a negative
  `outline-offset`. With clip off in Figma, leave `overflow` visible. Use `overflow: clip` when the
  clipper must not become a scroll container.
- **Constraints become responsive CSS.** Left and right is `left` plus `right` (stretch). Center is
  `left: 50%` with `translate: -50%` (or a flex or grid centre). Scale is a percentage width.
  Top and bottom follow the same rules on the vertical axis. A Figma frame at one width does not
  say what happens at another; read the constraints and ask when a breakpoint has no frame.
- **Stroke alignment does not map to `border`.** A CSS border sits inside the box under
  `box-sizing: border-box` (Tailwind's preflight sets it) and pushes content inward by its width.
  Figma strokes do not move auto layout children unless the frame includes strokes in layout.
  - Inside: `box-shadow: inset 0 0 0 Npx <colour>`, or a border with padding reduced by N.
  - Outside: `box-shadow: 0 0 0 Npx <colour>`, or `outline: Npx solid` with `outline-offset: 0`.
    Neither changes layout.
  - Center: half inside and half outside, as two rings of N/2.
- **Corner smoothing is not in `border-radius`.** Clip to an SVG squircle path (`clip-path` or
  `mask-image`) when the smoothing is visible at the rendered size. The CSS `corner-shape`
  property is new and not in every browser; check support before relying on it.
- **Figma px are CSS px; rem follows the root font size.** At the default 16px root, 1rem is 16px
  and Tailwind's spacing step is 0.25rem (4px). Convert with that root, and check whether the
  project changes the root size before trusting a rem value.
- **`100vh` is not the visible phone screen.** Mobile browsers count the area behind collapsing
  toolbars. Size a full-screen mobile frame with `100dvh` (or `100svh` for the smallest state).
  Use `env(safe-area-inset-bottom)` only with `viewport-fit=cover` in the viewport meta.
- **`object-fit` decides the squeeze.** `object-fit: fill` only for exported Figma art in a
  transcribed crop box; an API photo takes `object-fit: cover` with the Figma focal point as
  `object-position`.
- **Capture colour from the headless screenshot.** A macOS screenshot of a browser window may carry
  the display's colour profile, which shifts sampled values. Sample the verify tool's capture.
