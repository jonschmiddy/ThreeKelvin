The reasoning behind `tkg/scripts/sim/ChartShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Chart shot options

Inside `run()`, above `for a1 in OS.get_cmdline_user_args():`:

```text
`kind=N` photographs a CHOSEN galaxy instead of a rolled one, which is the
only way to look at a new shape without rerolling seeds until it turns up.

The map is regenerated after the swap rather than left alone. Node
positions read `reach`, `squash` and `ring` off `Run.galaxy`, so a chart
painted as one kind with systems laid out for another is a picture of a
galaxy that does not exist -- and the layout is half of what a new kind
has to be judged on.
```

Inside `run()`, above `for a0 in OS.get_cmdline_user_args():`:

```text
`flown=N` marks N systems visited before the chart opens.

A FRESH CHART CANNOT SHOW THE BUG. Everything on it is currently sensed, so
the "remembered" treatment has nothing to apply to and a screenshot of it is
evidence about the wrong state. Every report of "systems beyond my range"
has been a chart somebody had been flying for a while.
```

Inside `run()`, above `if "quest" in OS.get_cmdline_user_args():`:

```text
`quest` places one and photographs the marker.

A PLACEMENT CANNOT BE SET UP ANY OTHER WAY. It is the consequence of an
option resolution four jumps back, so there is no state to pose -- the only
honest setup is to make the call the outcome would make and let it choose
its own target the way it will in a real run.
```

Inside `run()`, above `var scp := Router.current as StarchartScreen`:

```text
THE PRIMER IS UP IN EVERY SHOT UNLESS IT IS TAKEN DOWN. It shows on the
first chart open of a run, and `flown=N` marks systems VISITED without
appending to `trail` -- so a harness run is always a first open, however
far it has notionally flown, and the card would sit over every photograph
ever taken of this screen.

`primer` keeps it up, to photograph the card itself.
```

Inside `run()`, above `var screen_h: float = sc0.get_viewport_rect().size.y`:

```text
JUMP IS THE CONTROL THIS SCREEN EXISTS TO REACH, so where its
bottom edge sits against the window is the assertion, not the
decoration. Anything at or past the height is off the screen.
AGAINST THE VIEWPORT, not against the panel. `global_position` is
in the viewport's frame and `sc0.size.y` is the panel's own height,
which starts below the HUD bar -- comparing them said the button
was thirteen pixels off the bottom of a screen it was plainly on.
```

Inside `run()`, above `for a in OS.get_cmdline_user_args():`:

```text
`zoom=N` frames it the way the PLAYER looks at it: centred on the ship,
close enough that both range rings are on screen.

The galaxy-wide shot above cannot answer a question about the rings at all
-- `_ring` gives up under six pixels of radius, so at full zoom-out neither
one is drawn and a screenshot of that view is evidence of nothing. Both
reports of "I can see systems outside my range" came from this framing.
```
