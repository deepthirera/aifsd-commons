#Requires -Version 5.1
<#
.SYNOPSIS
    Cursor Commons installation script for Windows (PowerShell).

.DESCRIPTION
    Installs Cursor Commons by cloning the repo to CURSOR_COMMONS_HOME,
    copies cursor-settings into $HOME\.cursor, and registers an auto-upgrade
    hook in the PowerShell profile.

    Run via (PowerShell 5.1+):
        irm https://github.com/adinath/aifsd-commons/raw/cursor-commons/tools/install.ps1?at=refs%2Fheads%2Fdevelop | iex

.PARAMETER Unattended
    Non-interactive install; skips all prompts.

.NOTES
    Environment variables (set before running to override defaults):
      CURSOR_COMMONS_HOME  - install directory       (default: $HOME\.cursor-commons)
      REMOTE               - git remote URL          (default: your bitbucket)
      BRANCH               - branch to checkout      (default: develop)
#>
[CmdletBinding()]
param(
    [switch]$Unattended
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Defaults (honour env overrides)
# ---------------------------------------------------------------------------
$CursorCommonsHome = if ($env:CURSOR_COMMONS_HOME) { $env:CURSOR_COMMONS_HOME } `
                     else { Join-Path $HOME '.cursor-commons' }
$Remote = if ($env:REMOTE) { $env:REMOTE } `
          else { 'https://github.com/adinath/aifsd-commons.git' }
$Branch = if ($env:BRANCH) { $env:BRANCH } else { 'develop' }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Info { param([string]$Msg) Write-Host $Msg -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host $Msg -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host $Msg -ForegroundColor Yellow }
function Write-Err  { param([string]$Msg) Write-Host "Error: $Msg" -ForegroundColor Red }

function Test-CommandExists {
    param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------------------
# Step 1 – Clone or update the cursor-commons repository
# ---------------------------------------------------------------------------
function Install-CursorCommons {
    Write-Info 'Cloning Cursor Commons...'

    if (Test-Path $CursorCommonsHome) {
        Write-Warn "Directory $CursorCommonsHome already exists."
        if (-not $Unattended) {
            $opt = Read-Host 'Do you want to reinstall/update? [Y/n]'
            if ($opt -match '^[Nn]') {
                Write-Host 'Installation skipped.'
                return $false
            }
        }
        try {
            Push-Location $CursorCommonsHome
            git fetch origin 2>&1 | Out-Null
            git checkout -q $Branch
            git pull --quiet origin $Branch
            if ($LASTEXITCODE -ne 0) { throw 'git pull failed' }
        } catch {
            Write-Err 'Failed to update existing installation'
            exit 1
        } finally {
            Pop-Location
        }
    } else {
        git clone --branch $Branch --depth 1 $Remote $CursorCommonsHome
        if ($LASTEXITCODE -ne 0) {
            Write-Err 'git clone of cursor-commons failed'
            exit 1
        }
    }
    Write-Host ''
    return $true
}

# ---------------------------------------------------------------------------
# Step 2 – Back up existing ~/.cursor and install cursor-settings
# ---------------------------------------------------------------------------
function Install-CursorDir {
    Write-Info 'Setting up cursor-settings directory...'

    $CursorDir = Join-Path $HOME '.cursor'
    $OldCursor = Join-Path $HOME '.cursor.pre-cursor-commons'

    if (Test-Path $CursorDir) {
        if (Test-Path $OldCursor) {
            $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
            $OldOld = "$OldCursor-$timestamp"
            Move-Item -Path $OldCursor -Destination $OldOld
            Write-Warn "Backed up previous .cursor.pre-cursor-commons to $OldOld"
        }
        Move-Item -Path $CursorDir -Destination $OldCursor
        Write-Ok 'Backed up existing .cursor to .cursor.pre-cursor-commons'
    }

    Copy-Item -Path "$CursorCommonsHome\cursor-settings" -Destination $CursorDir -Recurse
    Write-Ok "Installed .cursor to $CursorDir"
    Write-Host ''
}

# ---------------------------------------------------------------------------
# Step 3 – Inject hook into PowerShell profile
# ---------------------------------------------------------------------------
function Install-ProfileHook {
    Write-Info 'Configuring PowerShell profile...'

    $ProfilePath = $PROFILE
    $HookMarker  = '# Cursor Commons - shared Cursor IDE config'

    # Build the hook block (literal string so inner $ are not expanded here)
    $Hook = @'

# Cursor Commons - shared Cursor IDE config
$env:CURSOR_COMMONS_HOME = if ($env:CURSOR_COMMONS_HOME) { $env:CURSOR_COMMONS_HOME } else { "$HOME\.cursor-commons" }
if (Test-Path $env:CURSOR_COMMONS_HOME) {
    $_ccUpgrade = Join-Path $env:CURSOR_COMMONS_HOME 'tools\check_for_upgrade.ps1'
    if (Test-Path $_ccUpgrade) { . $_ccUpgrade }
    function cursor-commons-update {
        & (Join-Path $env:CURSOR_COMMONS_HOME 'tools\upgrade.ps1')
    }
}
'@

    $ProfileDir = Split-Path $ProfilePath
    if (-not (Test-Path $ProfileDir)) {
        New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
    }

    if (Test-Path $ProfilePath) {
        $existing = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
        if ($existing -and $existing.Contains($HookMarker)) {
            Write-Ok "Cursor Commons hook already present in $ProfilePath"
        } else {
            Add-Content -Path $ProfilePath -Value $Hook
            Write-Ok "Added Cursor Commons hook to $ProfilePath"
        }
    } else {
        Set-Content -Path $ProfilePath -Value $Hook.TrimStart()
        Write-Ok "Created $ProfilePath with Cursor Commons hook"
    }
    Write-Host ''
}

# ---------------------------------------------------------------------------
# Final message
# ---------------------------------------------------------------------------
function Write-Success {
    Write-Host ''
    Write-Ok 'Cursor Commons is now installed!'
    Write-Host ''
    Write-Host "  * Cursor commands and rules are in $HOME\.cursor"
    Write-Host '  * Update manually with: cursor-commons-update'
    Write-Host '  * Restart your terminal or run: . $PROFILE'
    Write-Host ''
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if (-not [Environment]::UserInteractive) { $Unattended = $true }

if (-not (Test-CommandExists 'git')) {
    Write-Err 'git is not installed. Please install git first.'
    exit 1
}

$ok = Install-CursorCommons
if ($ok -eq $false) { exit 0 }
Install-CursorDir
Install-ProfileHook
Write-Success
