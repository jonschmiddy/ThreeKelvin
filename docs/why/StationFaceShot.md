The reasoning behind `tkg/scripts/sim/StationFaceShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Station face shot

Above `var _tree: SceneTree`:

```text
THE STATION'S SIDE ALONE, photographed (`StationFace`), its clocks frozen:
  godot --path . --windowed --position 3840,0 -- sheet=StationFaceShot out=<dir>
      [side=<id>] [interior=<id>|none] [powers=0,1] [clock=0.37] [dock=0]
The pair (plate behind, front over it) on a plain dark 960 x 540 picture, the
hallway at row 270, the star's light white, every clock stopped at `clock`
seconds: one PNG per power, `<dir>/face_<side>_<interior>_p<power>.png`. The
same frozen frame on two builds is the same picture, pixel for pixel, so a
diff of two runs says whether a change moved anything. Needs a window.
```
