#!/usr/bin/env bash
# Usage: lint-skill.sh <skillDir>
# Checks a skill against the write-great-skills rules. Prints "error ..." and "warn ..." lines and
# exits 1 when there is any error, 0 otherwise. Warnings are judgment calls; fix them or say why not.
set -euo pipefail
export LC_ALL=C

dir="$(cd "${1:?usage: lint-skill.sh <skillDir>}" && pwd)"
skill="$dir/SKILL.md"
errors=0
error() { echo "error $*"; errors=1; }
warn() { echo "warn $*"; }
chars() { printf '%s' "$1" | tr -d '\200-\277' | wc -c | tr -d ' '; }

[ -f "$skill" ] || { echo "error no SKILL.md in $dir"; exit 1; }

frontmatter="$(awk 'NR==1 && $0=="---"{on=1; next} on && $0=="---"{exit} on' "$skill")"
[ -n "$frontmatter" ] || error "SKILL.md has no front matter block"

name="$(printf '%s\n' "$frontmatter" | sed -n 's/^name: *//p')"
description="$(printf '%s\n' "$frontmatter" | sed -n 's/^description: *//p' | sed 's/[[:space:]]*$//')"
folder="$(basename "$dir")"

[ "$name" = "$folder" ] || error "name '$name' does not match folder '$folder'"
printf '%s' "$name" | grep -qE '^[a-z0-9-]{1,64}$' || error "name must be 1-64 lowercase letters, digits or hyphens"
case "$description" in
  \"*\") description="${description#\"}"; description="${description%\"}" ;;
  \'*\') description="${description#\'}"; description="${description%\'}" ;;
esac
if printf '%s' "$description" | grep -qE '^[>|][-+0-9]*$'; then
  error "description is a '$description' block scalar; write it on one line"
elif [ -z "$description" ]; then
  error "description is missing or not on one line"
else
  length="$(chars "$description")"
  [ "$length" -le 1024 ] || error "description is $length characters, limit 1024"
  [ "$length" -le 450 ] || warn "description is $length characters; aim for 450 or fewer"
  case "$description" in "Use when"*) ;; *) warn "description should start with 'Use when'" ;; esac
  printf '%s' "$description" | grep -qiE '(^|[ .;])(not for|use [a-z0-9:-]+ (for|instead))' ||
    warn "description names no near-miss route ('Not for X; use Y')"
fi

lines="$(wc -l <"$skill" | tr -d ' ')"
[ "$lines" -le 150 ] || warn "SKILL.md is $lines lines; move once-per-repo or on-failure material into references/"

grep -qE '^## Hard rules[[:space:]]*$' "$skill" || error "SKILL.md has no '## Hard rules' section"
grep -qE '^## Report[[:space:]]*$' "$skill" || error "SKILL.md has no '## Report' section"

awk '
  /^## / { if (step != "" && !done) print "warn step " step " has no Done when line"; step = ""; done = 0 }
  /^## [0-9]+\./ { step = $2; sub(/\.$/, "", step) }
  /Done when/ { done = 1 }
  END { if (step != "" && !done) print "warn step " step " has no Done when line" }
' "$skill"

docs=("$skill")
if [ -d "$dir/references" ]; then
  while IFS= read -r file; do docs+=("$file"); done < <(find "$dir/references" -type f -name '*.md' | sort)
fi

texts=()
while IFS= read -r file; do texts+=("$file"); done < <(find "$dir" -type f \( -name '*.md' -o -name '*.sh' \
  -o -name '*.mjs' -o -name '*.js' -o -name '*.py' -o -name '*.json' -o -name '*.html' -o -name '*.yaml' \
  -o -name '*.yml' \) | sort)

banned_names=("em dash" "en dash" "curly quote" "curly quote" "curly quote" "curly quote")
banned_chars=($'\xe2\x80\x94' $'\xe2\x80\x93' $'\xe2\x80\x9c' $'\xe2\x80\x9d' $'\xe2\x80\x98' $'\xe2\x80\x99')

file_report="$(for file in "${texts[@]}"; do
  rel="${file#"$dir"/}"
  for i in "${!banned_chars[@]}"; do
    grep -nIF -e "${banned_chars[$i]}" "$file" | cut -d: -f1 | sed "s|^|error ${banned_names[$i]} in $rel:|" || true
  done
done
for file in "${docs[@]}"; do
  rel="${file#"$dir"/}"
  grep -niwE 'simply|obviously|just make sure|it is important to note' "$file" | sed "s|^|warn filler word in $rel:|" || true
  grep -oE '(^|[^/A-Za-z0-9._<-])(\./)?(references|scripts|assets)/[A-Za-z0-9._/-]*\.[A-Za-z0-9]+' "$file" |
    sed -E 's#^[^a-z.]##; s#^\./##' | sort -u | while read -r ref; do
    [ -e "$dir/$ref" ] || echo "error $rel points to $ref, which does not exist"
  done || true
done)"
if [ -n "$file_report" ]; then
  printf '%s\n' "$file_report"
  if printf '%s\n' "$file_report" | grep -q '^error'; then errors=1; fi
fi

portable=("${docs[@]}")
if [ -d "$dir/assets" ]; then
  while IFS= read -r file; do portable+=("$file"); done < <(find "$dir/assets" -type f | sort)
fi
portability="$(for file in "${portable[@]}"; do
  rel="${file#"$dir"/}"
  grep -nIE '(/Users|/home)/[A-Za-z0-9._-]+/' "$file" | sed "s|^|warn machine-specific path in $rel:|" || true
  grep -nIE '(^|[^A-Za-z~/])\.claude/agents/[A-Za-z0-9_-]+\.md' "$file" | sed "s|^|warn repo-local agent path in $rel (bundle it in assets/):|" || true
done)"
[ -z "$portability" ] || printf '%s\n' "$portability"

if grep -qsE 'mcp__|brew install|npm i -g|npx [a-z@]|argent run |xcrun |adb |agent-browser |osascript ' "${docs[@]}"; then
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
