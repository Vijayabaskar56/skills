# Light, shadow and reflection

A photo bakes every effect into one image. When parts move, each effect must move with whatever
causes it. Decide the owner first:

| Effect in the photo | Owner | Layer |
| --- | --- | --- |
| Overall light across a surface | the surface | the surface, repainted as smooth light |
| Shadow a part casts on a surface | the part | a shadow layer that rides the part, clipped to the surface |
| A neighbour's colour reflected in a part | the neighbour | removed from the part; optionally a reflection layer clipped to the part |
| Highlight sweeping over metal as it turns | the part's angle | a glint band inside the part, driven by its angle or speed |
| Contact shade where a part touches | the joint | stays on the part, small and tight |

## Repaint the receiving surface

1. Take "clear" pixels: on the surface, far from every part (more than the shadow's reach), away
   from the logo and the rim.
2. Fit the light as a plane (`[1, x/w, y/h]`) by least squares. A higher degree overshoots into
   corners.
3. Paint the face with the plane plus grain: Gaussian noise blurred a little, scaled to the
   photo's own fine-detail standard deviation, so the face is not plastic.
4. Keep the logo and the rim from the photo, except the rim next to the parts, which gets the
   plane times the rim's median shade.

layer-lint `stationary-shadow` fails when more of the face beside the parts than its
`--dark-share` limit is darker than the plane by `--darken`.

## Build each shadow

1. **From the photo, where it shows one.** Repaint the clean surface under it (above), then solve
   one tint and a per-pixel strength so `clean * (1 - a) + tint * a` gives the photo (alternate:
   strength per pixel given the tint, then tint given the strengths, about 20 passes). A coloured
   surface's shadow is a dark version of that colour, not black. Clip by the surface alpha.
2. **Where the photo shows none.** The photo only has shadow where the part lay over the surface.
   Blur the part's own alpha, shift it away from the light, scale it, and keep it only beyond the
   surface's rest outline grown by a small clearance (one minus the blurred, dilated outline). On
   the surface it would cover the photo's own shadow with a dark band hugging the part, hide the
   lit strip along its edge and make the part look thin. The keychain used blur 16, shift
   (-70, 110), strength 0.8, clearance 15 and feather 20 on a 1088 px canvas. Fit blur, shift and
   strength by least squares against the photo's shadow on the open surface beside the part; a
   guess (blur 16, shift (-30, 40)) gave a narrow streak that showed as "a thin thing" once the
   part swung over the logo. Write the shift as the shadow layer's `offset` in the rig, so
   layer-lint looks for the shadow where it lands.
3. **Split the photo's shadow between the parts.** The solved map holds every part's shadow at
   once. Give each pixel to the part whose shifted outline is nearest (distance transforms of each
   shifted alpha, the boundary blurred by 2 px), except that pixels within about 12 px of exactly
   one part (contact shade, the gaps between a key's teeth) go to that part. Without that rule the
   gaps of one part ride the other and float on the surface as hard specks. Each part's layer is
   the max of its share and its outline shadow from item 2.
4. Save one shadow layer per part, at the canvas size, so it rotates about the part's pivot. Check
   it in swing-sim at both extremes: the shadow beside each part must move with that part only.

A shadow fitted to all the darkening near the parts comes out wide, far and dark, and reads as a
stain. Tight, a little offset, soft.

## Remove a neighbour's colour from a part

In LAB, clamp a and b to at most 0 for chrome or other neutral material, then convert back. This
keeps its light and dark, drops the warm cast. layer-lint `cast` checks the result.

If the user wants the reflection as an effect, add it as its own layer: the neighbour's colour,
clipped to the part's alpha and to where the part overlaps the neighbour, faded by the part's
angle.

## Glint

A band (a linear gradient, light in the middle, transparent at the edges) three times the part's
width, clipped to the part, moved across it by the part's relative angle and faded in by its
angular speed. It reads as metal turning in the light without baking any light into the part.
