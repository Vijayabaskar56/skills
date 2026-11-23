# PR evidence

How to prove a change in a PR description. `file-pr`, `full-send`, `full-stop` and `babysit-pr`
all use these rules.

## Pick the evidence

| The change | Evidence |
| --- | --- |
| Nothing a user can see (logic, types, server, build) | A test that fails before the fix and passes after, with the command and both results. No media |
| A visible change that a still image shows (layout, styling, copy, a wrong state that stays wrong) | Before and after screenshots |
| A still image cannot show it (animation, flicker or jank, timing or race, scrolling, gestures, a flow where the bug shows between steps) | Before and after screenshots, plus a short linked clip for each side |

Most fixes need screenshots only. Keep clips short: the few seconds that show the bug.

## Capture it

- Capture both sides the same way: same viewport or device, same theme, same data, same steps.
- Before is the base commit; after is the PR head. Note both SHAs.
- Crop to what changed when the full screen would hide it.

## Check it before upload

Look at every image and clip before you upload it. Uploads are public links. Leave out tokens,
keys, email addresses, customer data, private repo names and anything else the user would not post
publicly. Crop or recapture to remove it.

## Upload it

```sh
fleet upload-file --before before.png --after after.png   # prints a Before | After table
fleet upload-file clip-before.mp4 clip-after.mp4          # prints one markdown line per file
```

`fleet upload-file` shrinks videos with ffmpeg (H.264, 720p, ready to stream) and compresses PNGs,
then uploads them to the file-drop Worker. It prints images as `![name](url)` and videos as
`[name](url)`.

- GitHub shows outside images inline only under 5 MB. If an image is larger, crop or scale it.
- GitHub never embeds an outside video, so clips are links. Put each one under its screenshot.
- If `fleet upload-file` is missing or fails, say so in the PR and describe what you saw. Never
  commit media to the repo to get around it.

## Write it up

Put an `## Evidence` section in the description, shaped like this:

```markdown
## Evidence

Reproduced in Chromium, 1280x800, light theme, with <setup>. <Steps in one or two sentences>.

| Before | After |
| --- | --- |
| [<base sha>](<commit url>) | [<head sha>](<commit url>) |
| ![Before: <what is wrong>](<url>) | ![After: <what is fixed>](<url>) |
| [Before recording](<url>) | [After recording](<url>) |

**Not shown:**
- <platforms, paths or settings you did not exercise>
```

Drop the recording row when there is no clip. Always keep **Not shown**, even when it has one line:
it tells the reviewer where the proof stops.
