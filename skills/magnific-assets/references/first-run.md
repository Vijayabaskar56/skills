# First run in a repo

Write `.magnific-assets.json` at the repo root, starting from `assets/magnific-assets.example.json`.
Detect what you can from the repo; ask only for the rest, in one round.

| Field | What it is | How to fill it |
| --- | --- | --- |
| `project.name`, `project.reference` | The Magnific project generations go to | Step 1 of the skill asks on every run and saves the answer here |
| `assetDir` | Repo folder the finished AVIF and still go to | Find where the art the user names lives (`git ls-files '*.png' '*.avif' '*.webp'`); confirm |
| `workDir` | Scratch folder for start images, clips and frames | Default `/tmp/magnific-assets`; outside the repo |
| `displaySize` | The box, in points, the app draws the asset in, as `"WxH"` (for example `"211x200"`) | Read the component that renders the art; ask if it varies, and use the smallest place it appears |
| `sizeBudgetKB` | Largest AVIF the project accepts | Ask; 300 if the project has no rule |
| `fps` | Loop frame rate | 12 unless the project already ships another rate |
| `stillSuffix` | Name of the still next to the AVIF | Default `-still.webp` |
| `stillIsArt` | true when the app shows the original art (not the AVIF's frame 0) before the loop loads | Read how the app renders the art; passes `--still-is-art` to audit |
| `notes` | Repo file with prose facts: how art is wired in code, platform limits, past decisions | Create `docs/magnific-assets.md` if none exists |

## The notes file

Write what the next run needs and the repo does not say elsewhere, for example:

- the map or component that names each art and its still, and the test that covers it
- which platforms animate AVIF (an image library may animate it only on newer OS versions)
- the bundler setting that lets the app import `.avif`
- per-art decisions: "the road art plays once and holds", "the sign loop uses clip frames 0..12"
