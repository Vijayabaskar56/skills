#!/usr/bin/env bash
# Usage: verify-finding.sh [--repo DIR] [--reach PATTERN] <base> <head> <path> <from> <to>
# Checks one finding against the range. Prints the cited lines as shipped at <head>, whether
# `git diff <base> <head>` touched lines <from>-<to> of <path>, and a reach count from `git grep -c`
# at <head>: matches of PATTERN, or by default the files importing <path>'s module (by basename,
# so approximate). Exits 0 when the range touched the span, 1 when it did not or the file or span
# is not at <head> (drop the finding), 2 on a usage error. A deletion counts when it sits inside
# the span or right above it.
set -euo pipefail

repo=.
reach=""
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:?--repo needs a value}"; shift 2 ;;
    --reach) reach="${2:?--reach needs a value}"; shift 2 ;;
    -h | --help) sed -n '2,8p' "$0"; exit 0 ;;
    *) args+=("$1"); shift ;;
  esac
done
[ "${#args[@]}" -eq 5 ] || { sed -n '2,8p' "$0" >&2; exit 2; }
base="${args[0]}" head="${args[1]}" path="${args[2]}" from="${args[3]}" to="${args[4]}"
case "$from$to" in *[!0-9]*) echo "error <from> and <to> must be line numbers" >&2; exit 2 ;; esac
[ "$from" -ge 1 ] && [ "$from" -le "$to" ] || { echo "error need 1 <= from <= to" >&2; exit 2; }
cd "$repo"
git rev-parse --verify --quiet "$base^{commit}" >/dev/null || { echo "error unknown ref '$base'" >&2; exit 2; }
git rev-parse --verify --quiet "$head^{commit}" >/dev/null || { echo "error unknown ref '$head'" >&2; exit 2; }

if ! shipped="$(git show "$head:$path" 2>/dev/null)"; then
  echo "missing  $path is not in $head; drop the finding"
  exit 1
fi
total="$(printf '%s\n' "$shipped" | wc -l | tr -d ' ')"
if [ "$from" -gt "$total" ]; then
  echo "missing  $path has $total lines at $head, so $from-$to does not exist; drop the finding"
  exit 1
fi
echo "shipped  $path:$from-$to at $(git rev-parse --short "$head")"
printf '%s\n' "$shipped" | awk -v from="$from" -v to="$to" 'NR >= from && NR <= to { printf "%6d  %s\n", NR, $0 }'

touched="$(git diff -U0 --no-renames "$base" "$head" -- "$path" | awk -v from="$from" -v to="$to" '
  /^@@ / {
    split($3, new, ",")
    start = substr(new[1], 2) + 0
    count = (2 in new) ? new[2] + 0 : 1
    if (count == 0) hit = (start >= from - 1 && start <= to)
    else hit = (start <= to && start + count - 1 >= from)
    span = (count == 0) ? "deletion after " start : start "-" (start + count - 1)
    if (++n <= 8) all = all " " span
    if (hit) hits = hits " " span
  }
  END {
    if (hits != "") print "yes" hits
    else if (all != "") print "no; the range changed only" all ((n > 8) ? " and " (n - 8) " more" : "")
    else print "no; the range did not change this file"
  }')"

if [ -n "$reach" ]; then
  counts="$(git grep -c -E -- "$reach" "$head" || true)"
  label="matches of '$reach'"
else
  mod="$(basename "$path")"
  mod="${mod%.*}"
  mod="${mod%.native}"; mod="${mod%.ios}"; mod="${mod%.android}"; mod="${mod%.web}"
  [ "$mod" != index ] || mod="$(basename "$(dirname "$path")")"
  counts="$(git grep -c -E "(from|import|require\()[[:space:]]*\(?['\"][^'\"]*/$mod(\.[a-z]+)?['\"]" "$head" -- \
    '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs' | grep -v "^$head:$path:" || true)"
  label="imports of '$mod' (approx., by basename)"
fi
files="$(printf '%s\n' "$counts" | grep -c . || true)"
sum="$(printf '%s\n' "$counts" | awk -F: 'NF { n += $NF } END { print n + 0 }')"
echo "reach    $sum $label in $files files at $head"

case "$touched" in
  yes*) echo "touched  $touched"; exit 0 ;;
  *) echo "touched  $touched; drop the finding or re-cite the changed lines"; exit 1 ;;
esac
