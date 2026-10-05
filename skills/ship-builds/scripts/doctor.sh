#!/usr/bin/env bash
# Usage: doctor.sh [ios|android|both]
# Prints one line per tool: "ok <tool> <version>" or "missing <tool> <install hint>".
# Exits 1 when any tool the chosen platforms need is missing.
set -euo pipefail

platform="${1:-both}"
missing=0

report() {
  local tool="$1" check="$2" hint="$3" out
  if out="$(eval "$check" 2>&1)" && [ -n "$out" ]; then
    echo "ok $tool ${out%%$'\n'*}"
  else
    echo "missing $tool $hint"
    missing=1
  fi
}

report git "git --version" "xcode-select --install"
report node "node -v" "install the version in .nvmrc or package.json engines (nvm, mise or brew)"
report jq "jq --version" "brew install jq"

if [ "$platform" = ios ] || [ "$platform" = both ]; then
  report xcode "xcodebuild -version" "install Xcode from the App Store (needs the user)"
  report asc "asc --version" "brew install asc"
  if [ -f ios/Podfile ]; then report cocoapods "pod --version" "brew install cocoapods"; fi
  if command -v asc >/dev/null; then
    if asc auth status >/dev/null 2>&1; then echo "ok asc-auth logged in"
    else echo "missing asc-auth run asc auth login (references/first-run.md)"; missing=1; fi
  fi
fi

if [ "$platform" = android ] || [ "$platform" = both ]; then
  report java "java -version" "brew install --cask zulu@17"
  sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  if [ -d "$sdk/build-tools" ]; then echo "ok android-sdk $sdk"
  else echo "missing android-sdk install Android Studio, then set ANDROID_HOME (needs the user)"; missing=1; fi
fi

exit "$missing"
