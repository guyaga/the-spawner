# The Spawner 🥥

> Spin up a brand-new, phone-controllable Claude Code project — from anywhere,
> with zero clicks at the machine.

**The Spawner** is a [Claude Code](https://code.claude.com) skill that, on
demand, creates a fresh project folder on your PC, opens a new terminal, and
starts a Claude Code session there with **Remote Control** already on. That
session auto-registers to your Claude account, so it pops up in your session
list at [claude.ai/code](https://claude.ai/code) or the Claude mobile app —
ready to drive from your phone.

The launching session is detached, so **you can spawn a new project from inside
another Remote Control session.** Lying on the beach, you decide you want a new
project on your home machine — `/spawner my-idea` — and start working on it from
your phone. That's the whole point.

---

## What it does

When invoked it:

1. Creates a new folder for the project.
2. **Pre-accepts workspace trust** for that folder (so the new session never
   blocks on the "trust this folder?" prompt you couldn't click remotely).
3. Opens a new terminal window in that folder.
4. **Clears `ANTHROPIC_API_KEY`** for that window only (Remote Control needs your
   subscription login, and a present API key would silently override it).
5. Runs `claude --dangerously-skip-permissions --remote-control "<name>"`.

The new session then shows up in your Claude account's session list — no pairing
code, no interaction at the machine.

## Why those two steps matter

These are the non-obvious things that make a "just launch claude" approach fail
**silently** when you're not at the keyboard:

- **Workspace trust.** A brand-new folder triggers a one-time *"Do you trust the
  files in this folder?"* prompt. It appears *before* the session is remotely
  visible, so you can't accept it from the phone. (A `claude -p` warm-up does
  **not** persist trust — tested.) The Spawner pre-seeds
  `"hasTrustDialogAccepted": true` for the folder in `~/.claude.json` via a
  surgical, backed-up, validated text edit.
- **Auth.** Remote Control requires a claude.ai login (Pro/Max/Team/Enterprise).
  If `ANTHROPIC_API_KEY` is set, Claude Code uses it and **disables** Remote
  Control. The launcher unsets it for the spawned process only.

## Optional flags

The default behavior above is unchanged. These flags are all opt-in:

| Flag | Mode | What it adds |
|------|------|--------------|
| `-Here` | current dir | Run in the **current directory** (or `$env:SPAWNER_HERE`) instead of a new folder, so the session inherits that project's existing `CLAUDE.md` / hooks. No folder is created and no trust pre-seed is needed. |
| `-Brief "<text>"` | either | **Spawn-and-go:** the session boots already executing an inline task brief (saved under `~/.claude/spawner-briefs`). |
| `-BriefFile <path>` | either | Same, but reads the brief from a file. |
| `-InitRepo` | new folder | After creating the folder, `git init` + commit and `gh repo create --source=. --push`. **Private by default.** |
| `-Public` | new folder | With `-InitRepo`, create a public repo instead of private. |

```powershell
# default: fresh folder, remote session
/spawner my-idea

# run in the current project instead of a new folder
... spawn.ps1 -Here -Name review-this

# boot already running a task
... spawn.ps1 -Name nightly -Brief "Refactor the parser and add tests; done = green CI."

# fresh folder + a private GitHub repo pushed
... spawn.ps1 -Name my-idea -InitRepo
```

`-InitRepo` needs `git` and an authenticated `gh` CLI. If either is missing or
the repo name is taken, the repo step is skipped with a note and the folder +
session still launch.

## Requirements

- **Claude Code v2.1.51+**
- Logged in with `/login` using a **Pro, Max, Team, or Enterprise** account
  (an API key will not work for Remote Control)
- **Windows** + PowerShell (Windows PowerShell 5.1 or PowerShell 7)
- Optional: [Windows Terminal](https://aka.ms/terminal) (`wt`) for a nicer
  window; otherwise a plain console is used
- Optional (for `-InitRepo`): `git` + an authenticated [`gh`](https://cli.github.com) CLI

## Install

Copy the skill into your Claude Code skills directory:

```powershell
# clone, then copy into ~/.claude/skills/spawner
git clone https://github.com/guyaga/the-spawner.git
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills\spawner" | Out-Null
Copy-Item the-spawner\SKILL.md, the-spawner\spawn.ps1, the-spawner\trust-folder.ps1 `
  "$env:USERPROFILE\.claude\skills\spawner\"
```

(Or just drop `SKILL.md`, `spawn.ps1`, and `trust-folder.ps1` into a
`~/.claude/skills/spawner/` folder.)

## Usage

From any Claude Code session — including one you're already Remote-Controlling
from your phone:

```
/spawner                  # auto-named session-<timestamp>
/spawner my-new-idea      # named project
```

Or ask in plain language: *"spin up a new remote project called my-new-idea."*

Then open **claude.ai/code** or the Claude app and pick the new session from the
list.

## Configuration

Where new project folders are created is resolved in this order:

1. `-Parent` argument to `spawn.ps1`
2. `SPAWNER_PARENT` environment variable
3. Default: `%USERPROFILE%\Projects`

To always create projects on, say, your `D:` drive:

```powershell
setx SPAWNER_PARENT "D:\"
```

The directory used by `-Here` can be overridden with `SPAWNER_HERE` (default: the
current directory).

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Skill manifest Claude Code reads (`/spawner`) |
| `spawn.ps1` | Creates the folder, pre-trusts it, launches the remote session |
| `trust-folder.ps1` | Standalone helper that marks a folder trusted in `~/.claude.json` |

## Safety notes

- `trust-folder.ps1` backs up `~/.claude.json` to `~/.claude.json.bak` before
  every edit and validates the result before writing.
- `--dangerously-skip-permissions` is used so the remote session isn't blocked
  waiting for permission prompts you can't answer from the phone. Only spawn
  projects you trust.
- `-InitRepo` creates a repo under your authenticated `gh` account and pushes to
  GitHub. It is opt-in and private by default; nothing is created or pushed
  without it.

## License

MIT © Guy Aga
