# Visual loop

Read this in step 5, together with the platform file (`verify-react-native.md` or `verify-web.md`),
which supplies the capture and measurement commands.

## Capture and crop

Navigate to the same state as the Figma node and capture at scale 1. When the Figma node is a
component rather than a whole screen, crop the capture to that component. A reviewer handed a full
screen against a card render spends its attention on the framing instead of the card.

```bash
ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 <capture.png>
ffmpeg -y -loglevel error -i <capture.png> -vf "crop=<w>:<h>:<x>:<y>" <cropped.png>
```

Take crop coordinates from the capture file itself, never from the preview you were shown.
Previews are downscaled: a 924-wide reading applied to a 1170px capture keeps the left 79% and
silently cuts every trailing chevron and value, and the critic will correctly report them missing.

Compare the same regions in both images: outer bounds and anchors; crop and focal point; effective
font family and weight, size, line height, tracking, colour, alignment, baseline and wrapping;
gradient stops; effect start, peak and disappearance; clipping seams; CTA and safe-area spacing.
A plausible full-screen thumbnail is not evidence of a match.

## Diff the text

Save the rendered strings as the platform file describes, then:

```bash
node scripts/text-diff.mjs <raw-node.json> <rendered.txt>
```

It lists each Figma string as exact, case-only, spacing-only or missing. A spacing-only mismatch is
always a transcription bug (it caught "$24.99 /6 months" against Figma's "$24.99 / 6 months").
Name each missing string as live data that differs by design, or a dropped span.

## Brief the critic

Your own reading of the two images is the weakest evidence in this step: you wrote the code and
already believe it matches. Hand the judgement to an agent that sees only the two images. Invoking
this skill authorises the spawn.

Spawn one critic per comparison, with `subagent_type: "figma-critic"` and no `model` override. The
agent definition (`assets/figma-critic.md`, installed per `setup.md`) carries the brief, so your
prompt supplies only the case:

1. the Figma file key and node id, so it fetches the render itself;
2. the absolute path to the capture, to open with `Read`;
3. the authored values from the ledger, stated as vocabulary for naming a gap, never as a
   checklist to confirm;
4. anything in the capture that is not the implementation: tooling overlays, loose crop framing,
   live data that differs from Figma's sample;
5. the scale: capture pixel size and scale factor, Figma frame size, and the device or viewport
   width.

Item 3's wording decides whether the critic stays visual. Hex codes and 2pt widths under "audit
against these" order a measurement nobody can do by eye. State the values, then say they are there
to name what a difference violates.

**Fallback** when no `figma-critic` agent exists (Codex, other agents, or not installed): spawn one
read-only subagent whose prompt is the body of `assets/figma-critic.md` followed by the same five
items. Give it no shell. A critic holding a shell measures instead of judging.

Then fix every ranked gap or record it as a measured platform constraint. "Cannot tell" is not a
pass; it is the one answer that earns a measurement. A clean report never replaces the ledger, and
re-running the critic on an unchanged capture buys nothing.

## Measure only a named gap you cannot explain

Measurement answers "why is this different", never "is this the same". Two images that agree are
the finish line. Gradients are the one exception: `gradients.md` samples the ramp even when the
images agree.

Measure only when all three hold:

1. a specific difference has been named, by the critic or plainly visible to you;
2. you cannot explain it from the diff you just wrote;
3. the answer is not already in the code. If the critic says a line reads one step small and the
   diff says `14px`, the diff is the answer.

Then measure in increasing order of cost, never by iterating style values:

1. **Trace the edge.** Walk pixel rows of the scale-1 capture to find where a surface begins. A
   radius reads as a curve across rows; a column of identical values is a square edge. Divide by
   the capture scale for points. Extract a row with `ffmpeg -f rawvideo -pix_fmt rgb24` and read
   the bytes in a `python3 -c` one-liner in the scratchpad. Python reads pixels and nothing else;
   source edits go through the editor.
2. **Read the platform's geometry.** Native frames on React Native, computed styles and bounding
   rects on the web; the platform file has the commands.
3. **Colour a layer.** When several layers could paint a region, set one to `red` for a single
   capture. One screenshot settles which layer owns the region.
