#!/usr/bin/env bash
# Usage: resolve-ref.sh <name>
# Finds the reference repo for <name> among the git repos directly inside the references dir
# ($BTCA_REFERENCES_DIR, default ~/work/references). Matches case-insensitively: exact name first,
# then names containing <name>, then names contained in <name> (so "plate.js" finds "plate").
# Exit 0: prints the one absolute path. Exit 2: several candidates, one path per line.
# Exit 1: no match; the available repos go to stderr. Exit 64: usage error.
set -euo pipefail

query="${1:-}"
[ -n "$query" ] || { echo "usage: resolve-ref.sh <name>" >&2; exit 64; }
refs="${BTCA_REFERENCES_DIR:-$HOME/work/references}"
[ -d "$refs" ] || { echo "references dir $refs does not exist; run doctor.sh" >&2; exit 1; }
refs="$(cd "$refs" && pwd)"
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
q="$(lower "$query")"

repos=()
for d in "$refs"/*/; do
  [ -e "${d}.git" ] || continue
  d="${d%/}"
  repos+=("${d##*/}")
done

exact=() contains=() contained=()
for name in ${repos[@]+"${repos[@]}"}; do
  n="$(lower "$name")"
  if [ "$n" = "$q" ]; then exact+=("$name")
  elif [[ "$n" == *"$q"* ]]; then contains+=("$name")
  elif [[ "$q" == *"$n"* ]]; then contained+=("$name")
  fi
done

report() {
  [ "$#" -gt 0 ] || return 0
  for name in "$@"; do echo "$refs/$name"; done
  [ "$#" -eq 1 ] && exit 0
  exit 2
}
report ${exact[@]+"${exact[@]}"}
report ${contains[@]+"${contains[@]}"}
report ${contained[@]+"${contained[@]}"}

echo "no reference repo matches '$query' in $refs" >&2
if [ "${#repos[@]}" -gt 0 ]; then echo "available: ${repos[*]}" >&2; else echo "available: none" >&2; fi
exit 1
