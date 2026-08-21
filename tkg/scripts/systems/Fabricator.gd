class_name Fabricator
extends RefCounted

## The bench. Spends materials and scrap; applies one effect the game already
## knows how to apply.
##
## Recipes are data (DB.RECIPES) and this file is the only thing that reads them,
## so a new recipe is a dictionary entry. If you find yourself adding a branch
## here for one recipe's sake, stop and add a `kind` instead — the same law
## CardResolver is held to, for the same reason.
##
## Availability is a property of the PLACE. An outpost has a welder and a still;
## a laboratory needs a city. That is what stops the bench from being a button
## that follows you around the galaxy, and what makes a developed system worth
## the fuel to reach.

## Every recipe this place can build, whether or not you can currently pay.
## Showing what you cannot afford is the point: a recipe you can see is a reason
## to go and find one more exotic.
static func available(n: MapGen.MapNode) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if n.type == MapGen.NodeType.GOAL:
		return out
	for r in DB.RECIPES:
		if int(n.development) >= int(r.dev):
			out.append(r)
	return out

static func has_bench(n: MapGen.MapNode) -> bool:
	return not available(n).is_empty()

## Scrap half of the bill, priced by the same local labour index as every other
## service. Materials are not indexed: a fragment is a fragment wherever you
## stand, and a place that charges two of them for the same job would read as
## the recipe changing rather than the price.
static func price(n: MapGen.MapNode, r: Dictionary) -> int:
	return maxi(1, int(round(float(r.credits) * Market.service_index(n))))

static func can_make(n: MapGen.MapNode, r: Dictionary) -> bool:
	if Run.credits < price(n, r):
		return false
	for id in (r.mats as Dictionary).keys():
		if Run.material(id) < int(r.mats[id]):
			return false
	return _useful(r)

## Refuses a job that would do nothing. A COOLANT BRAID is always useful, but the
## repair and fuel kinds are not — a patch on a full hull is not a purchase the
## player meant to make, and letting it through would spend a material on a no-op
## that nothing in the interface would explain afterwards.
##
## The repair and fuel kinds have no recipe behind them today: both were dev-0
## recipes whose real cost was alloy, and a station sells REPAIR and REFUEL at
## every development level, so retiring alloy retired them. The handlers stay
## because a recipe is meant to be a dictionary entry against an effect the game
## already applies — deleting the effect is what would make the next one code.
static func _useful(r: Dictionary) -> bool:
	match StringName(r.kind):
		&"repair":
			return Run.hp < Run.max_hp()
		_:
			return true

## What the bill reads, as one line. Materials first: they are the part you
## cannot go and earn in the next ten minutes.
static func cost_line(n: MapGen.MapNode, r: Dictionary) -> String:
	var bits: PackedStringArray = []
	for id in (r.mats as Dictionary).keys():
		bits.append("%d %s" % [int(r.mats[id]), DB.material_name(id).to_lower()])
	bits.append("%d credits" % price(n, r))
	return " · ".join(bits)

## Build it. Returns the log line, or an empty string when it did not happen —
## every caller checks, because a bench that silently declines is a bench the
## player will press twice.
static func make(n: MapGen.MapNode, r: Dictionary) -> String:
	if not can_make(n, r):
		return ""
	var cost := price(n, r)
	Run.add_credits(-cost)
	for id in (r.mats as Dictionary).keys():
		Run.spend_material(id, int(r.mats[id]))
	return _apply(n, r)

static func _apply(n: MapGen.MapNode, r: Dictionary) -> String:
	match StringName(r.kind):
		&"repair":
			var healed := Run.heal(int(r.amount))
			return "Fabricated plate. Repaired %d hull." % healed
		&"fuel":
			Run.fuel += int(r.amount)
			Sig.resources_changed.emit()
			return "Cracked feedstock for volatiles. +%d fuel." % int(r.amount)
		&"heat_cap":
			Run.add_heat_cap(int(r.amount))
			Sig.resources_changed.emit()
			Sig.ship_changed.emit()
			return "Coolant braid laid in. Heat cap +%d." % int(r.amount)
		&"artifact":
			# Precursor tech is unbranded by definition, so it is rolled the way
			# a fauna or core drop is rather than being pulled from a house's
			# catalog. Danger biases it, which makes reading a fragment deep in
			# the galaxy worth more than reading one on the rim.
			var m := LootGen.roll_module(n.danger, &"", true)
			Run.stow(m)
			Sig.ship_changed.emit()
			return "The fragment reads out as %s. It is in the hold." % m.name
	return ""
