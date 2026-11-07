The reasoning behind `tkg/scripts/ui/BoxGauge.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Box gauge

Above `enum Mode { HEAT, ENERGY, HULL }`:

```text
Countable cells for heat and energy.

A bar hides the number that matters. Overheating costs 1 hull per point over
cap, so the player needs to see *how many* points over they are, not roughly
how full a bar is. Cells past the divider are hull you will pay at end of turn.

Fill colour also states the situation without being read: steel while there is
room, ember approaching the cap, red past it.
```

## Cell meaning

Above `enum Mode { HEAT, ENERGY, HULL }`:

```text
HULL and HEAT are PROPORTIONS below their maximum; ENERGY is a count.

Energy cells map one-to-one onto a point, because you spend energy in single
points and the exact number is the decision every time you play a card.

Hull does not work that way: it runs from 22 on a Hairpin to 55 on an Ore
Barge, so one cell per point would draw a gauge that changes length when you
change ships and needs fifty-five cells at the top end. Ten cells always, each
one a tenth of whatever your maximum happens to be.

HEAT NOW READS THE SAME WAY BELOW THE CAP, and it is the same argument: a cap
is 12 on one chassis and 30 on another, and every vent module moves it, so a
one-cell-per-point gauge changed length as you refitted. Ten cells hold still.

Above the cap it stays one cell per point, and that half is not negotiable —
each of those cells is one hull at end of turn, so "how many am I over" is a
bill to count, not a proportion to eyeball. The divider is where the gauge
changes what a cell MEANS, which is why it is drawn as a break rather than a
tick.
```

## Over cap

Above `const OVER_MAX := 10`:

```text
THE BILL IS COUNTABLE UP TO A POINT, AND THEN IT IS A NUMBER.

Past the cap this gauge draws one cell per point, which is the right unit --
each is one hull at end of turn. It was drawing ALL of them: 41 heat against
a cap of 14 is twenty-seven cells, 189 pixels of gauge grown out of a widget
whose `custom_minimum_size` is a floor, and the HUD row it sits in pushed
CREDITS, FUEL and two buttons off the right edge of the screen.

Ten, then a tick, which is exactly what `EnemySlot.BracePips` does with the
same problem: more than the strip can hold says so rather than lying about
the count. Nothing is lost -- `HudBar` prints "41 - 27 HULL" beside it, and
by twenty-seven over you are reading the number, not counting boxes.
```

## Rounding

Above `func _cells_for(v: int) -> int:`:

```text
How many of the below-cap slots are lit.

Heat rounds UP where hull rounds down, and the asymmetry is deliberate: they
are asking opposite questions. Hull rounds down so that ten cells means FULL
and the first scratch shows. Heat rounds up so that the first point of it
shows, and a full gauge means you have reached the cap — the moment the next
point starts costing hull. Both make the gauge honest at the end that matters.
```

Above `func set_hull(hp: int, max_hp: int) -> void:`:

```text
Set from hp and max_hp.

Rounds DOWN, with a floor of one cell while any hull remains. Both halves of
that matter and they pull opposite ways. Rounding down means ten cells is
reachable only at FULL hull, so "have I taken a scratch" is answerable at a
glance — rounding up hid the first 10% of damage behind a full-looking bar.
The floor of one means a ship on 1 of 40 still draws a cell, because an empty
gauge has to mean destroyed and nothing else.
```
