The reasoning behind `tkg/scripts/sim/FlowShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Orbit clip

Above `func _orbit_clip(dir: String) -> void:`:

```text
`orbitclip=<dir>`: ONE PLANET TO ANOTHER, filmed through the real Router (run
with `--fixed-fps 30` so the frames play at true speed): in orbit of world A on
the map, LOCAL by the HUD's tab, the map again, a flight to world B, LOCAL
once. Every frame of the game's 960x540 view as `f_####.png`; then LOCAL's
sky at B bare (ships and labels hidden) as `sky/f_####.png` for the flicker
measure. Prints what LOCAL drew each time, the frame LOCAL first showed B on
and that frame's brightness against a settled one (a dark first frame shows).
```
