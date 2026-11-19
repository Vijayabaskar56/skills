#!/usr/bin/env bash
# Usage: doctor.sh [ios|android|both|ota]
# From the app's repo root. Prints one line per dependency: "ok <name> <version>",
# "missing <name>" with its section in references/setup.md, or "session <name> ..." for what only
# the agent can confirm. Exits 1 when anything the chosen platforms need is missing.
set -euo pipefail

platform="${1:-both}"
cfg=.ship-builds.json
missing=0

report() {
  local tool="$1" check="$2" out
  if out="$(eval "$check" 2>&1)" && [ -n "$out" ]; then
    echo "ok $tool ${out%%$'\n'*}"
  else
    echo "missing $tool, see references/setup.md#$tool"
    missing=1
  fi
}

report git "git --version"
report node "node -v"
report jq "jq --version"

if [ "$platform" = ota ]; then
  report curl "curl --version"
  report eas-cli "npx --no-install eas-cli --version 2>/dev/null || eas --version"
  if grep -q '"expo-updates"' package.json 2>/dev/null; then echo "ok expo-updates in package.json"
  else echo "missing expo-updates, see references/setup.md#expo-updates"; missing=1; fi
  if npx --no-install eas-cli whoami >/dev/null 2>&1; then echo "ok eas-login $(npx --no-install eas-cli whoami 2>/dev/null | head -1)"
  else echo "missing eas-login, see references/setup.md#eas-login"; missing=1; fi
  if grep -q '"@sentry/react-native"' package.json 2>/dev/null; then
    if [ -n "${SENTRY_AUTH_TOKEN:-}" ] || grep -qsE '^SENTRY_AUTH_TOKEN=.+' .env.local .env; then echo "ok sentry-token set"
    else echo "optional sentry-token not set; references/ota.md step 3 asks whether to set up source maps"; fi
  fi
  exit "$missing"
fi

if [ "$platform" = ios ] || [ "$platform" = both ]; then
  report xcode "xcodebuild -version"
  report asc "asc --version"
  if [ -f ios/Podfile ]; then report cocoapods "pod --version"; fi
  if command -v asc >/dev/null; then
    if asc auth status >/dev/null 2>&1; then echo "ok asc-auth logged in"
    else echo "missing asc-auth, see references/setup.md#asc-auth"; missing=1; fi
  fi

  if [ -f "$cfg" ] && command -v jq >/dev/null && jq -e '.perf' "$cfg" >/dev/null 2>&1; then
    report curl "curl --version"
    report argent "argent --version 2>/dev/null || npx --no-install @swmansion/argent --version"
    port="$(jq -r '.perf.metroPort // 8081' "$cfg")"
    if command -v curl >/dev/null && curl -fsS -m 3 "http://localhost:$port/status" 2>/dev/null | grep -q running; then
      echo "ok metro running on port $port"
    else
      echo "session metro not running on port $port; start it before the perf step"
    fi
    echo "session dev-build confirm the booted simulator has a dev build of the app, signed in and past onboarding"
  fi
fi

if [ "$platform" = android ] || [ "$platform" = both ]; then
  report java "java -version"
  sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  if [ -d "$sdk/build-tools" ]; then echo "ok android-sdk $sdk"
  else echo "missing android-sdk, see references/setup.md#android-sdk"; missing=1; fi
fi

exit "$missing"
