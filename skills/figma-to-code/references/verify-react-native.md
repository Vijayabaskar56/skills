# Verify on React Native (argent)

Read `visual-loop.md` first; this file supplies the platform commands for its steps. Opening the
device, deep links, saved flows and recovery from argent errors belong to the `verify-on-device`
skill; use it to reach the node's state, then capture here. For argent itself, load its
`argent-device-interact` skill before the first device call.

## Capture

Launch the app before opening a custom-scheme deep link, navigate to the node's state, then
capture at `scale: 1` and keep the returned path:

```bash
argent run list-devices --json
argent run open-url --udid <udid> --url "<config verify.open, filled in>"
argent run debugger-component-tree --port <metro-port> --device_id <udid> --maxNodes 150
argent run screenshot --udid <udid> --out <scratch>/figma-current.png
```

If the repo has a section or state deep link, use it instead of scrolling.

## Rendered text for the diff

```bash
argent run describe --udid <udid> > <scratch>/rendered.txt
node scripts/text-diff.mjs <raw-node.json> <scratch>/rendered.txt
```

## Scale for the critic

Give the capture's pixel size (`ffprobe`), its scale factor (3 on current iPhones), the Figma
frame's point size, and the device width in points.

## Measure a named gap

**Read the native frames.** When pixels are ambiguous, because two surfaces share a colour or a
shadow softens the boundary, take geometry from UIKit:

```bash
argent run native-devtools-status --udid <udid> --bundleId <id>   # restart-app if requiresRestart
argent run native-find-views --udid <udid> --bundleId <id> \
  --identifier <testID> --fields className,windowFrame,clipsToBounds --includeAncestors
```

`windowFrame` with `clipsToBounds` up the ancestor chain is the only way to see a view that
extends past the screen. Pixels cannot show what was never drawn, which is one more reason every
screen and shared component carries a `testID`.

## Platforms

For effects that differ by platform (blur, shadow, gradients, font rendering), repeat the loop on
both iOS and Android. Judge colour from capture pixels, never from the Simulator window.
