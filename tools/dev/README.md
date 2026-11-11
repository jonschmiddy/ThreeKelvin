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
| `env.sh` | Sourced by the rest. Finds TK_REPO, TK_WT, TK_SCRATCH, GODOT, PY; gives `tk_timeout`, `tk_new_profile`, `tk_isolated`, `tk_guard`, `tk_parse_run_args` (the -t and -C of godot.sh and render.sh) and `tk_import_project`. |
| `godot.sh [-t S] [-C DIR] args...` | Godot with a fresh throwaway profile, dummy audio and a time limit. Use this for every test and sim run. |
| `render.sh [-t S] [-C DIR] args...` | The same, windowed, for stills and films; at most two at once. On a Mac the window shows on screen. |
| `run_battery.sh [WORKTREE] [names...]` | The wide test battery (36 runs, PairLocalTest among them; about 9 minutes on the PC plus 1:30 for the timed ones; 17 before the split), JOBS at once (default 8), longest first: FlightTest and SolveTest split into shards (`FLIGHT_SHARDS` 4, `SOLVE_SHARDS` 8 as in the gate; FlightTest's hand phase its own row, `flighttest_hand`, as the gate's `flighthand`), their totals after (`sheet=ShardSum`), the four timed runs alone at the end (`SOLO=0` skips them). Logs and `summary.txt` in `$OUT`. The wide set for a change to flight, save, clock or net; not the gate. |
| `gate_land.sh WORKTREE BRANCH LABEL` | Merge main, import, run the full gate (about 10 minutes), fast-forward main and push on a pass. |
| `release.sh WORKTREE BRANCH LABEL VERSION` | First rename NEW THINGS' `NEXT` entry (`tkg/scripts/data/NewThings.gd`) to VERSION and date it, in the commit that raises config/version; it refuses otherwise (`new_things_check.sh`, before the gate and again on the landed main). Then gate_land, then build both zips from a clean copy, check the Mac app, copy zips to `builds/`, tag `alpha-VERSION` and push the tag. |
| `new_things_check.sh VERSION [NewThings.gd]` | Exit 0 only when NEW THINGS' newest entry is VERSION, dated, with no `NEXT` left. release.sh runs it. |
| `cut_changelog.py VERSION [DATE]` | Folds `changes/*.md` into `CHANGELOG.md` as the new build's section; you write its opening paragraph. release.sh refuses while `changes/` still has a file. |
| `encode_video.py IN.avi OUT.mp4 [START]` | A film the game wrote, as an MP4 a phone plays. |
| `pages/make_pick_page.py SPEC OUT` | A pick page of pictures and films for Jon to choose from. |
| `voice/record.py MANIFEST OUT plan/go/fx` | Record A.S.H. lines with ElevenLabs, several takes each, finished to the game's level. |
| `voice/make_page.py OUT "Title"` | The pick page for those takes. |
| `voice/install.py OUT "id:take ..."` | Copy the picked takes into the game. |
| `badge/dump_golden.py golden\|frames DIR` | The Custodian's badge (9b) drawn by the approved page's own code (`badge/core.js`, `badge/fin_eye.js`, `badge/dump.html`): `golden` writes `tkg/scripts/sim/badge_golden.json` for `BadgeTest`, `frames` the page's PNGs of the frames `-- sheet=BadgeFrames` writes. Uses the installed Chrome. |
| `badge/diff_frames.py GAME WEB [SHEET.png]` | Those two frame folders compared file by file, and a 4x contact sheet. |
| `jump_compare.py GAME_DIR ID OUT [--strips]` | A jump film as the game played it (`-- jumpcine whole film=ID`, through `render.sh --fixed-fps 60`) muxed with its taped cues, 1x and 2x MP4s, and laid beside the approved film's frames at the strip's moments. `uv run --with pillow --with numpy --with soundfile --with imageio-ffmpeg python tools/dev/jump_compare.py ...` |
| `golden_diff.py A B` | On demand, never in the gate: two `-- sheet=GoldenFrames out=<dir>` capture folders (temp, before and after a drawing refactor) compared file by file: prints each file that differs with its changed pixel count, each missing or extra file, and exits 1 on any. `uv run --with pillow tools/dev/golden_diff.py A B`. `docs/tests.md` has the capture command. |

Python tools run through uv, for example:
`uv run --with pillow python ...` for images, or the `--with` list in `voice/record.py`'s header.

## How we work (rulings that hold)

- **Nothing reaches main without the full gate.** One gate at a time; pause
  other Godot work while it runs (the older timing tests fail on a busy machine;
  a new test must not depend on speed, see `tkg/CLAUDE.md`). Agents
  run only the tests for what they touch, never `validate.sh`.
- **Branches live in worktrees** under `../tk-wt/<name>`. A fresh worktree needs
  one `--import` before its tests. A change's CHANGELOG line is its own file,
  `changes/YYYY-MM-DD-what-changed.md`, in the bold style (`- **Fixed** —`,
  `- **Changed** —`, `- **Added** —`), so branches never conflict over the one file.
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

## Handoff, Nov 8

- **Landed on main since the Nov 1 handoff:** twin stars (ruling 20), flight length C
  (ruling 21) and the twin looks picks; NEW THINGS on the title menu and the edge
  arrows (Nov 5); the co-op shared-fight fixes (Nov 5 to 6); then the Nov 7 to 8 work:
  the gate in four parts on four runners, long comments moved into `docs/why/`,
  `tkg/CLAUDE.md` as an index, and `changes/`. `feat/twin-fix` and `feat/twin-stars`
  are both ancestors of main.
- **Version:** still 0.4.2-alpha.1. What is unreleased is one file per change in
  `changes/` (`CHANGELOG.md`'s [Unreleased] is only a pointer to it).
- **To release:** `tools/dev/cut_changelog.py <version>`, rename and date NEW THINGS'
  NEXT entry, then `release.sh` (it refuses without both).
- **Plan:** `docs/DEVELOPMENT_PLAN.md` (phases 10 to 15 are the post-alpha roadmap).
  Older handoffs: `docs/handoffs/`.
