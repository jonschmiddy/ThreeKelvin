The reasoning behind `tkg/scripts/systems/options/OptionsPart03.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Fuel price

Inside `OptionsPart03.entries()`, above `{label = "Buy fuel at her rates", cost_credits = 4, effect = func() -> Dictionary:`:

```text
4 for 6 units, so "the cheapest in the galaxy" is true: a
capital's REFUEL is 24 for 25, about 1 a unit (fuel:A, Oct 18).
It was 30 for 6, five a unit, dearer than any dock.
```

## Named plus rolled payout

Inside `OptionsPart03.entries()`, above `return {text = "Years of heat and cold have welded the housing to its frame, and the cutter cannot free it in time. You take the readings instead: the interval, the bearing and the decay curve, shot onto film straight off the dish. You also take something the cutter shook loose.", material_id = &"survey_film", material = &"wreck"},`:

```text
NAMED FOR THE STORY, ROLLED FOR THE SCALE, and a branch this
deep wants both. `survey_film` is the readings and is worth
35 whatever the danger -- a named material has a FIXED value
and is the one kind of payout the tier ladder cannot reach.
Alone it made a LETHAL partial pay less than an EASY
success. The rolled wreck material beside it goes through
`MaterialTable.roll(table, danger)`, which grades, so the
depth is paid for by the half of the haul that can be.
```

## Fight declaration

Inside `OptionsPart03.entries()`, above `{label = "Engage", fight = true, effect = func() -> Dictionary:`:

```text
TWO STATEMENTS, NOT ONE, and collapsing them broke RULING 5.

`fight` in the RETURNED dictionary is the TRIGGER: it is what
`OptionResolve.take` reads to start the fight, and it is how
EventTable's two hostile endings have always worked. It is only
knowable by running the callable.

`fight` on the CHOICE is a DECLARATION: this row leads to a
fight. The sector list has to print a contact reading BEFORE the
click, so it needs an answer that does not require resolving the
option first. Removing it made every hostile row print nothing.

An outcome may still open a fight the choice did not declare --
that is a twist, and it is why the trigger is the runtime one.
```
