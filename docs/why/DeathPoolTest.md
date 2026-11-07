The reasoning behind `tkg/scripts/sim/DeathPoolTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Death pools

Above `var h := Harness.new()`:

```text
WHICH WAY THINGS DIE (Jon's picks, Oct 13).
  godot --headless --path . -- sheet=DeathPoolTest
Over many seeded kills: every kept ship style and every creature style is
reachable; the cut styles (E CHAIN, H SLICE) never play; a ship never rolls a
creature's death and a creature never rolls a ship's; the Custodian rolls
one of its own three (C1a, C1b, C1c) and never a ship's, the Hellbender H3;
the same place gives the same death every time. Then a
real fight won: each wreck lies in the slot the fight assumed when it chose
its death, so LOCAL's wreck is the wreck the animation ended on.
```
