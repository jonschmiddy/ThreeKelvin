The reasoning behind `tkg/scripts/sim/CometCatchTest.gd`; each heading is referenced from the code by a `Why:` line.

## Comet catch test

Above `extends Node`:

```text
The catch on the real map, headless at a fixed 60 fps (Phase 13, Jon's C). In
a one-sun system with a comet and its reading, the ship in orbit of a world
as the comet comes in:

- all three spots are planned (YOU) beside the comet's IT;
- the comet's page offers its spots with IT and YOU in their words;
- a spot is flown to, and the ship settles on it within 0.5 px before the comet;
- as the comet reaches it, the map goes down to LOCAL with the reading open,
  met at that spot (`CometPath.caught_at`, `LocalEventDrawer.here_now`);
- back on the map the ship is on its spot, not at the system's edge;
- TOO LATE: the far spot once the comet has passed it, and the star spot a
  second before the comet with the ship seconds away. Neither is flown to.
```

## One pass

Above `func _pass_once(n: MapGen.MapNode, opt: int) -> void:`:

```text
Jon, Nov 21: "When you finish a comet mission it keeps passing by over and over
and over." LOCAL's close pass (`LocalComet._step_pass`) started again whenever
its reading was "open here", and `LocalEventDrawer.open_here` keeps naming the
last event opened at the bar even once it is taken, while the spot stays caught
for the visit. So every 5 s (ARRIVE_S + LEAVE_S) the comet came in, saw the
reading taken, went out, and came in again.

LOCAL builds no sky headless, so the test makes the real `LocalComet` on a stub
sky that holds only the node, steps it until the pass comes alongside, marks
the reading taken (the rule reads `node.taken`, as OptionResolve leaves it),
then steps 15 s, room for three more passes, and counts any that start. A fresh
`LocalComet` (LOCAL opened again) must not start one either. It reopens the reading after so
the TOO LATE checks, which plan spots only for an open reading, still run.
