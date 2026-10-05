#!/usr/bin/env bash
# Usage: check-notes.sh <notesFile>
# Checks What to Test notes before upload. Exits 1 when the file is missing or empty, over 4000
# characters, or holds an em dash or a curly quote (it prints each such line). Warns over 1200.
set -euo pipefail

file="${1:?usage: check-notes.sh <notesFile>}"
[ -s "$file" ] || { echo "notes file $file is missing or empty" >&2; exit 1; }

chars="$(LC_ALL=en_US.UTF-8 wc -m <"$file" | tr -d ' ')"
bad=0
if [ "$chars" -gt 4000 ]; then
  echo "notes are $chars characters; App Store Connect allows 4000" >&2
  bad=1
elif [ "$chars" -gt 1200 ]; then
  echo "warn notes are $chars characters; aim for 1200 or fewer" >&2
fi

#! Byte patterns keep this file ASCII: e2 80 94 is the em dash, e2 80 98/99/9c/9d the curly quotes.
if LC_ALL=C grep -nE $'\xe2\x80(\x94|\x98|\x99|\x9c|\x9d)' "$file" >&2; then
  echo "replace the em dashes and curly quotes above with straight ASCII" >&2
  bad=1
fi

[ "$bad" -eq 0 ] && echo "ok notes $chars characters"
exit "$bad"
