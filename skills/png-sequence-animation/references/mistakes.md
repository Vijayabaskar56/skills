# Mistakes behind the rules

Each entry is something a run did, what the user saw, the cause and the rule that came out of
it. They come from building one swinging keychain (a tag, two keys and a split ring) from one
product photo, in an Expo app with Reanimated. The rule is general; the numbers are that
object's, as an example of scale.

## Choose the approach

| Tried | Result | Rule |
| --- | --- | --- |
| A native 3D pin library | Looked like a toy, not the photo | A renderer gives you its look, not the photo's |
| three.js on WebGPU | Closer, but on a mid-range Android release build the dashboard open went from 188 to 839 ms worst frame overrun, and memory grew 54 to 78 MiB | Measure a release build on a real phone before choosing a renderer |
| A clean CG redraw of the keys | "key edges are not what it look in the png at all", regular teeth, flat metal | Realism is in the photo's pixels: reflections, bitting, wear. Code-side glint cannot add it |
| Flat PNG layers on transforms | Kept: the photo's detail at almost no cost | Start here; add a renderer only for motion layers cannot fake, such as a twist that shows the back |

## Source

- **Image generation for separate parts.** Asked to "generate two separate keys that look
  exactly like this". The generator's own check failed: head position, teeth, texture,
  reflections, the tag outline and the ring curve all changed, and the layers did not register to
  the photo. Rule: never build on generated or redrawn layers.
- **Low-resolution export.** A 2x node export came out 352x468, because export scale applies to
  the node's box on the canvas (176x234), not to the photo inside it. The raw image fill was
  1088x1445 with alpha. Rule: download the raw fill (`references/source-assets.md`).

## Extraction

- **Fill read the wrong surface.** The first repaint of the tag under the keys bled dark from the
  ring and the background. Rule: seed a fill only from pixels of the surface being repainted.
- **Noisy silhouette.** "the badge itself look choppy": key bevels counted as tag colour and
  stretched the outline about 15 px, then it snapped back as a notch. Rule: replace a
  thresholded edge with a fitted shape (lines and corner radii), drawn supersampled.
- **Sliver of a neighbour.** "the big key look choppy": a thin strip of the front key's blade
  edge was attached to the back key, and the back key's neck ended in a straight cut. Rule: where
  two layers meet, measure the boundary from the gap between them, and rebuild a hidden part
  from the part's own visible pixels (its blade shifted up, the other key's head offset).
- **Hairline outline left on a key.** A 1 to 2 px line of the tag edge stayed in the front key
  layer. Rule: keep only components attached to the part's main body; layer-lint `fragments`.
- **Hole filled with metal.** Inpainting under the ring also filled the key's own hole. Rule:
  exclude real holes from the region before inpainting.
- **Singular solve.** Pockets under the keys had no clean surface beside them, so the Laplace
  system had no data. Rule: add a tiny anchor to the mean colour, solve only regions that touch
  clean pixels, and inpaint the rest.
- **Logo taken as metal or chrome taken as logo.** Colour alone mixed up white logo and bright
  chrome. Rule: pick a region by colour and connectivity: the largest blob inside the outline
  that is not connected to the metal.

## Light, shadow and reflection

- **Orange on the keys.** "orange lighting bouncing off the badge, not realistic when I move the
  keychain": the tag's reflection was baked into the chrome and slid with the key. Rule: a moving
  part carries no colour of its neighbour; neutralise it (layer-lint `cast`).
- **Then the user wanted the bounce back.** "before it shows orange like an effect that bounces
  from the badge, now that is missing". Rule: a reflection of a neighbour is its own layer,
  clipped to the part and shown only where the part is over the neighbour. Ask which look the
  user wants before removing an effect they may like.
- **Shadow left on the tag.** "just remove this shadow mark that is in the badge": the repaint
  under the keys followed the photo's shading, and the photo's shadow reached past the repainted
  band, so a dark smear stayed on the tag when the keys swung away. A narrow repaint did not fix
  it. Rule: repaint the whole receiving face from fitted light, a plane on clear pixels, with
  grain matched to the photo; keep the rim and the logo from the photo (layer-lint
  `stationary-shadow`). A higher-degree fit darkened a corner.
- **A bruise instead of a shadow.** "what have u done here?": a cast shadow fitted to all the
  photo's darkening around the keys came out offset 80,116 px, wide and 63% dark. Rule: a cast
  shadow is tight to its part, offset a little away from the light, and soft.
- **Half a shadow.** "currently shadow only have half": the photo only shows shadow where the
  keys lay over the tag; the lower blades hung past its edge, so the shadow stopped halfway.
  Rule: build the rest from the part's own blurred, offset outline, blended in with a feathered
  band beyond the receiver's rest outline (layer-lint `shadow-length`).
