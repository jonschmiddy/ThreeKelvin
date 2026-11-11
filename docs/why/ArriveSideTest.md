The reasoning behind `tkg/scripts/sim/ArriveSideTest.gd`; each heading is referenced from the code by a `Why:` line.

## Arrive side test

Above `extends Node`:

```text
The side and way round a flight arrives (Jon, Nov 10, "S3"), headless at a
fixed 60 fps. Two parts:

THE REAL MAP (seed 4242, the first one-sun system with two worlds, the ship
parked in orbit of the first):
- the second world selected, the pointer put on its lit half (a mouse motion
  through `_on_map_input`): the hover reads side +1, the map asks the autopilot
  for side +1 and the spin's sense, the tag reads "LIT SIDE · WITH ITS SPIN"
  and "HOLD SHIFT: AGAINST ITS SPIN", the preview drawn is that flight; the
  click (`tap` on the overlay's own hit) flies it and the ship arrives on the
  lit side (`ArriveSide.side_now`, the solver's own margin) going round with
  the spin (`rail.dir`);
- Shift pressed as a key through the input system (forced for the harness
  only if that does not take), the first world's dark half the same way: side
  -1, against the spin, the tag's "DARK SIDE · AGAINST ITS SPIN" and "LET GO OF
  SHIFT: WITH ITS SPIN", arrived dark and against;
- the pointer off the world: no wish at all.

THE SOLVER ALONE: over seeds 4242 and 7, the first 3 one-sun systems a seed
with two worlds and 1 twin a seed, from every world's ring to every other at
2 line-ups, the game's own target (`ShipFlight._tgt_of` with the wish set,
`flight_opts` for the path and pace): free, lit, dark, with, against, and dark
against. Judged: every sided flight found lands on its half, 0.05 clear of the
terminator by the map's own light at its arrival; every sensed one goes its
way; each ask found and flown clean in at least FOUND_MIN (90%; measured 100%).
Printed, not judged: click to arrival (median, p90, worst) per ask, and against
the free flight for the same pair (median and p90 of the difference, how many
are over a second longer), how many fell back to any side, and the solve time.

`shots=<dir>` (windowed, through render.sh) writes hover_lit, arrived_lit,
hover_dark and arrived_dark PNGs. `map=0` or `solver=0` skips a part;
`systems=N` sets the one-sun systems a seed.
```
