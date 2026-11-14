The reasoning behind `tkg/scripts/sim/ChartFilter.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Known only filter

Above `const OPENING_CEILING := 0.06`:

```text
What KNOWN ONLY actually shows you:
  godot --headless --path . -- chartfilter

The chart has two views and the useful one is the filtered view — the map you
have earned, as opposed to the map the generator built. That only means
anything if the filter is mostly filtering.

THE FAILURE IT EXISTS FOR is an exception that grows until it swallows the
rule. Stations are on the chart before you visit them, deliberately and for a
good reason, and the range that exception reached was the entire galaxy — so
KNOWN ONLY drew your four visited systems and every station out to the rim.
Nothing errored. The view simply stopped answering the question it is for, and
the only symptom was a screen that looked wrong to somebody who opened it.

Measured across seeded galaxies at three depths of exploration, because "the
filter is too loose" is a claim about a ratio and a ratio needs numbers.
```

## Outside sight

Above `func _outside_sight() -> void:`:

```text
Is anything DRAWN that is further off than the dish can see?

THE SHEET ABOVE COULD NOT ANSWER THIS. It counts `visited or station_heard or
at` -- three of the six reasons `StarchartScreen._visible_set` draws a dot --
so the one the player actually complains about, `sensed`, was outside what it
measured. It passed while the screen looked wrong, which is the same blind
spot shape as a fingerprint that omits a field.

Reported "I can see systems out of my view range", three times. Both rings are
drawn and the outer one is sight, so the question is not whether dots appear
beyond the ORANGE ring -- they should, that gap is what a dish buys -- but
whether any appear beyond the TEAL one.

MEASURED AFTER FLYING, which the first cut of this check did not do. A fresh
chart is the one state where `visited` is a single node and `station_heard`
reaches almost nothing, so measuring only there measures the case that cannot
fail. Every report has been a screenshot of a chart somebody had been flying.
```

Inside `_outside_sight()`, above `_ok("the dish never marks anything beyond its own radius (worst %d)" % worst,`:

```text
WHAT THIS IS AND IS NOT. `beyond` climbs to fifteen after twenty-five jumps
and that is CORRECT: it is where you have been, plus stations you have
heard, plus the core. None of those claim to be a current sighting, and
StarchartScreen draws them dimmed for exactly that reason.

The invariant is narrower and is about the DISH alone: `sensed` is set by
`chart_from` measuring a radius, so a `sensed` node outside that radius is
the radius not being honoured. Written as a reason test rather than a count,
because a count is not an identity -- "at most one" would also pass on the
day an ordinary system started leaking through and the core stopped being
drawn.
```
