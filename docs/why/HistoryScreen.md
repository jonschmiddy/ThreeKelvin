The reasoning behind `tkg/scripts/ui/HistoryScreen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Flight record

Above `var _back: Callable`:

```text
Every run you have finished. Career totals across the top, then the runs
themselves newest first.

Reachable from two places with one class: the HUD during a run, and the
launcher before one. `setup()` takes the way back rather than deciding it,
because the screen genuinely does not know which door it came through.

A run is summarised by where it ENDED and how deep it got, not by how long it
lasted. Depth in shells is the honest measure — jump count rewards farming
the rim, which is the reading this game least wants to encourage.
```

## Seed line

Inside `_row()`, above `var run_seed := int(e.get("seed", 0))`:

```text
The seed, on its own line and in the dimmest colour on the screen. It is
not a stat — nobody is comparing seeds — it is a thing you copy down when a
run was worth flying twice, so it wants to be findable and not loud.

Runs recorded before this existed have no seed and get no line, rather than
a zero pretending to be one.
```
