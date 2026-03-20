#Requires -Version 5.1
<#
.SYNOPSIS
    Cursor Commons upgrade script for Windows (PowerShell).

.DESCRIPTION
    Pulls the latest changes from remote and syncs cursor-settings to $HOME\.cursor.
    Equivalent to running the cursor-commons-update function registered by install.ps1.
#>

$ErrorActionPreference = 'Stop'

$CursorCommonsHome = if ($env:CURSOR_COMMONS_HOME) { $env:CURSOR_COMMONS_HOME } `
                     else { Join-Path $HOME '.cursor-commons' }

if (-not (Test-Path $CursorCommonsHome)) {
    Write-Host "Error: Cursor Commons not found at $CursorCommonsHome" -ForegroundColor Red
    Write-Host 'Run the install script first.' -ForegroundColor Red
    exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host 'Error: git is not installed' -ForegroundColor Red
    exit 1
}

Write-Host 'Updating Cursor Commons...'
Push-Location $CursorCommonsHome
git pull
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Error: git pull failed' -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

$MaxBackups = 5
$CursorDir  = Join-Path $HOME '.cursor'

Write-Host "Syncing cursor-settings to $HOME\.cursor..."
if (Test-Path $CursorDir) {
    $Timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $Backup    = Join-Path $HOME ".cursor.backup-$Timestamp"
    Copy-Item -Path $CursorDir -Destination $Backup -Recurse
    Write-Host "Backed up existing .cursor to $Backup"

    Get-Item (Join-Path $HOME '.cursor.backup-*') -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -Skip $MaxBackups |
        ForEach-Object {
            Remove-Item -Path $_.FullName -Recurse -Force
            Write-Host "Removed old backup: $($_.FullName)"
        }
}

New-Item -ItemType Directory -Path $CursorDir -Force | Out-Null
Copy-Item -Path "$CursorCommonsHome\cursor-settings\*" -Destination $CursorDir -Recurse -Force

Write-Host 'Cursor Commons has been updated successfully.' -ForegroundColor Green

Write-Host ''
