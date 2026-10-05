#!/usr/bin/env bash
# Usage: upload-ios.sh <appId> <version> <scheme> <buildNumber> <notesFile> <locale> [exportOptions]
# Exports the archive to an IPA and uploads it with the notes, then waits for processing and prints
# the App Store Connect build id on stdout and "processing <state>" on stderr. Refuses notes that
# fail check-notes.sh. Refuses unless both the archive and the exported IPA carry
# <buildNumber>: Xcode's export silently renumbers a build that App Store Connect already has.
# Rerun-safe: if build <buildNumber> is already in App Store Connect, it skips the upload and
# only sets the notes.
set -euo pipefail

app_id="$1" version="$2" scheme="$3" n="$4" notes_file="$5" locale="$6" export_options="${7:-}"
archive=".asc/artifacts/$scheme.xcarchive"
ipa=".asc/artifacts/$scheme.ipa"
"$(dirname "$0")/check-notes.sh" "$notes_file" >&2
notes="$(cat "$notes_file")"

find_build() {
  asc builds list --app "$app_id" --version "$version" --build-number "$n" --platform IOS \
    --processing-state all --output json | jq -r '.data[0].id // empty'
}

build_id="$(find_build)"
if [ -n "$build_id" ]; then
  echo "build $n already in App Store Connect ($build_id); setting notes only" >&2
  asc builds test-notes update --build-id "$build_id" --locale "$locale" --whats-new "$notes" >/dev/null 2>&1 ||
    asc builds test-notes create --build-id "$build_id" --locale "$locale" --whats-new "$notes" >/dev/null
else
  archive_n="$(plutil -extract ApplicationProperties.CFBundleVersion raw "$archive/Info.plist")"
  if [ "$archive_n" != "$n" ]; then
    echo "archive has build $archive_n, expected $n; rebuild before uploading" >&2
    exit 1
  fi

  export_args=(--archive-path "$archive" --ipa-path "$ipa" --overwrite --output json)
  [ -n "$export_options" ] && export_args+=(--export-options "$export_options")
  asc xcode export "${export_args[@]}" >/dev/null

  check_dir="$(mktemp -d)"
  unzip -q -o "$ipa" 'Payload/*.app/Info.plist' -d "$check_dir"
  ipa_n="$(plutil -extract CFBundleVersion raw "$check_dir"/Payload/*.app/Info.plist)"
  if [ "$ipa_n" != "$n" ]; then
    echo "export renumbered build $n to $ipa_n; not uploading" >&2
    exit 1
  fi

  asc builds upload --app "$app_id" --ipa "$ipa" --test-notes "$notes" --locale "$locale" --output json >/dev/null
  build_id="$(find_build)"
  [ -n "$build_id" ] || { echo "upload finished but build $n is not listed" >&2; exit 1; }
fi

wait_status=0
wait_err="$(mktemp)"
waited="$(asc builds wait --build-id "$build_id" --output json 2>"$wait_err")" || wait_status=$?
state="$(jq -r 'first(.. | .processingState? // empty)' <<<"$waited" 2>/dev/null || true)"
echo "processing ${state:-unknown}" >&2
if [ "$wait_status" -ne 0 ]; then
  echo "asc builds wait exited $wait_status for build $n ($build_id):" >&2
  tail -5 "$wait_err" >&2
  exit 1
fi
echo "$build_id"
