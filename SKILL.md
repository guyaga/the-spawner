---
name: spawner
description: Spawn a brand-new, independent Claude Code session in a fresh folder with Remote Control enabled, in its own terminal window, so it can be driven from a phone or browser. Use when the user wants to "spin up a remote session", "spawn a new project", "open a new claude I can control from my phone", "start a phone-controllable claude", or types "/spawner". Works mid-conversation - the new session is detached and the current one keeps running, so you can even spawn a new project from inside another remote session.
---

# The Spawner

Launches a **separate** Claude Code session in a new folder + new terminal
window, with Remote Control on, so it can be continued from `claude.ai/code` or
the Claude mobile app. Because the new window is detached, the session you launch
it from keeps running.

## What it runs in the new window

```
claude --dangerously-skip-permissions --remote-control "<name>"
```

## How to invoke

Run `spawn.ps1` from this skill's folder with the PowerShell/Bash tool. It
returns immediately (the new session runs detached), so the current conversation
is unaffected.

```
powershell -ExecutionPolicy Bypass -File "<this-skill-folder>\spawn.ps1" -Name "<name>"
```

- If the user gave a name/topic, pass it as `-Name`. If not, omit it -- the
  script auto-generates `session-<timestamp>`.
- Folder location is resolved as: `-Parent` arg, else `$env:SPAWNER_PARENT`,
  else `<user profile>\Projects`.

## After launching

1. Report the session name and the folder path the script printed.
2. Tell the user it **auto-registers to their Claude account** -- open
   `claude.ai/code` or the Claude app and pick this session from the list. No
   pairing code to read locally.
3. Do NOT try to read, attach to, or drive that session from here -- it is a
   fully independent process.

## Why it works unattended (from the phone)

Two things would otherwise make a spawned session fail silently when launched
remotely; both are handled automatically:

1. **Workspace trust** -- a brand-new folder normally shows a one-time "trust
   this folder?" prompt that a remote user can't click. `spawn.ps1` calls
   `trust-folder.ps1` first, which writes `"hasTrustDialogAccepted": true` for
   the folder into `~/.claude.json` (surgical, backed-up, validated insert), so
   the new session never prompts.
2. **Auth** -- Remote Control needs claude.ai login auth. If `ANTHROPIC_API_KEY`
   is set in the environment it takes precedence and would silently disable
   Remote Control, so the launcher clears it for the new session's process only
   (the user's global var is left untouched).

The new session then auto-registers to the logged-in account and appears in the
session list at `claude.ai/code` and in the Claude app.

## Requirements

- Claude Code **v2.1.51+**, logged in via `/login` with a **Pro/Max/Team/
  Enterprise** account (Remote Control does not work with an API key).
- Windows + PowerShell. Uses Windows Terminal (`wt`) if available, else a plain
  PowerShell console window; prefers `pwsh`, falls back to Windows PowerShell.

See `README.md` for full setup and configuration.
