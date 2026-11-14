The reasoning behind `tools/tests_map_check.py`, the gate's test-map ratchet.

## What it catches

`docs/tests.md` is how a session knows which test to run after touching a file: it greps the file
for the class it touched and runs every row that names it. A harness with no row is invisible
there. A sweep found 38 working harnesses nobody ran for that reason. The check keeps the map
whole, with three kinds of fact:

- `uncovered <Stem>`: a runnable harness in `tkg/scripts/sim` that no row in `docs/tests.md`
  names. A new one fails with what a row is for and a template to fill in.
- `stale-row <name>`: a row that tells you to run `-- sheet=<Stem>` or `-- <flag>` that the game
  no longer has. A stale row sends a session after a test that is not there.
- `gate-missing <name>`: `.github/scripts/validate.sh` runs a `sheet=<Stem>` or a flag that no
  longer exists, so that unit tests nothing.

## What is runnable

Decided by what `tkg/scripts/DevFlags.gd` can start, not by the file name:

- A file named by a flag row (`{flag = "maptest", script = "res://scripts/sim/MapTest.gd"}`) is
  runnable by that flag. A row with a `fn` (`_holdtest`, `_savetest`, `_sim`) runs the harnesses its
  function body names.
- Any other file that is a Node (it extends `Node`, or a sim script that does, down the chain) and
  defines `_ready` is runnable as `-- sheet=<Stem>`: the `sheet=` row loads any such script and
  adds it to the tree. A helper such as `Harness.gd` (a RefCounted with no entry point), a
  `RefCounted` with no flag row, or a Node with no `_ready` is not runnable and is not checked.

## What counts as having a row

The stem (`MapTest`), its lowercase form (`maptest`), or a flag written as `-- <flag>`, anywhere
in `docs/tests.md`, as a whole word. A flag is matched only after `-- ` because several are common
words (`sim`, `fit`, `sky`, `wear`). A harness mentioned in passing in another row counts as named:
the check cannot tell a row from a sentence, so it asks only that the file is findable by a grep.

Said plainly: "has a row" means the harness's stem or flag appears as a whole word ANYWHERE in
`docs/tests.md`. A harness named after a common word can therefore count as covered by a sentence that
happens to use the word (the stem `Fit` is covered by any line that says "fit"; this is why flags are only
matched after `-- `, but stems are not). That is a weaker rule than "a row runs it", and it was chosen on
purpose: telling a row's command cell from prose needs a parse of a hand-written table that the check
would then have to keep in step with it, and a false "uncovered" blocks every commit, so the rule errs
toward covered. A harness with a common-word name needs its row checked by eye.

## How a key is formed

`uncovered <Stem>`, `stale-row sheet=<Stem>` or `stale-row <flag>`, `gate-missing ...`. No line
numbers. The baseline `tools/tests_map_check_baseline.txt` holds today's uncovered harnesses, about
sixteen look-and-dump tools (shots, dumps, sheets) left without a row on purpose. The gate fails
only on NEW entries; a fixed one is printed (`FIXED`) and does not fail.

## `--update`: when it is legitimate, and when it is cheating

Legitimate: you added the row, so the entry is gone and the baseline shrinks. Or the harness is a
look-and-dump tool that should not have a row: record it, and say so in the PR.

Cheating: a new test, a `-- sheet=` harness that guards behaviour, recorded instead of given a row.
The point of a row is that the next session runs the test; a test nobody runs is no test.

## What it deliberately does not catch

- Whether a row is TRUE (that it says the right thing to run after the right class).
- A row whose harness is named but whose command is wrong in other ways (a missing option).
- Flags that DevFlags reads by another route: a flag a script reads with `"flag" in args` outside
  DevFlags is treated as existing if the quoted name appears anywhere in `tkg/scripts`.
- Harnesses outside `tkg/scripts/sim`, and the shell tools under `tools/` (`tools/cofight.sh`).
