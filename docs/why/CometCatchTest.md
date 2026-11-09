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
