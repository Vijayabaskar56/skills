# Setup

`scripts/doctor.sh` checks these. Ask the user once before installing anything.

| Need | Why | Fix |
| --- | --- | --- |
| `python3` 3.9 or later | runs `scripts/build.py` and `scripts/extract.py` | macOS: `xcode-select --install` (ships 3.9) or `brew install python`. Debian or Ubuntu: `sudo apt install python3` |
| Artifact tool (session) | publishes the page in step 6 | Available in Claude Code with Artifacts enabled. Without it, the built `index.html` is the deliverable; say in the report that publishing was skipped and why |

The fonts load from Google Fonts when the page opens; building needs no network.
