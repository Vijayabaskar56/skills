#!/usr/bin/env bash
# Usage: find-lint-rule.sh [--repo DIR] <pattern>
# Checks a claim that lint does (or does not) enforce something. Greps every tracked lint config
# for <pattern>, a case-insensitive extended regex such as 'use-?effect' or 'no-restricted-imports'.
# Configs: oxlint*/.oxlintrc*, eslint*.config.*/.eslintrc*, biome.json(c), package.json eslintConfig,
# and any file a package.json script passes to eslint, oxlint or biome with --config/-c.
# Prints each match as file:line and exits 0, or prints "none" with the configs searched and
# exits 1. Read the matched line for its severity.
set -euo pipefail

repo=.
if [ "${1:-}" = --repo ]; then repo="$2"; shift 2; fi
pattern="${1:?usage: find-lint-rule.sh [--repo DIR] <pattern>}"
cd "$repo"

configs="$(git ls-files | grep -iE '(^|/)(\.?oxlintrc[^/]*|oxlint[^/]*\.(jsonc?|[cm]?[jt]s)|\.?eslintrc[^/]*|eslint[^/]*\.config\.[^/]+|biome\.jsonc?)$' || true)"

if git ls-files --error-unmatch package.json >/dev/null 2>&1; then
  grep -q '"eslintConfig"' package.json && configs="$(printf '%s\npackage.json' "$configs")"
  passed="$(awk '
    /"scripts"[[:space:]]*:/ { on = 1; next }
    on && /^[[:space:]]*}/ { exit }
    on {
      sub(/^[[:space:]]*"[^"]*"[[:space:]]*:[[:space:]]*"/, "")
      sub(/",?[[:space:]]*$/, "")
      gsub(/\\"/, "")
      n = split($0, cmd, /&&|\|\||;|\|/)
      for (i = 1; i <= n; i++) {
        c = cmd[i]
        sub(/^[[:space:]]+/, "", c)
        sub(/^(npx|bunx|pnpm exec|yarn)[[:space:]]+/, "", c)
        if (c !~ /^(eslint|oxlint|biome)([[:space:]]|$)/) continue
        m = split(c, word, /[[:space:]=]+/)
        for (j = 1; j < m; j++) if (word[j] == "--config" || word[j] == "-c") print word[j + 1]
      }
    }' package.json || true)"
  while read -r file; do
    [ -n "$file" ] && git ls-files --error-unmatch "$file" >/dev/null 2>&1 &&
      configs="$(printf '%s\n%s' "$configs" "$file")"
  done <<<"$passed"
fi
configs="$(printf '%s\n' "$configs" | grep . | sort -u || true)"
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
