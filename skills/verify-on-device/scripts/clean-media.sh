#!/usr/bin/env bash
# Usage: clean-media.sh <video> [video...]
# Deletes the given recordings: the `video` paths this run's screen-recording-stop returned.
# Every path must be a regular file (not a symlink) directly inside the config's recordingsDir
# (default .argent/recordings, relative to the git top level, or absolute). If any path fails that
# check, nothing is deleted and the script exits 1. A path that is already gone counts as removed,
# so it is safe to rerun.
set -euo pipefail

[ "$#" -gt 0 ] || { echo "Usage: clean-media.sh <video> [video...]" >&2; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"
root="$(git rev-parse --show-toplevel)"
rec="$("$here/config.sh" '.recordingsDir' .argent/recordings)"
flows="$("$here/config.sh" '.flowsDir' .argent/flows)"
case "$rec" in /*) ;; *) rec="$root/$rec" ;; esac
case "$flows" in /*) ;; *) flows="$root/$flows" ;; esac

if [ ! -d "$rec" ]; then
  echo "no recordings directory at $rec; nothing to clean"
  exit 0
fi
rec="$(cd "$rec" && pwd -P)"
flows="$(cd "$flows" 2>/dev/null && pwd -P || printf '%s' "$flows")"
case "$rec" in / | "$HOME" | "$(cd "$root" && pwd -P)" | "$flows")
  echo "recordingsDir resolves to $rec; refusing to delete from it" >&2; exit 1 ;;
esac

delete=()
gone=0
refused=0
for path in "$@"; do
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then gone=$((gone + 1)); continue; fi
  if [ -L "$path" ] || [ ! -f "$path" ]; then
    echo "refused $path: not a regular file" >&2; refused=1; continue
  fi
  parent="$(cd "$(dirname "$path")" && pwd -P)"
  if [ "$parent" != "$rec" ]; then
    echo "refused $path: not directly inside $rec" >&2; refused=1; continue
  fi
  delete+=("$parent/$(basename "$path")")
done
[ "$refused" -eq 0 ] || { echo "deleted nothing" >&2; exit 1; }

for file in ${delete[@]+"${delete[@]}"}; do rm -- "$file"; done
echo "removed ${#delete[@]} recordings from $rec ($gone already gone)"
