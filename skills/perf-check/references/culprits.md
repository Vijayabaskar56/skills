# Culprits

Each id is printed by `triage.py` and `bench.py`. A culprit is a lead, not a verdict: open the
trace in https://ui.perfetto.dev and confirm the frame before changing code. The fixes keep the
design; check them with a before and after screenshot (argent screenshot-diff).

## cpu-shadow-blur

Signature: repeated `Texture upload WxH` wider than the screen during scroll, slow bitmap uploads
in gfxinfo, RenderThread `Drawing` above 8ms.

Cause: React Native draws `boxShadow` on Android with `BlurMaskFilter`, which Skia rasterizes on
the CPU and redoes on every frame the shape is clipped by the screen edge. A shadow on a tall view
(a page panel, a long card) costs a full CPU blur per scroll frame. Inset shadows do the same.

Fix:
- Cast an outer shadow from a short strip clipped to the edge where it shows (`overflow: hidden`
  container, caster inside it), not from the tall view.
- Put an inset shadow on its own overlay view with `renderToHardwareTextureAndroid`, so it
  rasterizes once into a layer.
- Small fixed-size shadows on fully visible cards are cheap; leave them.

## svg-raster

Signature: one large square `Texture upload`, often with `allocateImageMemory` on the
RenderThread in the same frame.

Cause: react-native-svg on Android rasterizes each `Svg` into a bitmap at its full pixel size on
the CPU. A decorative 800dp glow becomes a 2400px bitmap.

Fix: draw gradients natively with `experimental_backgroundImage` (`radial-gradient(...)`,
`linear-gradient(...)`, React Native 0.80 or newer). Use percent geometry when the SVG used a
stretched `viewBox`. Keep SVG for icons and paths.

## oversized-bitmap

Signature: `Texture upload` or `Bitmap#prepareToDraw` larger than the view it fills.

Cause: bundled artwork exported at 2048px or more for a view a few hundred dp wide; the full
image is decoded and uploaded.

Fix: resize the asset to 3 times its largest display size (macOS: `sips -z <h> <w> file.png`), or
request a sized URL for remote images. Check every place the asset is used before picking the size.

## full-screen-bitmap

Signature: `Texture upload` exactly the screen size, with a long `Record View#draw()` in the same
main-thread frame.

Cause: something drew the window into a software bitmap: a blur or glass view capturing its
backdrop, a `MaskedView` in software mode, a snapshot. Find it by bisecting: build with the
suspect removed and look for the upload again.

## eager-webview

Signature: `WebViewFunctor::draw` slices during an open or scroll.

Cause: a WebView mounted before anyone opened it (a warmed sheet, a pre-warmed document stack).
It boots a browser engine and draws with the page.

Fix: mount web content on first open; drop warm or pre-load keys for web documents.

## live-map

Signature: `GL-Map` or `androidmapsapi` threads with tens of ms of CPU during an open.

Cause: a full interactive Google map inside a scrolling page for a card that never moves.

Fix: on Android, pass `liteMode` to a non-interactive `MapView` (it renders a static bitmap and
supports styles, markers and polylines), or mount the map when the card nears the viewport.

## text-heavy-mount

Signature: many `createViewUnsafe(RCTText)` in the long frames; around 0.3 to 0.5ms per Text on a
mid-range phone in a release build.

Cause: components that render one Text per character or word (rolling digits, per-word wrap
tricks), or hidden content mounted for later.

Fix: render static text until it must animate (a rolling number shows plain digits until its
value first changes); mount sheets on first open; stage below-the-fold sections one per idle
frame instead of all in one commit.

## svg-heavy-mount

Signature: many `createViewUnsafe(RNSVG...)` in the long frames.

Fix: replace decorative SVG trees (ticks, gauges, icons repeated per row) with views or a single
image, or stage them after the screen settles.

## Long frames without a named culprit

`frame ... mount Nms` means Fabric created and mounted views in that frame: cut how many views
that frame mounts. `draw Nms` with a large `wait-render` means the RenderThread was busy:
look at its slices in the same frame for uploads and layers.
