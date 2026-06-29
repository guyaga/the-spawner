<#
  The Spawner :: spawn.ps1
  Launches a brand-new, independent Claude Code session in a fresh folder with
  Remote Control enabled, in its own terminal window, so it can be driven from a
  phone or browser. The new window is detached, so the session you launch it from
  keeps running -- you can even spawn a new project from inside another remote
  session.

  Opt-in flags (all default OFF -- a plain run behaves exactly as before):
    -Here              Run in the CURRENT directory instead of a new folder, so
                       the session inherits that project's CLAUDE.md / hooks.
                       No folder is created and no trust pre-seed is needed.
    -Brief "<text>"    Boot the session already executing an inline task brief.
    -BriefFile <path>  Same, but read the brief from a file.
    -InitRepo          (new-folder mode only) Create a GitHub repo and push the
                       first commit -- private by default, -Public for public.

  See README.md.
#>
param(
    [string]$Name,
    [string]$Parent,
    [switch]$Here,        # opt-in: run in the current directory, no new folder
    [string]$Brief,       # opt-in: inline task brief; the session boots running it
    [string]$BriefFile,   # opt-in: path to a task-brief file
    [switch]$InitRepo,    # opt-in (new-folder mode): create a GitHub repo and push
    [switch]$Public       # with -InitRepo: create a public repo instead of private
)

$ErrorActionPreference = "Stop"

# --- name / folder ---------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Name)) {
    $Name = "session-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}
$folderName = ($Name -replace '[^\w\-. ]', '-').Trim()
if ([string]::IsNullOrWhiteSpace($folderName)) {
    $folderName = "session-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

$repoInfo = ""

if ($Here) {
    # --- opt-in "here" mode: attach to the CURRENT directory -------------------
    # Runs in an existing project so the spawned session inherits whatever
    # CLAUDE.md / SessionStart hooks it already has. No folder is created and no
    # trust pre-seed is needed -- a project you launch from is already trusted.
    # Priority: $env:SPAWNER_HERE  >  current directory.
    $base = $env:SPAWNER_HERE
    if (-not $base) { $base = (Get-Location).Path }
    if (-not (Test-Path -LiteralPath $base)) {
        throw "Here dir not found: $base  (set `$env:SPAWNER_HERE to override)"
    }
    $dir = (Resolve-Path -LiteralPath $base).Path
}
else {
    # --- DEFAULT: brand-new project folder (unchanged from upstream) -----------
    # Priority: -Parent arg  >  $env:SPAWNER_PARENT  >  <user profile>\Projects
    if (-not $Parent) { $Parent = $env:SPAWNER_PARENT }
    if (-not $Parent) { $Parent = Join-Path $env:USERPROFILE "Projects" }

    $dir = Join-Path $Parent $folderName
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    # Pre-accept workspace trust so the spawned session never blocks on the one-time
    # "trust this folder?" prompt -- essential when launching remotely, where there
    # is no one at the machine to click it.
    & (Join-Path $PSScriptRoot "trust-folder.ps1") -Path $dir | Write-Host

    # --- opt-in: create a GitHub repo and push the first commit ----------------
    # Best-effort: if git/gh are missing or the name is taken, the folder and the
    # session still launch -- only the repo step is skipped, with a note.
    if ($InitRepo) {
        try {
            if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "git not found" }
            if (-not (Get-Command gh  -ErrorAction SilentlyContinue)) { throw "gh CLI not found" }

            $readme = "# $Name`n`nSpawned with The Spawner on $(Get-Date -Format 'yyyy-MM-dd').`n"
            Set-Content -LiteralPath (Join-Path $dir "README.md") -Value $readme -Encoding utf8
            $ignore = @(
                "node_modules/", ".env", ".env.*", "*.log", "dist/", "build/",
                ".DS_Store", "__pycache__/", "*.pyc", ".venv/", "_spawner-launch.ps1"
            ) -join "`n"
            Set-Content -LiteralPath (Join-Path $dir ".gitignore") -Value $ignore -Encoding utf8

            $repoName = $folderName -replace '\s+', '-'
            Push-Location $dir
            # git/gh write benign warnings (e.g. LF->CRLF) to stderr; don't let those
            # abort the run. Use exit codes, not exceptions, inside this block.
            $savedEAP = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                git init -q 2>&1 | Out-Null
                git add -A  2>&1 | Out-Null
                # Use the global git identity; fall back to a generic one if unset.
                $gname = (git config user.name)  2>$null
                $gmail = (git config user.email) 2>$null
                if ([string]::IsNullOrWhiteSpace($gname)) { $gname = "spawner" }
                if ([string]::IsNullOrWhiteSpace($gmail)) { $gmail = "spawner@local" }
                git -c "user.name=$gname" -c "user.email=$gmail" commit -q -m "init: $repoName (spawned)" 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "git commit failed (exit $LASTEXITCODE)" }

                $vis = if ($Public) { "--public" } else { "--private" }
                # Creates the repo under the authenticated gh account, sets origin, pushes.
                $createOut = (gh repo create $repoName $vis --source=. --remote=origin --push 2>&1) -join " "
                if ($LASTEXITCODE -ne 0) { throw "gh repo create failed: $createOut" }
                $repoUrl = (gh repo view --json url -q .url 2>$null)
                if ($repoUrl) { $repoInfo = "$repoUrl  ($($vis -replace '--', ''))" }
                else { $repoInfo = "created ($($vis -replace '--', ''))" }
            }
            finally {
                $ErrorActionPreference = $savedEAP
                Pop-Location
            }
        }
        catch {
            $repoInfo = "SKIPPED repo ($($_.Exception.Message)) -- folder still created"
        }
    }
}

