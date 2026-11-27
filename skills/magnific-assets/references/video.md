# Video: animate an illustration

The goal is a micro-animation: one named element moves a little, everything else is the original
art, it loops (or plays once and holds), and its first frame doubles as the still. "A little" is
measured where it is shown: pick an element and a travel that read at the config's `displaySize`
(SKILL.md step 2, `judging.md` check 3), and say that size in the prompt ("rises about a third of
the crane's height"), not "slightly".

## Model

Free in Relax mode (checked 2026-11-26 in the model picker, which marks the free ones):
Kling 2.5 at 720p with a start image only. Verify in the picker each run; the free list changes.

## Start image

First make the art the size it ships at: trim it to its outline and scale it to match the
project's other shipped arts (read one from the config's `assetDir`, for example its width).
Every builder writes frames at the art's size. Then
`scripts/prep_start.py <art.png> <work>/start.png --bg green|white`, scaled 2x.

- `--bg green` when the moving part will be cut out of the clip: it leaves its outline in the art
  (rolls, tips, sways out), or it has white or light edges.
- `--bg white` when the motion stays inside the art (water, smoke, lights), built with
  `loop_from_clip.py`, which takes alpha from the art.

## Prompt pattern

Kling follows positive, concrete sentences. Name the one thing that moves, say how little, and
say everything else is still.

```
Static locked-off camera, no camera movement, no zoom. <Scene in a few words> on a flat solid
<green|white> background that stays perfectly flat and unchanged. <Every other object> never moves.
Only <the element> <verb>: <the exact small motion, direction and return>, staying in exactly the
same spot. Small, slow, subtle movement. Everything keeps its exact shape, colours and details.
```

Negative prompt: `camera movement, zoom, pan, <other object> moving, sliding, moving backwards,
tumbling, large movement, morphing, distortion, new objects, background change, colour shift,
lighting change, flicker, melting`.

For a part that travels along a fixed path (a crane trolley, a car on a road, a lift), say the
track, the direction and the distance ("the trolley slides left along the jib to its tip, about a
third of its length"), and drop "staying in exactly the same spot", which fights the motion.
For a one-shot action, describe each beat in order and the end state ("stands up on its edge,
tips over, falls flat onto the stack, wobbles once and settles; after it settles nothing moves").

Verbs that worked: "flows down", "ripples", "rises", "blink left and right", "flicker", "sways".
For a small rotation, "wobbles gently in place, rocks a few degrees to the right then back" gave
the best opening half-second; "rolls slightly" made the object roll away.

## What Kling does

- It overshoots "slight" motion: the first 0.5 to 1 s is usually the gentle part, then the object
  tumbles or slides. Read `contact_sheet.sh --first 15 --every 2` and keep only the calm stretch.
- It cannot end where it started (no end image in Relax mode), so a return is built locally.
- It may restyle the art (new windows on houses, different textures). The builders keep every
  unmoving pixel from the art; if the moving part itself is restyled, try a new prompt or go
  procedural.
- Two takes of the same prompt differ a lot; when one fails, submit two variations at once.
- It may zoom or shift the framing slightly. `part_over_art.py` measures the scale and offset
  against the unmoving part of the art; other builders assume the clip is the start image
  scaled, so compare a clip frame with the art side by side first.
- Some clips play one complete, good action over the full 5 s (a crane slews and lowers its load,
  a coin rocks and comes back). Then the opening-only rule does not apply: use the whole action,
  or one full swing of it.

## Keep the art consistent

What ships must look like the art everywhere except the moving part. Never ship whole Kling
frames, even when the clip looks right on its own: Kling repaints the ground, base tiles and
textures a little lighter or blurrier, and next to the other arts that reads as a different
picture. Take only the moving part from the clip and every other pixel from the art, and prove
it with `audit.py --protect` on the regions that must not change.

## Pick the builder

| Motion | Builder | Notes |
| --- | --- | --- |
| Stays inside the art's outline and repeats (water, smoke, ripples, lights, sparks, grass) | `loop_from_clip.py art clip out` | Crossfaded loop from clip frames 36..120. `--threshold 5` drops jitter, `--alpha-min 40` lets soft smoke move, `--box` limits it to a region. |
| Small motion that leaves the outline and should come back (rock, tip, sway) | `keyed_pingpong.py art clip out --last N` | Needs a green start image. Out and back on an eased timeline, then rest. Choose N on the opening contact sheet. |
| One action that should play once and hold (a landing, a strike, a drive) | `loop_from_clip.py --once`, then `encode.sh --once` | Start from a state that already makes sense: the object is in the scene at frame 0, not appearing from nowhere. |
| Kling keeps restyling it, or the motion is rigid and simple (a blinking light, a glint) | A small procedural script on the art's own pixels | Glows, pulses and sprite moves look right; rigid rotations with filled-in hidden areas looked fake. |
| A whole action, or one full swing, where the part travels far or leaves its pose (a crane slews and lowers a load, a coin rocks or falls) | `part_over_art.py art clip out --range S:E:STEP --seed-hue LO,HI --zone ...` | Aligns the clip to the art, then per frame takes only the part (its colour, the motion joined to it, `--hang` for a cable, anything opaque over background) and the art elsewhere. `--erase-box` removes the art's old pose. Ping-pong by default; `--cycle MIN` plays one full swing that ends where it started; `--forward` plays once. Check `outside_zone_max` in its report. |

## Size

On one 633 px scene, dropping `encode.sh --qalpha` from 90 to 50 took the AVIF from 712 KB to
384 KB with no visible loss: the alpha plane's quality is often the bigger lever than `--quality`. Keep 24 fps: dropping frames saves size but makes travelling motion step
(see "Frame rate" in mistakes.md).

## Numbers to read

`loop_from_clip.py` prints `motion_in_mask` (about 1.5 was the least that read as motion at card
size on one art; calibrate per art),
`clip_drift_static` (how far the clip strayed from the art outside the mask) and `loop_wrap`.
`audit.py` checks the finished frames; see `judging.md` for what to accept.
