#!/usr/bin/env bash
# Usage: clean-media.sh [repoRoot]
# Deletes everything inside the config's recordingsDir (default .argent/recordings) and keeps the
# directory itself. Never touches the flows directory. repoRoot defaults to the git top level.
# Safe to rerun.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="${1:-$(git rev-parse --show-toplevel)}"
cd "$root"
rec="$("$here/config.sh" '.recordingsDir' .argent/recordings)"
flows="$("$here/config.sh" '.flowsDir' .argent/flows)"
case "$rec" in
  "" | . | ./ | /* | *..*) echo "recordingsDir '$rec' must be a relative path inside the repo" >&2; exit 1 ;;
esac
[ "$rec" != "$flows" ] || { echo "recordingsDir equals flowsDir; refusing to clean" >&2; exit 1; }

if [ -L "$rec" ]; then
  echo "$rec in $root is a symlink; refusing to clean it" >&2
  exit 1
fi
if [ ! -d "$rec" ]; then
  echo "no $rec in $root; nothing to clean"
  exit 0
fi

count="$(find "$rec" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
size="$(du -sh "$rec" | cut -f1 | tr -d ' ')"
find "$rec" -mindepth 1 -delete
left="$(find "$rec" -mindepth 1 | wc -l | tr -d ' ')"

[ "$left" -eq 0 ] || { echo "$left entries left in $root/$rec" >&2; exit 1; }
echo "removed $count entries ($size) from $root/$rec"
