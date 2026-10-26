# Extracting layers

The extractor is one script in the repo (the config's `extract`) that reads the source and writes
every layer. It is the source of truth: a layer changes only when the script changes. Use numpy,
scipy and OpenCV.

## Canvas

Write every layer at the source's full size, RGBA, on the source's pixel grid. Then pivots,
offsets and masks are all in one coordinate space, the stack recomposes to the photo, and the app
places every layer with the same box. Transparent margins compress to almost nothing.

## Segment

1. Separate materials by colour in HSV: a saturated surface (the tag) against low-saturation
   metal. Close small gaps, fill holes under a few hundred px.
2. Take each region by connectivity as well as colour: metal that is connected to the outside of
   the surface, the largest non-metal light blob inside it for a logo.
3. Split touching objects with shapes measured on the photo: an ellipse for a key's head, a
   polygon for its blade, a line fitted to the gap between two blades. Measure, do not eyeball.
4. Keep only components attached to each part's body (dilate the body by a few px and keep what
   it touches), and open the mask once to drop hairlines.

## Outline a flat surface

A threshold edge is noisy where other objects touch it. Fit straight edges with `cv2.fitLine`
(Huber) on windows of the contour you trust, intersect neighbours for corners, take the corner
radius from a visible corner (`R = gap * sin(t/2) / (1 - sin(t/2))`, gap from the corner point
to the contour, t the corner angle), and draw the shape 4x size, then `INTER_AREA` down. Use this
outline as the surface's alpha where parts overlap it, and the photo's alpha elsewhere.

## Fill what the parts hide

When a part swings away it reveals what was under it.

- **A flat surface under the parts:** see `light-and-shadow.md`. Repaint from fitted light.
- **A part hidden by another part:** rebuild from the part's own pixels: the same blank shape
  offset, its own blade shifted along its length. Darken a rebuilt area that sits in shade.
- **A small area under a thin object (a ring over a head):** `cv2.inpaint` (TELEA), with real
  holes excluded from the region.
- **A smooth region with clean pixels around it:** a harmonic (Laplace) fill seeded only from
  those pixels. Add a small anchor to the mean seed colour (about 1e-4 on the diagonal) so
  regions with few seeds stay solvable, and inpaint pockets that touch no seed.

## Fill a hidden area that crosses an edge

When a part covers the surface's own silhouette (a ball hanging past a bell's lip), a fill seeded
from both sides ramps from metal to background and leaves a ghost. Fill along the surface's
texture (bend the rows so the stripes run level, interpolate across, bend back), then close the
silhouette on a curve fitted to the edge beside the part, where the source shows it.

## Check

- `recompose.py`: alpha error near 0; on a straight extraction, mean colour error of 1 to 2 /255.
  Its heatmap shows which layer disagrees. Probe failing pixels by printing source and stack
  values side by side; a colour that is darker but not black is a tinted shadow.
- `layer-lint.py`: `fragments` and `cast`.
- `swing-sim.py`: hidden areas appear at the extremes.
