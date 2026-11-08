The reasoning behind `tkg/scripts/sim/SunSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Sun sheet

Above `const SUN := preload("res://scripts/ui/sysmap/SunView.gd")`:

```text
The system map's ordinary, red and blue suns on one sheet, as the GPU paints
them (`SunView` + `sun.gdshader`), each in the mockup's 420x300 box on black:
  godot --path . -- sheet=SunSheet sun_out=<png> [sun_cases=<txt>] [sun_t=S]
      [sun_from=S] [sun_bg=#rrggbb]
  godot --path . -- sheet=SunSheet sun_bench=1 [sun_copies=N] [sun_zoom=K]
  godot --path . -- sheet=SunSheet sun_out=<png> sun_zooms=1,2,3,4 [sun_cases=<txt>]

The default cases are the mockup page's own suns -- system 0 (index 18, a red
giant), 3 (index 311, ordinary) and 6 (index 1023, blue) -- then a few other
systems of each kind chosen so that every look in each kind's pool appears.
A cases file has one sun a line, `KIND:system_index:radius:t`, for setting
beside the mockup's own render of the same suns (scratchpad `sun/mkref.py`).

`sun_bench=1` puts N copies (default 20) of one sun at a time where the map
puts it, in a 960x540 view with vsync off, and prints what one sun adds to
the frame and to the view's GPU time over 120 frames, and what `step` costs
on the CPU. Copies, because one sun is lost in the noise of a frame.

`sun_zooms=` draws each case once a row at every zoom listed (`set_zoom`),
each in its whole zoomed box (420k x 300k), left to right. `sun_zoom=K`
benches the suns zoomed.
Needs a window: a shader draws nothing headless.
```
