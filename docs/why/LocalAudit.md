The reasoning behind `tkg/scripts/sim/LocalAudit.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Local audit

Above `const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")`:

```text
LOCAL IN EVERY STYLE AND STATE, in one window (`LocalShot` and `CutawayShot`
take one state a run; this walks the whole matrix in one process, for the
polish audit and its before/after):
  godot --path . --windowed --position 3840,0 --fixed-fps 30 -- sheet=LocalAudit
      out=<dir> [styles=simplified,painted,radiant] [cases=<name>,...]
      [clipframes=45] [cut] [nocut] [noblur]
Each case: a new run (its seed), the ship parked as the sector map leaves it,
LOCAL shown, then <dir>/<style>/<case>.png (the game's own 960x540 frame),
<case>_clip/f_####.png (the sky and the dust, ships and words hidden, every
frame for `frames.py`), and with `cut` (the default for the cases marked so)
the cutaway pushed in on your ship: <case>_cut/f_####.png every frame of the
push-in and 30 held after it (its ship, parts and panel hidden), the scene as
the player sees it behind the cutaway (`noblur`: the blur held off, to see
what the zoom itself draws). The clocks step 1/30 s a frame; run with
`--fixed-fps 30` so the frames play at true speed. Needs a window.
```
