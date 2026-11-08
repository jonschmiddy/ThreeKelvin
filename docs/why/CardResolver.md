The reasoning behind `tkg/scripts/systems/CardResolver.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Vent dissipation

Inside `resolve()`, above `var v := mini(Run.heat, c.vent + Run.dissipation())`:

```text
PLUS THE SHIP'S DISSIPATION, which no longer sheds on its own. The
stat's prominence is finally earned: it was half of attr_thermal and
worth one point a turn, and it is now a multiplier on a decision the
player makes rather than a drip that happens to them. Fifteen vent
cards get better and stop competing against free automatic cooling.

`vent_all` is untouched -- it already zeroes heat and there is nothing
for a multiplier to add to.
```
