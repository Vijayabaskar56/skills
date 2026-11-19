#!/usr/bin/env bash
# Usage: doctor.sh [object]
# Checks what png-sequence-animation needs. A config with an "objects" map holds one entry per
# layered object; name one to check only it, or omit it to check them all. Prints "ok <item> <detail>", "missing <item> <fix>",
# "optional <item> <note>" or "session <item> <what to confirm>". Exits 1 when anything is missing.
# Install steps: references/setup.md.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
config="$root/.png-sequence-animation.json"
missing=0

if command -v jq >/dev/null; then echo "ok jq $(jq --version)"
else echo "missing jq brew install jq"; missing=1; fi

field() { [ -f "$config" ] && command -v jq >/dev/null && jq -r "$1 // empty" "$config" || true; }

if [ -f "$config" ]; then echo "ok config $config"
else echo "missing config run the first-run setup (references/first-run.md)"; missing=1; fi

python="$(field .python)"
python="${python:-python3}"
if "$python" -c "import numpy, scipy, cv2" 2>/dev/null; then
  echo "ok python $python ($("$python" -c 'import cv2; print("opencv", cv2.__version__)'))"
else
  echo "missing python $python cannot import numpy, scipy and cv2; make a venv (references/setup.md) and set .python"
  missing=1
fi

if command -v ffmpeg >/dev/null; then echo "ok ffmpeg $(ffmpeg -version | head -1 | cut -d' ' -f3)"
else echo "missing ffmpeg brew install ffmpeg"; missing=1; fi

objects="$(field '.objects // {} | keys[]')"
if [ -n "${1:-}" ]; then
  if ! grep -qx "$1" <<<"$objects"; then
    echo "missing object $1 not in .objects; add it (references/first-run.md)"; missing=1; objects=""
  else objects="$1"; fi
fi
for object in ${objects:-.}; do
  for key in source extract assetDir rig notes; do
    if [ "$object" = . ]; then label="$key"; value="$(field ".$key")"
    else label="$object.$key"; value="$(field ".objects[\"$object\"].$key")"; fi
    if [ -z "$value" ]; then echo "optional $label not set yet; the first run fills it"; continue; fi
    case "$value" in /*) path="$value" ;; *) path="$root/$value" ;; esac
    if [ -e "$path" ]; then echo "ok $label $value"
    else echo "missing $label $value not found; fix it in .png-sequence-animation.json"; missing=1; fi
  done
done

echo "session argent confirm the argent MCP tools (list-devices, screenshot, screen-recording-start) answer"
echo "session device confirm no other agent is driving the simulator you pick"
exit "$missing"
