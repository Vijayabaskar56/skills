---
name: png-sequence-animation
description: Use when splitting a photo into PNG layers that move on their own (swing, dangle, drag, tilt), or when such layers look fake in motion: a shadow left behind, a neighbour's colour on a moving part, half a shadow, smudges, choppy or stray edges. Extracts layers from real pixels, moves light off moving parts, rigs them in React Native with touch, gyro and haptics, and proves it offline and on device. Not for static Figma builds; use figma-to-code.
argument-hint: "the source photo or Figma node, or the defect the user saw"
---

# PNG sequence animation

A layered photo looks real only if every pixel lives on the layer that moves with it: a part
carries its own pixels, a surface carries its own light, and each shadow or reflection belongs to
the part that casts it. Every check below exists because a run got one of these wrong; the ledger
is `references/mistakes.md`. Scripts are in this skill's `scripts/`; `$PY` is the config's
`python`, and the Python checks share `scripts/rig.py`, which loads and poses a rig. Project facts live in the repo's `.png-sequence-animation.json`, one entry per object under
`objects`, and the notes file each entry names; they win over this file.

A correction ("looks fake", "shadow stays behind", "half the shadow") reruns steps 3 to 8 for the
layer the user named.

## 0. Check setup

Run `scripts/doctor.sh <object>`. If the config or the object is missing, follow
`references/first-run.md`. Fix other
`missing` lines with `references/setup.md`, asking once before installing anything. Confirm each
`session` line yourself.

**Done when** doctor exits 0.

## 1. Choose layers over a renderer

If the user asks for 3D, a renderer or Blender, read the "Choose the approach" section of
`references/mistakes.md` first. Flat layers moved by transforms keep the photo's detail and cost
almost nothing. A 3D renderer must earn its place with a release build measured on a real phone.

**Done when** the approach is chosen, with the measurement or the reason.

## 2. Get the source at native resolution

Extract from the real photo, never from a generated or redrawn copy: image generation changes
the edges, teeth, texture and reflections, and the result never registers to the source. For a
Figma image, take the raw image fill, not the node export; `references/source-assets.md` says how.

**Done when** the source file has the photo's own pixel size and an alpha channel, and its path
is in the config's `source`.

## 3. Plan the rig

Write the rig JSON (`assets/rig.example.json`): every layer in draw order, back to front, on one
canvas the size of the source. Give each moving part a `pivot` in source pixels and a `swing`;
give each shadow the part it `follows`, the surface it is clipped to and its fitted `offset`; mark parts that must
not carry a neighbour's colour `neutral`, and the surface they move over `receives`. A part that
hangs inside another (a clapper in a bell) names it as `parent`; a region a part may show through
(an opening) is a `mask` layer that `follows` its part and is the part's `clip`. Settle which
object is in front where they cross by reading the photo (which edge occludes which), not by
size. Split objects baked into one layer before anything else: two keys in one PNG swing as one.

**Done when** the rig names every visible object once, with pivots read off the photo.

## 4. Extract into a fresh directory

Back up first: `scripts/backup-layers.sh <assetDir> <extract> <component>` prints the backup
directory; keep it for the report. Then run the config's `extract` into a new `mktemp -d` and
read `references/extraction.md` for segmentation, outlines, hidden areas and fills.

```bash
$PY scripts/recompose.py <rig> <source> --layers <out> --heatmap <out>/heat.png
$PY scripts/layer-lint.py <rig> --layers <out>
```

**Done when** recompose exits 0 with its heatmap bright only where you repainted on purpose, and
layer-lint prints no `fail` for `fragments`.

## 5. Separate light from the moving parts

Read `references/light-and-shadow.md` before touching a shadow, a reflection or a highlight. In
short: a surface carries no shadow of a part that moves over it; a part carries no reflection of
a neighbour; each shadow is its own layer that rides its part and is clipped to its receiver;
and a shadow taken from the photo is extended where the photo never showed one.

**Done when** layer-lint exits 0.

## 6. Simulate the swing offline

```bash
$PY scripts/swing-sim.py <rig> <out>/swing.png --layers <out> --angles=-18,-9,0,9,18
```

Open the sheet. Look for anything that stays put while its part moves, a hole where a hidden area
shows, a seam where two layers meet, and a shadow that stops partway down a part.

**Done when** the sheet at both extreme angles shows none of those, and you have looked at it.

## 7. Install only what changed

```bash
scripts/compare-layers.sh <out> <assetDir> <each layer you meant to change>
```

If it exits 1, a layer you did not mean to touch changed: find out why before installing. Copy
only the changed files into `assetDir`. Then wire or update the component with
`references/react-native.md`: one rig with `motion`, `touch` and `both` input modes, and any
haptic fired from the physics step that makes the motion.

**Done when** compare-layers exits 0 and the component draws every rig layer in rig order.

## 8. Verify on the device

Follow `references/verification.md`: one simulator that no other agent is driving, the config's
`deepLink`, a full-resolution screenshot cropped to the object, then a recording of a hard swing
turned into a sheet with `scripts/contact-sheet.sh`. A simulator has no gyro or haptics: there,
check that nothing throws and the scripted motion plays, and ask the user to feel the haptic and
tilt the rig on a phone. Run the repo's validate command.

**Done when** the contact sheet shows the widest swing with nothing left behind, validate exits
0, and each platform the user asked for has a capture.

## Hard rules

- Extract every visible pixel from the source photo. Use generation or inpainting only for areas
  the photo hides, and say which areas.
- Run `backup-layers.sh` before installing a round, so a revert is a copy.
- Regenerate into a fresh `mktemp -d` and install through `compare-layers.sh` with the list of
  layers the request covers.
- Keep the extractor the source of truth: change a layer by changing the script, never by
  editing the PNG.
- Before acting on a complaint screenshot, check it shows the installed build: compare its time
  with the install time and the screen with the deep link.
- Drive at most one simulator and one Android device per run, and only devices no other agent
  holds.
- Keep superseded layers until the user says to delete them; then use `trash`.

## Report

- Source path, size and where it came from (raw fill, file, export)
- The backup directory `backup-layers.sh` printed
- recompose's `mean`, `p99` and `alpha` line, and what the heatmap shows
- Every layer-lint line
- The swing sheet path, and the angles at which you looked
- compare-layers output: each changed file
- Device captures: screenshot crops and contact sheet paths, per platform, and the validate result
- Skipped steps, each with its reason
