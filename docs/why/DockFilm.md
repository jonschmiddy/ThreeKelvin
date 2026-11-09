The reasoning behind `tkg/scripts/sim/DockFilm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Dock film

Above `var _tree: SceneTree`:

```text
THE DOCK, FILMED WITH ITS SOUND (`ZoomLadder` 3B, `SectorScreen.ladder_cam`,
the station's elevator after it):
  godot --path . --windowed --resolution 1920x1080 --fixed-fps 30
      --write-movie <dir>/dock.avi -- sheet=DockFilm [route=local|map|first|undock]
      [seed=N] [weight=light|medium|heavy] [rm]
A run beside a station, the ladder on, its clock stepped by the game's own
(`GameClock` through `--fixed-fps`, never the wall's): LOCAL beside the
station (`route=local`, the default: DOCK pressed on LOCAL's bar) or the map
parked at the station (`route=map`: the map's DOCK card, down to LOCAL and on
in), then the dock through to the berth and two seconds of it at rest, and
quit; `route=first` films instead the arrival a run's first system plays,
at the same station, for laying the dock's beside (`[ship]` lines: every
frame of an arrival, your ship's place and size; the AVI's frame is `drawn`),
quit (`stills=<dir>`: the frame before it and 0.5 s and 1 s into it, at
2x). `undock` then undocks (`stills=` 0.5 s, 1 s and 1.5 s after LOCAL
comes up, at 2x); `route=undock` films the undock alone: docked at once (no
dock played), four seconds of the berth, then UNDOCK. `rm` docks under
reduced motion. A half-speed film is this one slowed
by the encoder, so its sound stays on its pictures. Prints the frame each
step began on. Needs a window.
```
