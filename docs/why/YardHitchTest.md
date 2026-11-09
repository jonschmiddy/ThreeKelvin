The reasoning behind `tkg/scripts/sim/YardHitchTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Yard hitches

Above `const OPEN_MS := 250.0`:

```text
THE SHIPYARD'S HITCHES (#34), timed headless:  -- sheet=YardHitchTest
A Korvan medium, whose belly gun's empty ring sits inside a yard stand, docked
with parts in the hold. Before the fix the click took 7.9 s, a part off the
hull 7.5 s and a move in the hold 5.7 s. The budgets catch seconds, not ms.
```
