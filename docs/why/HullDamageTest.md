The reasoning behind `tkg/scripts/sim/HullDamageTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hull damage rules

Above `const Film := preload("res://scripts/sim/HullDamageFilm.gd")`:

```text
THE HULL DAMAGE LOOKS KEEP THEIR RULES (Oct 17; `HullHitFx`, `ShipHitFx.look`).
  godot --headless --path . -- sheet=HullDamageTest
Headless. For each look (A, B, C, and D, all three mixed), on three ships' pictures (a light hull, a
dark one, a white one) from their full sheets and their half sheets, the nine
hits of `HullDamageFilm` from full hull to 6, the clock stepped 1/60 s:
  * NO HOLES: no blob of 4 or more pixels gone near black (under 9% light)
    where the art was not (15% or more). Today's marks fail this by design
    (Chain's bites were 40 to 115 px), and that is the playtester's note;
  * every mark on the hull's own pixels and never its outline;
  * every mark's colour one the sprite already has, or the heat ramp's
    darkest (burnt metal); every glowing pixel the heat ramp's, on the hull;
  * the same seed, the same marks, pixel for pixel;
  * a glow changes shape, while it glows, between 8 and 12 times a second;
  * the marks build up: more of the hull marked at 6 hull than at 60;
  * D mixes: its hits roll A's, B's and C's kinds over the three ships, and it
    marks less of each hull than today's marks do for the same nine hits.
Then the real fight, in the older marks (0), B and D: every ship's hits are
that look's (yours too), a shot through `Combat.damage_enemy` marks the
enemy's picture, and the kill's wreck keeps the marks. And D is the game's
look (Jon's pick): with no `-- hull=` every ship wears D, the Custodian the
older marks.
```
