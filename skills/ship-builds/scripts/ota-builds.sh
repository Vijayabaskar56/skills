#!/usr/bin/env bash
# Usage: ota-builds.sh <ios|android> <channel> [limit]
# From the app's repo root. Read-only. Lists the newest EAS builds on <channel>, one per line:
#   build <N> runtime <R> status <S> commit <sha> created <iso> id <buildId>
# The runtime is the one EAS recorded for the build, which is what an OTA must target.
# Builds made outside EAS are not listed; read those with ota-runtime.sh file <path>.
set -euo pipefail

platform="$1" channel="$2" limit="${3:-5}"
json="$(npx eas-cli build:list --platform "$platform" --channel "$channel" --limit "$limit" \
  --json --non-interactive 2>/dev/null)" || { echo "eas build:list failed; run npx eas-cli whoami" >&2; exit 1; }
jq -r '.[] | "build \(.appBuildVersion) runtime \(.runtime.version // .runtimeVersion // "unknown") status \(.status) commit \((.gitCommitHash // "none")[0:8]) created \(.createdAt) id \(.id)"' <<<"$json"
[ "$(jq length <<<"$json")" -gt 0 ] || { echo "no $platform builds on channel $channel" >&2; exit 1; }
