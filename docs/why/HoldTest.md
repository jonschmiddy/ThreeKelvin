The reasoning behind `tkg/scripts/sim/HoldTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hold overlap test

Above `func run() -> void:`:

```text
The hold never overlaps itself and never spills out of the grid:
  godot --headless --path . -- holdtest

Written because the failure is INVISIBLE IN THE DATA. Two parts sharing a cell
still add up to a sensible "17 of 28", still save and load, still sell for the
right price. The only symptom is on screen, where one plate is drawn over
another — and reading that off a screenshot means measuring plate edges and
inferring column indices, which is guesswork about a thing the code can just
be asked.

Every hull, because the grid is a property of the hull: a light is 4x5 and a
heavy 4x10, and a placement rule that only ever ran against one of them has
only ever been tested at one shape.
```

## Card rarity law

Above `func _card_law() -> void:`:

```text
EVERY MODULE OBEYS THE CARD RARITY LAW, and the shape of the catalogue is
reported rather than asserted.

The law is a function of the part — see ModuleData.card_rarities — so a
violation can only come from a card that DECLARED its own rarity and got it
wrong. That is exactly the case worth checking: the derived path cannot fail
and the authored one is the one a person types.

In the gate because it is arithmetic on two tables and needs no window, and
because a legendary 1x1 granting two legendary cards is the kind of mistake
that reads as generosity rather than as a bug.
```

Inside `_card_law()`, above `var names := {}`:

```text
ORDER-INSENSITIVE. Which card a module lists first is arbitrary, so the
law is about the SET: one card at the part's own grade, and the rest at
or below whatever the second slot allows. Read as an ordered pair it
failed two modules for listing their shared card first, which is a
fact about typing rather than about the card.
```

Inside `_card_law()`, above `if m.cells() < 3 and int(m.rarity) > 0:`:

```text
THE PAIR BLIND SPOT. A pair on a 1-2 cell part above common passes
the check above, because its second copy is stamped a grade lower
when it is granted -- so it reads as one-and-one. §3 says such a
part may not be a pair at all. Printed, not failed, until the
parts that do it are rewritten.
```

## Plate legibility

Above `func _legible() -> void:`:

```text
EVERY MANUFACTURER'S ART STAYS READABLE ON EVERY RARITY'S GROUND.

A plate says two things at once: rarity is the ground it is painted on and
the manufacturer is the art standing on it. That only works while the two
palettes stay apart, and nothing keeps them apart except this — 7 manufacturers by 7
rarities is 49 pairings and a new manufacturer is one line of a table.

Here rather than in `-- fittest`, which is where the rest of the plate is
tested, because this is arithmetic on two colour tables and needs no window.
It belongs in the gate; that one cannot be.
```

Inside `_legible()`, above `var dimmest := 99.0`:

```text
AND EVERY GRADE'S NAME STAYS READABLE ON THE VOID. A separate claim from
the one above and it needed a separate check: the loop above asks whether
the ART can be seen on the PLATE, and a rarity whose ink vanished into the
page behind it would sail through it — the plate would be fine and the
card's name would be gone. Contraband is black on purpose, so this is the
only thing standing between that ruling and an invisible card name.
```

## Turning materials

Above `func _turn_materials() -> void:`:

```text
R TURNS A MATERIAL IN THE HOLD BY THE MODULE'S RULES.

It turned module plates only: `ShipScreen.turn_in_hold` asked
`HoldGrid.icon_at`, which finds nothing but modules, so a 4x1 crate under
the pointer did nothing. A real `HoldGrid`, pointed at the crate's middle,
the call R makes on the refit screen and in LOCAL's cutaway. The same rules
as a part: it turns when the turned shape fits, stays put and unturned when
it does not, and a square one is left alone.
```

## Moving day

Above `func _moving_day() -> void:`:

```text
MOVING SHIP CONSERVES OBJECTS, AND MOVES NOTHING BY ITSELF.

THE ONE PROPERTY THE WHOLE PAD EXISTS FOR. `transfer_to_hull` used to destroy
whatever would not fit -- it had to, because `cargo` may only contain things
that sit at a real cell, and there is no such cell for the thirteenth item in
a twelve-cell hold. The claim being made is arithmetic: NOTHING LEAVES.

AND NOTHING ARRIVES EITHER. The swap now moves nothing at all: the old frame
keeps its guns on their hardpoints and its crates in their cells, and every
crossing is a hand moving one thing. So the assertions below are about the
SHAPE of the state a swap leaves behind, which the transfer screen draws --
a gun still remembering a mount is a gun that screen puts back on the hull.

Run onto a LIGHT from a HEAVY on purpose: every mount count falls and the
hold halves, which is the case where the old code deleted the most.
```

## Calling off a move

Above `func _changed_your_mind() -> void:`:

```text
CALLING OFF A MOVE PUTS THE SHIP BACK EXACTLY.

