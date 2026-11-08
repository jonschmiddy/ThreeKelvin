The reasoning behind `tkg/scripts/sim/AshTeachCostTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Teaching frame cost

Above `const MAX_MS := 100.0`:

```text
WHAT HER TEACHING COSTS A FRAME, headless, through the real screens:
  godot --headless --fixed-fps 60 --path . -- sheet=AshTeachCostTest

Jon, Oct 20: "When opening the starchart for the first time, and A.S.H. is
reading the tutorial tip, the game becomes SUPER laggy and unresponsive. The
game comes back after she's done talking." Measured on a 410-system chart:
840 ms a frame (2.3 s at most) while her line on the chart's list was up,
against 6.9 ms with it gone. The cause was `Ash.covers`, the check that her
box covers nothing a click picks, asked every tenth of a second while a
teaching line is up (`_lesson_must_go`): it asked the chart's `_node_at` at
every 3 px of her box, about 1,500 points, and each of those rebuilt the
visible set over every system (0.8 ms): 1.2 s a check. It asks the systems
near her box once now (`MapChart.nodes_near`), 1 ms.

THE CLAIM, in the order a first run meets it: a run under way (her
introduction heard, the launch's step said), the chart opened with nothing
left to teach there, and its frames timed; then the hints reset, the chart
opened again, and every frame timed while she says its list's line, types
it and holds it, and while she says the goal's step after it. No frame over
MAX_MS, and the mean within MEAN_SLACK of the chart with her silent.
THE SAME ANSWER: `covers` finds exactly the system the old point-by-point
scan found, on her box, on every spot she can stand in, and on boxes swept
over the chart, hits and misses both.

Times frames against the wall clock, so it is one of the gate's SOLO_UNITS.
```
