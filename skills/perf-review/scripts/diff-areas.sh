#!/usr/bin/env bash
# Usage: diff-areas.sh [--repo DIR] [--depth N] <range>
#   <range> is one of:
#     BASE..HEAD | BASE HEAD      explicit refs (tags, branches, shas)
#     --builds PREFIX             the two newest tags matching PREFIX*, e.g. --builds testflight-
#     --since-build PREFIX        the newest PREFIX* tag..HEAD
#     --since-time "TIME"         last commit before TIME..HEAD (a guess; TIME is the upload time)
# Resolves the range and prints it, native/config files touched, changed files grouped by area
# with line counts, the changed files with the most approx. importers, and perf commits before the
# base. A failed range prints "error ..." with the next range to try.
# Area is the first N path segments (default 2) of the file's directory; a leading src/ is free.
set -euo pipefail

repo=.
depth=2
mode=""
a=""
b=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --depth) depth="$2"; shift 2 ;;
    --builds | --since-build | --since-time) mode="$1"; a="${2:?$1 needs a value}"; shift 2 ;;
    -h | --help) sed -n '2,11p' "$0"; exit 0 ;;
    *..*) mode=explicit; a="${1%%..*}"; b="${1#*..}"; shift ;;
    *) if [ -z "$a" ]; then a="$1"; else b="$1"; fi; mode=explicit; shift ;;
  esac
done
[ -n "$mode" ] || { sed -n '2,11p' "$0" >&2; exit 2; }
cd "$repo"
git rev-parse --git-dir >/dev/null

fail() { echo "error $*" >&2; exit 1; }
label=""
same_hint=""
empty_hint=""
case "$mode" in
  explicit)
    [ -n "$b" ] || b=HEAD
    basis=explicit
    label="$a..$b"
    ;;
  --builds)
    tags="$(git tag -l "$a*" --sort=-version:refname | head -3)"
    [ "$(printf '%s\n' "$tags" | grep -c .)" -ge 2 ] || fail "need two tags matching '$a*', found: ${tags:-none}"
    b="$(printf '%s\n' "$tags" | sed -n 1p)"
    a="$(printf '%s\n' "$tags" | sed -n 2p)"
    older="$(printf '%s\n' "$tags" | sed -n 3p)"
    [ -z "$older" ] || empty_hint="; try the next older pair: $older..$a"
    basis="build tags"
    label="$a..$b"
    ;;
  --since-build)
    tag="$(git tag -l "$a*" --sort=-version:refname | head -1)"
    [ -n "$tag" ] || fail "no tag matches '$a*'"
    same_hint="; the newest build is HEAD, so use --builds $a"
    empty_hint="; HEAD has the same files as the newest build, so use --builds $a"
    a="$tag"; b=HEAD
    basis="build tag to HEAD"
    label="$a..HEAD"
    ;;
  --since-time)
    time="$a"
    a="$(git rev-list -1 --before="$time" HEAD)"
    [ -n "$a" ] || fail "no commit before '$time'"
    b=HEAD
    basis="GUESS: last commit before upload time $time; confirm with the user"
    label="guess..HEAD"
    ;;
esac

base="$(git rev-parse --verify --quiet "$a^{commit}")" || fail "unknown ref '$a'"
head="$(git rev-parse --verify --quiet "$b^{commit}")" || fail "unknown ref '$b'"
[ "$base" != "$head" ] || fail "base and head are the same commit ($a)$same_hint"

if ! git merge-base --is-ancestor "$base" "$head"; then
  base="$(git merge-base "$base" "$head")" || fail "'$a' and '$b' share no history"
  basis="$basis; base moved to the merge base, so the range is head's own changes"
  [ "$base" != "$head" ] || fail "'$b' is an ancestor of '$a'; swap the refs"
fi

show() { git log -1 --format='%h %cd %s' --date=format:'%Y-%m-%d %H:%M' "$1"; }
echo "range    $(git rev-parse --short "$base")..$(git rev-parse --short "$head") ($label)"
echo "basis    $basis"
echo "base     $(show "$base")"
echo "head     $(show "$head")"
echo "commits  $(git rev-list --count "$base..$head")"

numstat="$(git diff --numstat --no-renames "$base" "$head")"
[ -n "$numstat" ] || fail "no file changes in range $label$empty_hint"

