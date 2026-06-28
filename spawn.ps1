<#
  The Spawner :: spawn.ps1
  Launches a brand-new, independent Claude Code session in a fresh folder with
  Remote Control enabled, in its own terminal window, so it can be driven from a
  phone or browser. The new window is detached, so the session you launch it from
  keeps running -- you can even spawn a new project from inside another remote
  session. See README.md.
#>
param(
    [string]$Name,
    [string]$Parent
)

$ErrorActionPreference = "Stop"

# --- where new project folders go -----------------------------------------
# Priority: -Parent arg  >  $env:SPAWNER_PARENT  >  <user profile>\Projects
if (-not $Parent) { $Parent = $env:SPAWNER_PARENT }
if (-not $Parent) { $Parent = Join-Path $env:USERPROFILE "Projects" }

# --- name / folder ---------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Name)) {
    $Name = "session-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}
$folderName = ($Name -replace '[^\w\-. ]', '-').Trim()
if ([string]::IsNullOrWhiteSpace($folderName)) {
    $folderName = "session-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

$dir = Join-Path $Parent $folderName
New-Item -ItemType Directory -Force -Path $dir | Out-Null

# Pre-accept workspace trust so the spawned session never blocks on the one-time
# "trust this folder?" prompt -- essential when launching remotely, where there
# is no one at the machine to click it.
& (Join-Path $PSScriptRoot "trust-folder.ps1") -Path $dir | Write-Host

# --- pick a shell for the new window --------------------------------------
$shellExe = "powershell"
if (Get-Command pwsh -ErrorAction SilentlyContinue) { $shellExe = "pwsh" }

# --- write a launcher so we avoid nested-quote hell ------------------------
$safeName = $Name -replace "'", "''"
$launcher = Join-Path $dir "_spawner-launch.ps1"
$content = @"
Set-Location -LiteralPath '$dir'
# Remote Control requires claude.ai login auth; a present ANTHROPIC_API_KEY takes
# precedence and would silently disable it. Clear it for THIS process only
# (your global env var is untouched).
Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
Write-Host ''
Write-Host '== The Spawner :: $safeName ==' -ForegroundColor Cyan
Write-Host 'Folder: $dir' -ForegroundColor DarkGray
Write-Host 'This session auto-registers to your Claude account - open' -ForegroundColor DarkGray
Write-Host 'claude.ai/code or the Claude app and pick it from the list.' -ForegroundColor DarkGray
Write-Host ''
claude --dangerously-skip-permissions --remote-control '$safeName'
"@
Set-Content -LiteralPath $launcher -Value $content -Encoding utf8

# --- launch a new terminal window -----------------------------------------
$wt = Get-Command wt.exe -ErrorAction SilentlyContinue
if ($wt) {
    # Windows Terminal: new window, tab opened in $dir, running the launcher
    & wt.exe -w new new-tab -d "$dir" $shellExe -NoExit -ExecutionPolicy Bypass -File "$launcher"
} else {
    # Fallback: plain console window
    Start-Process -FilePath $shellExe -WorkingDirectory $dir `
        -ArgumentList @('-NoExit', '-ExecutionPolicy', 'Bypass', '-File', $launcher)
}

Write-Host "OK: spawned remote session '$Name'"
Write-Host "Folder: $dir"
