The reasoning behind `tkg/scripts/sim/HullNumberTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hull number

Above `var _tree: SceneTree`:

```text
THE HULL NUMBER BESIDE THE PIPS (ruling 12 C, Jon, Oct 27):
  godot --headless --path . --fixed-fps 60 -- sheet=HullNumberTest

Geno, in the friends' alpha, read the chassis select's HULL as 4, 6 and 8
pips against Korvan's 29, 40 and 57 hull and took them for a mismatch. The
pips are hull over 7, rounded, and the tooltip claimed an exact "A pip is 7
hull". So:

- the real chassis select, at the game's 960x540, prints every frame's real
  hull ("29 hull") after HULL's number, for every manufacturer and weight,
  and that is the hull the run launches with (`Run.max_hp()`, full). Every
  startable frame, for certain: a scratch flight record with a win for every
  manufacturer opens them all (`_unlock_all`), so the count does not hang on
  DevMode being on, and it must be all of them;
- HULL is the only row that carries one;
- it fits: no overlap with anything drawn on the screen, inside its column,
  the column no wider than `ChassisSelect.SIDE_W`, inside the screen;
- the HULL tooltip says about 7, never an exact 7, and its sum is the ship's
  own, "Your 29 hull rounds to 4 pips." (also on a damaged ship and at 1 pip);
- a block set up without `amounts` (the refit screen, the cutaway, the yard)
  prints no readout.
```
