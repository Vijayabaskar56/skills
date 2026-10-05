#!/usr/bin/env bash
# Usage: build-android.sh <apk|aab> <logFile>
# Runs the release Gradle task and prints the artifact path.
set -euo pipefail

kind="$1" log="$2"
case "$kind" in
  apk) task=assembleRelease; out=android/app/build/outputs/apk/release/app-release.apk ;;
  aab) task=bundleRelease; out=android/app/build/outputs/bundle/release/app-release.aab ;;
  *) echo "kind must be apk or aab" >&2; exit 2 ;;
esac

run() { (cd android && ./gradlew "$task") >"$log" 2>&1; }
if ! run; then
  #! A parallel iOS bundle or a running Metro can delete react-native-worklets/.worklets files
  #! mid-bundle ("Failed to get the SHA-1"). That race clears on a second, solo attempt.
  if grep -q 'Failed to get the SHA-1' "$log"; then
    echo "bundling raced another bundler; retrying once" >&2
    run || { echo "gradle $task failed again; last lines:" >&2; grep -v '^w: ' "$log" | tail -30 >&2; exit 1; }
  else
    echo "gradle $task failed; last lines:" >&2
    grep -v '^w: ' "$log" | tail -30 >&2
    exit 1
  fi
fi
[ -f "$out" ] || { echo "gradle succeeded but $out is missing" >&2; exit 1; }
echo "$out"
