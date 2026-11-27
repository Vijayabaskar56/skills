# Image: generate or restyle a still

Use for new art in an existing set's style, a start image variant, or a background.

## Model

Free in Relax mode (checked 2026-11-26 in the image picker, which marks the free ones):
Google Nano Banana 2.1 and Qwen Image 3.0 Pro. Recheck the picker each run; the free list changes.
Generate must read "Relax mode" with no credit number before you click it.

## Inputs

- Add one or two finished arts from the same set as references, so the new image keeps the
  stroke, palette and lighting. Name the style in the prompt as well: "flat vector illustration,
  soft shading, same palette as the reference".
- Ask for a flat solid background (white, or green 0,177,64 when you will cut it out) and the
  subject centred with margin around it.
- Ask for the size the set uses, or the nearest square, and scale it down locally.
- Compose for the config's `displaySize`, not the file size. Detail under about 2 pt there
  vanishes, so ask for a few large, clear shapes, and make anything that will move later (a
  vehicle, a bird, a light) big enough to read: about 8 pt or more across on the display.

## After generating

1. Download every candidate into the work folder.
2. Put them next to an existing art of the set at card size, on light and dark, and pick the one
   that sits in the set: same stroke weight, perspective and level of detail.
3. Cut the background locally (key on the solid colour), trim to the set's canvas, and check the
   edges on dark.
4. If it will be animated next, it becomes the art for `video.md`.

Judge with `judging.md` checks 1, 6 and 7 (subject, edges, size); there is no motion.
