# Judging motion

Score every clip before building, and every built loop before showing it. Look at pictures, not
only numbers: a contact sheet of the whole clip, one of the opening (`--first 15 --every 2`), and
after the build the audit boards on light and dark and the preview GIF.

## Order of checks

Reject at the first failure; later checks only rank clips that pass the earlier ones.

1. **Only the named element moves.** Everything else matches the art. A moving camera, a second
   object that shifts, or a restyled scene fails, unless the builder masks it out completely.
2. **It moves the way the request said.** Direction and kind: "rolls right and back" is a rotation
   in place, not a slide backwards. When the request names a motion, compare against those words.
3. **It reads at the display size, and no bigger than asked.** Judge it in display points, on
   the card GIF from `display_size.py`, never on the full-size preview. What read on a 211 pt
   card: a solid object at least about 8 pt across travelling 15 pt or more (a crane basket
   rising 29 pt), a coin tipping across a stack, water falling over 40 pt, a light that blinks.
   What read as nothing: a part under about 3 pt thick (an excavator arm, a wire), churn or
   shimmer of busy texture (trash, gravel, leaves), smoke under about 20 pt tall, four frames of
   a coin tipping. Judge it on the card GIF, not on `display_size.py`'s numbers: Kling smearing trash
   changed 600 pt^2 and read as nothing, three gulls changing 50 pt^2 read at once. Calibrate
   the sizes above per project. If the clip plays one complete action well (a load lowered, a
   full rock), use all of it; reach for the calm opening only when the rest goes wrong.
4. **It stays physically plausible.** Pivots stay put, contact points stay on the ground, nothing
   passes through another object, shapes keep their size.
5. **It returns cleanly.** For a loop, the audit's `loop_wrap` is no bigger than a normal step;
   for out-and-back, the rest pose is the art.
6. **Edges are clean on both backgrounds.** No white halo on dark, no coloured fringe, no holes
   between objects, no notches where the cut meets unmoving art, no ghost of the art's old pose,
   no straight cut where the part crossed the edge of a mask box. Zoom into where moving and still
   parts meet, and check every frame (not every 2nd) around the frames where it peaks.
   Also check the scene around it is the art: base, ground and neighbours unchanged
   (`audit.py --protect`).
7. **The file is within budget.** Shorter loops and smaller motion areas give smaller files.

## Choosing between clips

Crop contact sheets to the moving part and what holds it (the cage and its cable, the coin and
the stack it stands on), with frame numbers, so small parts are readable.

Prefer, in order: the clip whose motion matches the request's words; then the smaller motion; then
the cleaner edges; then the smaller file. When two pass and differ only in taste, show both
previews side by side and let the user pick.

## When to stop

After three clips for one art fail check 1 or 2, stop and report with contact sheets; propose a
procedural build or a different motion. Kling rarely fixes itself with a fourth retry of the same
idea.
