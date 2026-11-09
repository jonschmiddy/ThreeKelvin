The reasoning behind `tkg/scripts/sim/FogShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Fog shot

Above `const SHOTS := [0, 4, 12]`:

```text
What the chart actually looks like now that sight is live:
  godot --path . -- fogshot

NEEDS A WINDOW. `--headless` never emits `frame_post_draw`.

THE SIMULATOR CANNOT SEE THIS CHANGE. Its policy chooses from what is
reachable this instant and never plans a route, so an accumulated chart is
worth nothing to it -- live sight moved win rate by one run in five hundred.
What a chart is FOR is planning, and the only way to judge it is to look.

Three shots: the first frame, a few jumps in, and deep. What to look for is
whether the lit part is enough to choose from -- a spawn in a sparse region
is the stated worry, and `_map_range_from` being relative to the nearest
neighbour rather than absolute is the reason it may not be.
```

## Fog shot framing

Inside `run()`, above `for i in 20:`:

```text
ZOOMED, AND CENTRED ON THE SHIP. The default view centres the GALAXY,
and the ship spawns on the rim -- so the one thing these shots are of
sits off the edge of the frame.
AFTER the screen has settled. `show_starchart` builds a fresh screen and
its deferred fit sets zoom and pan itself, so anything set before that
lands is simply overwritten.
```
