The reasoning behind `tkg/scripts/sim/YardSeatTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Yard seat

Above `const LEVELS := {"unclaimed": MapGen.Development.UNCLAIMED, "outpost": MapGen.Development.OUTPOST,`:

```text
EVERY HULL ON ITS STANDS, headless (`YardScene._stand`):
  godot --headless --path . -- sheet=YardSeatTest
Jon, on the medium Korvan in the yard: "The ship needs to sit lower. Like
actually be on the stands and centered on them. It's too high and to the
left." For every hull frame the game has (each manufacturer's three, the
three salvage frames) at every grade, on every level's stands, measured off
the pictures themselves and not off the numbers `_stand` kept:
  - ON THE STANDS: across each cap (the stand's columns that reach its seat
    row), no floor shows between the hull's lowest pixel and the stand's top;
    the hull's lowest pixel over one of the two caps lies exactly on its
    contact row (`seat - 1`, plus `sink` rows where a step in the belly
    needed it, never more than `SINK_MAX`), and over the other it is on
    it or below it (a fin, a pod, that stand standing up behind it), never
    above;
  - CENTRED: the two caps' middles stand within 1 px either side of the
    hull's mass middle (its opaque pixels' balance, column by column);
  - the two stands one height (Jon: "Why are the stands two different
    heights"), and the hull inside the hall.
Hulls share pictures (Korvan's and Solari's are their own; every other chassis
and the salvage frames draw Korvan's), so each picture is stood once and the
frames drawing it are named beside it.
```

## Sink limit

Above `const SINK_MAX := 6`:

```text
The most rows a hull may be let down past its seat to close a step in its
belly over a cap: the heavy B on the unclaimed slab takes 5, its lowest
pixel then 5 rows down the slab's front face, below its front edge (row 7).
6 since Solari's light (Oct 17): its blade keel drops 11 rows below the
stern and the nose, the hull is too short for both caps to stand under the
keel, and on the unclaimed slab the best pair lets it down 6. Still above
row 7, so the slab's front edge stays in front of the belly.
```
