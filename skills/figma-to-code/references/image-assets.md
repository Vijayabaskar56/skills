# Image assets and crop geometry

Read this when a node includes bitmap artwork, needs an asset download, or renders with an
unwanted rectangular background.

## Contents

- [Choose the source image](#choose-the-source-image)
- [Download into the config figmaDownloadDir](#download-into-the-config-figmadownloaddir)
- [Prove transparency](#prove-transparency)
- [Read the image fill](#read-the-image-fill)
- [Record and judge](#record-and-judge)
- [React Native](#react-native)
- [Web (React)](#web-react)

## Choose the source image

Figma can expose two images that are not equivalent:

| Source                | Typical size | Result                                             |
| --------------------- | ------------ | -------------------------------------------------- |
| Original source image | 2048×2048    | original transparency and resolution               |
| Layer image or export | screen-sized | composited layer, background possibly baked in     |

Use the original source image. A composited layer export draws a rectangle edge and stops the
artwork sitting on the real background or gradient behind it.

Export vector art (icons, flat shapes, lines) as SVG. Export bitmaps as PNG when they need alpha
and JPG only for opaque photos.

## Download into the config figmaDownloadDir

The Figma desktop MCP writes assets only into directories allow-listed in Figma under Dev Mode,
MCP panel, Allowed directories. Pass the config `figmaDownloadDir` as `dirForAssetWrites`. If the
config has no `figmaDownloadDir`, ask the user for a directory they have allow-listed and save it to the config.
If desktop rejects it, have the user re-add it under Allowed directories. Never bypass the
allow-list.

Assets arrive with hashed filenames. Use the absolute path `get_design_context` returns, or list
the newest files, then copy the file into the config `assetDir` (the repo's asset folder) under a real name:

```bash
/bin/ls -t "$ASSET_DIR" | head
/bin/cp -f "$ASSET_DIR/<hash>.png" <project asset folder>/<name>.png
```

Remote connectors may return a short-lived asset URL instead. Download it before it expires. Pass
`dirForAssetWrites` only when the active tool schema has it.

## Prove transparency

Check dimensions, a corner pixel and the transparent fraction of the installed file:

```bash
python3 -c "
from PIL import Image
im=Image.open('path/to/x.png').convert('RGBA'); w,h=im.size
a=im.getchannel('A').histogram(); t=w*h
print(im.size, 'corner:', im.load()[0,0], f'transparent: {a[0]/t:.1%}')
"
```

- Transparent corner and a meaningful transparent fraction: likely the original artwork.
- Coloured corner and `0.0%` transparent: likely a baked background.

If one file is baked, audit its folder, because exports arrive in batches:

```bash
python3 -c "
from PIL import Image; import glob, os
for f in sorted(glob.glob('path/to/folder/*.png')):
    im=Image.open(f).convert('RGBA'); w,h=im.size
    tr=im.getchannel('A').histogram()[0]/(w*h)
    print(f'{os.path.basename(f):26} {w}x{h} {tr:5.1%} '
          f'{\"BAKED BG\" if tr<0.02 else \"ok\"}')
"
```

**Done when** the installed file's dimensions and alpha evidence match the intended original,
with no baked surface colour.

## Read the image fill

`get_design_context` usually expresses a crop as an oversized image inside a clipping box, with
percentages relative to the clip box:

```html
<div class="h-[304px] w-[380px] top-[-8px]">
  <div class="absolute inset-0 overflow-hidden">
    <img class="h-[133.57%] w-[106.72%] left-[-3.31%] top-[-15.48%]" />
  </div>
</div>
```

Transcribe those percentages. When they are missing or disagree with the screenshot, read the
`IMAGE` paint in the raw read: `raw-node.js` records its `scaleMode`, `imageTransform`,
`scalingFactor`, `rotation` and `filters`.

| `scaleMode` | Figma behaviour                                   | Extra field                   |
| ----------- | ------------------------------------------------- | ----------------------------- |
| `FILL`      | scale to cover the node, centred, overflow cut    | `rotation`                    |
| `FIT`       | scale to fit inside the node, centred, letterbox  | `rotation`                    |
| `CROP`      | the visible window into the image                 | `imageTransform` (2x3 matrix) |
| `TILE`      | repeat at the image's size times a factor         | `scalingFactor`, `rotation`   |

For `CROP` with no rotation, `imageTransform` is `[[a, 0, tx], [0, d, ty]]`: `a` and `d` are the
visible fraction of the image's width and height, `tx` and `ty` the fraction cut from its left and
top. Relative to the clip box, the image is `100/a`% wide, `100/d`% tall, at left `-100*tx/a`% and
top `-100*ty/d`%. Check the result against the `get_design_context` percentages when both exist.

If `filters` has non-zero values (exposure, contrast, saturation and the rest), the source image
does not carry the adjustment. Export the image layer alone, with no background sibling, or record
the gap in the ledger.

## Record and judge

Ledger fields per image: source (original or layer export), installed path, pixel size, alpha
evidence, `scaleMode`, clip box and image box (or `imageTransform`), focal point, and the densities
exported.

In the capture, check the artwork's edges for a rectangle, the focal point against the Figma
screenshot, and sharpness. A soft image means the density or export scale is too low.

**Done when** clip bounds, image bounds and focal point match the Figma screenshot on the target.

## React Native

Transcribe the clip box and image box into a style, with the image absolutely positioned inside an
`overflow: "hidden"` clip:

```tsx
const CLIP_W = 380;
const CLIP_H = 304;

const styles = StyleSheet.create({
  clip: { height: CLIP_H, marginTop: -8, overflow: "hidden", width: CLIP_W },
  illustration: {
    height: CLIP_H * 1.3357,
    left: CLIP_W * -0.0331,
    position: "absolute",
    top: CLIP_H * -0.1548,
    width: CLIP_W * 1.0672,
  },
});

<View style={styles.clip}>
  <Image source={source} style={styles.illustration} contentFit="fill" />
</View>;
```

- Exported Figma art: use `expo-image` `contentFit="fill"`, because the authored box already sets
  the final aspect ratio. `contain` changes the scale and the focal point.
- A photo from an API has an unknown aspect ratio, and `fill` stretches it. Give it
  `contentFit="cover"` in the authored frame and set `contentPosition` to the Figma focal point.
- `FILL` maps to `contentFit="cover"`, `FIT` to `contentFit="contain"`.
- `TILE`: core `Image` `resizeMode="repeat"` tiles the source. Check the tile size in the capture.
- Density: ship `name.png`, `name@2x.png` and `name@3x.png` side by side and
  `require("./name.png")`; Metro picks the file for the device's pixel ratio.
- SVG: render it as a component through the project's SVG setup (`react-native-svg`) at the
  authored frame size.

## Web (React)

**Export.** In Figma's export settings, export PNG or JPG at 1x, 2x and 3x of the frame size, or
SVG for vectors. Name them `name.png`, `name@2x.png`, `name@3x.png`. PNG and WebP keep alpha; JPG
does not, so artwork that sits on a gradient is never JPG.

**Where assets live.**

- `public/` (Vite, Next, CRA): served as is at `/name.png`, no hashing, no build-time check. Use it
  for files referenced by a fixed URL (favicons, `og:image`, CSS `url()` in files outside the
  bundle).
- Imported from the source tree (`import hero from "./hero.png"`): the bundler fingerprints the
  URL and fails the build if the file is missing. Next's static import also yields `width` and
  `height`. Prefer this for component artwork.
- SVG icons: import as a component (SVGR, `vite-plugin-svgr`) when colour or size is driven by
  props, or as a URL otherwise. Follow what the project already does.

**Reproduce the image fill with `<img>`.**

| `scaleMode` | CSS                                                                         |
| ----------- | --------------------------------------------------------------------------- |
| `FILL`      | `object-fit: cover; object-position: <focal point>` (default `50% 50%`)    |
| `FIT`       | `object-fit: contain`                                                       |
| `CROP`      | clip box `position: relative; overflow: hidden`, img `position: absolute` at the transcribed width, height, left, top percentages |
| `TILE`      | background image, below                                                     |
| `rotation`  | `transform: rotate(<n>deg)` on the image inside the clip                    |

For `CROP`, the Tailwind classes from `get_design_context` work as is (`absolute`,
`w-[106.72%]`, `h-[133.57%]`, `left-[-3.31%]`, `top-[-15.48%]`) inside an `overflow-hidden` box.
Set `max-width: none` on the img, because Tailwind's preflight gives every img `max-width: 100%`,
which caps an oversized crop.

**Background-image equivalents** for decorative images:

- `FILL`: `background-size: cover; background-position: center; background-repeat: no-repeat`.
- `FIT`: `background-size: contain` with the same position and repeat.
- `CROP`: `background-size: calc(100% / a) calc(100% / d)`. A background-position percentage
  aligns that point of the image with the same point of the box, so the position is
  `tx / (1 - a) * 100`% and `ty / (1 - d) * 100`%. When `a` or `d` is 1, that axis needs no
  offset. Pixel offsets are the simpler alternative.
- `TILE`: `background-repeat: repeat; background-size: <natural width * scalingFactor>px auto`.
- Density: `background-image: image-set("x.png" 1x, "x@2x.png" 2x)`. Safari before 17 needs
  `-webkit-image-set`; write both.

**srcset and sizes.**

- Fixed-size artwork: `<img src="x.png" srcset="x.png 1x, x@2x.png 2x, x@3x.png 3x" width="380"
  height="304" alt="">`.
- Fluid images: width descriptors plus `sizes`, e.g. `srcset="x-640.png 640w, x-1280.png 1280w"
  sizes="(min-width: 768px) 50vw, 100vw"`.
- Always set `width` and `height` (or `aspect-ratio`) so the box is reserved before load.
- Different crops per breakpoint: `<picture>` with `<source media>`.
- Next.js `next/image`: pass the static import, or `fill` plus `sizes` inside a positioned
  parent, and set `object-fit` through `style` or a class. Use it when the project already does.

**Judge** the capture at the device scale factor the design targets (2 or 3), since a missing 2x
or 3x file only shows up as softness at that density.
