# Cursor Commons - check for upgrades
# Dot-source this script from your PowerShell profile (added automatically by install.ps1).
# Compares the local MANIFEST version with the remote; prompts if an update is available.

# ---------------------------------------------------------------------------
# Guards
# ---------------------------------------------------------------------------
if (-not $env:CURSOR_COMMONS_HOME)               { return }
if (-not (Test-Path $env:CURSOR_COMMONS_HOME))   { return }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return }

$_ccIsRepo = Push-Location $env:CURSOR_COMMONS_HOME
try   { git rev-parse --is-inside-work-tree 2>$null | Out-Null; $LASTEXITCODE -eq 0 }
catch { $false }
finally { Pop-Location } | Set-Variable _ccIsRepo

if (-not $_ccIsRepo)                                 { return }
if ($env:CURSOR_COMMONS_UPDATE_DISABLED -eq '1')     { return }

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
$_ccFreqDays     = if ($env:CURSOR_COMMONS_UPDATE_DAYS) { [int]$env:CURSOR_COMMONS_UPDATE_DAYS } else { 14 }
$_ccLastCheckFile = Join-Path $env:CURSOR_COMMONS_HOME '.last-update-check'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function _cc_GetEpochDays {
    [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() / 86400)
}

function _cc_GetManifestVersion {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $line = Get-Content $Path | Where-Object { $_ -match '^VERSION=' } | Select-Object -First 1
    if ($line) { return ($line -split '=', 2)[1].Trim() }
    return $null
}

function _cc_VersionGt {
    # Returns $true if $Remote is strictly greater than $Local
    param([string]$Local, [string]$Remote)
    if (-not $Local)  { $Local  = '0.0.0' }
    if (-not $Remote) { $Remote = '0.0.0' }
    try {
        $l = [System.Version]$Local
        $r = [System.Version]$Remote
        return ($r -gt $l)
    } catch {
        return $false
    }
}

# ---------------------------------------------------------------------------
# Frequency check – skip if checked recently
# ---------------------------------------------------------------------------
$_ccCurrentEpoch = _cc_GetEpochDays
$_ccLastEpoch    = $null

if (Test-Path $_ccLastCheckFile) {
    $line = Get-Content $_ccLastCheckFile | Where-Object { $_ -match '^LAST_EPOCH=' } | Select-Object -First 1
    if ($line) { $_ccLastEpoch = [int](($line -split '=', 2)[1].Trim()) }
}

if ($null -ne $_ccLastEpoch -and ($_ccCurrentEpoch - $_ccLastEpoch) -lt $_ccFreqDays) { return }

# ---------------------------------------------------------------------------
# Fetch remote (silently – network may be unavailable)
# ---------------------------------------------------------------------------
Push-Location $env:CURSOR_COMMONS_HOME
git fetch origin 2>$null | Out-Null
Pop-Location

# ---------------------------------------------------------------------------
# Resolve branch and read remote MANIFEST version
# ---------------------------------------------------------------------------
Push-Location $env:CURSOR_COMMONS_HOME
$_ccBranch = git symbolic-ref --short HEAD 2>$null
Pop-Location
if (-not $_ccBranch) { $_ccBranch = 'develop' }

$_ccRemoteRef = "origin/$_ccBranch"

Push-Location $env:CURSOR_COMMONS_HOME
$_ccRemoteVersion = git show "${_ccRemoteRef}:MANIFEST" 2>$null |
    Where-Object { $_ -match '^VERSION=' } |
    Select-Object -First 1
Pop-Location

if ($_ccRemoteVersion) {
    $_ccRemoteVersion = ($_ccRemoteVersion -split '=', 2)[1].Trim()
} else {
    $_ccRemoteVersion = $null
}

$_ccLocalVersion = _cc_GetManifestVersion (Join-Path $env:CURSOR_COMMONS_HOME 'MANIFEST')

# ---------------------------------------------------------------------------
# Record check time
# ---------------------------------------------------------------------------
"LAST_EPOCH=$_ccCurrentEpoch" | Set-Content $_ccLastCheckFile

# ---------------------------------------------------------------------------
# Prompt if remote is newer
# ---------------------------------------------------------------------------
if (-not $_ccRemoteVersion) { return }
if (-not (_cc_VersionGt -Local $_ccLocalVersion -Remote $_ccRemoteVersion)) { return }

Write-Host ''
Write-Host '[cursor-commons] A new version is available!' -ForegroundColor Yellow
Write-Host "  Local:  $(if ($_ccLocalVersion) { $_ccLocalVersion } else { 'unknown' })"
Write-Host "  Remote: $_ccRemoteVersion"
Write-Host '  Run ' -NoNewline
Write-Host 'cursor-commons-update' -ForegroundColor White -NoNewline
Write-Host ' to upgrade.'
Write-Host ''
