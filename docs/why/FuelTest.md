The reasoning behind `tkg/scripts/sim/FuelTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Fuel tank test

Above `var _tree: SceneTree`:

```text
THE 45 TANK (Jon, Oct 17: "fuel:A warn:A events:A"), headless:
  godot --headless --path . -- sheet=FuelTest

Four things, each read off the game rather than restated here:

- THE CAP. A run starts full at 45 and no write can overfill it: the
  setter, a refuel, a grant. REFUEL at a full tank says TANK FULL and takes
  nothing; a top-up is the room left, charged by the unit.
- THE EVENT FLOOR (`Run.drain_fuel`). An event leaves the fuel to reach a dock
  in sight, or three of the cheapest jumps with none; it never adds fuel; and
  every event outcome in `OptionTable` drains through it, at the 45 scale.
- THE HINT. Not above a third of the tank, at it; its second line names the
  nearest dock the tank can reach and the jumps to it -- checked against a
  search written here, not the game's -- or says what to do with none.
- THE HUD READOUT. "FUEL [bar] 23/45" at full, a third and near empty: the
  figure, the bar's fill, the colour (ice, amber, red, with or without hints,
  so a party is warned too); and the box test -- every piece inside the bar,
  on screen, clear of every other thing on the row, of the goal line and of
  the band under it on the left, and every spot A.S.H. can stand in; with dev
  mode's two extra
  tabs too. Not pressable: no button, no focus, the arrow cursor.
- THE PRICE AND THE WAY OUT (Jon, Oct 18: "fuel:AB"), in a USED run -- a
  few hops flown, credits spent, a can bought, docks visited -- not a fresh
  one. A whole tank costs 55-60 at an outpost and follows the service
  ladder elsewhere. Docked, broke and short of every other dock, REFUEL
  sells exactly the fuel to reach the cheapest one (checked against a
  search written here, and then flown), for what that costs or every credit
  you have; buying again gets nothing more; and it is not offered when the
  ordinary can is affordable, when a dock is already in reach, or away from
  the dock.
```

## Event drains

Above `func _flee_and_pulsar() -> void:`:

```text
Every event outcome drains through the floor and none moves more than a few
units: the 109 drains and 47 grants were rescaled from a 279 tank to 45
(round(n * 45 / 279), at least 1), so the largest of either is 6. Counted
at least, not exactly, so a branch that adds an event (feat/fauna-events'
`in_the_wake`) passes once its drain goes through `drain_fuel` at the scale.
FLEE AND THE PULSAR ON THE 45 SCALE (Jon: "flee:A", "pulsar:C"). A flee burns
1, and 2 more on a partial, through the floor; the pulsar pays 14 + danger,
about half a tank, held under the top.
```

## Unflyable dock hint

Above `func _hint_unflyable() -> void:`:

```text
A DOCK THE CHART DRAWS AND THE SHIP CANNOT FLY TO (Jon, Oct 18: "hint:fix").
A heavy frame reaches past its dish, so a dock you have visited can sit in
reach, on the chart, and out of sight -- `can_jump_to` refuses it. Routed
over the chart the hint named it, one jump; now it names the dock the ship
can fly to, as this test's own search finds it, or says none is in reach.
A.S.H. says the same line's name (`Hints.values`), so she is checked too.
```

## Nearest dock search

Above `func _my_nearest_dock(by_chart := false) -> Dictionary:`:

```text
Fewest jumps to a station, then least fuel, each hop priced as the game
prices a hop from where it starts, over hops the ship can take when it gets
there: the first to a star seen from here, each after it to one inside the
dish of the star it leaves (sight is live), through no core. Written apart
from `Run.nearest_dock` so the two can disagree. `by_chart` routes the old
way, over every system the chart draws -- the rule that named docks the ship
could not fly to (Jon, Oct 18: "hint:fix").
```
