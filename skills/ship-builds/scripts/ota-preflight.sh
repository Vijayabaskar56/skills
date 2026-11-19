#!/usr/bin/env bash
# Usage: ota-preflight.sh <ios|android> <targetRuntime> [NAME=value ...]
# From the directory you will publish from. Read-only. Computes this tree's runtime fingerprint
# with the build's env (for example APP_VARIANT=production) and compares it to the runtime the
# installed build reports (ota-builds.sh or ota-runtime.sh). Prints
#   local <L> target <R> match|mismatch
# and exits 1 on a mismatch: an update published from here would never reach that build.
set -euo pipefail

platform="$1" target="$2"; shift 2
json="$(env "$@" npx expo-updates fingerprint:generate --platform "$platform" 2>/dev/null)" ||
  { echo "fingerprint:generate failed; is expo-updates installed?" >&2; exit 2; }
local_fp="$(jq -r .hash <<<"$json")"
if [ "$local_fp" = "$target" ]; then echo "local $local_fp target $target match"; exit 0; fi
echo "local $local_fp target $target mismatch"
exit 1
