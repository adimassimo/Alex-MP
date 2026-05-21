# gh-explore Skill — Design

**Date:** 2026-05-20
**Plugin:** AlexUtils (renamed from `plugin1`)
**Skill:** `gh-explore`

## Purpose

Let the user ask natural-language questions about their GitHub repos and get grounded answers. The skill is a procedural playbook Claude follows: it identifies what tier(s) of data are needed, runs the minimum `gh` CLI calls required, and answers from the fetched data.

## Repository Scope

All repos the authenticated `gh` user can see: owned + organization + collaborator. Listed via `gh repo list <user> --limit 1000` against the authenticated identity (plus org repos via `gh repo list <org>` when an org is referenced or needed).

## Data Tiers

The skill defines three tiers that act as building blocks. Tiers are not strictly hierarchical "stop early" rungs — they are tools applied to the question as needed. Each tier minimizes work by fetching only for a narrowed shortlist.

### Tier 1 — Metadata
- **Call:** `scripts/list-repos.sh` (wraps `gh repo list --json ... --jq ...`) — emits one compact line per repo: `name | owner | lang | updated | stars | description`.
- **Filter flags:** `--lang <name>`, `--name-contains <substr>`, `--updated-since <YYYY-MM-DD>`, `--owner <user-or-org>`, `--limit <N>` (default 1000). Claude passes flags to narrow server-side instead of pulling all repos into context.
- **Used for:** locating repos by name/language/topic/recency; almost every question starts here.

### Tier 2 — READMEs
- **Call (per shortlisted repo):** `scripts/repo-readme.sh <owner/name> [--max-chars N]` — wraps `gh api repos/{owner}/{name}/readme -H "Accept: application/vnd.github.raw"` and truncates output.
- **Used for:** confirming what a repo is, disambiguating similarly-named repos, answering questions about purpose/content.
- **Minimization:** only fetch for the ≤5 candidate repos identified in Tier 1, never the full list.

### Tier 3 — Code / Issues / PRs / Commits
- **Inline `gh` calls (no wrapper scripts — output is already small and varies per question):**
  - `gh pr list --repo {owner}/{name} --json number,title,state,author,updatedAt,url`
  - `gh issue list --repo {owner}/{name} --json number,title,state,author,updatedAt,url`
  - `gh search code --owner {owner} '<query>'`
  - `gh api repos/{owner}/{name}/commits` (recent commits)
- **Used for:** questions explicitly about PRs, issues, code, or commits.
- **Minimization:** scoped to the shortlist from Tier 1/2, never run blindly across all repos.

## Skill Flow

The `SKILL.md` instructs Claude to:

1. **Preflight auth.** Run `gh auth status`. If not authenticated, run `gh auth login` and relay the interactive prompts (device flow / browser) to the user. Resume once auth completes.
2. **Parse the question.** Identify the subject (specific repo? category of repos? content type?) and which tiers will likely be needed.
3. **Tier 1 always.** Run the metadata query. Cache the resulting JSON in the conversation for the session — do not re-list for follow-up questions.
4. **Narrow to a shortlist** (≤5 repos) by matching name, topics, language, or recency from Tier 1 results.
5. **Tier 2 when needed.** Fetch READMEs for the shortlist when the question is about purpose/content or when name-only identification is ambiguous.
6. **Tier 3 when needed.** Run the targeted `gh` call(s) on the shortlist when the question explicitly requires PRs, issues, code, or commit data.
7. **Answer.** Cite repo names and link with `https://github.com/{owner}/{name}`. Be explicit about what was checked vs. not checked — if Tier 3 wasn't consulted, do not claim "no PRs exist," say "PRs not checked."

### Example Walkthrough

User: *"Any open PRs in my keeptradecache repo?"*

1. Preflight: `gh auth status` — OK.
2. Parse: specific repo (`keeptradecache`), question about PRs → tiers 1+2+3.
3. Tier 1: list repos, locate `keeptradecache`.
4. Tier 2: fetch README to ground context about what the repo is.
5. Tier 3: `gh pr list --repo <owner>/keeptradecache --state open --json ...`.
6. Answer with repo summary + PR list (or "none open"), linked.

## Error Handling

- **`gh` not installed:** tell user to install GitHub CLI, stop.
- **Auth fails after `gh auth login`:** report the error and stop.
- **Repo not found:** report what was searched and the closest name matches from Tier 1.
- **API rate limit:** report it; the session-cached Tier 1 JSON should make this rare.

## Helper Scripts

Thin bash wrappers around `gh` to (a) compact output for context efficiency and (b) accept filter flags so Claude narrows server-side.

- **`AlexUtils/skills/gh-explore/scripts/list-repos.sh`** — Tier 1 wrapper. Uses `gh repo list --json ... --jq` for formatting. Supports filter flags listed above. Output: one repo per line, pipe-delimited.
- **`AlexUtils/skills/gh-explore/scripts/repo-readme.sh`** — Tier 2 wrapper. Fetches raw README, optionally truncates to `--max-chars`.

Both rely only on `gh` (no `jq`, no python). Skill preflight checks that `gh` is installed and authenticated.

## Non-Goals

- No daemons or persistent state.
- No persistent cache across sessions — Tier 1 results are conversation-scoped only.
- No write operations — read-only exploration.

## Plugin Restructuring

As part of this work:

- Rename directory `plugin1/` → `AlexUtils/`.
- Update `.claude-plugin/marketplace.json`: replace the `plugin1` entry with `AlexUtils` (name, description, source path).
- Update `AlexUtils/.claude-plugin/plugin.json`: set `name: "AlexUtils"` and a fitting description.
- Remove `AlexUtils/skills/.gitkeep` once `gh-explore/SKILL.md` exists.

`plugin2` is left untouched.

## Deliverables

- `AlexUtils/skills/gh-explore/SKILL.md` — the procedural playbook described above, formatted as a Claude Code skill with frontmatter (`name`, `description` triggering on GitHub repo questions).
- `AlexUtils/skills/gh-explore/scripts/list-repos.sh` and `repo-readme.sh` — bash helper scripts.
- Updated `marketplace.json` and `AlexUtils/.claude-plugin/plugin.json`.
