The reasoning behind `tkg/scripts/sim/WowClip.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Wow clip

Above `const ScreenS := preload("res://scripts/ui/sysmap/SystemMapScreen.gd")`:

```text
THE SECTOR MAP'S KEPT POLISH, filmed before and after at the same moment:
  godot --path . -- sheet=WowClip out=<dir> [kind=ordinary|red|blue|nebula|station|node:<i>]
    [seed=N] [zoom=Z|open] [aim=star|world|belt|<i>] [t0=S] [secs=8]
    [wow=glints,orbitdepth,sunfix] [ab] [cost=N] [zoomto=Z2|open] [style=...]
Opens the system on the real map screen (as `SystemSheet`'s sweep does: Main's
frame and theme, the weather and the far novae held off), aims the camera,
and films `secs` seconds at 30 frames a second with the map's clock stepped a
thirtieth a frame: `<out>/f_NNNN.png`, the map window in game pixels. With
`ab` it films them before and after, interleaved frame by frame at the same
clock (`<out>/before/`, `<out>/after/`): the things named in `wow=` taken out
for the before -- the belts' glints (`SystemView.belt_glints`), the orbits'
near half (`SystemView.orbit_depth`), the sun's zoom cap past 4
(`SunView.k_max` 4 before, 9 after) -- so the two differ only by them.
`zoomto=Z2` eases the zoom from Z to Z2 over the clip (zooming must only
magnify). `cost=N` then times N frames before and N after, four times over,
alternating, the clock running: the place picture's GPU time, the window's,
and the map's own CPU time (its profiler). `list` prints every system's
bodies, headless. Needs a window (but for `list`).
```
