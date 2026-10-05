#!/usr/bin/env bash
# Usage: find-flows.sh <area> [flowsDir]
# Lists saved argent flows whose file name contains <area> (case-insensitive), one per line:
#   <name>  <kind>  runs: <flows it runs>  DEAD: <reason>
# then "flowsDir: <dir> (gitignored|tracked|not in git)". kind is the first glob in the config's flowKinds
# ({"<glob>": "<kind>"}, in order) that matches the name, else "flow"; without flowKinds the
# defaults below apply. DEAD marks a flow that is, or runs (at any depth), one of the config's
# deadFlows. flowsDir defaults to the config's flowsDir (.argent/flows) under the git top level.
# Exits 1 when nothing matches.
set -euo pipefail

area="${1:?Usage: find-flows.sh <area> [flowsDir]}"
here="$(cd "$(dirname "$0")" && pwd)"
root="$(git rev-parse --show-toplevel)"
dir="${2:-$root/$("$here/config.sh" '.flowsDir' .argent/flows)}"
[ -d "$dir" ] || { echo "no flows directory at $dir" >&2; exit 2; }

dead_flows=" $("$here/config.sh" '.deadFlows | join(" ")') "
kinds="$("$here/config.sh" '.flowKinds | to_entries[] | "\(.key)\t\(.value)"')"
[ -n "$kinds" ] || kinds="$(printf '%s\t%s\n' '*-fragment*' fragment '*-edge-cases*' edge-cases \
  '*-stress*' stress '*-profile*' profile 'perf-*' perf '*smoke*' smoke 'enter-*' enter)"

kind_of() {
  local glob kind
  while IFS=$'\t' read -r glob kind; do
    [[ "$1" == $glob ]] && { echo "$kind"; return 0; }
  done <<<"$kinds"
  echo flow
}

runs_of() {
  local file="$dir/$1.yaml"
  [ -f "$file" ] || file="$dir/$1.yml"
  [ -f "$file" ] || return 0
  sed -nE 's/^[[:space:]]*-[[:space:]]*run:[[:space:]]*([A-Za-z0-9_.-]+)[[:space:]]*$/\1/p' "$file" |
    sed -E 's/\.ya?ml$//' | sort -u
}

dead_reason() {
  local name="$1" seen="$2" child reason
  case "$dead_flows" in *" $name "*) echo "$name"; return 0 ;; esac
  case "$seen" in *" $name "*) return 0 ;; esac
  for child in $(runs_of "$name"); do
    reason="$(dead_reason "$child" "$seen $name ")"
    if [ -n "$reason" ]; then echo "$name > $reason"; return 0; fi
  done
}

found=0
for file in "$dir"/*.yaml "$dir"/*.yml; do
  [ -f "$file" ] || continue
  name="$(basename "$file")"
  name="${name%.*}"
  printf '%s' "$name" | grep -qiF -- "$area" || continue
  found=$((found + 1))
  kind="$(kind_of "$name")"
  line="$(printf '%-48s %-10s' "$name" "$kind")"
  runs="$(runs_of "$name" | paste -sd, -)"
  [ -z "$runs" ] || line="$line runs: $runs"
  dead="$(dead_reason "$name" " ")"
  [ -z "$dead" ] || line="$line DEAD: $dead"
  printf '%s\n' "$line" | sed 's/ *$//'
done

if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then ignored="not in git"
elif git -C "$dir" check-ignore -q "$dir"; then ignored=gitignored
else ignored=tracked; fi
echo "flowsDir: $dir ($ignored)"

if [ "$found" -eq 0 ]; then
  echo "no flow name contains '$area' in $dir"
  exit 1
fi
