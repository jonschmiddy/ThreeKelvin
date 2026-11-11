The reasoning behind `tkg/scripts/sim/HellbenderGateTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hellbender gate test

Above `var h := Harness.new()`:

```text
THE HELLBENDER FLIES ONLY AT ASCENSION 7 AND UP, headless:
  godot --headless --path . -- sheet=HellbenderGateTest [seeds=60]
Jon, Nov 8: "remove the hellbender from the game and ONLY have the hellbender
show up on Ascention 7+". And his follow-up: "the signs for the hiring board
can stay as a little hint to what's coming".

At ascension 0 (every run until the ladder is built), over `seeds` seeds:
no Hellbender spawns (`hellbender_at` -1, hull 0, `hellbender_max` 0), its
clock moves nothing however many jumps the party makes, no system is eaten,
and none of what a player sees names it: no log line over real jumps, no
system's drawer line, no body past the last orbit (`SystemLayout.
hellbender_here`, which the map, the sector page, LOCAL and the chart's
label all read), ENGAGE nowhere, and the WANTED posters not stamped
DESTROYED (`Run.hellbender_destroyed`). The hiring boards' own paper still
names it, as the hint. At ascension 7, the same seeds spawn it at its
template hull in the middle shells, and the world around it is the one
tier 7 rolls with the Hellbender kept off (`Run.hellbender_off`, the sim's
control seam): its place is a positional roll, so nothing else moves. Until
Tiers (Nov 10) the comparison was against level 0's world; since then the
galaxy takes the tier's form from tier 1 (`Ladder.roll_kind`), so level 7
is rightly a ball galaxy and level 0's world is not the measure. A
dev's `-- fight foe=hellbender` at level 0 opens at its template hull, not
at 1 (`Router.start_combat` read a dead rival's hull of 0). A save from
before the level (VERSION 40) loads at 0.
```
