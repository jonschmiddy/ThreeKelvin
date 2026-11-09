The reasoning behind `tkg/scripts/data/Attributes.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Attribute scale

Above `const ATTR_MAX := 10`:

```text
Ten, not six. Six cells could not separate twenty-one chassis: half the
Thermal column landed on the same number and the difference between a Korvan
medium and a Solari medium — which is most of what those two manufacturers ARE —
rounded away. Every constant below was rescaled with it, not multiplied
through: the point of the wider scale is that the ships spread out in it.
HOW MANY CELLS THE BAR DRAWS. NOT a ceiling on the value.

Attributes go over ten and are meant to. Pillar 5: the ceiling is meant to
break, and a gauge that clamps is a gauge that hides the one moment the
whole loot loop exists to produce. A stealth build that reads 14 should say
14 — the bar runs out of cells, and the bar running out IS the readout.

THE FLOOR STAYS. Zero is still zero; nothing reads negative. See attr_sensors
for why that one is enforced and where.

WHAT DOES CAP IS EVERY CONSUMER, at its own call site rather than here. The
ambush roll divides by this and would take a probability negative at 17
stealth; it clamps its own ratio now. That is the correct place for it: the
gauge reports what you built, and each rule decides how much of it it can
use.
```

## Hull reference

Above `const HULL_REF := 70.0`:

```text
Hull is measured against a fixed reference, not against your own maximum.

Dividing by max_hp was the obvious version and it is wrong: it reads 6 for a
full Skiff and 6 for a full Ore Barge, so the attribute would say the two
ships are equally sturdy while one has less than half the other's plating.
A fixed reference makes frame size and damage both count, which is the whole
point of a Hull check.

70 rather than 60 because 60 put the Ore Barge at 6 on the first turn of the
run, and an attribute already at its ceiling cannot be improved by the tier
upgrades and found hulls that are supposed to improve it.
```

## Pip costs

Above `const PER_PIP := {`:

```text
Every attribute, in display order, as {key, label, short, value, base, text}.

`base` is the same attribute read off the bare chassis, so the display can
paint what the ship IS separately from what you bolted to it. Both are
computed here rather than differenced by the caller, because the difference
has to be taken AFTER the rounding and the clamp — a module worth 0.4 of a
cell moves neither number, and a caller subtracting raw values would paint a
bonus cell that the attribute does not actually have.
One list so the ship tab, the chassis select and any future check UI cannot
disagree about the order or the names.
WHAT ONE PIP COSTS, in the raw units the attribute formulas read.

ONE ENTRY PER GAUGE, and a gauge with two terms moves BOTH. A part that
raises MANEUVER raises dodge and initiative; a part that raises THERMAL
raises how much heat you hold and how fast you lose it. That is the whole
simplification: a part says +1 MANEUVER, not "+1 of the initiative half of
maneuver", and there is nothing to explain in brackets afterwards.

Each term carries HALF a pip, and the divisors above were set to whole
numbers so that half a pip is one whole point in an int field. That is the
constraint that decides those divisors, and it is why they are here rather
than tuned to taste: dodge is a float and can carry a fraction, initiative
and dissipation cannot.

INVERTED OUT OF THE FUNCTIONS ABOVE, not measured against them. Change one
of those formulas and this has to change with it, which is exactly what
`-- attrtest` is for: it bolts every part onto a reference frame and checks
the gauge actually moved by the number the grade promised.
```

Inside `attr_stealth()`, above `&"maneuver": {&"dodge": 1.0 / 23.0},`:

```text
DODGE ALONE, and initiative is deliberately not here any more. The comment
above still holds for gauges with two live terms -- but initiative is not
one: it is summed, it feeds attr_maneuver, and NOTHING else in the game
reads it. Combat rolls randf() < Run.dodge() for the enemy to miss and never
asks who goes first.

So half of every maneuver pip was buying nothing at all, and a part or an
affix advertising +1 MANEUVER delivered about 2% of enemy attacks missing
where the gauge implied twice that. 1/23 rather than 1/46 makes the whole
pip land on the half that works.

Hull initiative is untouched: attr_maneuver still reads it, so a light frame
still gauges higher than a heavy one. That is the gauge DESCRIBING a chassis,
which it does honestly. What it may no longer do is sell a bonus.
```

Inside `attr_stealth()`, above `&"reactor": {&"reactor": 1.0},`:

```text
THE TWO THAT WERE MISSING. Every other gauge could be graded and these two
could not, so a part meant to be worth a pip of REACTOR or THRUST had no
unit to be worth it in. Both are one-for-one: a reactor level IS a pip
(attr_reactor returns the level), and thrust is now its own field for the
same reason -- see attr_thrust.

A reactor pip is the dearest thing on this table: three cells of capacity
AND half a point of energy, since energy steps every second level.
```

## Gauge names

Above `const ATTR_LABEL := {`:

```text
THREE LETTERS PER GAUGE, and the one place they are spelled.

Two things print them -- the attributes panel's own rows, and every rolled
affix on a module readout -- and the second used to write the gauge out in
full. "TUNED INJECTORS -- +1 THRUST" wrapped onto a second line inside a
panel that is 93 pixels of card wide, so a part with three affixes spent six
lines saying three things.

A dictionary rather than a field on each row, because the affixes need the
mapping without building a row: `attribute_rows()` computes seven live values
and seven sentences, and Database calls this at seed time when there is no
ship to compute them from.
THE GAUGE NAMES IN FULL, and the one place they are spelled.

Beside ATTR_SHORT rather than derived from it, because MANEUVERABILITY is not
MNV with letters put back -- the short forms were chosen to be three
characters, not to be abbreviations of these.

The station's part panel prints these. The abbreviations exist because a card
readout is 93 pixels wide and "+1 THRUST" wrapped; the shelf's column is 256
and has no such problem, so it says the whole word.
```
