#!/usr/bin/env bash
# Usage: config.sh <jq path> [default]
# Prints one value from the repo's .verify-on-device.json (found from the git top level), or the
# default when the file or key is missing. Sourced by the other scripts; also handy by hand.
set -euo pipefail

path="${1:?usage: config.sh <jq path> [default]}"
default="${2:-}"
file="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.verify-on-device.json"

if [ -f "$file" ] && value="$(jq -er "$path // empty" "$file" 2>/dev/null)"; then
  printf '%s\n' "$value"
else
  printf '%s\n' "$default"
fi
