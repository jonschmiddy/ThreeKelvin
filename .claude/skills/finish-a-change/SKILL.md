---
name: finish-a-change
description: |
  The checklist for finishing a Three Kelvin change. Use when you are about to say a change
  is done, before you commit, before you open or update a PR, when Jon asks "is this done?",
  "can we land it?" or "what did you not test?", and after a ratchet, the pre-commit hook or
  check.sh reports a failure. Covers the one command to run, the save and co-op version rules,
  the changes/ line, the test map, what each ratchet failure means, and how to land.
---

# Finishing a change

Do these in order. Each step says why, so you can tell when it does not apply.

1. **Run `bash tools/dev/check.sh --tests`.** One command: the static checks, `-- parseall`, and
   the headless test rows `docs/tests.md` lists for what you touched. A change you did not run
   is a guess. (`bash tools/dev/check.sh` without `--tests` is the quick version; the Stop hook
   still asks for `--tests` after a change under `tkg/`.) Why: `docs/why/check.md`.
2. **Read what `tests_for.py` printed under "run by hand"** (windowed rows, art, audio, anything it
   will not start). You did not run those. Name each in your report as not run.
3. **A new `class_name` or a new script needs an import:**
   `bash tools/dev/godot.sh --headless --path tkg --import`, or its tests fail with unknown class.
4. **Save format:** if a change alters what a save holds, raise `SaveGame.VERSION` and keep every
   version since 29 loading (`.github/scripts/version_guard.py` enforces it). Never raise
   `RunHistory.VERSION` for this. No players yet, so rename a key clean: no migration shim.
5. **Co-op wire format:** a change to what crosses the wire raises `PROTOCOL`.
6. **Add `changes/YYYY-MM-DD-what-changed.md`** with one bold line a player would notice:
   `- **Added** — ...` (`**Fixed**`, `**Changed**`). A developer-only tool still gets a line.
   Why: one file per change so branches never conflict (`changes/README.md`).
7. **Long reasoning goes to `docs/why/<Stem>.md`**, and the code keeps a one-line `# Why:` pointer
   (comments over 5 lines fail the comment check). A new test harness gets a row in `docs/tests.md`.
8. **Never start Godot directly.** Always `bash tools/dev/godot.sh ...` or `render.sh`: the real
   profile is never touched. (The Bash hook blocks a direct start.)
9. **Branch in a worktree** under `../tk-wt/<name>`; never commit on `main` in the main checkout.
   Land only with `bash tools/dev/gate_land.sh WORKTREE BRANCH LABEL`; or push the branch and open
   a PR. Merging is the humans' call.
10. **Say plainly what was not tested**: Windows, a windowed run, a live co-op session, anything
    skipped in step 2, any check you could not run and why. Never write "should work".

## When a ratchet fails

A NEW failure means this change added debt. The honest way to clear it is to fix the code.

| Message starts | It means | Fix |
|---|---|---|
| `NEW length` / `GREW` (code_check) | a function over 100 lines, or one that grew | split the function |
| `NEW bare` (code_check) | a function returning a bare Dictionary, Array or Variant | give it `Array[T]` or `Dictionary[K, V]` |
| `NEW layer ... ->` (code_graph) | game code reaches into sim, or systems/data/net reach into ui | move the call to the right layer |
| `NEW private ... <-` (code_graph) | a call to another class's `_private` method | make it public or use the right method |
| `NEW frame ...` (frame_check) | `load(`, image or colour building, a tree search inside `_process` or `_draw` | do it once in `_ready` |
| `path:line:` (comment_check) | a comment run over 5 lines, or a dead `docs/why` pointer | move the text to `docs/why` |
| `NEW uncovered` (tests_map_check) | a runnable harness with no `docs/tests.md` row | add the row |

`python3 tools/<name>.py --update` rewrites a baseline. Use it only for a thing that was moved or
renamed, and say in the PR why each ADDED line is a move and not new debt. Never to silence a NEW line.
Why: `docs/why/code_check.md`, `code_graph.md`, `frame_check.md`, `tests_map_check.md`.
Every check is listed with its first words in `tkg/CLAUDE.md`, "Checks that will stop you".
