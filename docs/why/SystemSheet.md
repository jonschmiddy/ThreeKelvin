The reasoning behind `tkg/scripts/sim/SystemSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## System sheet

Above `const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")`:

```text
The system map's picture for real systems of a real run, one PNG each:
  godot --path . -- sheet=SystemSheet out=<dir> [seed=N] [systime=S]
A red giant, an ordinary sun, a blue giant, a station, a system in a nebula,
a pulsar and the core, as `SystemLayout` lays them out and `SystemView`
draws them. Needs a window.

THE ZOOM SWEEP, through the real map screen (`SystemMapScreen`, the overlay,
the orbits and the labels as play shows them):
  godot --path . -- sheet=SystemSheet sweep=<dir> [style=...] [kinds=red,nebula,...]
    [zframes=120] [oframes=90] [pframes=60] [only=stills,zoom,zoomw,orbit,pan]
For each system kind, in `<dir>/<kind>/`:
  `z<k>.png`      stills at zooms from the whole system to the closest the
                  wheel reaches (`ZOOM_MAX`), and past both ends as the zoom
                  ladder carries the map (`l_out.png`, `l_in.png`), centred
                  on the star; `w<k>.png` held on the system's biggest world
  `zoom/`         a slow zoom from the whole system to ZOOM_MAX, about the
                  star, every zoom between (the wheel's ease passes through
                  them all), the clock stopped: only the camera moves
  `zoomw/`        the same held on the biggest world (as LOCATION holds it)
  `orbit/`        in orbit of that world at zoom 3.2, the clock (and the
                  gas's) running a 30th of a second a frame
  `pan/`          a slow pan at zoom 2.5, the clock stopped
  `slow<k>/`      a tenth more zoom over 60 frames at the whole system, 1, 2
                  and 3.6 about the star (0-3) and 2.5 about the world (4):
                  the project's flicker measure (flip-back under 0.0035)
Each clip folder has `f_NNNN.png` (the map window, game pixels) and
`meta.json`; `times.json` holds each still's frame time (ms, real clock).
The weather and the far supernovae are held off and the room's sound is
stopped, so two builds' clips differ only by what they draw.
```

## Frame cost

Above `func _cost(scr: Control, n: int) -> Dictionary:`:

```text
The frame's cost at the camera as it is, over n frames (the real clock is held
to the display's rate, so it is measured as work): the map's own place
picture on the GPU, the game's 960x540 frame on the GPU, the window's own
pass on the GPU, and `cpu`: the engine's `TIME_PROCESS` read every frame
and averaged. That is NOT a frame's process time: the engine sets it once a
second, to that second's worst process plus draw (`main.cpp`), so `cpu` is
a slow-moving worst that may still hold the last switch's stall, comparable
only with itself. (`MacBench` reads it once per sample and times each
frame's scripts on the engine's signals instead.)
(`game_gpu` was `window_gpu` until Oct 27, and was never the window: this
sheet runs inside the game's SubViewport, so `get_viewport()` is the game
view. The window is `get_tree().root`, read as `root_gpu`.)
```
