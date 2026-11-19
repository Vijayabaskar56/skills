#!/usr/bin/env bash
# Usage: ota-sentry-check.sh <distDir> <org> <project> [sentryUrl]
# From the app's repo root. Read-only. For each bundle in <distDir>/_expo/static/js/<platform>/,
# reads the Sentry debug ID baked into it and asks Sentry whether a source map for that ID exists.
# Reads SENTRY_AUTH_TOKEN from the environment, else from .env.local or .env. Prints
#   ok <platform> <debugId>  or  missing <platform> <debugId|no-debug-id>
# and exits 1 if any bundle has no source map on Sentry.
set -euo pipefail

dist="$1" org="$2" project="$3" base="${4:-https://sentry.io}"
token="${SENTRY_AUTH_TOKEN:-}"
for f in .env.local .env; do
  [ -n "$token" ] || ! [ -f "$f" ] || token="$(grep -E '^SENTRY_AUTH_TOKEN=' "$f" | head -1 | cut -d= -f2- | tr -d '"' || true)"
done
[ -n "$token" ] || { echo "SENTRY_AUTH_TOKEN is not set" >&2; exit 2; }

failed=0 found=0
for bundle in "$dist"/_expo/static/js/*/*; do
  case "$bundle" in *.map) continue ;; esac
  platform="$(basename "$(dirname "$bundle")")" found=1
  id="$(LC_ALL=C grep -ao 'sentry-dbid-[0-9a-f-]\{36\}' "$bundle" | head -1 | cut -c13- || true)"
  if [ -z "$id" ]; then echo "missing $platform no-debug-id"; failed=1; continue; fi
  hits="$(curl -sS --max-time 30 -H "Authorization: Bearer $token" \
    "${base%/}/api/0/projects/$org/$project/artifact-lookup/?debug_id=$id" | jq 'length' 2>/dev/null || echo 0)"
  if [ "$hits" -gt 0 ]; then echo "ok $platform $id"; else echo "missing $platform $id"; failed=1; fi
done
[ "$found" = 1 ] || { echo "no bundles under $dist/_expo/static/js" >&2; exit 2; }
exit "$failed"
