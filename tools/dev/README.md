# tools/dev: how Jon and Claude work on Three Kelvin

These are the scripts Claude used for the alphas (Oct 2026), moved out of a
Windows temp folder so they work from either machine: Jon's Windows PC (Git
Bash) or his Mac. Every script reads `env.sh` first, which finds the repo, the
worktrees, a scratch folder and Godot on its own.

Read this first if you are a Claude session starting on the Mac. The handoff
at the bottom says where the work stands.

## First time on the Mac

1. **Godot 4.7.1** (the same version as Windows) in `/Applications/Godot.app`,
   with the **4.7.1 export templates** installed (Godot > Editor > Manage Export
   Templates). Builds need them; tests do not.
2. **uv** (`brew install uv`) for the Python tools, and `python3`.
3. **Keys**, in `~/.zshrc`, never printed, logged or written to a file:
   `export ELEVENLABS_API_KEY=...`. PixelLab is reached through its MCP server
   in Claude Code.
4. **The repo** cloned with worktrees beside it: `.../GitHub/ThreeKelvin`, and
   `.../GitHub/tk-wt/` for branches. `tk-scratch/` is made beside them on first use.
5. **Prove the profile guard:** `bash tools/dev/godot.sh --headless --path tkg --import`.
   It refuses to run if it cannot show that Godot writes to a scratch profile
   instead of `~/Library/Application Support/ThreeKelvinAlpha`.
6. **Claude's memory** does not travel with git. Copy the memory folder from
   Windows (`C:\Users\Jon\.claude\projects\c--Users-Jon-Documents-GitHub-ThreeKelvin\memory\`)
   into this project's folder under `~/.claude/projects/` (run `/memory` to find it).

## The scripts

| Script | What it does |
|---|---|
| `env.sh` | Sourced by the rest. Finds TK_REPO, TK_WT, TK_SCRATCH, GODOT, PY; gives `tk_timeout`, `tk_new_profile`, `tk_isolated`, `tk_guard`. |
| `godot.sh [-t S] [-C DIR] args...` | Godot with a fresh throwaway profile, dummy audio and a time limit. Use this for every test and sim run. |
| `render.sh [-t S] [-C DIR] args...` | The same, windowed, for stills and films; at most two at once. On a Mac the window shows on screen. |
| `gate_land.sh WORKTREE BRANCH LABEL` | Merge main, import, run the full gate (about 12 minutes), fast-forward main and push on a pass. |
| `release.sh WORKTREE BRANCH LABEL VERSION` | gate_land, then build both zips from a clean copy, check the Mac app, copy zips to `builds/`, tag `alpha-VERSION` and push the tag. |
| `resolve_changelog.py CHANGELOG.md` | Keeps both sides of a CHANGELOG-only merge conflict. gate_land runs it. |
| `encode_video.py IN.avi OUT.mp4 [START]` | A film the game wrote, as an MP4 a phone plays. |
| `pages/make_pick_page.py SPEC OUT` | A pick page of pictures and films for Jon to choose from. |
| `voice/record.py MANIFEST OUT plan/go/fx` | Record A.S.H. lines with ElevenLabs, several takes each, finished to the game's level. |
| `voice/make_page.py OUT "Title"` | The pick page for those takes. |
| `voice/install.py OUT "id:take ..."` | Copy the picked takes into the game. |

Python tools run through uv, for example:
`uv run --with pillow python ...` for images, or the `--with` list in `voice/record.py`'s header.

## How we work (rulings that hold)

- **Nothing reaches main without the full gate.** One gate at a time; pause
  other Godot work while it runs (timing tests fail on a busy machine). Agents
  run only the tests for what they touch, never `validate.sh`.
- **Branches live in worktrees** under `../tk-wt/<name>`. A fresh worktree needs
  one `--import` before its tests. CHANGELOG lines go under `## [Unreleased]` in
  the bold style (`- **Fixed** —`, `- **Changed** —`, `- **Added** —`).
- **Never read or write Jon's real profile.** Every Godot run goes through
  `godot.sh` or `render.sh`. For his saves, ask for SAVE MY LOGS (a zip on his
  Desktop) and work from that copy.
- **Never spend ElevenLabs or PixelLab credits without asking**, with the takes
  and a hard stop. `voice/record.py plan` gives the number to ask with.
- **Decisions go on a page** Jon can tap: pictures, films or sounds side by
  side, three or so options, a reply line he copies back. Publish the folder
  with the Artifact tool (`files` map printed by the builder).
- **Windowed runs steal the screen on a Mac.** Ask before a batch of stills or
  films, and never run one while Jon is playing.
- **Player text is plain** (a tired engineer's manual), grade 7 or under
  (`python tools/prose_grade.py --all`, `python tools/prose_tells.py`), no
  dashes in sentences. Encounters go through the encounter-prose skill.
- **Releases are built from a clean detached copy** of the landed commit
  (`release.sh` does this). Zips are not uploaded anywhere; Jon shares them.
- **Saves:** a change to what a save holds raises `SaveGame.VERSION` and keeps
  every version since 29 loading (`.github/scripts/version_guard.py`). Never
  raise `RunHistory.VERSION`: it discards the whole flight record, unlocks
  included.

## Handoff, Oct 23

- **Released:** 0.4.2-alpha.1 (2a0ee950) is with the friends' alpha (Cody, Geno,
  Jeremy, Kevin). Jon is on vacation from Oct 24. No updates mid-alpha unless
  something strands players, as the hull-swap softlock did.
- **Plan:** `docs/DEVELOPMENT_PLAN.md`. Phases 1 to 9 are the build order as
  done; phases 10 to 15 are the post-alpha roadmap from the testers' notes (updated Oct 27).
- **Waiting on Jon:**
  - chassis hull numbers against pips (A Korvan only, B every chassis exact, C show the number);
  - the star chart marking stars in reach but too deep (parked);
  - the combat health study (phase 11, step 1).
- **Collect during the alpha:** lines that "read as AI" (phase 14), and every
  SAVE MY LOGS zip with what the player was doing.
- **Not ported:** the Windows hidden desktop (`hiddesk.exe`) stays on the PC;
  set TK_HIDDESK to it there.
