<#
  The Spawner :: trust-folder.ps1
  Marks a folder as trusted in ~/.claude.json so Claude Code does NOT show the
  one-time "Do you trust the files in this folder?" prompt when it starts there.
  This is what lets a remote/phone user pre-accept trust with no physical click.
  Safe: backs up the config, does a surgical text insert (no full JSON re-encode),
  validates before writing, and is a no-op if the folder is already present.

  Can be used standalone:  powershell -File trust-folder.ps1 -Path "C:\some\folder"
#>
param(
    [Parameter(Mandatory = $true)][string]$Path
)

$ErrorActionPreference = "Stop"

$cfg = Join-Path $env:USERPROFILE ".claude.json"
if (-not (Test-Path $cfg)) { throw "Config not found: $cfg" }

# Claude stores project keys with forward slashes, no trailing slash.
$key = ($Path -replace '\\', '/').TrimEnd('/')

$raw = [System.IO.File]::ReadAllText($cfg)

if ($raw -match [regex]::Escape('"' + $key + '"')) {
    Write-Output "ALREADY-PRESENT: $key"
    return
}

$marker = '"projects": {'
$idx = $raw.IndexOf($marker)
if ($idx -lt 0) { throw 'Could not find "projects" object in config.' }
$insertAt = $idx + $marker.Length

$entry = @"

    "$key": {
      "allowedTools": [],
      "mcpContextUris": [],
      "mcpServers": {},
      "enabledMcpjsonServers": [],
      "disabledMcpjsonServers": [],
      "hasTrustDialogAccepted": true,
      "projectOnboardingSeenCount": 0,
      "hasCompletedProjectOnboarding": true
    },
"@

$new = $raw.Substring(0, $insertAt) + $entry + $raw.Substring($insertAt)

# Validate BEFORE touching the real file. We can't ConvertFrom-Json the whole
# file: a Claude config can legitimately contain keys differing only by case
# (e.g. D:/Website vs D:/website) which JSON allows but PowerShell rejects as
# "duplicate". So instead: (a) confirm the inserted entry is well-formed JSON,
# and (b) confirm brace/bracket balance is unchanged (a surgical insert at the
# start of a valid object preserves validity).
$probe = "{" + $entry.TrimEnd().TrimEnd(',') + "}"
try { $null = $probe | ConvertFrom-Json } catch { throw "Aborting: generated entry is not valid JSON. $_" }

$bal = { param($s, $o, $c) ($s.ToCharArray() | Where-Object { $_ -eq $o }).Count - ($s.ToCharArray() | Where-Object { $_ -eq $c }).Count }
if ((& $bal $new '{' '}') -ne (& $bal $raw '{' '}')) { throw "Aborting: brace balance changed." }
if ((& $bal $new '[' ']') -ne (& $bal $raw '[' ']')) { throw "Aborting: bracket balance changed." }

# Backup, then write UTF-8 without BOM (matches Claude's own format).
[System.IO.File]::Copy($cfg, "$cfg.bak", $true)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($cfg, $new, $utf8NoBom)

Write-Output "TRUSTED: $key"