The purchase was final by design for about a day. What makes reversing it
cheap is that a swap no longer MOVES anything -- so an undo is a snapshot
going back over a state nothing has happened to, and the thing worth
asserting is that it really is exact: the same frame, the same hull points,
the same guns on the same hardpoints, the same crates in the same cells, and
the money back.

Checked AFTER carrying something across, because restoring an untouched move
is the easy half. A gun that has been bolted to the new ship has had its
`mount` overwritten with an index on a different hull, and that is precisely
what the snapshot is for.
```

## No twin cards

Above `func _no_twins() -> void:`:

```text
NO TWO CARDS ARE THE SAME CARD.

Written because four duplicates were found BY EYE, one at a time, by reading
a list — Bolt On was Brace, Sight In was Load was Lay the Guns, Range Finding
was Range, and a card called Hold Fast sat next to a different card called
Hold Fast. Every one of them shipped, and every one of them was found by a
person noticing. That is not a process; it is luck with a good reader.

They hide because nothing in the game ever puts them next to each other. A
card is authored on one module, drawn from a deck of fifteen, and rendered by
its own name — so two cards with one effect look like a varied catalogue from
every angle except the one nobody has: all of them, side by side.

TWO FAILURES, opposite directions, both real:

  one effect, two names — the catalogue claims 73 cards and has 69. The
  player is offered a choice that is not one.
  one name, two effects — worse. Two different things print the same word,
  and the deck list is a lie.

THE FINGERPRINT IS EVERY FIELD BUT FIVE, by reflection rather than by a hand
written list, because a hand written list stops covering the catalogue the
day somebody adds a field and does not think of this file. The five left out
are the ones that are not the card's behaviour: `name` (the thing under
test), `copies` and `rarity` (how much of it you get and what it is worth —
the same card at two grades is still one card, and Range Finding was exactly
that), `lane` (a label for set bonuses), `source_rarity`, which is not a
property of the card at all — it is stamped on at grant time with the grade of
the part that handed it over, so one shared card carries seven of them — and
`shared` itself.

SIX NOW, and the sixth was found the hard way. `shared` says where a card was
AUTHORED, not what it does: a card written into the shared vocabulary and the
same card written out again as a module literal differ in that flag and in
nothing else. So this check reported them as two cards under one name and gave
the flag as the whole of the difference, which reads as a real fork and is
not one. The duplicate WAS real and is gone -- Patch Kit grants `&"patch"`
now -- but the flag had to come out of the signature too, or the next module
that re-authors a shared card trips the same wire with the same confusing
message.
```

Inside `_no_twins()`, above `var solo := {}`:

```text
THE NEAR MISSES, printed and not failed. A card that does exactly one
thing has nothing else to tell it apart from the next card that does that
one thing, so single-verb cards are the family duplicates keep coming out
of — Range, Range Finding, Lock On and Lay In were four of them under one
verb. Differing numbers make them legitimately different cards, which is
why this cannot be a failure; having four is still worth seeing.
```

## No echo names

Above `func _no_echoes() -> void:`:

```text
NO CARD IS NAMED AFTER THE RULE IT PRINTS.

A keyword is the rule; a card is a thing that uses it. When the two share a
name the card says one thing twice and the glossary loses its referent —
"Lock On — Lock on +4" tells a player nothing they could not read off the
corner, and the word "lock on" now means both a mechanic and a particular
piece of Korvan hardware.

The catalogue already knew this and had written it down once: the shared
brace card is called Bolt On "and not Brace — Brace is the KEYWORD". That
comment held for one card and nothing enforced it for the rest, so four more
walked in: Lock On, Evoke, Launch Drone and Wasp Screen. The last two are the
sharpest version of it — their names were the effect line with the number
taken off.

THE GLOSSARY IS COLLECTED FROM THE CARDS, not typed here. `keywords()` is the
only place a keyword is defined, and asking every card in the game what it
explains is the only way this check keeps up with a keyword added next month.
The one thing it cannot see is a keyword no card uses yet — which cannot
collide with anything either, until a card uses it, at which point it can.
```

## Korvan runs cold

Above `func _korvan_runs_cold() -> void:`:

```text
KORVAN BALLISTICS RUN COLD. The manufacturer says so in the one line a
player reads before choosing it: "Ex-military surplus parts. Ballistics run
cold; ordnance and brace run hot."

THE MECHANICS ALREADY TELL THE TWO APART and nothing had noticed. An
ordnance card BANKS THE SHOT — it charges, and the heat is the price of
holding it. A ballistic card FIRES — hits and salvo, volume rather than
patience. So the rule needs no new field: a Korvan attack may cost heat if
and only if it charges.

Four cards failed it when this was written, and every one was a gun whose
own flavour said ballistic: a rotary cannon, a three-barrel ripsaw and both
cards off the KH-500. They cost the manufacturer the one advantage it has — a
Korvan gun that heats you up is a worse Solari gun.

ARMOUR IS EXEMPT AND HOT BY THE SAME LINE. Bulwark and Bulkhead pay heat to
hold a plate up, which is the other half of the sentence.
```
