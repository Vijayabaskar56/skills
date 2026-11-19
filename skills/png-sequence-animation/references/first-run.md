# First run in a repo

Run when `.png-sequence-animation.json` is missing. Find facts yourself; ask only for choices.

## 1. Detect

| Field | Source |
| --- | --- |
| object | a short name for the thing that moves (`keychain`, `bell`); an existing config gains one more `objects` entry |
| python | a venv that imports numpy, scipy and cv2 (`setup.md` makes one) |
| source | the file the user named, or the raw fill from `source-assets.md` |
| extract | an existing extractor script for this object (`tools/**/extract*.py`), else the path you will create |
| assetDir | where the object's PNGs live, or the repo's image folder plus the object's name |
| rig | beside the extractor: `rig.json` |
| component | the component that draws the layers, if one exists |
| deepLink | the repo's deep link catalog or `scheme` in app.json / app.config.* plus the screen's route |
| validate | package.json: `validate`, else `check`, else `lint` plus `typecheck` |
| notes | `docs/<object>-layers.md` |

Read the repo's AGENTS.md or CLAUDE.md for asset, comment and verification rules first.

## 2. Ask once

Only if detection did not settle it, in one question round, recommended answer first:

1. Which object or screen, if the repo has several layered objects.
2. Whether the source may stay outside the repo (recommended for large working files).

## 3. Write

Fill `assets/png-sequence-animation.example.json` and save it as `.png-sequence-animation.json` at
the repo root. `python` and `validate` are shared; every other field sits in the object's entry
under `objects`. When the config exists, add the new object's entry and leave the others alone.
Write the rig from `assets/rig.example.json`. Create the notes file with what you learned:
pivots and where they come from, which layer is in front, constants that took calibration, and
known open issues. Tell the user the files exist; commit only when asked.
