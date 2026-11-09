The reasoning behind `tkg/scripts/sim/ChartBench.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Chart bench

Above `const FRAMES := 240`:

```text
What the star chart costs, still, dragged and zoomed:
  godot --path . -- chartbench [style=painted|radiant] [graphics=low] [calm] [kind=N]

NEEDS A WINDOW, like every other measurement of drawing in this project:
under `--headless` the dummy display server never emits `frame_post_draw` and
the numbers are of a renderer that is not running.

IT EXISTS BECAUSE "IT FEELS LAGGY" IS NOT A NUMBER. The chart holds 60fps
standing still and drops while the galaxy is dragged, which points at
`_repaint_galaxy` — the one thing a drag does that resting does not. This
times the states against each other so a fix can be shown to have worked
rather than argued to have.

Measured in FRAME TIME rather than fps, because fps is a rate and the thing
being fixed is a cost: 60fps to 40fps sounds like a third gone and is
actually 8ms of work added to a 16ms budget.

FRAME TIME ALONE CAN HIDE THE COST. When the driver holds the swap to the
display, a frame that costs 3ms and one that costs 15ms both read 16.67, so
each sample also prints what the chart's layers spent in GDScript drawing
(`MapChart.prof`) and what the GPU spent on the game's frame.
```

## Bench input

Inside `run()`, above `tree.root.gui_disable_input = true`:

```text
NOTHING FROM THE KEYBOARD OR THE MOUSE, while it measures. The window takes
focus when it opens, and this bench holds one chart for some five hundred
frames: a Tab from whoever is at the machine cycles to the ship screen, a
click on a HUD tab swaps the screen, and either frees the chart under the
next nudge -- the "previously freed" crash at the drag sample. Nothing in
the chart or the router frees it on its own; one Tab sent to a bench-like
run did it every time, and with input off here it did not.
```

## Bench seed

Inside `run()`, above `Rng.forced = 4242`:

```text
Rng.forced, NOT Rng.reseed -- see ChartFilter, which already learned this.
start_new_run rolls its own master seed, so a reseed before it changes
nothing and every run of this bench drew a DIFFERENT galaxy: 157, 244, 332
and 356 systems across four runs, with the title screen swinging from 5.6
to 36.1 ms. Comparing an optimisation against numbers like that is
measuring the galaxy, not the change.
```

## Bench title screen

Inside `run()`, above `var run_galaxy: Dictionary = Run.galaxy.duplicate(true)`:

```text
THE TITLE SCREEN FIRST, because it draws the same galaxy and is where the
worst frame rate was reported. It is also the screen a player sees before
anything else, so a slow one is the game's first impression.

Its galaxy is rolled off the global generator, once a process, so it is
seeded here or the title would be a different galaxy -- and a different
number -- every run of the bench.

AND THE RUN'S GALAXY IS PUT BACK AFTER. The launcher writes its own into
`Run.galaxy` (it expects no run to be live), so every chart sample after
it used to measure the TITLE's galaxy at the chart's size: 70k primitives
one run, 100k the next, from the same seed.
```

## Bench sampling

Above `func _sky_rid(chart: Node) -> Array[RID]:`:

```text
Mean frame time over FRAMES, optionally moving the view every frame.

The first frames of either state are discarded: the first drag frame pays for
whatever the still state had cached, and counting it measures the transition
rather than the state.
The chart's sky draws into a viewport of its own (`ChartSky`), whose GPU
time the game's viewport does not include: measured beside it.
(The simplified sky is three viewports -- stars, place, composite -- and
all three are counted; the painted sky a fourth, its band memory.)
```
