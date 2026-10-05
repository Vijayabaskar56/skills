#!/usr/bin/env bash
# Usage: resume-state.sh <appId> <version> <scheme> <tagPrefix>
# From the app's repo root. Read-only. Compares the newest App Store Connect build of <version>
# with the local <tagPrefix><N> tags and the archive build-ios.sh recorded, and prints the step to
# resume at as its last line:
#   resume bump                 start a new iOS build at the bump step
#   resume upload <N> <commit>  build N is uploaded or archived but not finished: skip the bump
#                               and the iOS archive, then draft notes, upload, invite and tag N
set -euo pipefail

app_id="$1" version="$2" scheme="$3" prefix="$4"
archive=".asc/artifacts/$scheme.xcarchive"
record=".asc/artifacts/$scheme.archived"
is_number() { [[ "$1" =~ ^[0-9]+$ ]]; }
tree_state() { { git rev-parse HEAD; git status --porcelain -- . ':!.asc'; git diff HEAD -- . ':!.asc'; } | shasum | cut -c1-12; }

builds="$(asc builds list --app "$app_id" --version "$version" --platform IOS --processing-state all \
  --sort -uploadedDate --limit 200 --output json)" ||
  { echo "could not list builds of $version in App Store Connect" >&2; exit 1; }
asc_n="$(jq -r '[.data[]?.attributes.version | tonumber? ] | max // empty' <<<"$builds")"
echo "asc newest build of $version: ${asc_n:-none}"

latest_tag=""
while read -r tag; do
  n="${tag#"$prefix"}"
  if is_number "$n" && { [ -z "$latest_tag" ] || [ "$n" -gt "$latest_tag" ]; }; then latest_tag="$n"; fi
done < <(git tag -l "$prefix*")
if [ -n "$latest_tag" ]; then echo "tag newest local: $prefix$latest_tag"; else echo "tag newest local: none"; fi

arch_n="" arch_version="" arch_sha="" arch_state=""
if [ -f "$archive/Info.plist" ] && [ -f "$record" ]; then
  arch_n="$(plutil -extract ApplicationProperties.CFBundleVersion raw "$archive/Info.plist")"
  arch_version="$(plutil -extract ApplicationProperties.CFBundleShortVersionString raw "$archive/Info.plist")"
  read -r rec_n arch_sha arch_state <"$record" || true
  [ "$rec_n" = "$arch_n" ] || arch_sha="" # the record belongs to an older archive
fi
echo "archive: ${arch_n:-none}${arch_sha:+ $arch_version from $arch_sha}"

if is_number "$asc_n" && ! git rev-parse -q --verify "refs/tags/$prefix$asc_n" >/dev/null; then
  if [ "$arch_n" = "$asc_n" ] && [ -n "$arch_sha" ]; then
    [ "$arch_sha" = "$(git rev-parse HEAD)" ] ||
      echo "warn HEAD moved since build $asc_n was archived; that build lacks the newer commits"
    echo "resume upload $asc_n $arch_sha"
    exit 0
  fi
  echo "warn build $asc_n is in App Store Connect with no $prefix$asc_n tag and no matching archive; it was uploaded from elsewhere"
fi

if is_number "$arch_n" && [ -n "$arch_sha" ] && [ "$arch_version" = "$version" ] &&
  { [ -z "$asc_n" ] || [ "$arch_n" -gt "$asc_n" ]; } && [ "$arch_state" = "$(tree_state)" ]; then
  echo "archive $arch_n is not uploaded yet and matches the working tree"
  echo "resume upload $arch_n $arch_sha"
  exit 0
fi
echo "resume bump"
