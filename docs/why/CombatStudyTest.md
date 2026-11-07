The reasoning behind `tkg/scripts/sim/CombatStudyTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Combat study flags

Above `var h := Harness.new()`:

```text
THE COMBAT STUDY'S FLAGS (Phase 11 step 1, Oct 27):
  godot --headless --path . -- sheet=CombatStudyTest

`-- sim enemyhp=X enemydmg=Y` flies every enemy but the boss at X times its
hull and Y times its damage (`HeadlessSim.scale_enemies`), and the study's
closing line reports the credits won runs ended with and the runs that ended
on an empty tank (`HeadlessSim.end_line`). Checked here:

  - every template but the boss: hull times X (rounded), every intent's
    damage in its loop and its pool times Y (rounded), and nothing else on
    the intent moved (hits, block, heal);
  - the Custodian, the one boss, kept every number it was tuned to;
  - a fight planned from a scaled template fields the scaled hull and damage
    (danger 1, where danger scaling is x1), and a new run's Hellbender
    carries the scaled hull;
  - the closing line's median, maximum and counts.

Called through `call()` on purpose, so on a HeadlessSim without the flags
this prints FAIL lines rather than failing to compile.
```
