# OrbitPreviewTest

## Orbit preview test

Above `var h := Harness.new()`:

```text
THE ORBIT MAP MUST MATCH WHAT THE PLAYER FINDS (Jon, Nov 22, destination panel B).

For a few seeds, run A reads every system's orbit map (ChartOrbits.signature, from
SystemLayout.of) before anything is visited, then arrives at each the way the game
settles an arrival (Router.settle_arrival: options rolled, ambush rolled, goals posted)
and reads the layout the sector map draws there. Run B, the same seed, arrives at each
without looking first. All three must agree, so the preview is right and looking at it
moves nothing. Jobs are signed off the first station's board first, so a job's place is
compared too; the sweep fails if it never saw a twin, a red or blue hypergiant, a
pulsar, a station and a job.

Then the fog (nothing out of sight, nothing for the core, always where you stand) and
the panel itself: the in-range list with nothing picked, the orbit map and no list with
a star picked, and the list again once cleared.
```
