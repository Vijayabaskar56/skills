#!/usr/bin/env bash
# Usage: lint-skill.sh <skillDir>
# Checks a skill against the write-great-skills rules. Prints "error ..." and "warn ..." lines and
# exits 1 when there is any error. Warnings are judgment calls; fix them or say why not.
set -euo pipefail

dir="$(cd "${1:?usage: lint-skill.sh <skillDir>}" && pwd)"
skill="$dir/SKILL.md"
errors=0
error() { echo "error $*"; errors=1; }
warn() { echo "warn $*"; }

[ -f "$skill" ] || { echo "error no SKILL.md in $dir"; exit 1; }

frontmatter="$(awk 'NR==1 && $0=="---"{on=1; next} on && $0=="---"{exit} on' "$skill")"
[ -n "$frontmatter" ] || error "SKILL.md has no front matter block"

name="$(printf '%s\n' "$frontmatter" | sed -n 's/^name: *//p')"
description="$(printf '%s\n' "$frontmatter" | sed -n 's/^description: *//p')"
folder="$(basename "$dir")"

[ "$name" = "$folder" ] || error "name '$name' does not match folder '$folder'"
printf '%s' "$name" | grep -qE '^[a-z0-9-]{1,64}$' || error "name must be 1-64 lowercase letters, digits or hyphens"
[ -n "$description" ] || error "description is missing or not on one line"
[ "${#description}" -le 1024 ] || error "description is ${#description} characters, limit 1024"
[ "${#description}" -le 450 ] || warn "description is ${#description} characters; aim for 450 or fewer"
case "$description" in "Use when"*) ;; *) warn "description should start with 'Use when'" ;; esac
printf '%s' "$description" | grep -qiE '(^|[ .;])(not for|use [a-z0-9:-]+ (for|instead))' ||
  warn "description names no near-miss route ('Not for X; use Y')"

lines="$(wc -l <"$skill" | tr -d ' ')"
[ "$lines" -le 150 ] || warn "SKILL.md is $lines lines; move once-per-repo or on-failure material into references/"

steps="$(grep -cE '^## [0-9]+\.' "$skill" || true)"
done_when="$(grep -c 'Done when' "$skill" || true)"
if [ "$steps" -gt 0 ] && [ "$done_when" -lt "$steps" ]; then
  warn "$steps numbered steps but $done_when 'Done when' lines"
fi

file_report="$(for file in "$skill" "$dir"/references/*.md; do
  [ -f "$file" ] || continue
  rel="${file#"$dir"/}"
  grep -n '—' "$file" | sed "s|^|warn em dash in $rel:|" || true
  grep -niwE 'simply|obviously|just make sure|it is important to note' "$file" | sed "s|^|warn filler word in $rel:|" || true
  grep -oE '(^|[^/A-Za-z0-9._<-])(references|scripts|assets)/[A-Za-z0-9._-]*\.[A-Za-z0-9]+' "$file" |
    sed -E 's#^[^a-z]##' | sort -u | while read -r ref; do
    [ -e "$dir/$ref" ] || echo "error $rel points to $ref, which does not exist"
  done || true
done)"
if [ -n "$file_report" ]; then
  printf '%s\n' "$file_report"
  if printf '%s\n' "$file_report" | grep -q '^error'; then errors=1; fi
fi

portability="$(for file in "$skill" "$dir"/references/*.md "$dir"/assets/*; do
  [ -f "$file" ] || continue
  rel="${file#"$dir"/}"
  grep -nE '(/Users|/home)/[A-Za-z0-9._-]+/' "$file" | sed "s|^|warn machine-specific path in $rel:|" || true
  grep -nE '(^|[^A-Za-z~/])\.claude/agents/[A-Za-z0-9_-]+\.md' "$file" | sed "s|^|warn repo-local agent path in $rel (bundle it in assets/):|" || true
done)"
[ -z "$portability" ] || printf '%s\n' "$portability"

if grep -qsE 'mcp__|brew install|npm i -g|npx [a-z@]|argent run |xcrun |adb |agent-browser |osascript ' "$skill" "$dir"/references/*.md; then
  [ -e "$dir/scripts/doctor.sh" ] || [ -e "$dir/references/setup.md" ] ||
    warn "calls MCP tools or external CLIs but has no scripts/doctor.sh or references/setup.md"
fi

for script in "$dir"/scripts/*; do
  [ -f "$script" ] || continue
  rel="${script#"$dir"/}"
  [ -x "$script" ] || error "$rel is not executable"
  case "$script" in
    *.sh) bash -n "$script" 2>/dev/null || error "$rel has a syntax error" ;;
  esac
  head -5 "$script" | grep -q 'Usage:' || warn "$rel has no 'Usage:' header comment"
done

[ "$errors" -eq 0 ] && echo "ok $folder"
exit "$errors"
