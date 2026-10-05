#!/usr/bin/env bash
# Usage: build-ios.sh <workspace> <scheme> <logFile> [extra xcodebuild flags...]
# Archives to .asc/artifacts/<scheme>.xcarchive. `asc xcode archive` exits 0 even when the
# archive fails, so success is read from the log. Prints "<buildNumber> <commit>", where commit
# is HEAD when the archive started, and records both in .asc/artifacts/<scheme>.archived for
# resume-state.sh.
set -euo pipefail

workspace="$1" scheme="$2" log="$3"; shift 3
archive=".asc/artifacts/$scheme.xcarchive"
record=".asc/artifacts/$scheme.archived"
flags=()
for flag in "$@"; do flags+=("--xcodebuild-flag=$flag"); done
tree_state() { { git rev-parse HEAD; git status --porcelain -- . ':!.asc'; git diff HEAD -- . ':!.asc'; } | shasum | cut -c1-12; }

commit="$(git rev-parse HEAD)"
state="$(tree_state)"

asc xcode archive --workspace "$workspace" --scheme "$scheme" --configuration Release \
  --archive-path "$archive" --overwrite --output json ${flags[@]+"${flags[@]}"} >"$log" 2>&1 || true

if ! grep -q '\*\* ARCHIVE SUCCEEDED \*\*' "$log"; then
  echo "archive failed; errors:" >&2
  grep -E 'error:|ARCHIVE FAILED' "$log" | head -20 >&2
  exit 1
fi
n="$(plutil -extract ApplicationProperties.CFBundleVersion raw "$archive/Info.plist")"
mkdir -p "$(dirname "$record")"
echo "$n $commit $state" >"$record"
echo "$n $commit"
