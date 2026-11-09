The reasoning behind `tkg/scripts/sim/ScienceSimTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## The sim pilots science

Above `var h := Harness.new()`:

```text
THE SIM PILOT'S SCIENCE (Phase 12, plan S12):
  godot --headless --path . -- sheet=ScienceSimTest

`-- sim science=on|off|ignore` and the pilot that flies it (`Policy`):

  - the flag parses, and each mode sets the world (`Run.science_off`) and
    the pilot (`policy.science`) the way plan §6 says;
  - with science off, seed 4242 rolls no science event anywhere (and with it
    on, the same seed does, so the check can see one), a played run leaves
    the board unbought and DATA at 0, and the Lab's bench is RELIC ANALYSIS
    alone, with no step for sale;
  - a reading's line, on built options: a full tank takes the risky line, a
    hurt ship or a cautious pilot at long odds the careful one, and the
    buyer's credits when the tank is at the way out (the fuel gate), when the
    board is finished or already covered, and with science off; a
    non-science option gets the old answer; choosing draws from no stream;
  - at a dock: film and relics are read for DATA before the counter can buy
    them, the cheapest step is bought first, AUGMENT puts on at most one
    affix a visit, never takes credits under FUEL_RESERVE and leaves the
    part's price where it was, and a finished board sells its film;
  - a better find never replaces an augmented part while a plain one shares
    its slot;
  - the human pilot steers 6 more for a dock while its DATA buys a step;
  - STRIP's reactor guard (S5) counts SPARE CELLS: Bus-Fed the reactor needs
    is refused bare and comes off with SPARE CELLS owned;
  - five seeded runs of the sim's own loop earn DATA and buy a step, and
    the report's `science:` lines are there (and with science off, the one
    `science: off` line).

Each key check fails with its rule taken out of Policy: `_choose_science`
(the line rules), `lab` (no film read, no step bought), `augment`'s reserve
and one-a-visit, `_worst_fitted`, `human_score`'s dock pull, and the off
cell's `apply_science`.
```
