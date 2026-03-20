---
description: "End-to-end SonarQube fix: fetch issues by severity, analyze, fix, test, commit per issue, and raise one PR for all fixes—with gatekeepers before code change and before PR."
---

> **Prerequisite:** The `fetch-sonarqube-issues` skill must be available. It handles CLI installation, authentication, and token validation.

# Fix SonarQube Issues Command

When the user says **"Fix sonarqube"** or **"Fix sonarqube {ISSUE_ID}"**:

---

## 1. Preflight

Run the **full preflight sequence from the `fetch-sonarqube-issues` skill** (token check → CLI check → auth check). Do not proceed until all three pass.

Then resolve the **project key** using the lookup sequence in the same skill.

---

## 2. Workspace Sync

- **Detect default branch:** Run `git rev-parse --abbrev-ref origin/HEAD` and strip the `origin/` prefix. Fall back to checking `main`, `master`, `develop` if the command fails.
- **Check for local changes:** Run `git status --porcelain`. If uncommitted or unstaged changes exist, **stop immediately** and ask the developer to choose:
  - **Stash** the changes and continue (`git stash`).
  - **Commit** to the current branch before switching.
  - **Abort** the workflow.
- **Sync:** Once the working tree is clean, checkout the default branch and pull latest.
- **Create branch:** Create and checkout a single branch for this entire run:
  `fix/sonarqube-{YYYYMMDD}` (e.g. `fix/sonarqube-20260313`).
  All per-issue commits land on this one branch.

---

## 3. Fetch Issues

- **If an issue ID was provided:** Use the `fetch-sonarqube-issues` skill in `single` mode for that issue only.
- **If no issue ID was provided:** Use the `fetch-sonarqube-issues` skill in `list` mode. Fetch a maximum of **5 issues** ordered by severity (BLOCKER first). Do not fetch more unless the user explicitly asks.

Display the fetched issue(s) as a summary table:

| # | ID | Severity | Type | File | Line | Message |
|---|---|---|---|---|---|---|

**Gatekeeper: YOU MUST STOP HERE.** Await explicit user confirmation. The user may deselect specific issues. Only proceed with approved issues.

---

## 4. Per-Issue Fix Loop

Process each approved issue **sequentially**.

### 4a. Triage & Analysis

- Locate the exact file and line(s) in the codebase.
- Read the `rule_description` returned by the skill to understand the SonarQube rule intent — do not infer meaning from the issue message alone.
- Produce a structured analysis:
  - **Root Cause:** Why this code violates the rule.
  - **Proposed Fix:** The precise code change needed.
  - **Confidence:** HIGH / MEDIUM / LOW.
  - **Side Effects:** Any downstream impact.

**Confidence Gate:**
- **HIGH confidence:** Proceed to 4b.
- **MEDIUM or LOW confidence:** Do NOT attempt a fix. Present the analysis and ask the user how to proceed (provide a hint, skip, or mark for manual review). Never guess a fix.

### 4b. Implementation

- Apply the fix strictly per the SonarQube rule description and Secure Coding Standards (OWASP Top 10, input sanitisation).
- Fix **only** the reported issue. Do not refactor unrelated code in the same change.
- Follow all active workspace rules.

### 4c. Tests

- Update existing tests or write new unit/integration tests that directly exercise the fixed code path.
- **Tests are mandatory.** A fix without a test must not be committed.
- Line coverage for the modified file must remain above 80%.

### 4d. Validation

- Detect the project's build system by inspecting `pom.xml`, `build.gradle`, `package.json`, `pyproject.toml`.
- Run tests using the project's native command:
  - Maven: `mvn clean test`
  - Gradle: `gradle test`
  - Python: `pytest`
  - Node: `npm test`
- **Zero-Failure Policy:** If any test fails, halt. Diagnose and fix before proceeding. No commits on a red build.

### 4e. Commit

- Stage **only** the files modified for this specific issue.
- Commit message format: `fix(sonarqube): [{SEVERITY}] {rule} - {short description} ({issue_id})`
  - Example: `fix(sonarqube): [HIGH] java:S2077 - parameterize SQL query (AY1234)`

**Critical Rule: Never commit without passing tests.**

---

## 5. Code Review

- After all per-issue commits are complete, use the **review-pr** skill to review the full diff of the fix branch against the default branch.
- Address any Blocker or High findings before raising the PR.
- **Gatekeeper: YOU MUST STOP HERE.** Await explicit user confirmation before creating the PR.

---

## 6. Pull Request

- Push the branch to the configured remote.
- Create a **single PR** for all issue commits with:
  - **Title:** `fix(sonarqube): resolve {N} issue(s) [{highest severity}]`
  - **Body:**
    - Summary table: ID, severity, rule, file, one-line fix description.
    - Issues skipped (low confidence) with reason.
    - Test execution result (pass/fail count).
  - **Tone:** Professional, concise, no emoticons.
