---
name: review-pr
description: "Expert code review skill. Supports two modes: (1) Bitbucket PR review via the bitbucket MCP server, and (2) local diff review of uncommitted/staged changes before a commit."
disable-model-invocation: false
---

## PHASE 0 — MODE DETECTION

Determine the review mode from what the user provided:

| Signal | Mode |
|---|---|
| A Bitbucket PR URL (contains `/pull-requests/`) | **Bitbucket PR** |
| Phrases like "review my local changes", "before I commit", "staged changes", "working tree" | **Local Diff** |
| Ambiguous | Ask: "Should I review a Bitbucket PR (share the URL) or your local uncommitted changes?" |

---

## MODE A — BITBUCKET PR

### A0: Preflight
Call `getProjects` (server: `bitbucket`) with no arguments.
- Success → proceed.
- Error → stop and output:

> The `bitbucket` MCP server is not reachable.
> Add the Bitbucket MCP server in Cursor → Settings → MCP (server identifier: `bitbucket`), restart Cursor, and retry.

### A1: Parse the PR URL
Pattern: `https://<host>/projects/<PROJECT_KEY>/repos/<repo-slug>/pull-requests/<ID>/...`

| Variable | Source | Example |
|---|---|---|
| `projectKey` | `/projects/<X>/` | `LCP` |
| `repositorySlug` | `/repos/<X>/` | `lcp-core-application-management-service` |
| `pullRequestId` | `/pull-requests/<X>/` | `986` |

### A2: Fetch PR metadata
Call `getPage` (server: `bitbucket`):
```
projectKey:     <parsed>
repositorySlug: <parsed>
state:          ALL
limit:          10
```
> Note: each page is large (~60 KB for 10 results). Parse only the fields you need and discard the rest immediately.

Paginate (increment `start` by 10) until the item with `id == pullRequestId` is found.
**Stop immediately** once located.

Record: `title`, `description`, `fromRef.displayId`, `fromRef.latestCommit`, `toRef.displayId`, `toRef.latestCommit`, `author.user.displayName`, reviewer names.

### A3: Fetch all diffs in one call
Call `streamDiff_1` (server: `bitbucket`) **with `path` set to empty string** — this returns the complete diff for every changed file in a single response:
```
projectKey:     <parsed>
repositorySlug: <parsed>
path:           ""
from:           <fromRef.latestCommit>
to:             <toRef.latestCommit>
contextLines:   3
```

> Do NOT call `streamChanges` — it has a known output-schema validation bug (fails when `nextPageStart` is null on the last page).
> Do NOT loop `streamDiff_1` per file — one call with `path=""` returns everything more efficiently.

From the response, extract the list of changed files (`diffs[].destination.toString` or `diffs[].source.toString`) and the full diff hunks.

**Skip during analysis** (do not review): binary files, lock files (`*.lock`, `package-lock.json`, `yarn.lock`, `go.sum`, `Podfile.lock`), generated files (`*_gen.*`, `*.generated.*`, `*.pb.go`, `*.pb.ts`), pure DELETE changes.

**Cap**: If the response contains more than **25 files**, prioritise for review: source code → behaviour-affecting config → test files paired with changed source. Note the remainder as not reviewed.

**Line guard**: If the total diff lines across all files exceeds **10,000**, note which files were not fully analysed.

### A4: Fetch existing PR comments
Call `getReview` (server: `bitbucket`):
```
projectKey:     <parsed>
repositorySlug: <parsed>
pullRequestId:  <pullRequestId>
```
Use returned threads to avoid re-raising already-discussed issues.

---

## MODE B — LOCAL DIFF

### B1: Determine scope
Ask the user (or infer from context) which changes to review:

| User intent | Command to run |
|---|---|
| Staged changes only (what will be committed) | `git diff --staged` |
| All local changes (staged + unstaged) | `git diff HEAD` |
| Specific branch comparison | `git diff <base>...<head>` |

