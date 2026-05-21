---
name: gh-explore
description: Use when the user asks a question about their GitHub repositories — finding repos, understanding what a repo is about, checking PRs/issues/commits, comparing repos, or any "which of my repos..." style query. Scans repos via the `gh` CLI with tiered data fetching to minimize context.
---

# gh-explore

Answer natural-language questions about the user's GitHub repos by running `gh` CLI commands on demand. Pull the minimum data needed: locate repos via metadata first, fetch READMEs only when context is needed, and only run PR/issue/code/commit queries when the question explicitly calls for them.

## Scope

All repos the authenticated `gh` user can see: owned + organization + collaborator.

## Preflight

Before the first data call in a session:

1. Run `gh auth status`.
2. If not authenticated, run `gh auth login` directly. It is interactive (device flow / browser) — relay the prompts to the user and wait for completion. Then resume.
3. If `gh` is not installed at all, tell the user to install GitHub CLI and stop.

## Data Tiers

Tiers are building blocks, not a strict ladder. Use each tier when the question requires it; minimize **within** each tier by filtering and shortlisting.

### Tier 1 — Metadata (almost always)

Run `${CLAUDE_PLUGIN_ROOT}/skills/gh-explore/scripts/list-repos.sh` to get a compact pipe-delimited table of repos: `name | owner | lang | updated | stars | description`.

Use flags to narrow server-side / output-side:
- `--lang <name>` — primary language contains
- `--name-contains <str>` — repo name contains
- `--updated-since <YYYY-MM-DD>`
- `--owner <user-or-org>` — limit to a specific owner
- `--limit <N>` — default 1000

Reuse Tier 1 output across follow-up questions in the same conversation — do not re-list 1000 repos for each question.

### Tier 2 — READMEs (when content/context needed)

For each shortlisted repo (≤5), run `${CLAUDE_PLUGIN_ROOT}/skills/gh-explore/scripts/repo-readme.sh <owner/name> --max-chars 4000`. Use this when:
- The question is about what a repo *is* or *does*
- Multiple repos match by name and you need to disambiguate
- You need grounding before reporting on PRs/issues

### Tier 3 — Code / Issues / PRs / Commits (when explicitly asked)

Use inline `gh` calls, scoped to the shortlisted repo(s):

- PRs: `gh pr list --repo <owner>/<name> --state <open|closed|all> --json number,title,state,author,updatedAt,url --limit 50`
- Issues: `gh issue list --repo <owner>/<name> --state <open|closed|all> --json number,title,state,author,updatedAt,url --limit 50`
- Code search: `gh search code --owner <owner> '<query>' --json repository,path,textMatches --limit 30`
- Recent commits: `gh api repos/<owner>/<name>/commits?per_page=20 --jq '.[] | "\(.sha[0:7]) | \(.commit.author.date[0:10]) | \(.commit.message | split("\n")[0])"'`

## Procedure

For every question:

1. **Parse the question.** Identify: specific repo (named or implied)? category (language, topic, recency)? what data type — metadata, content, PRs/issues/code?
2. **Tier 1.** Run `${CLAUDE_PLUGIN_ROOT}/skills/gh-explore/scripts/list-repos.sh` with the most specific filters that match the question. Reuse prior Tier 1 output when answering follow-ups.
3. **Shortlist** — ≤5 candidate repos by name match, language, topic, or recency.
4. **Tier 2 if needed.** Fetch READMEs only for the shortlist.
5. **Tier 3 if needed.** Run the targeted `gh` call(s) on the shortlist.
6. **Answer.** Cite repo names and full URLs (`https://github.com/<owner>/<name>`). Be explicit about what was checked: if PRs weren't queried, don't claim "no PRs" — say "PRs not checked." If a repo was missed in Tier 1, the user can re-run with a broader filter.

## Examples

**Q: "Which of my repos use Rust?"**
→ Tier 1 with `--lang rust`. Answer with the table. No Tier 2/3.

**Q: "What is keeptradecache about?"**
→ Tier 1 with `--name-contains keeptradecache` to locate it. Tier 2 README fetch. Summarize.

**Q: "Any open PRs in keeptradecache?"**
→ Tier 1 to locate. Tier 2 README for brief context. Tier 3 `gh pr list --state open`. Report.

**Q: "Which repo had my auth experiment?"**
→ Tier 1 (full list, or `--name-contains auth`). Tier 2 READMEs on the top candidates. Identify and answer.

## Error Handling

- `gh` not installed → tell user, stop.
- `gh auth login` fails → report the error and stop.
- Repo not found → report what was searched and the closest matches from Tier 1.
- API rate limit → report it. Tier 1 reuse across follow-ups should make this rare.

## Non-Goals

- No write operations (no creating issues/PRs/repos).
- No persistent cache across sessions — Tier 1 reuse is conversation-scoped only.
