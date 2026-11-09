The reasoning behind `tkg/scripts/sim/CometFlightTest.gd`; each heading is referenced from the code by a `Why:` line.

## Comet flight test

Above `extends Node`:

```text
The comet's spots as flights (Phase 13, `CometCatch`). A comet is forced into
every system that may hold one (`CometPath._force`), up to SYSTEMS a seed over
four seeds. From every world's orbit, at a seeded angle, at the map time the
comet comes in (`t_in`), each spot still ahead of it is planned as the catch
plans it (`CometCatch.target`: a keep at a still point). One in four is flown on
the ship's own clock, held HOLD_S on the spot, and the comet met there.

It is its own harness on purpose: FlightTest is untouched, so every existing
sweep, shard and limit stays as it was (the DIRECT twin 90th at 6.1 s among
them). Its own numbers are printed for Jon to set its limits: click to settled
by spot (median, 90th, worst), how many could be made from the moment the comet
comes in, and planning time.

What it judges now: found and clean in FOUND_MIN (FlightTest's 99%), settled
within END_PX (0.5 px) and held there, the comet passing within a pixel of the
waiting ship, and never inside a sun's keep-out by more than the planner's own
BURN_PAD.
```
