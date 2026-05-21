#!/usr/bin/env bash
# List GitHub repos accessible to the authenticated user, in compact pipe-delimited form.
#
# Output format (one repo per line):
#   name | owner | lang | updated | stars | description
#
# Flags:
#   --lang <name>           Filter by primary language (case-insensitive contains)
#   --name-contains <str>   Filter by substring of repo name (case-insensitive)
#   --updated-since <date>  Filter to repos updated on/after YYYY-MM-DD
#   --owner <user-or-org>   Only list repos for this owner (default: all accessible)
#   --limit <N>             Max repos to request from GitHub (default: 1000)
#   -h, --help              Show this help

set -euo pipefail

LANG_FILTER=""
NAME_FILTER=""
UPDATED_SINCE=""
OWNER=""
LIMIT=1000

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lang)            LANG_FILTER="$2"; shift 2 ;;
    --name-contains)   NAME_FILTER="$2"; shift 2 ;;
    --updated-since)   UPDATED_SINCE="$2"; shift 2 ;;
    --owner)           OWNER="$2"; shift 2 ;;
    --limit)           LIMIT="$2"; shift 2 ;;
    -h|--help)         sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

# gh's --jq filter: emit one pipe-delimited line per repo, no client-side filtering here.
# Description is collapsed to single-line and truncated to 100 chars.
JQ_FILTER='.[] | [
  .name,
  .owner.login,
  (.primaryLanguage.name // "-"),
  (.updatedAt | .[0:10]),
  (.stargazerCount | tostring),
  ((.description // "") | gsub("\\s+"; " ") | .[0:100])
] | join(" | ")'

gh_args=(repo list --limit "$LIMIT" --json name,owner,primaryLanguage,updatedAt,stargazerCount,description --jq "$JQ_FILTER")
if [[ -n "$OWNER" ]]; then
  # gh repo list takes owner as a positional arg before flags
  gh_args=(repo list "$OWNER" --limit "$LIMIT" --json name,owner,primaryLanguage,updatedAt,stargazerCount,description --jq "$JQ_FILTER")
fi

# Apply filters with awk on the compact output. Field separator: " | "
lc_lang=$(printf '%s' "$LANG_FILTER" | tr '[:upper:]' '[:lower:]')
lc_name=$(printf '%s' "$NAME_FILTER" | tr '[:upper:]' '[:lower:]')

gh "${gh_args[@]}" | awk -F ' \\| ' \
  -v lang="$lc_lang" -v name="$lc_name" -v since="$UPDATED_SINCE" '
  {
    name_lc = tolower($1)
    lang_lc = tolower($3)
    updated = $4
    if (lang != "" && index(lang_lc, lang) == 0) next
    if (name != "" && index(name_lc, name) == 0) next
    if (since != "" && updated < since) next
    print
  }
'