- **One key carried both shadows.** "the second key shadow look like a actual first key shadow"
  and "this shadow looks small, not matching the height of the key". The whole solved photo
  shadow rode the front key, and the back key only had its outline past the tag. Rule: split the
  photo shadow by the nearest shifted part.
- **Outline shadow over the photo's shadow.** Fixing that by laying each key's full outline
  shadow over the tag too: "why does it look thinner?". It hid the photo's lit strip and set a
  dark band against the blade. Rule: the synthetic shadow only goes where the photo has none, and
  a critic compares the rest frame with the photo before the fix ships.
- **Guessed outline shadow.** "what exactly is this thin thing here": the outline shadow (blur
  16, close to the key) crossed the white logo as a narrow streak, unlike the photo's broad
  shadow. Rule: fit the outline shadow to the photo's shadow by least squares.
- **Teeth gaps on the wrong key.** Dark gaps between one key's teeth were assigned to the other
  key's shadow and floated on the tag as specks when the keys parted. Rule: contact shade goes
  to the part it touches.
- **Shadow drawn past the edge.** A dark band showed outside the tag. Rule: clip every shadow to
  its receiver's alpha, in the extractor for the photo part and in the app for the moving part.
- **Shadow colour.** The shadow on an orange tag is deep red, not black: compositing black left
  error. Rule: solve one tint and a per-pixel strength so `clean * (1 - a) + tint * a` gives the
  photo.

## React Native

- **Mask drew nothing on iOS.** Shadows and glint vanished. Swapping image components did not
  help. Cause: the masked view misplaces a mask sized with absoluteFill on iOS. Rule: give the
  mask element an explicit pixel box; debug a mask by tinting its children solid.
- **Two keys in one PNG.** "two separate keys that dangle independently, and one shadow cast on
  the other": they swung as one. Rule: one layer, one pivot, one pendulum per object.
- **Touch moved the wrong key.** Hit tests still used the merged shape, and the start point came
  from the activated gesture, about 10 pt along the drag. Rule: re-derive hit areas when a layer
  splits, and hit-test at touch-down.

- **Two versions of one footer.** The dashboard had a tilt version and a separate touch version.
  "can we do it both": one rig with a `both` mode feeds tilt and gestures into the same
  pendulums. Rule: inputs are modes of one rig, never separate components.
- **Sleeping motion rig.** Letting a tilt rig sleep until the tilt passed a threshold would
  ignore small tilts. Rule: only a touch-only rig sleeps.
- **Width read inside a shared component.** The footer read the window width itself; the repo's
  lint rejected it. Rule: the stage width is a prop from the screen.

## Second object: a bell with a clapper

- **The design render was not the shipped asset.** The design folder held a glossy bell render;
  the screen drew a brushed webp with alpha. Rule: extract from the file the screen draws, and
  check the user's screenshot against it before planning a rig.
- **Ghost under the clapper.** The ball hung past the lip, and a row fill across it ramped from
  lip to background. Rule: fill along the texture and close the silhouette on a fitted edge
  (`extraction.md`).
- **A stem the source never showed.** A drawn stem poked above the ball at rest and changed the
  design. Rule: the rest frame must recompose to the source; invent nothing that shows at rest.
- **Clip at rest.** `rig.py` clipped a moving layer with its clip layer as drawn at rest, so a
  window riding the bell stayed put offline. The pose now clips with the posed layer.
- **Scratch files blocked install.** `compare-layers.sh` failed on the heatmap and sheet left in
  the output directory, and `backup-layers.sh` failed on an asset folder with no PNG yet. Both
  now handle it.

## Process

- **Judged a stale screenshot.** "the shadows look choppy" came from a screenshot taken five
  minutes before the fix was installed. Rule: compare a complaint's time with the install.
- **Wrong screen.** Another session drove the same simulator and the app jumped to other screens;
  a crash came from another thread's component. Rule: one simulator per agent, reopen the deep
  link, and leave other agents' code alone.
- **Five devices running.** "keep it max of 2, one for iOS and another for Android". Rule: stop
  what you start; at most one of each.
- **Wrong Metro.** Error and reload commands hit port 8081 while this app ran on 8083. Rule: read
  the port from the dev client's URL, not from a default.
- **Downscaled evidence.** The image an action returns is scaled down; detail claims need a full
  resolution screenshot. A swing settles in about a second, so single screenshots miss it; record
  and tile.
- **Revert without a backup.** "can we go back to the state before this?" had to be rebuilt from
  the extractor. Rule: back up before each round, and regenerate plus `cmp` to prove the rest is
  byte-identical when told to change one thing.
- **Tuned by eye.** Several rounds changed values by look. Rule: a metric decides (recompose
  error, layer-lint, pixel counts), and the eye confirms.
