---
name: spawner
description: Spawn a brand-new, independent Claude Code session in a fresh folder with Remote Control enabled, in its own terminal window, so it can be driven from a phone or browser. Use when the user wants to "spin up a remote session", "spawn a new project", "open a new claude I can control from my phone", "start a phone-controllable claude", or types "/spawner". Works mid-conversation - the new session is detached and the current one keeps running, so you can even spawn a new project from inside another remote session. Optional opt-in flags add a current-directory mode (-Here), spawn-and-go task briefs (-Brief / -BriefFile), and GitHub repo creation (-InitRepo); the default behavior is unchanged.
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

## Optional flags (opt-in, default behavior unchanged)

All of these are off by default, so a plain `/spawner` keeps creating a fresh,
pre-trusted folder exactly as before.

### `-Here` -- run in the current directory

Instead of creating a new folder, root the session in the **current directory**
(or `$env:SPAWNER_HERE` if set). The spawned session inherits whatever
`CLAUDE.md` / SessionStart hooks that project already has. No folder is created
and no trust pre-seed is needed -- a project you launch from is already trusted.

```
... \spawn.ps1 -Here -Name "<name>"
```

### `-Brief` / `-BriefFile` -- spawn-and-go

Pass a task brief and the session boots already executing it. The kickoff prompt
tells the new session to read the brief and run it to completion.

```
... \spawn.ps1 -Name "<name>" -Brief "<task text>"
... \spawn.ps1 -Name "<name>" -BriefFile "C:\path\to\brief.md"
```

- An inline `-Brief` is saved to `~/.claude/spawner-briefs/<name>.md`.
- A good brief includes: role/context, the task, pointers to the relevant files,
  hard constraints, and a clear definition of done.
- Works with either folder mode.

### `-InitRepo` (+ `-Public`) -- create a GitHub repo (new-folder mode only)

In the default new-folder mode, also seed `README.md` + `.gitignore`,
`git init` + commit, and `gh repo create <name> --source=. --push`. The repo is
**private** by default; add `-Public` for a public one. This needs `git` + an
authenticated `gh` CLI; if either is missing or the name collides, the repo step
is skipped with a note and the folder + session still launch.

```
... \spawn.ps1 -Name "<name>" -InitRepo
... \spawn.ps1 -Name "<name>" -InitRepo -Public
```

## After launching

1. Report the session name and the folder path the script printed (plus the repo
   URL if `-InitRepo` was used, and the brief path if a brief was passed).
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
   the new session never prompts. (`-Here` mode skips this -- an existing project
   is already trusted.)
2. **Auth** -- Remote Control needs claude.ai login auth. If `ANTHROPIC_API_KEY`
   is set in the environment it takes precedence and would silently disable
   Remote Control, so the launcher clears it for the new session's process only
   (the user's global var is left untouched).

The new session then auto-registers to the logged-in account and appears in the
session list at `claude.ai/code` and in the Claude app.

## Config / overrides

- `$env:SPAWNER_PARENT` -- where new-folder projects are created (default
  `<user profile>\Projects`).
- `$env:SPAWNER_HERE` -- override the directory used by `-Here` (default: the
  current directory).

## Requirements

- Claude Code **v2.1.51+**, logged in via `/login` with a **Pro/Max/Team/
  Enterprise** account (Remote Control does not work with an API key).
- Windows + PowerShell. Uses Windows Terminal (`wt`) if available, else a plain
  PowerShell console window; prefers `pwsh`, falls back to Windows PowerShell.
- `-InitRepo` additionally needs `git` + an authenticated `gh` CLI.

See `README.md` for full setup and configuration.
