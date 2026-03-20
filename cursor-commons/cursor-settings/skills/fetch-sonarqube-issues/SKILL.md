---
name: fetch-sonarqube-issues
description: "Fetch open SonarQube issues from the SonarQube instance using the official CLI. Centralised preflight (token, CLI, auth) and AI-optimised output via --format toon."
disable-model-invocation: false
---

Retrieves open issues from a SonarQube project using the official SonarQube CLI (`sonar`). The `--format toon` output is specifically designed for AI agent consumption.


> **Note:** The SonarQube CLI is currently in Beta.

---

## Preflight — Run This Before Any Issue Fetch

Execute all three checks in order. Do not skip any. Do not proceed to issue fetching until all three pass.

### 1. Check the API Token

Run `echo $SONARQUBE_TOKEN` (Unix / macOS) or `echo $env:SONARQUBE_TOKEN` (PowerShell) to check if the token is set.

If it is empty or unset, **stop and ask the user to provide their SonarQube token**, explaining where to get it:

> Generate a user token from sonarqube → User menu → My Account → Security → Generate Token.
> Once you have it, paste it here and I will set it up for this session.

Once the user provides the token value, **offer to run** the export command on their behalf:

Unix / macOS — offer to run:
```bash
export SONARQUBE_TOKEN=<token_provided_by_user>
```

PowerShell — offer to run:
```powershell
$env:SONARQUBE_TOKEN = "<token_provided_by_user>"
```

Also advise the user to add it to their shell profile (`~/.zshrc`, `~/.bashrc`, or PowerShell `$PROFILE`) so it persists across sessions.

### 2. Check CLI Installation

Run `sonar --version`. If the command is not found, **offer to install it automatically** by running the platform-appropriate command:

**macOS / Linux** — offer to run:
```bash
curl -o- https://raw.githubusercontent.com/SonarSource/sonarqube-cli/refs/heads/master/user-scripts/install.sh | bash
```

**Windows (PowerShell)** — offer to run:
```powershell
irm https://raw.githubusercontent.com/SonarSource/sonarqube-cli/refs/heads/master/user-scripts/install.ps1 | iex
```

After running the install, verify with `sonar --version` and confirm success to the user before continuing.

### 3. Check Authentication

Run `sonar auth status`. If the CLI is not authenticated against sonarqube, **offer to run the login command** automatically:

Unix / macOS — offer to run:
```bash
sonar auth login -s sonarqube --with-token $SONARQUBE_TOKEN
```

PowerShell — offer to run:
```powershell
sonar auth login -s sonarqube --with-token $env:SONARQUBE_TOKEN
```

After login, re-run `sonar auth status` and confirm the connection is live before proceeding.

---

## Resolve the Project Key

The SonarQube project key is distinct from the project display name. Resolve it using this sequence — stop at the first match:

1. **Scan config files** in the current repository (use the Read/Grep tools, not shell commands):
   - `sonar-project.properties` → value of `sonar.projectKey`
   - `pom.xml` → `<properties><sonar.projectKey>` value, or fall back to `<artifactId>`
   - `build.gradle` / `build.gradle.kts` → `property "sonar.projectKey", "<value>"`
   - `.sonarcloud.properties` → `sonar.projectKey`

2. **Search SonarQube by repo name** if no config file match is found:
   - Infer the repo name from the git remote: `git remote get-url origin` → extract the last path segment without `.git` (e.g. `my-service`)
   - Run: `sonar list projects -q <repo_name>`
   - If exactly one project is returned, use its key.
   - If multiple are returned, present them to the user and ask them to confirm the correct one.

3. **Ask the user** if both of the above fail to find an unambiguous match.

---

## Fetch Issues

### List mode (default — top N issues by severity)

```bash
sonar list issues -p <project_key> --severity BLOCKER,HIGH,MEDIUM --format toon --page-size <N>
```

- Default `N` is **5** unless the caller specifies otherwise.
- Add `--branch <branch_name>` if a specific branch is requested.
- Use `--format toon` output directly — it is optimised for AI agent consumption.

### Single issue mode (caller provides a specific issue ID)

The CLI does not support filtering by issue key. Use `curl` for this case only:

Unix / macOS:
```bash
curl -s -u "$SONARQUBE_TOKEN:" "https://sonarqube.tc.<company>.com/api/issues/search?issues=<issue_id>"
```

PowerShell:
```powershell
curl.exe -s -u "${env:SONARQUBE_TOKEN}:" "https://sonarqube.tc.<company>.com/api/issues/search?issues=<issue_id>"
```

Also fetch the rule description for the issue:

```bash
curl -s -u "$SONARQUBE_TOKEN:" "https://sonarqube.tc.<company>.com/api/rules/show?key=<rule_key>"
```

From the rule response, prefer `descriptionSections` (SonarQube 10.x): extract `root_cause` and `how_to_fix` entries as plain text. Fall back to `htmlDesc` / `mdDesc` and strip HTML tags.

---

## Severity Reference

| Severity | Rank | Legacy alias |
|---|---|---|
| BLOCKER | 1 (highest) | BLOCKER |
| HIGH | 2 | CRITICAL |
| MEDIUM | 3 | MAJOR |
| LOW | 4 | MINOR |
| INFO | 5 (lowest) | INFO |

Normalise all legacy severity labels to their modern equivalents before presenting results.

---

## Error Handling

| Symptom | Likely cause | Action |
|---|---|---|
| `SONARQUBE_TOKEN` is empty | Token not configured | Ask user for token, offer to export it for the session |
| `sonar: command not found` | CLI not installed | Offer to run the platform install command |
| `Not authenticated` from `sonar auth status` | Token not in keychain | Offer to run `sonar auth login` |
| `HTTP 401` from curl fallback | Bad or expired token | Ask user to regenerate token, offer to re-run auth login |
| `HTTP 404` from curl fallback | Wrong project key | Stop — re-run project key resolution |
| Empty issue list | No open issues at configured severity | Inform user — no fixes needed |

Always surface the raw error to the user before stopping.
