#!/usr/bin/env bash
# Usage: compare-layers.sh <new-dir> <installed-dir> [expected-changed.png ...]
# Compares every PNG byte for byte and prints "unchanged", "changed", "new" or "only-installed"
# per file. With an expected list, exits 1 if any other installed file changed, so a fix scoped to
# one layer cannot quietly alter the rest; a new file outside the list (a heatmap or a sheet left in
# the new dir) prints "extra" and is not installed. Without a list, it only reports.
set -euo pipefail
shopt -s nullglob

new="$1" installed="$2"
shift 2
expected=" $* "
scoped=$#
unexpected=0

for path in "$new"/*.png; do
  name="$(basename "$path")"
  if [ ! -e "$installed/$name" ]; then state=new
  elif cmp -s "$path" "$installed/$name"; then state=unchanged
  else state=changed; fi
  listed=1
  [ "$scoped" -gt 0 ] && [[ "$expected" != *" $name "* ]] && listed=0
  if [ "$state" = new ] && [ "$listed" -eq 0 ]; then state=extra; fi
  echo "$state $name"
  if [ "$state" = changed ] && [ "$listed" -eq 0 ]; then unexpected=1; fi
done
for path in "$installed"/*.png; do
  name="$(basename "$path")"
  [ -e "$new/$name" ] || echo "only-installed $name"
done

if [ "$unexpected" -eq 1 ]; then
  echo "fail a layer outside the expected list changed"
  exit 1
fi
