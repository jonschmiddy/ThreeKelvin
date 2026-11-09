The reasoning behind `tkg/scripts/systems/Science.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## The labs services

Above `const AUGMENT_DATA := 5`:

```text
THE LAB'S SERVICES (Phase 12, science; Jon's picks 1A 2B 3A, Nov 4): the
board's steps, AUGMENT and STRIP. No UI here; the Lab screen (plan S9) reads
these and draws them.

Static, like Fabricator, and for the same reason: every rule about what the
Lab sells and what it costs lives in one file the screen, the hints and the
sim pilot all call, so none of them can disagree about a price.

EACH SERVICE WRITES ITS OWN LOG LINE AND RETURNS IT, or "" when it refused
and nothing moved. The caller plays a sound on a non-empty line and logs
nothing, because `Run.buy_step` already logs the board's line itself and a
screen that logged it again would print every purchase twice. (Fabricator's
DEVELOP FILM and READ FOR DATA are bench recipes and keep the bench's way:
`Fabricator.make` returns the line and the caller logs it.)

EVERY SERVICE REFUSES WHILE `Run.science_off`, the sim's control cell
(`-- sim science=off`), so a pilot that wanders into a Lab there can spend
nothing a run without science could not.

WHAT AUGMENT IS (pick 3A): one more affix on a part you own, picked from
three, ONCE PER PART EVER. The part keeps its price (`scrap_value` is set at
the drop and nothing here touches it) and its cards (no affix moves a card;
see AffixData). STRIP takes any one affix off, the Lab's or a rolled one,
and leaves the AUGMENTED mark, so a stripped part can never be augmented
again (open call 10).
```

## The three affixes this lab offers

Above `static func augment_offer(m: ModuleData, n: MapGen.MapNode) -> Array[AffixData]:`:

```text
The three affixes this Lab offers for this part.

FROM `LAB_AFFIXES` ONLY: never Cryo-Lined (heat capacity is a thermal
module's job) and never Deregulated (contraband), and never one the part
already has. Drawn the way loot rolls them (`LootGen._roll_affixes`): an
even pick, with a scarce affix (Bus-Fed, weight 0.35) refused that often and
dropped from the draw rather than tried again.

THE SAME THREE EVERY TIME YOU LOOK (open call 11). Off its own derived stream,
keyed to the station and the part (its id and the scrap value it dropped
with, which nothing writes after), and stored nowhere: closing the Lab and
opening it again cannot reroll it, and drawing it moves no stream the world,
the loot or a fight draws from. Another Lab may offer a different three,
which costs a trip.

NOT KEYED TO THE AFFIXES THE PART HAS. The Lab ranks all of its affixes for
this part once (`_offer_order`) and offers the first three the part lacks,
so STRIP cannot buy a fresh three: taking an affix off can only let that
same affix back into the offer, in the place the ranking already gave it.
```

## Add affix a to part m

Above `static func augment(m: ModuleData, a: AffixData, n: MapGen.MapNode) -> String:`:

```text
Add affix `a` to part `m`. `a` must be one of this Lab's three for the part
(`augment_offer`), so a caller cannot hand in Deregulated.

A NEW ARRAY, never an append in place: the affix list may be shared with
the template it was duplicated from. `ship_changed` lets RunState move the
hull with a fitted part, so 40/40 with a Reinforced added reads 47/47 (the
damage carried, as fitting a plate does).
```

## Whether affix a can come off

Above `static func can_strip(m: ModuleData, a: AffixData, n: MapGen.MapNode) -> bool:`:

```text
Whether affix `a` can come off part `m` here and now. Any affix, the Lab's
or a rolled one, on any part of yours, as often as you pay (open call 10).

REFUSED WHEN THE REACTOR WOULD COME UP SHORT. Taking a reactor pip off a
fitted part (Bus-Fed, Deregulated) lowers the level the fitted parts are
measured against; a strip that left them drawing more cells than the
reactor has would run a ship `can_power` would never have let you build.
```
