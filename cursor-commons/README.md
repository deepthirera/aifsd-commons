# Cursor Commons

A shared Cursor IDE configuration for teams. Includes custom commands and rules to standardize PR prep, onboarding, and code refactoring across projects.

## Table of Contents

- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Basic Installation](#basic-installation)
  - [Manual Inspection](#manual-inspection)
- [Using Cursor Commons](#using-cursor-commons)
  - [Commands](#commands)
  - [Rules](#rules)
  - [MCP Servers](#mcp-servers)
- [Updates](#updates)
  - [Update Behavior](#update-behavior)
  - [Manual Update](#manual-update)
  - [Disable Update Check](#disable-update-check)
- [Advanced Topics](#advanced-topics)
  - [Custom Directory](#custom-directory)
  - [Unattended Install](#unattended-install)
  - [Custom Repository](#custom-repository)
- [Uninstalling](#uninstalling)

## Getting Started

### Prerequisites

- **Node.js** v16 or higher (replaces the previous curl/wget requirement)
- **git** (v2.4.11 or higher recommended)

### Basic Installation

Cursor Commons is installed by running the following command in your terminal (macOS, Linux, or Windows):

```bash
npx --yes github:adinath/aifsd-commons
```

_Note: Any existing `~/.cursor` will be backed up to `~/.cursor.pre-cursor-commons`. After installation, you can merge any customizations you want to keep into the new `~/.cursor`._

#### Manual Inspection

It's a good idea to inspect the install script before running it. Clone the repository and run the script locally:

```bash
git clone https://github.com/adinath/aifsd-commons.git
# Review cursor-commons/tools/install.js
node aifsd-commons/cursor-commons/tools/install.js
```

## Using Cursor Commons

### Commands

Cursor Commons provides custom Cursor commands in `~/.cursor/commands/`:

| Command            | Description                                                                 |
| ------------------ | --------------------------------------------------------------------------- |
| **pr-prep**       | Prepare for peer review: review branch changes, generate PR title (Conventional Commits), summary, test plan, risk assessment, and check for leftover `console.log` / `System.out.println` |
| **onboard**       | Generate a "New Hire Welcome Guide" with architecture overview, key directories, data flow, dependent repos, and setup steps |
| **leancode-refactor** | Refactor and tidy code: remove redundant comments, fix code smells, enforce DRY, guard clauses, formatting, and anti-hallucination checks |

### Rules

Custom rules can be placed in `~/.cursor/rules/` to enforce team conventions across projects.

### MCP Servers

The **sequential-thinking** server runs locally via `npx` and does not require any environment variables.

## Updates

### Update Behavior

By default, Cursor Commons checks for updates every **14 days** when you start a new shell. If a newer version is available (based on the `MANIFEST` version), you'll see a message like:

```
[cursor-commons] A new version is available!
  Local:  1.0.0
  Remote: 1.1.0
  Run cursor-commons-update to upgrade.
```

### Manual Update

To update at any time:

```bash
cursor-commons-update
```

Or run the upgrade directly with npx:

```bash
npx --yes github:adinath/aifsd-commons --upgrade
```

### Disable Update Check

Add this to your `~/.bashrc` or `~/.zshrc` **before** the Cursor Commons hook:

```bash
export CURSOR_COMMONS_UPDATE_DISABLED=1
```

To change the check frequency (in days):

```bash
export CURSOR_COMMONS_UPDATE_DAYS=7
```

## Advanced Topics

### Custom Directory

By default, Cursor Commons is installed to `~/.cursor-commons`. To use a different location:

```bash
CURSOR_COMMONS_HOME="$HOME/.dotfiles/cursor-commons" npx --yes github:adinath/aifsd-commons
```

### Unattended Install

For automated or non-interactive installation:

```bash
npx --yes github:adinath/aifsd-commons --unattended
```

### Custom Repository

To install from a fork or different branch:

```bash
REMOTE=https://github.com/your-org/cursor-commons.git BRANCH=main npx --yes github:adinath/aifsd-commons
```

## Uninstalling

To uninstall Cursor Commons:

1. Remove the hook block from your `~/.bashrc` or `~/.zshrc` (search for "Cursor Commons").
2. Remove the installation directory:
   ```bash
   rm -rf ~/.cursor-commons
   ```
3. Optionally restore your previous `.cursor`:
   ```bash
   rm -rf ~/.cursor
   mv ~/.cursor.pre-cursor-commons ~/.cursor
   ```