# --- opt-in spawn-and-go: resolve the task brief --------------------------
# When a brief is supplied the spawned session boots already executing it. An
# inline -Brief is saved under ~/.claude/spawner-briefs so the kickoff prompt can
# point the new session at a stable path.
$briefPath = $null
if ($BriefFile) {
    if (-not (Test-Path -LiteralPath $BriefFile)) { throw "BriefFile not found: $BriefFile" }
    $briefPath = (Resolve-Path -LiteralPath $BriefFile).Path
}
elseif ($Brief) {
    $briefDir = Join-Path $env:USERPROFILE ".claude\spawner-briefs"
    New-Item -ItemType Directory -Force -Path $briefDir | Out-Null
    $briefPath = Join-Path $briefDir ($folderName + ".md")
    Set-Content -LiteralPath $briefPath -Value $Brief -Encoding utf8
}

# --- pick a shell for the new window --------------------------------------
$shellExe = "powershell"
if (Get-Command pwsh -ErrorAction SilentlyContinue) { $shellExe = "pwsh" }

# --- build the claude launch line -----------------------------------------
$safeName = $Name -replace "'", "''"
if ($briefPath) {
    # Plain-English kickoff: read the brief, then run it to completion.
    $kickoff = "Read your full task brief at `"$briefPath`" and execute it now -- start with any sources it points to, then work through it end to end. This is a detached, autonomous session; report back when done."
    $kickoffEsc = $kickoff -replace "'", "''"
    $claudeLine = "claude --dangerously-skip-permissions '$kickoffEsc' --remote-control '$safeName'"
}
else {
    $claudeLine = "claude --dangerously-skip-permissions --remote-control '$safeName'"
}

# --- write a launcher so we avoid nested-quote hell ------------------------
# New-folder mode keeps the launcher inside the throwaway folder (git-ignored).
# "here" mode writes it to TEMP instead, so an existing project is never polluted.
if ($Here) {
    $launcher = Join-Path ([System.IO.Path]::GetTempPath()) ("_spawner-launch-" + (Get-Date -Format "yyyyMMddHHmmss-fff") + ".ps1")
} else {
    $launcher = Join-Path $dir "_spawner-launch.ps1"
}
$repoBanner = ""
if ($repoInfo)  { $repoBanner  = "Write-Host 'Repo: $repoInfo' -ForegroundColor Green" }
$briefBanner = ""
if ($briefPath) { $briefBanner = "Write-Host 'Brief: $briefPath' -ForegroundColor Yellow" }
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
$repoBanner
$briefBanner
Write-Host 'This session auto-registers to your Claude account - open' -ForegroundColor DarkGray
Write-Host 'claude.ai/code or the Claude app and pick it from the list.' -ForegroundColor DarkGray
Write-Host ''
$claudeLine
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
if ($repoInfo)  { Write-Host "Repo:   $repoInfo" }
if ($briefPath) { Write-Host "Brief:  $briefPath" }
Write-Host "Folder: $dir"
