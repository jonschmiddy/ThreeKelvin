The reasoning behind `tkg/scripts/sim/SystemProf.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## System profile

Above `const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")`:

```text
Where a frame of the system map goes: each layer switched off in turn.
  godot --path . -- sheet=SystemProf
VSYNC OFF AND NO CAP, from the first frame: with vsync on a windowed run
reads 16.7 ms for every row and the differences between rows are nothing.
(It set `max_fps = 0` only after the last row until Oct 27, where it did no
good.) The line at the end says what the rows ran under in a windowed run;
headless it always prints vsync=1, as the headless display server ignores
the call and reports ENABLED whatever was set.
```
