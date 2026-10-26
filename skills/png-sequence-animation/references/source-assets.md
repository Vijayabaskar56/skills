# Getting the source

## Requirements

- The photo's own resolution. Layers are drawn scaled down on screen, so a source smaller than
  about 3x the largest on-screen size shows soft edges.
- An alpha channel around the object, if the object sits on nothing. With an opaque background,
  cut it out first and keep the cutout as the source.
- One source for every layer. Layers from different files never register.

## From Figma

The node export (`get_screenshot`, Export at 2x) renders the node's box, so a photo placed in a
small frame comes out small. Take the image fill itself:

1. Create a session for the file and call `download_assets` for the node into the config's
   allow-listed download folder. It returns `rawImages`: every image fill under the node at its
   original size.
2. Several may come back (an opaque original, a cutout, thumbnails). Pick the largest one with
   alpha: check with `python -c "import cv2, sys; print(cv2.imread(sys.argv[1], -1).shape)" <image>`; a cutout has 4
   channels and a large transparent share.
3. Record its path in `source`. Keep it outside the repo if it is a working file.

Keep every Figma call read-only.

## From a file the user sends

Check the size and channels the same way. If it is a screenshot of a design, ask for the
original: a screenshot has the canvas's resolution, not the photo's.

## What generation is allowed to do

Only fill areas the photo hides, such as a key's head behind a ring, and only after building
them from the object's own visible pixels has failed. Report each generated area. Never generate
a whole part.
