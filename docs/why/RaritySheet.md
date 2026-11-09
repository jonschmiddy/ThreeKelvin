The reasoning behind `tkg/scripts/sim/RaritySheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Rarity sheet

Above `const LADDER := [`:

```text
What a rarity actually BUYS, in card numbers:
  godot --headless --path . -- rarity

A MEASUREMENT, not a gate, in the shape of `-- content`: it prints and it
passes, because the answer is a balance question rather than a correctness
one and a test that fails until somebody retunes the tables is a test people
learn to skip.

THE QUESTION IT EXISTS FOR. Affixes are moving off cards and onto the ship,
which takes the only thing that made a gun hit harder over a run with them.
The replacement is supposed to be rarity itself -- an Epic gun being a better
gun rather than a Common one with better rolls. That is a claim about the
module tables, and this is the number that says whether the claim is already
true, nearly true, or wishful.

READS THE TABLES, not a rolled drop. `LootGen` adds affixes and jitters scrap
value; both are noise here. What is wanted is the AUTHORED card, which is what
`DB.modules` holds.

PER MODULE, then averaged over its cards. A module granting three cards is
one data point and not three, or the parts with the thickest grants would
quietly set the mean for their whole rarity band.
```

Inside `run()`, above `_sheet("EVERY SLOT", -1)`:

```text
SEGMENTED BY SLOT, and the first version of this was not -- which made it
lie. Pooled across every slot, COMMON out-damaged UNCOMMON and RARE, and
the trend the whole sheet exists to show ran BACKWARDS. The cause is mix,
not balance: the common band is mostly guns, and the bands above it carry
systems and utilities whose cards deal no damage at all, so the mean was
measuring what a band is MADE of rather than how hard it hits.

"Does an Epic gun beat a Common gun" is a question about guns. Ask it
about guns.
```

Inside `_sheet()`, above `var turns := 1.0 + float(maxi(0, card.charge_turns))`:

```text
AND THE SAME NUMBER PER TURN, which is the fair comparison and the
one that changes the answer. A siege driver reading "Deal 40,
Charge 2" is not four times a mass driver reading "Deal 16, Charge
1" -- it is 40 across three turns against 16 across two. Raw output
flatters every big slow gun, and the top of the rarity ladder is
made of big slow guns.
```
