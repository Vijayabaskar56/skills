#!/usr/bin/env bash
# Usage: find-lint-rule.sh [--repo DIR] <pattern>
# Checks a claim that lint does (or does not) enforce something. Greps every tracked lint config
# (oxlint, ESLint, Biome, package.json eslintConfig) for <pattern>, a case-insensitive extended
# regex such as 'use-?effect' or 'no-restricted-imports'. Prints each match as file:line and exits 0,
# or prints "none" with the configs searched and exits 1. Read the matched line for its severity.
set -euo pipefail

repo=.
if [ "${1:-}" = --repo ]; then repo="$2"; shift 2; fi
pattern="${1:?usage: find-lint-rule.sh [--repo DIR] <pattern>}"
cd "$repo"

configs="$(git ls-files | grep -iE '(^|/)(\.?oxlintrc[^/]*|oxlint\.json|\.?eslintrc[^/]*|eslint\.config\.[a-z]+|biome\.jsonc?)$' || true)"
if git ls-files --error-unmatch package.json >/dev/null 2>&1 && grep -q '"eslintConfig"' package.json; then
  configs="$(printf '%s\npackage.json' "$configs" | grep .)"
fi
[ -n "$configs" ] || { echo "none: no lint config is tracked in $(pwd)"; exit 1; }

matches="$(printf '%s\n' "$configs" | while read -r file; do
  grep -niE -- "$pattern" "$file" | sed "s|^|$file:|" || true
done)"
if [ -n "$matches" ]; then
  printf '%s\n' "$matches"
else
  echo "none: '$pattern' is in no lint config. Searched: $(printf '%s\n' "$configs" | paste -sd ' ' -)"
  exit 1
fi
