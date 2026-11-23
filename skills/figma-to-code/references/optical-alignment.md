# Optical alignment

Read this for either of two checks, on either axis:

- **Lone glyph in a container** (an icon button in a circle or square, a play button, a chevron in
  a pill, a badge glyph, a floating action button): is the ink centred? Sections "The procedure"
  to "Limits".
- **Icon beside text** (list rows, key/value rows, menu items, chips, labelled buttons): does the
  icon sit on the label's line, and does the label sit on the row's line? Section "Rows and lists".

| Script | Measures | Use for |
| --- | --- | --- |
| `scripts/glyph-weight.py <crop.png> --scale N [--bg edges]` | ink centre of one crop against its centre, x and y | any crop you cut yourself |
| `scripts/button-crop.py <capture.png> --scale N --out DIR NAME:X,Y,W,H:GLYPH ...` | crops each container from `describe` frames, then runs glyph-weight | every icon button on a screen in one call |
| `scripts/row-align.py <capture.png> --scale N [--side lead\|trail] NAME:LABEL[:SIBLING] ...` | icon against label, label baseline against a sibling text, icon column x | rows and lists |

All three take frames as `describe` prints them (fractions of the screen), print points, and use
+x right, +y down.

## Why the box centre looks wrong

Figma and code both centre an icon by its frame, so a 24-unit frame sits dead centre in a 48-unit
circle. The eye centres by visual weight instead: where the ink sits. Asymmetric glyphs carry
their weight off the frame centre. A pencil-on-square edit icon in a 24 frame weighs at about
(11.29, 12.66), so it reads left and low; a trash can with a lid weighs at about (11.97, 12.29),
so it reads low; a play triangle reads well left. Box-centred, they look misplaced even though
every authored value is exact. Symmetric glyphs (plus, close, a circle, a square) need nothing.

## The procedure

1. **Read the authored placement first.** Compare the glyph's vector bounds with its frame, and the
   frame with its container, in `get_metadata`. When the designer already offset the glyph (frame
   or vector off the container centre), that offset is the optical nudge: transcribe it literally
   and stop here.
2. **Build box-centred first.** Implement the authored frame, size and container exactly, then
   capture at scale 1 as in `visual-loop.md`.
3. **Measure the weight.** Take the container frames from `describe` and run, for a whole screen
   at once:

   ```bash
   python3 scripts/button-crop.py <capture.png> --scale 3 --out <dir> --bg edges \
     "share:0.851,0.076,0.109,0.050:20" "dislike:0.075,0.915,0.109,0.050:20"
   ```

   `--scale` is the capture's density: 3 for a 3x iPhone, the Android density for an emulator, 1
   for a 1x browser capture. GLYPH (the last field) is the icon size in points. Use `--bg edges`
   when the container sits on a gradient, blur or photo; it reads the background per row from the
   crop's edges. Each line prints the offset and a nudge rounded to 0.25. Open the crops in
   `<dir>`: a neighbour, label, badge, dot or dev overlay in a crop makes its numbers wrong. For a
   crop you cut yourself, `glyph-weight.py <crop.png> --scale N` does the measuring alone.
4. **Apply the nudge when it is 0.25 or more on either axis.** Move the glyph by a transform
   (`transform: [{ translateX }, { translateY }]` in React Native, `translate` on the web), never
   by margin or padding, so the container's layout and hit area do not move. Positive x moves it
   right, positive y down.
5. **Put the nudge on the icon, not the screen.** Store it with the icon component as a fraction
   of the icon's size, so every consumer and every size gets it: the edit icon's
   `+0.5, -0.5` at 24 becomes `+0.25, -0.25` at 12. Name it (`EDIT_OPTICAL_OFFSET`), per the
   hard rule on values in comments. A map from icon to fraction with one `opticalShift(icon,
   size)` helper works when icons come from several sets. Make it opt-in where the icon is
   rendered (an `optical` prop on the shared icon wrapper, set by the circular button), because
   the same glyph beside text must not move. Find every place the glyph renders in a lone
   container: a screen that draws the icon directly, not through the wrapper, needs the shift
   applied there too, and only a re-measure shows you missed one.
   - One glyph, one offset: when a control swaps glyphs (outline and filled, saved and unsaved),
     measure both; if only one is safe to capture, apply its value to both and say so.
   - Put the transform on a wrapper view when the glyph already animates `transform` (a pop or
     scale), so the two do not overwrite each other.
6. **Record and re-capture.** Write the measured offset and the applied nudge in the ledger as a
   deviation from the authored centre, re-capture, and let the critic judge it.

**Done when** each lone glyph in a symmetric container either carries an authored offset
transcribed literally, or has a measured weight, a nudge under 0.25 recorded as none, or an
applied nudge recorded in the ledger and judged by the critic.

## Limits

- The weight is a pixel centroid of the rendered glyph, so measure the shipping colour on the
  shipping background; a faint glyph on a near-matching fill weighs badly. Crop tightly to one
  glyph with no label or ring in the crop.
- Solid wedges such as a play triangle get the largest nudges. When the critic says the nudged
  glyph now reads past centre, halve the nudge and record both values.
- A glyph beside text, in a row of icons, or on a list leading edge aligns to its neighbours, not
  to its own weight. Optical centring is for a glyph alone in its container.
- Glyphs drawn off-centre in their own frame on purpose (a back chevron, a left arrow tucked to
  the leading edge) are authored that way; check Figma before nudging them.
- Hide dev overlays first (the Expo dev-menu "Tools button", a performance monitor): they sit on
  header buttons and poison the crop. Turn them back on when you finish.

## Rows and lists

An icon beside a label aligns to the label, not to its own weight. Two things can be off, and the
fix differs, so measure both before changing anything.

1. **Capture and frame.** Capture at scale 1 and take each row's label frame from `describe`.
   Where a row has a second text (a value on the right), take that frame too.
2. **Run the row check:**

   ```bash
   python3 scripts/row-align.py <capture.png> --scale 3 \
     "khata:0.152,0.330,0.5,0.032" "carpet:0.152,0.385,0.4,0.032:0.6,0.385,0.3,0.032"
   python3 scripts/row-align.py <capture.png> --scale 3 --side trail --reach 110 \
     "khata:0.152,0.330,0.5,0.032"
   ```

   Keep the label frame clear of the trailing icon, and raise `--reach` until it covers the gap
   to the icon you want (lead icons sit within 28pt by default).
3. **Read it.**
   - `icon-label` 0 to +0.33 is aligned: one device pixel either way. Beyond ±0.5 is visible.
   - `base-sib` not 0 means the label is off its own line: two texts on one row should share a
     baseline. Fix the label (usually a tight `lineHeight`, see `translation-traps.md`), not the
     icon. On the first rows this ran on, every label read `icon-label +1.00` and `base-sib
     -1.00`; dropping `leading-[15px]` made both 0.00 with no row height change.
   - The same value on every row means one shared cause (leading, a wrapper's alignment), so fix
     it once at the source. One odd row means that icon's artwork.
   - `icon-x` equal down a column means the icons line up; a row that differs has a different
     icon size or gap.
4. **Only then nudge the icon**, and only when the label checks out (`base-sib` 0) and the icon
   still reads off. Moving the icon to meet a high label would make the row and its sibling text
   disagree instead.
5. **Re-capture and re-run** after the fix, and record before and after numbers in the ledger.

**Done when** every row type on the screen reads `icon-label` within 0 to +0.33, `base-sib` 0,
and equal `icon-x` per column, or each exception is recorded with its cause.
