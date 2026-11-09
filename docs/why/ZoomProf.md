The reasoning behind `tkg/scripts/sim/ZoomProf.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Zoom profile

Above `const ScreenS := preload("res://scripts/ui/sysmap/SystemMapScreen.gd")`:

```text
Where the sector map's frame time goes while the camera moves:
  godot --path . -- sheet=ZoomProf [node=I] [seed=N]
Shows a system on the real screen and, for each test, runs 240 frames:
held still, zooming in and out without stopping, and panning without
stopping. Prints the frame time (mean and slowest tenth), the CPU in the
map's own GDScript by part, and the GPU time of the map's two pictures.
`wev=<name>` (or `a+b`, a pair) holds that weather event at its height (`SkyWeather.PEAK`)
through every test, after a still run with no weather at all, and prints
what it added to the scene's GPU time.

FOUR GPU COLUMNS, AND THE LAST TWO WERE ONE MISLABELLED ONE. The sheet runs
inside the game's SubViewport (`GameShell.view`), so `get_viewport()` here
is the game's 960x540 frame, not the window: the column printed as "window"
until Oct 27 was the game view. The window (`get_tree().root`, the shell's
glass and its passes at the window's own size) is read on its own now.
VSYNC OFF, as `chartbench` learned: with it on, every frame time is the
monitor's 16.7 and the frame columns measure nothing.
```
