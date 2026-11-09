The reasoning behind `tkg/scripts/sim/ZoomClip.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Zoom clip

Above `const END := 23.0`:

```text
The sector map's camera, played as a player would and filmed with its sound:
  godot --path . --write-movie <out.avi> --fixed-fps 30 -- sheet=ZoomClip [seed=N]
Starts a run on the real shell and router, then on a fixed timeline: the
cursor sweeps the map (the scan blips), the wheel zooms in over a world (the
ticks), a drag pans, LOCATION zooms onto the ship, a beacon is opened (the
ship flies, the panel opens), and the wheel zooms back out. Quits at the end.
`--fixed-fps` makes every frame one thirtieth of a second, so the film runs
at true speed however slowly the frames are saved.
```
