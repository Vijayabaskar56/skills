#!/usr/bin/env bash
# Usage: backup-layers.sh <asset-dir> [extra-file ...]
# Copies every PNG in the asset dir, plus the extractor, component or any other file named, into
# a fresh temp directory and prints its path. Run it before installing a new round, so "go back to
# the state before this" is a copy, not a reconstruction. An asset dir with no PNG yet backs up
# only the extra files.
set -euo pipefail

assets="$1"
shift
dir="$(mktemp -d "${TMPDIR:-/tmp}/png-sequence-animation-backup.XXXX")"
mkdir -p "$dir/assets"
shopt -s nullglob
layers=("$assets"/*.png)
[ ${#layers[@]} -eq 0 ] || cp "${layers[@]}" "$dir/assets/"
for file in "$@"; do
  [ ! -e "$dir/$(basename "$file")" ] || { echo "two files named $(basename "$file"); back them up separately" >&2; exit 1; }
  cp "$file" "$dir/"
done
echo "$dir"
