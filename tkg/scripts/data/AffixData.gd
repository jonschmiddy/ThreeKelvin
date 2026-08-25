class_name AffixData
extends Resource

## A rolled modifier on a module, paid out in SHIP attributes.
##
## THESE USED TO REWRITE CARDS, and that is exactly why they no longer do. Every
## affix set a card field — add_damage, add_brace, add_draw — and
## `CardData.describe()` appends one clause per non-zero field. So three affixes
## turned "Deal 4 × 2." into "Deal 4 × 2. Draw 1. Vent 2. Heal 2." inside a text
## box 93 pixels wide with `fit_content` on and no clipping: the words grew out
## of the bottom of the card.
##
## The deeper problem was not the overflow. It was that two copies of the same
## card read differently depending on which module handed them out, so a card
## could not be LEARNED — and a card you cannot learn is a card you have to
## re-read every time it appears.
##
## A card face is now a fact about the card. A module's roll is a fact about the
## SHIP, and the attributes panel has a whole column to say it in where a card
## face had thirty-nine pixels.
##
## AUTHORED IN PIPS, one per gauge, never in raw units. That is RunState's own
## rule — "a part says +1 MANEUVER, not +1 of the initiative half of maneuver" —
## and `PER_PIP` does the translation, so an affix cannot drift from what the
## gauge actually does. `-- attrtest` checks that round trip for authored parts
## and the same table is what these go through.

## Every gauge an affix can pay in, in the order the ship panel lists them.
##
## The names match `RunState.PER_PIP` exactly, because `raw_for` looks them up
## there. A gauge missing from that table pays nothing and says nothing, which
## is why the two entries it was missing had to be added before this existed.
const GAUGES: Array[StringName] = [&"hull", &"reactor", &"thrust", &"maneuver",
	&"thermal", &"sensors", &"stealth"]

@export var name: String = ""

## What the module readout prints. Written in pips, in the player's units —
## "+1 HULL", not "+7 max_hull". The gauge is what they can see on the panel.
@export var text: String = ""

## Runs hot, loud or illegal. Gated by `LootGen` in policed space and read by
## `ModuleData.contraband`, which is what the market and the patrols check.
@export var contraband: bool = false

## How often this may be rolled, relative to the rest of the table.
##
## A REACTOR PIP IS THE DEAREST THING ON THE LADDER and needs pricing somewhere:
## it is three cells of module capacity AND half a point of energy a turn, since
## energy steps every second level. Every other gauge pays in one currency. So
## the two reactor affixes are scarce rather than weakened — a rare part that is
## worth finding beats a common one that is worth shrugging at.
@export var weight: float = 1.0

## Grant Count Law, affix arm. Changes how MANY cards a module hands over, which
## is a different question from what any one of them says — so it survived the
## move off card faces intact. Nothing rolls it today; it is the lever for
## "grants one fewer card" if that is ever wanted.
@export var grant_delta: int = 0

@export_group("Pips")
@export var hull: int = 0
@export var reactor: int = 0
@export var thrust: int = 0
@export var maneuver: int = 0
@export var thermal: int = 0
@export var sensors: int = 0
@export var stealth: int = 0
@export_group("")


## What this affix adds to one RAW passive field, in that field's own units.
##
## COMPUTED ON DEMAND AND NEVER BAKED INTO THE MODULE, which is not a style
## preference. `SaveGame._module_from` rebuilds a part as a fresh duplicate of
## its DB template and then re-attaches affixes BY NAME — so anything written
## into the template's fields when the part was rolled is gone the first time a
## save is loaded. Adding the pips up on demand is the only version that
## survives a round trip.
##
## Through PER_PIP rather than by carrying raw numbers, so retuning a gauge's
## formula moves every affix with it. A pip of MANEUVER is dodge and initiative
## together; a caller summing dodge asks for "dodge" and gets only that half,
## which is precisely what it wants.
func raw_for(field: StringName) -> float:
	var total := 0.0
	for g in GAUGES:
		var pips: int = int(get(g))
		if pips == 0:
			continue
		var per: Dictionary = Run.PER_PIP.get(g, {})
		if per.has(field):
			total += float(per[field]) * float(pips)
	return total
