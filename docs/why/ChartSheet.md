The reasoning behind `tkg/scripts/sim/ChartSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Chart sheet

Above `var out := "user://chartsheet"`:

```text
The star chart and the title screen's galaxy, photographed at fixed states:
  godot --path . -- sheet=ChartSheet out=<dir>

FOR PROVING A CHANGE TO THE CHART'S DRAWING CHANGED NOTHING YOU CAN SEE. Run it
before the change and after, into two folders, and diff the folders. Every
state is reached the same way both times -- the same seed, the same zooms,
the same drag a frame at a time -- and the sky's clock is held on a chosen
moment through `MapChart.clock_override`, so even the galaxy's turn, the gas
and the swirl round the hole are compared at the same instant.

The states: the chart as it opens; a ladder of zooms on the core from the
minimum to the maximum; the ship framed; the wheel in and out about a point
off centre (which pivots the sky); drags short, long, by fractions of a pixel,
zoomed in and at the minimum (the old sky's slide margin set their lengths);
the core at several moments, the galaxy turned to each of them, a
pulsar's flash and a gamma-ray burst in each of the places one can happen; a
system pointed at, one selected and a cloud pointed at, which are the chart's
own drawing rather than the sky's; the escape menu's inset; and the title
screen's galaxy, turned and not.

Each PNG is the chart's own rect cut out of the frame it is drawn in (the
title shots are the whole 960x540 frame, with everything but the galaxy
hidden). `out` defaults to user://chartsheet.
NEEDS A WINDOW: the renderer has to run for there to be pixels.
```

## Zoom sweep

Above `func _sweep() -> void:`:

```text
THE ZOOM SWEEP (`sweep`): every zoom the player can reach, not just the
wheel's notches, at five places -- the core, YOU, the first cloud that is not
dark, a point out in the arms and the rim -- `sweepn=` steps (default 25)
evenly spaced in log zoom from ZOOM_MIN to ZOOM_MAX, so the in-between values a
glide passes through are in it too. `s_<place>_<i>_<zoom>.png`, for finding
what goes wrong as you zoom: holes, seams, dust that thins or flattens.
```
