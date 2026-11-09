The reasoning behind `tkg/scripts/sim/StationSideShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Station side shot

Above `var _tree: SceneTree`:

```text
THE STATION SIDES ON LOCAL, photographed (`StationSides`, `StationFace`):
  godot --path . --windowed --position 3840,0 --fixed-fps 30 -- sheet=StationSideShot
      out=<dir> pairs=drum3:iris_90_0,pile1:cargo_130_0,... [seed=N]
For each side:interior, LOCAL at the run's first station with that side and
interior forced, built afresh, at rest: `<side>__<interior>__rest.png` (the
lights standing by, as you find it) and `<side>__<interior>__on.png` (every
lamp on, as the dock leaves it before the camera moves), the game's 960 x 540
picture. Also writes `<side>__<interior>__bay.json`: where the plate's
top-left is on the picture, for crops. Needs a window.
```
