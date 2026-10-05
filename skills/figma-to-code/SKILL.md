---
name: figma-to-code
description: Use when given a Figma link, node or the user's current Figma selection to build in React or React Native, when a screen or control "doesn't match", "looks off" or is "still wrong" against the design, or for a typography, shadow, blur, gradient or colour pass, even without a link. Builds pixel-accurate UI from authored Figma values, verified on a simulator (argent) or in a browser (agent-browser). Not for editing the Figma file; use figma-use.
argument-hint: "Figma link or node id, or the element that does not match"
---

# Figma to code

Figma is an evidence pipeline: structure, authored values, code mapping, render. Take every value
Figma can expose from Figma; where generated code contradicts the screenshot or the raw read, the
generated code is wrong. A correction ("doesn't match", "looks off") runs every step, scoped to the
element the user named. Most Figma work is a correction, and corrections fail when the agent skips
the re-read and tunes by eye.

`scripts/` and `references/` are relative to this skill's base directory. Project facts live in the
repo's `.figma-to-code.json` and the notes file it names; they win over this file.

## 0. Check setup

Run `scripts/doctor.sh <platform>` (use the config's platform, or detect it as in
`references/first-run.md`). Fix each `missing` line with `references/setup.md`, asking once before
installing anything. Fix an `optional` line only when this run needs that tool (an Android
capture, a desktop selection). Confirm each `session` line yourself.

**Done when** doctor exits 0 and the Figma MCP tools answer in this session.

## 1. Load the project config

Read `.figma-to-code.json` and its notes file. If the config is missing, follow
`references/first-run.md`.

**Done when** platform, figmaDownloadDir, assetDir, tokenFile, componentDirs, validate and verify
are known.

## 2. Lock the target

Get the node from the link in the message or earlier in the session; with neither, read the
desktop selection; if desktop is down, ask. Never work from memory or the user's screenshot alone.
Extract the file key and exact node id. Pick the Figma server before the first call:
`references/figma-mcp-servers.md` says which. Metadata, screenshot and design context come from
that one server; the raw read always goes through remote `use_figma`.

Then call, on that exact node, every time, even if you fetched it an hour ago:

1. `get_metadata` for the node tree and geometry.
2. `get_screenshot` for the visual source of truth.
3. `get_design_context` for authored styles and assets.
4. The raw read: load `figma-use`, run `references/raw-node.js` through remote `use_figma` with the
   node id filled in, and save the JSON to `<scratchpad>/figma-<nodeId>/raw.json` (`:` in the id
   written as `-`), overwriting an earlier run's. It returns every effect, gradient and image fill
   exactly as authored plus the visible text strings.

If the frame has no children, or its context is only a translucent fill with a backdrop blur, it
is a backdrop or a neighbour: read the desktop selection or ask for the element's link.

**Done when** the screenshot and metadata describe the requested state, `raw.json` holds this
run's raw read, and the target is one exact node.

## 3. Build the evidence ledger

Write the ledger to `<scratchpad>/figma-<nodeId>/ledger.md`, updating it in place on a rerun, and
give every visible layer a source of evidence; `references/evidence-ledger.md` has the fields and
the text, colour and icon procedure. Read completely, before implementing, each reference the node
calls for:

| The node has | Read |
| --- | --- |
| bitmap artwork or assets to download | `references/image-assets.md` |
| `LAYER_BLUR`, `BACKGROUND_BLUR`, progressive blur, or exported `blur(0px)` | `references/progressive-blur.md` |
| a gradient fill | `references/gradients.md` |
| a type or divider audit | `references/typography-pass.md` |
| shadows, rings or blur washes | `references/shadow-pass.md` |

For every text descendant, match its node id in `get_design_context` and record family, weight,
size, line height, tracking, alignment, colour, width, wrapping, truncation and line count. Check
each fill and stroke with `scripts/find-color-token.sh <hex> <tokenFile>`.

**Done when** `ledger.md` gives every layer and text descendant a node-id-matched record, every chosen token is
expanded and compared, and every weight, shadow slot and colour is exact or answered by the user.

## 4. Map evidence to the repository

Search `componentDirs` for the component name from Figma, its test id family, and screens showing
the same element, before building any card, button, badge, sheet, carousel or toast. Reuse or
extend what exists; if two code components render one Figma component, merge them. In a
correction, fix the shared component and re-capture every consumer. Compare what the text
component, variant, classes and inline style produce together; a matching variant name is not
evidence.

**Done when** every ledger entry has a destination, and shared changes are listed apart from
per-screen ones.

## 5. Implement literally

Read `references/translation-traps.md`, the neutral part and your platform's section. In a
correction, change only the authored value the element breaks. Preserve layer order and decorative
fills, transcribe crops instead of approximating them, take line height from type styles, keep
fixed offsets fixed unless the design is responsive, and use the project's tokens and wrappers.

**Done when** the render accounts for every ledger entry with no placeholder geometry, colour,
crop or effect.

## 6. Close the visual loop

Read `references/visual-loop.md` and your platform file: `references/verify-react-native.md`
(argent) or `references/verify-web.md` (agent-browser). Capture at scale 1, crop to the component,
run `scripts/text-diff.mjs <raw.json> <rendered.txt>`, spawn the critic, and fix or record every ranked gap.

**Done when** a critic has judged the current capture and every gap it ranked is fixed or
recorded as a named platform constraint with its measured impact.

## 7. Validate

Run the config's `validate` command. For platform-sensitive effects, repeat "Close the visual loop" on each target
(iOS and Android, or Chromium and WebKit).

**Done when** validate exits 0 and each requested target has a matching capture.

## Hard rules

- Re-fetch the node before every fix and change values only from what it returns.
- Take blur type, radii, gradient stops and image transforms from the raw read, never from
  generated CSS.
- Resolve colours, font weights and shadow slots by exact value. With no exact match, add a token
  or ask before writing code, and record the answer in the ledger.
- Download Figma assets only to `figmaDownloadDir`, then copy them into `assetDir` under real names.
- Keep every `use_figma` call read-only; this skill never changes the design file.
- Keep node ids, "Figma says" and authored values out of code comments; name values with a
  constant or token.
- Say "matches" only after a critic has judged the current capture.
- Read pixels with Python in the scratchpad only; edit source with the editor.

## Report

- Node id, server used, and the `raw.json` and `ledger.md` paths
- Questions asked and the answers recorded in the ledger
- `text-diff.mjs` counts: exact, case-only, spacing-only, missing, with each missing string named
- The critic's ranked gaps, each marked fixed or constraint with its measured impact
- Capture paths per target, and the validate exit status
- Skipped steps, each with its reason
