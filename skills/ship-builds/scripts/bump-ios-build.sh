#!/usr/bin/env bash
# Usage: bump-ios-build.sh <appId> <version> <infoPlist>
# Sets the project to the next build number App Store Connect expects, patches a literal
# CFBundleVersion (Expo prebuild writes one), and prints the number. Safe to rerun: until a
# build is uploaded, App Store Connect returns the same next number.
set -euo pipefail

app_id="$1" version="$2" info_plist="$3"

n="$(cd ios && asc xcode version edit --version "$version" --next-build-number --app "$app_id" --output json | jq -r '.buildNumber')"
[ -n "$n" ] && [ "$n" != null ] || { echo "could not read the next build number" >&2; exit 1; }

current="$(plutil -extract CFBundleVersion raw "$info_plist")"
case "$current" in
  *'$('*) ;;
  *) plutil -replace CFBundleVersion -string "$n" "$info_plist" ;;
esac

actual="$(plutil -extract CFBundleVersion raw "$info_plist")"
case "$actual" in *'$('*|"$n") ;; *) echo "Info.plist has $actual, expected $n" >&2; exit 1 ;; esac
echo "$n"
