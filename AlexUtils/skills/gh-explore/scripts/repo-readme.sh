#!/usr/bin/env bash
# Fetch a repo's README as raw markdown, optionally truncating.
# If the repo has no README, fall back to a compact metadata summary
# (description, homepage, topics, language) so callers always get usable context.
#
# Usage:
#   repo-readme.sh <owner/name> [--max-chars N]

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
    -h|--help)   sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

emit() {
  local content="$1"
  if [[ -n "$MAX_CHARS" ]]; then
    printf '%s' "$content" | head -c "$MAX_CHARS"
    if (( ${#content} > MAX_CHARS )); then
      printf '\n\n[...truncated, %d of %d chars shown]\n' "$MAX_CHARS" "${#content}"
    else
      printf '\n'
    fi
  else
    printf '%s\n' "$content"
  fi
}

# Try README first
if out=$(gh api "repos/$REPO/readme" -H "Accept: application/vnd.github.raw" 2>/dev/null); then
  emit "$out"
  exit 0
fi

# Fall back to repo metadata
META_JQ='[
  "# " + .name,
  "",
  "_No README found. Showing repo metadata:_",
  "",
  "- Description: " + (.description // "(none)"),
  "- Homepage: " + (.homepage // "(none)"),
  "- Language: " + (.language // "(none)"),
  "- Topics: " + ((.topics // []) | join(", ") | if . == "" then "(none)" else . end),
  "- Visibility: " + (if .private then "private" else "public" end),
  "- Default branch: " + .default_branch,
  "- Created: " + (.created_at | .[0:10]),
  "- Last pushed: " + (.pushed_at | .[0:10]),
  "- Stars: " + (.stargazers_count | tostring),
  "- Open issues: " + (.open_issues_count | tostring)
] | join("\n")'

if meta=$(gh api "repos/$REPO" --jq "$META_JQ" 2>/dev/null); then
  emit "$meta"
  exit 0
fi

echo "Could not fetch README or metadata for $REPO" >&2
exit 1