native_re='(^|/)(package\.json|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb?|Podfile(\.lock)?|app\.json|app\.config\.[a-z]+|eas\.json|babel\.config\.[a-z]+|metro\.config\.[a-z]+|vite\.config\.[a-z]+|next\.config\.[a-z]+|webpack\.config\.[a-z]+|build\.gradle(\.kts)?|gradle\.properties|Info\.plist)$|^(ios|android|patches)/'
native="$(printf '%s\n' "$numstat" | cut -f3 | grep -E "$native_re" | paste -sd ' ' - || true)"
echo "native   ${native:-none (JS and styles only)}"

if [ "$head" = "$(git rev-parse HEAD)" ]; then
  dirty="$(git status --porcelain --untracked-files=no | grep -c . || true)"
  [ "$dirty" -eq 0 ] || echo "dirty    $dirty uncommitted files are not in the range and are not reviewed"
fi

echo
echo "areas (most changed lines first; area  files  +added -deleted, then each file)"
printf '%s\n' "$numstat" | awk -F'\t' -v depth="$depth" '
  {
    add = ($1 == "-") ? 0 : $1; del = ($2 == "-") ? 0 : $2
    n = split($3, seg, "/")
    last = ((seg[1] == "src" && n > 2) ? 1 : 0) + depth
    if (last > n - 1) last = n - 1
    area = (last < 1) ? "(root)" : seg[1]
    for (i = 2; i <= last; i++) area = area "/" seg[i]
    files[area]++; lines[area] += add + del; adds[area] += add; dels[area] += del
    detail[area] = detail[area] sprintf("  %-60s +%d -%d\n", $3, add, del)
  }
  END {
    for (a in files) printf "%d\t%-40s %3d files  +%d -%d\n%s\036", lines[a], a, files[a], adds[a], dels[a], detail[a]
  }
' | tr '\036' '\0' | sort -z -rn | tr '\0' '\n' | cut -f2- | grep -v '^$'

echo
echo "widest reach (top 10 changed code files by approx. importers at head, matched by file basename)"
echo "approx. importers: 2-hop direct  file"
changed_code="$(printf '%s\n' "$numstat" | cut -f3 | grep -E '\.(tsx?|jsx?|mjs|cjs)$' |
  grep -vE '(\.test\.|\.spec\.|__tests__/|(^|/)tests?/)' || true)"
{
  printf '%s\n' "$changed_code" | sed 's/^/CHANGED\t/'
  git grep -o -E "(from|import|require\()[[:space:]]*\(?['\"][^'\"]+['\"]" "$head" -- \
    '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs' | sed "s|^$head:||" |
    sed -E "s/^([^:]+):.*['\"]([^'\"]+)['\"]\$/IMPORT\t\1\t\2/" || true
} | awk -F'\t' '
  function modname(path,   n, seg, name) {
    n = split(path, seg, "/")
    name = seg[n]
    sub(/\.(tsx?|jsx?|mjs|cjs)$/, "", name)
    sub(/\.(native|ios|android|web)$/, "", name)
    if (name == "index" && n > 1) name = seg[n - 1]
    return name
  }
  $1 == "CHANGED" { changed[++nc] = $2; next }
  $1 == "IMPORT" && index($3, "/") {
    name = modname($3)
    if (!((name, $2) in seen)) { seen[name, $2] = 1; users[name] = users[name] "\n" $2 }
  }
  END {
    for (i = 1; i <= nc; i++) {
      path = changed[i]; split("", hop); n1 = 0; n2 = 0
      m = split(users[modname(path)], direct, "\n")
      for (j = 2; j <= m; j++) {
        if (direct[j] == path) continue
        n1++
        if (!(direct[j] in hop)) { hop[direct[j]] = 1; n2++ }
        k = split(users[modname(direct[j])], second, "\n")
        for (l = 2; l <= k; l++)
          if (second[l] != path && !(second[l] in hop)) { hop[second[l]] = 1; n2++ }
      }
      printf "%5d %5d  %s\n", n2, n1, path
    }
  }
' | sort -rn | head -10

echo
echo "perf commits before base (check the range undoes none of them)"
git log -i --grep=perf --format='  %h %cd %s' --date=format:'%Y-%m-%d' -n 12 "$base" || true
