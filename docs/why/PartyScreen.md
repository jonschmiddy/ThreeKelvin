The reasoning behind `tkg/scripts/ui/PartyScreen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Party page

Above `var _back: Callable = Callable()`:

```text
Everyone you are flying with, on one page.

The convoy strip answers "who is in this room", which is the right question
while something is shooting at you and the wrong one the rest of the time. It
is also a fixed column with a fixed height: three partners plus separations
is 362 rows against the 378 the arena leaves, so it was measured for a party
of four and silently drops everybody past that. Photographed at seven, the
fourth ship is cut in half by the quiet strip and the last three are not
drawn at all.

So the strip keeps its job — presence, at a glance, in the room — and this
takes the one it was never able to do: the whole party, however many that is,
with the numbers you would actually plan around. It scrolls, so it does not
care how many there are.

EVERYTHING HERE IS ALREADY ON THE WIRE. A roster slot carries the ship, the
hull points, the heat, the heat cap and the system that player is in, because
`netcode.md`'s presence message has carried all five since the convoy strip
needed them to draw a gauge. Not one new message was added to build this
page, and that is the test of whether it deserved to exist: a screen that
needs a new channel is a feature, and a screen assembled out of facts the
party already agrees on is a view.
```

## Party rows

Above `func _row(slot: Dictionary) -> Control:`:

```text
One ship, and the four numbers you would plan around: how much hull is left,
how hot they are running, where they are, and whether they are in a fight.

Not a stat dump. `ShipBuild` deliberately carries what is DRAWN rather than
what is played — no cards, no affixes, no rolled numbers — so those are not
available to print here and should not be: what another player is holding is
their business, and `coop-design.md`'s first pillar is that the wallets stay
separate. What the party shares is exposure, and exposure is exactly these
four.
```
