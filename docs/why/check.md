The reasoning behind `tools/dev/check.sh`, `tools/dev/tests_for.py` and `.githooks/pre-commit`: a mistake caught at the commit costs seconds, the same mistake caught by the merge gate costs ten minutes and a rerun.

## static_units

`GATE_STATIC=1 .github/scripts/validate.sh` runs the units in `STATIC_UNITS`: those whose
body starts no Godot (no `run_godot`, `gate_sheet`, `gate_check` or `$GODOT`). They are
plain shell, python or node, need no `--import`, and take about five seconds side by side.
They are the same functions the gate runs, so a green static run and the gate cannot
disagree about them. The flight and solve totals are not in the list: they read their
shards' logs, which only a Godot run writes. A new unit that starts no Godot goes into the
list; the start-up check refuses a name in the list that has no `unit_` function, and a
`unit_` defined twice (the later silently replaced the earlier, as `unit_codecheck` did
for a week).

## check

One command to run before saying a change is done: the static units, then `-- parseall`
(a script that does not load is the commonest silent break), then with `--tests` the
headless rows `tests_for.py` picks. It only reads the units' own output, so the messages
are the tools' own. A failing check prints what the tool printed; it never hides it
behind a summary. The gate is still the gate: this is the cheap part of it.

## tests_for

`docs/tests.md` names what to run after touching what. A session was told to grep it by
hand; this does the grep. A row applies to a changed file when its text names the file's
stem or `class_name` (in backticks, or bare when the name is not an ordinary word:
`Run` or `Market` bare would match any sentence), a `Seq*.gd` style pattern that fits, or
a function the diff added, removed or changed (git names the function around a hunk).
A function alone, without the class, counts only when it is public and snake_case
(`site_here`, not `heal` or `_open`), because short names are in many classes.

Which rows it runs by itself: only those that say headless, or whose command the merge
gate runs headless (read from `validate.sh`), and that need no argument filled in
(`out=<dir>`). Windowed rows, rows that do not say, and installers or builds that write
files are listed as "run by hand". A row with `~N min` over three minutes runs only with
`--slow`. A run passes as `run_battery.sh` decides: exit 0, no error line, no failing
verdict line, and a PASS line (a row its cell calls a MEASUREMENT or a Profiler prints none).

## Runs side by side

A change to a core file (`Database`, `Combat`, `CardData`) maps to 40 rows or more, each a
Godot run of 20 to 60 seconds: one at a time that was 15 to 30 minutes. `--run` now starts
`--jobs` of them at once (default `TK_TEST_JOBS`, else six or the cores less two, at least
one), as the gate's pool does, and prints each result whole and in row order, so the output
reads as it did serially and `check.sh` greps the same lines.

Some rows still run alone, after the pool, one at a time, because a busy CPU fails them for
reasons that are not the code's:

- a command one of the gate's `SOLO_UNITS` runs, read from `validate.sh` (the unit's
  `-- sheet=X` and its bare words: `FlightTest clicks` is alone, `FlightTest seeds=2` is
  not), so the two lists cannot drift; `--selftest` fails if a SOLO unit yields no command;
- a row `docs/tests.md` marks as timing: "**In the merge gate**, solo", "alone (it times",
  "SOLO", "times frames" or "times the step";
- a MEASUREMENT or Profiler that times something (counts are unaffected and stay in the pool);
- a windowed row (none run today) and the co-op scripts, whose two processes pair over the network.

`--list-all` prints which rows run alone and why. Each run is isolated as before: `godot.sh`
gives every process its own fresh profile (APPDATA and LOCALAPPDATA on Windows, HOME and XDG
elsewhere), so user:// and `TestRun.scratch` are never shared; harnesses write nothing under
res://, and the gate already runs six Godots on one imported `tkg/` at once. Logs are numbered
per row. The pool starts the longest first, by the gate's `gate_weight` seconds. On Windows a run is started suspended inside a job object and then resumed, so
everything it starts (bash, `timeout`, `godot_console.exe`, `godot.exe`) belongs to the job;
the job is ended after every run, at its time limit and on Ctrl-C, which a plain kill of bash
did not do (it left `godot.exe` running). Elsewhere a run is its own process group.

## What `--tests` runs

`check.sh --tests` and `tests_for.py --run` run the checked-out branch's own code: the game, and the four
allowlisted scripts. Do not run them on a branch you have not read. Only the engine flags `--headless`,
`--fixed-fps N`, `--disable-vsync`, `--quit-after N`, `--resolution WxH`, `--rendering-driver NAME` and
`--audio-driver NAME` are passed to Godot from a row; a row with any other flag (`--script`, `--log-file`,
`--write-movie`) is not run and is listed as "run by hand: engine flag not on the allowlist".

## pre-commit

Runs `tools/dev/check.sh --static --quiet`, which is `GATE_STATIC=1 validate.sh`. It
looks at the working tree, not the index, so a partly staged commit is judged by what is
on disk. It does nothing when the commit touches none of `tkg/ tools/ docs/ changes/
.github/ music/ relay/`, skips itself in a rebase, merge or cherry-pick, and lets the commit
through (with one line) when python or bash is missing. It never starts Godot; for a new
script or `class_name` it prints the `--import` reminder instead.

A failure warns and commits anyway (Jon, Nov 14, sweep 2 ruling 1A): it prints the failing
checks and a `WARNING` line and exits 0. `TK_GUARD_BLOCK=1` in the environment makes it refuse
the commit, as it did before; the merge gate runs the same checks and always stops.
