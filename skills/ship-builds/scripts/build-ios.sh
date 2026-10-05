#!/usr/bin/env bash
# Usage: build-ios.sh <workspace> <scheme> <logFile> [extra xcodebuild flags...]
# Archives to .asc/artifacts/<scheme>.xcarchive. `asc xcode archive` exits 0 even when the
# archive fails, so success is read from the log. Prints the archived build number.
set -euo pipefail

workspace="$1" scheme="$2" log="$3"; shift 3
archive=".asc/artifacts/$scheme.xcarchive"
flags=()
for flag in "$@"; do flags+=("--xcodebuild-flag=$flag"); done

asc xcode archive --workspace "$workspace" --scheme "$scheme" --configuration Release \
  --archive-path "$archive" --overwrite --output json ${flags[@]+"${flags[@]}"} >"$log" 2>&1 || true

if ! grep -q '\*\* ARCHIVE SUCCEEDED \*\*' "$log"; then
  echo "archive failed; errors:" >&2
  grep -E 'error:|ARCHIVE FAILED' "$log" | head -20 >&2
  exit 1
fi
plutil -extract ApplicationProperties.CFBundleVersion raw "$archive/Info.plist"