Default to `git diff HEAD` if unspecified.

### B2: Get the file list and line counts
Run: `git diff --stat <scope>`

If total changed lines exceed **10,000** or files exceed **25**, tell the user:
> "This diff is large. I'll review the first 25 files up to 10,000 lines. Consider breaking the change into smaller commits."

**Skip**: binary files, lock files, generated files, pure deletions.

### B3: Fetch diffs
Run: `git diff -U3 <scope> -- <file>` for each file in the prioritised list (same 25-file, 10,000-line caps).

### B4: Capture additional context (optional)
If a finding requires verifying surrounding code not visible in the diff, run `git show HEAD:<file path>`.
Fetch only the relevant section — do not load entire files.

---

## PHASE 1 — REVIEW ANALYSIS (shared by both modes)

Apply these rules to all collected diffs. The diff hunks are the primary source of truth.
Do NOT fetch additional content unless a specific finding requires confirmation.

### What to flag (high-signal only)
- Correctness bugs / broken logic
- Security vulnerabilities (auth bypass, injection, secrets in code, unsafe deserialization)
- Data loss, privacy risk, permission escalation
- Reliability issues (timeouts, retries, race conditions, resource leaks)
- Performance regressions that are clearly material (N+1, unbounded loops, O(n²) on hot paths)
- Breaking API or contract changes (backward incompatibility)
- Test gaps when a critical-path change has zero test coverage
- Maintainability issues that create real divergence risk (duplicated logic, hidden coupling)

### What NOT to flag
- Formatting, lint, minor refactors, "prefer X over Y" without concrete impact
- Speculative issues ("might be slow") without evidence in the diff
- Broad rewrites; keep suggestions minimal and scoped to the diff

### High-rigor verification protocol
Before raising any finding:
1. **Trace the data flow** — follow the actual path through all changed functions, not just the touched lines.
2. **Verify with concrete examples** — walk through 2–3 specific input values to confirm the bug path.
3. **Check coverage** — if a test file in the diff covers the scenario, do not flag it.
4. **Prove it** — record the exact trigger input, execution trace, and expected vs. actual outcome.
5. **Disprove it** — actively try to find evidence the code is correct before including the finding.
6. **No findings is valid** — an empty table is better than noise.

Only report findings you would stake your reputation on (≥80% confidence after analysis).

---

## PHASE 2 — OUTPUT (shared by both modes)

### Summary header
```
Mode:    Bitbucket PR  |  Local Diff
PR/Ref:  <title or git ref>
Branch:  <source> → <target>   (Bitbucket mode only)
Author:  <author>               (Bitbucket mode only)
Files:   <N reviewed> of <total changed> (skipped: <reason if any>)
```

### Findings table
| Finding ID | Severity | Confidence | Category | File | Line(s) | Issue | Evidence (snippet, ≤12 lines) | Fix suggestion | Risk if unfixed | Effort |
|---|---|---|---|---|---|---|---|---|---|---|

**Severity scale**:
- `Blocker` — will likely break prod / security issue / data loss
- `High` — probable bug or major reliability risk
- `Medium` — plausible bug or meaningful maintainability risk
- `Low` — small issue with clear value (only if genuinely helpful)

Include `Confidence`: High / Medium / Low. Omit findings with Low confidence unless Severity is Blocker or High.

### After the table
1. **Top 3 priorities** — only when Blocker/High items exist.
2. **Suggested tests** — only when it materially reduces risk.
3. **Not reviewed** — list files skipped by cap or skip rules so the author knows coverage gaps.
4. **Non-issues intentionally ignored** — 1–5 bullets explaining what was examined and deliberately excluded.

### Posting findings (Bitbucket PR mode only)
If the user asks to post findings as PR comments, call `createComment` (server: `bitbucket`) for each Blocker/High finding.
Do not post Medium/Low findings as comments unless explicitly requested.
