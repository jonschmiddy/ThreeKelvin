The reasoning behind `tkg/scripts/systems/Fabricator.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Bench rules

Above `static func available(n: MapGen.MapNode) -> Array[Dictionary]:`:

```text
The bench. Spends materials and scrap; applies one effect the game already
knows how to apply.

Recipes are data (DB.RECIPES) and this file is the only thing that reads them,
so a new recipe is a dictionary entry. If you find yourself adding a branch
here for one recipe's sake, stop and add a `kind` instead — the same law
CardResolver is held to, for the same reason.

Availability is a property of the PLACE: a station has a bench and the Core
has none. A laboratory used to need a city; since Jon's Nov 3 ruling every
station has all five decks at every level, so RELIC ANALYSIS is dev 0 and a
developed system is worth the fuel for its PRICE (`price`, by the place's
service index), not for the door. The `dev` gate stays for a later recipe.
```

## Useless jobs

Above `static func _useful(r: Dictionary) -> bool:`:

```text
Refuses a job that would do nothing. A RELIC ANALYSIS is always useful, but the
repair and fuel kinds are not — a patch on a full hull is not a purchase the
player meant to make, and letting it through would spend a material on a no-op
that nothing in the interface would explain afterwards.

The repair and fuel kinds have no recipe behind them today: both were dev-0
recipes whose real cost was alloy, and a station sells REPAIR and REFUEL at
every development level, so retiring alloy retired them. `heat_cap` went the
same way for a different reason — heat capacity is a thermal module's job, so
COOLANT BRAID and the yard's coolant service both came out. The handlers stay
because a recipe is meant to be a dictionary entry against an effect the game
already applies — deleting the effect is what would make the next one code.
```
