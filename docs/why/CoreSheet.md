The reasoning behind `tkg/scripts/sim/CoreSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Core sheet

Above `const CoreView := preload("res://scripts/ui/sysmap/CoreView.gd")`:

```text
THE CORE, as the GPU paints it, over a test sky at several moments:
  godot --path . -- sheet=CoreSheet coreout=<dir> [coretimes=1,4.3,9.7] [coreraw] [corebench=120]

Drawn in its own 960 x 540 viewport, the game's, with the hole where the
system map puts it (622, 262). The test sky is a grid every 24 px, hashed
stars and a few dim purple tiles -- the same function as the scratchpad's
`core/ref.js`, which draws the mockup's `coreDraw` over it, so the two can
be set side by side pixel for pixel. Writes `core_<t>.png` per moment
(341 x 331, the lens's whole patch) and `sheet.png`, the moments in a row.
`coreraw` writes the renderer's own picture instead (330 x 210, no glow, no
lens: the mockup's `BH.draw`). `corebench=N` then times N frames with the
hole and N without, and prints the cost. Needs a window: a shader draws
nothing headless.

ZOOM: `corezoom=1,1.5,2,3,4,2.6` takes the hole through those zooms in turn
at the first of `coretimes`, in a 1440 x 1380 viewport over the test sky
(not magnified: the map's sky keeps its stars single pixels zoomed). For each
k: `standin_<k>.png`, the frame drawn just after the zoom changed (the
nearest kept trace stretched), when k was not kept yet, and `zoom_<k>.png`,
once its own trace is in; each the lens's patch, 340k + 1 x 330k + 1. Then
`zoomsheet.png`, the settled 1, 2, 3, 4 side by side at their own sizes,
`standins.png`, each stand-in beside its settled frame, and the times.
`corek=K` with `corebench=N` times the hole at zoom K where the map puts it,
(480, 270) in the 960 x 540 picture (`corestack` as before), and takes no
pictures. `coretracetime=1,2,3,4` times the trace itself at each zoom: its
GPU time and its read back.
```
