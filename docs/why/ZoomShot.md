The reasoning behind `tkg/scripts/sim/ZoomShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Zoom shot

Above `const ZOOMS: Array[float] = [0.42, 0.8, 1.5, 2.5, 4.0, 6.0]`:

```text
The star chart at a ladder of zooms:
  godot --path . -- zoomshot

NEEDS A WINDOW. Under `--headless` the dummy display server never emits
`frame_post_draw`, so nothing is ever captured and it looks like a hang.

IT EXISTS BECAUSE THE BUG IS A SHAPE, NOT A NUMBER. The report is that the
galaxy sits inside a boundary, and that zooming IN makes that boundary
smaller -- which is backwards, and not something a frame time or an assert
can see. Six shots at a fixed seed, so the only thing that changes between
them is `zoom`.

Seeded with `Rng.forced`, NOT `Rng.reseed`: `start_new_run` rolls its own
master seed, so a reseed before it changes nothing and every run draws a
different galaxy. ChartFilter learned this first.
```

## Density step

Above `func _profile(img: Image, chart: Control, z: float) -> void:`:

```text
How many pixels are lit, as a function of distance from the galaxy's centre.

A DENSITY STEP IS A VISIBLE EDGE. `_star_layer` drops 88% of the foreground
stars inside `disc` and none outside it, so there is a hard circle at that
radius where the sky abruptly gets busier. On a smooth image this profile
falls away steadily; a step in it is the boundary, and where the step lands
says which radius drew it.
```
