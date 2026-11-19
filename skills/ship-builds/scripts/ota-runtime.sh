#!/usr/bin/env bash
# Usage: ota-runtime.sh eas <buildId>
#        ota-runtime.sh file <path.ipa|path.xcarchive|path.app>
# Read-only. Prints the runtime, channel and update URL the installed build will send:
#   runtime <R> channel <C> url <U>
# Android files are not supported: read an Android build's runtime from EAS.
set -euo pipefail

mode="$1" target="$2"
if [ "$mode" = eas ]; then
  json="$(npx eas-cli build:view "$target" --json 2>/dev/null)" || { echo "eas build:view $target failed" >&2; exit 1; }
  jq -r '"runtime \(.runtime.version // "unknown") channel \(.updateChannel.name // .channel // "unknown") url eas"' <<<"$json"
  exit 0
fi
[ "$mode" = file ] || { echo "mode must be eas or file" >&2; exit 2; }

work="$(mktemp -d)"
case "$target" in
  *.ipa) unzip -q -o "$target" 'Payload/*.app/Expo.plist' 'Payload/*.app/EXUpdates.bundle/*' -d "$work" 2>/dev/null || true
         app="$(find "$work/Payload" -maxdepth 1 -name '*.app' | head -1)" ;;
  *.xcarchive) app="$(find "$target/Products/Applications" -maxdepth 1 -name '*.app' | head -1)" ;;
  *.app) app="$target" ;;
  *) echo "unsupported file: $target (use an .ipa, .xcarchive or .app; Android builds: ota-runtime.sh eas <id>)" >&2; exit 2 ;;
esac
plist="${app:-}/Expo.plist"
[ -f "$plist" ] || { echo "no Expo.plist in $target: expo-updates is not in this build" >&2; exit 1; }

runtime="$(plutil -extract EXUpdatesRuntimeVersion raw "$plist")"
if [ "$runtime" = "file:fingerprint" ]; then runtime="$(cat "$app/EXUpdates.bundle/fingerprint")"; fi
channel="$(plutil -extract EXUpdatesRequestHeaders.expo-channel-name raw "$plist" 2>/dev/null || echo none)"
url="$(plutil -extract EXUpdatesURL raw "$plist")"
echo "runtime $runtime channel $channel url $url"
