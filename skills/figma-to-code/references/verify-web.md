# Verify on the web (agent-browser)

Read `visual-loop.md` first; this file supplies the platform steps. agent-browser serves command
syntax for the installed version: run `agent-browser skills get core --full` once per session and
take exact flags from it rather than from memory.

## Capture

1. Start the dev server from the repo's scripts if it is not running.
2. Open `verify.open` with the route for the node's state. Prefer a URL or query that lands on the
   state directly over clicking through.
3. Set the viewport to the Figma frame's width and height, at device scale factor 2 so text and
   edges are sharp. Record both numbers for the critic.
4. Wait for fonts and images to finish loading (`document.fonts.ready`, no pending network), then
   take a viewport screenshot at scale 1 into the scratchpad. For a component, screenshot the
   element or crop per `visual-loop.md`.

## Rendered text for the diff

Save the accessibility snapshot to a file and diff it:

```bash
node scripts/text-diff.mjs <raw-node.json> <scratch>/rendered.txt
```

If the snapshot omits visually hidden or aria-hidden text that the design shows, extract
`document.body.innerText` with agent-browser's eval command into the same file instead.

## Scale for the critic

Give the screenshot's pixel size, the device scale factor, the Figma frame's size, and the
viewport width in CSS pixels. One CSS pixel equals one Figma point at scale 1.

## Measure a named gap

Read geometry and computed styles from the DOM instead of pixels:

- `getBoundingClientRect()` on the element for position and size in CSS pixels.
- `getComputedStyle()` for the effective font family, weight, size, line height, letter spacing,
  colour, border radius, box shadow, filter and backdrop filter.
- Walk parents for `overflow: hidden` to find what clips an element.

Run these through agent-browser's eval command and compare with the ledger. The computed value is
the answer; the stylesheet is only a claim.

## Browsers

Chromium is the default. When the gap involves `backdrop-filter`, font smoothing or colour
interpolation, recheck in WebKit if agent-browser offers it, and record any difference as a
platform constraint.
