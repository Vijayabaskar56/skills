#!/usr/bin/env bash
# Usage: ota-served.sh <updatesUrl> <ios|android> <runtime> <channel>
# Read-only. Asks the update server what an installed build with <runtime> on <channel> gets,
# the same request the app sends at launch. Prints
#   served <updateId> created <iso>    and exits 0
#   none <reason>                      and exits 1 (for example NO_UPDATE_AVAILABLE)
set -euo pipefail

url="$1" platform="$2" runtime="$3" channel="$4"
body="$(mktemp)" headers="$(mktemp)"
code="$(curl -sS --max-time 30 -o "$body" -D "$headers" -w '%{http_code}' \
  -H "expo-platform: $platform" -H "expo-runtime-version: $runtime" \
  -H "expo-channel-name: $channel" -H 'expo-protocol-version: 1' \
  -H 'accept: multipart/mixed,application/expo+json,application/json' "$url")"
if [ "$code" = 200 ]; then
  id="$(LC_ALL=C grep -ao '"id":"[^"]*"' "$body" | head -1 | cut -d'"' -f4 || true)"
  created="$(LC_ALL=C grep -ao '"createdAt":"[^"]*"' "$body" | head -1 | cut -d'"' -f4 || true)"
  echo "served $id created $created"; exit 0
fi
reason="$(grep -i '^expo-reason-code:' "$headers" | cut -d' ' -f2 | tr -d '\r' || true)"
echo "none ${reason:-HTTP_$code}"
exit 1
