The reasoning behind `tkg/scripts/sim/BandDropTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Band drop

Above `var _tree: SceneTree`:

```text
THE EVENT BAND'S DROP NEVER JUMPS. It moved up to 29 px a frame: a cubic
ease-in ends at three times its average speed. Measured every frame here:
  godot --headless --fixed-fps 60 --path . -- sheet=BandDropTest

The shortest, a middle and the longest event in the table, each opened on
LOCAL's band, its text finished, then NOT NOW. Every frame of the drop the
band's top edge moves no more than `LocalEventDrawer.DROP_MAX_PX`, the band
is gone at the end, and the bar under the view (parked while the band was
up) eases back up only after it has gone (Jon, Oct 14).

`film` (in a window, with --write-movie and --fixed-fps 60) runs the middle
event only and prints `mark drop <frame>`.
```
