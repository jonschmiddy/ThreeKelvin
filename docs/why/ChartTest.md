The reasoning behind `tkg/scripts/sim/ChartTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Sky cache test

Above `var fails: int = 0`:

```text
Correctness and cost of the star chart's shared sky cache.

  godot --path . -- charttest        (needs a window: it renders)

RUN THIS AFTER ADDING ANYTHING TO _build_stars OR ITS SUB-BUILDERS.

The cache saves and restores a named list of fields, MapChart.SKY_FIELDS, and
there is exactly one way for it to go wrong: a builder gains a new output and
nobody adds it to that list. Nothing errors. The field simply keeps whatever
the previous galaxy left in it, and the chart draws last run's dust lanes
over this run's stars — on the second visit only, which is the kind of bug
that gets blamed on anything but the cache.

So this compares a RESTORED sky against a freshly BUILT one, field for field.
Screenshots cannot answer the question: SkyAnim redraws every frame, so two
captures of an identical sky differ anyway.
```
