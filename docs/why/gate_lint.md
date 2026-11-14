The reasoning behind `tools/gate_lint.py`, the check that the merge gate script is sound.

## What it catches

`.github/scripts/validate.sh` is built from `unit_<name>() {` functions and a few lists of unit
names. The scheduler finds the units with a `sed`, so a slip is silent:

- `unit_codecheck` was defined twice for a week. The list had it twice, so it ran twice, and
  nobody noticed. The check fails on any `unit_<name>() {` defined more than once.
- `SOLO_UNITS`, `FIRST_UNITS` and `AFTER_UNITS` must name defined units. (The scheduler already
  stops with exit 2 for one it does not find; this says so before a gate run, and in plain words.)
- Every label in `gate_weight` must be a defined unit (a trailing `*` matches a family, as in
  `solvetest_*`). A weight for a renamed unit does nothing, and the unit it was meant for starts
  late: a wrong weight costs minutes, never a result, so nothing else would ever say so.
- Every `docs/why/<file>.md#<anchor>` pointer in `validate.sh` must name a real heading.
  `tools/comment_check.py` already checks these in `.gd` files; this reuses its resolver for the
  gate script, which it does not read.

## No baseline

All of it is zero today and has to stay zero, so there is no baseline and no `--update`. If a unit
list names a unit that is gone, fix the list; if a why-pointer is dead, add the heading or fix the
pointer. There is nothing to record.

## What it deliberately does not catch

- Whether a weight is right, or a unit belongs in SOLO_UNITS: those are judgement calls.
- A unit that exists and is never reached (the scheduler runs every `unit_*` function).
- Pointers in files other than `validate.sh`: `tools/comment_check.py` has the `.gd` files.
