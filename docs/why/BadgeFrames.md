The reasoning behind `tkg/scripts/sim/BadgeFrames.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Badge frames

Above `var _tree: SceneTree`:

```text
THE CUSTODIAN'S BADGE, FRAME BY FRAME, as the game draws it, headless:
  godot --headless --path . -- sheet=BadgeFrames out=<dir>

Each frame from the real badge on the real goal line (a run up on LOCAL, the
HUD's own `GoalLine`, its `CustodianBadge` held to a fixed clock and asked
for the Image it shows), at 1x on a transparent 40 x 15 PNG, with the badge's
left edge at x 0 and its middle row at y 7:
  jumps 1, 10, 15, 16, 18, 20, 28, 35   idle frames 0 to 15 (j<jump>_idle_<n>.png)
  jumps 12, 16, 20, 25, 33              every step of the arrival, then the
                                        first idle frame (j<jump>_arrive_<s>.png)
and manifest.json (each file's jump, t, since and what it is). The same names
and clock as `tools/dev/badge/dump_golden.py frames <dir>` writes from the
approved page, so `tools/dev/badge/diff_frames.py <game> <web>` compares them.
```
