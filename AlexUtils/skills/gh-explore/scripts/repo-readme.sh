#!/usr/bin/env bash
# Fetch a repo's README as raw markdown, optionally truncating.
#
# Usage:
#   repo-readme.sh <owner/name> [--max-chars N]
#
# Exits non-zero with a clear message if the README isn't found.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: repo-readme.sh <owner/name> [--max-chars N]" >&2
  exit 2
fi

REPO="$1"; shift
MAX_CHARS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-chars) MAX_CHARS="$2"; shift 2 ;;
    -h|--help)   sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

if ! out=$(gh api "repos/$REPO/readme" -H "Accept: application/vnd.github.raw" 2>&1); then
  echo "Could not fetch README for $REPO: $out" >&2
  exit 1
fi

if [[ -n "$MAX_CHARS" ]]; then
  printf '%s' "$out" | head -c "$MAX_CHARS"
  if (( ${#out} > MAX_CHARS )); then
    printf '\n\n[...truncated, %d of %d chars shown]\n' "$MAX_CHARS" "${#out}"
  fi
else
  printf '%s\n' "$out"
fi
