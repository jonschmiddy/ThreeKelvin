class_name Fabricator
extends RefCounted

## Recipes are data: add a `kind`, not a branch. Every station has all five decks (Nov 3).
## Why: docs/why/Fabricator.md#bench-rules

## Shows what you cannot afford too: a visible recipe is a reason to find one more exotic.
## The data recipes are science's: a run with `Run.science_off` does not see them.
static func available(n: MapGen.MapNode) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if n.type == MapGen.NodeType.CORE:
		return out
	for r in DB.RECIPES:
		if Run.science_off and StringName(r.kind) == &"data":
			continue
		if int(n.development) >= int(r.dev):
			out.append(r)
	return out

static func has_bench(n: MapGen.MapNode) -> bool:
	return not available(n).is_empty()

## Scrap is priced by the local labour index; materials are not, or the recipe seems to change.
## A recipe at 0 credits (DEVELOP FILM, READ FOR DATA) costs 0 anywhere: no floor of 1.
static func price(n: MapGen.MapNode, r: Dictionary) -> int:
	if int(r.credits) == 0:
		return 0
	return maxi(1, int(round(float(r.credits) * Market.service_index(n))))

static func can_make(n: MapGen.MapNode, r: Dictionary) -> bool:
	if Run.credits < price(n, r):
		return false
	for id in (r.mats as Dictionary).keys():
		if Run.material(id) < int(r.mats[id]):
			return false
	return _useful(r)

## A no-op job is refused; the dead repair and fuel handlers stay so the next effect is data.
## Why: docs/why/Fabricator.md#useless-jobs
static func _useful(r: Dictionary) -> bool:
	match StringName(r.kind):
		&"repair":
			return Run.hp < Run.max_hp()
		&"data":
			# (the control cell's bench has none; see `available`)
			return not Run.science_off
		_:
			return true

## What the bill reads, as one line. Materials first: they are the part you
## cannot go and earn in the next ten minutes.
##
## A DATA RECIPE READS AS THE TRADE, "1 survey film → 6 DATA": it costs no
## credits, so "0 credits" would be a price that is not one, and what you get
## is the number that decides whether to press it.
static func cost_line(n: MapGen.MapNode, r: Dictionary) -> String:
	var bits: PackedStringArray = []
	for id in (r.mats as Dictionary).keys():
		bits.append("%d %s" % [int(r.mats[id]),
			str(MaterialTable.by_id(id).get("name", id)).to_lower()])
	var cost := price(n, r)
	if cost > 0:
		bits.append("%d credits" % cost)
	var line := " · ".join(bits)
	if StringName(r.kind) == &"data":
		line += " → %d DATA" % int(r.amount)
	return line

## Returns an empty string when nothing happened, or a silent bench gets pressed twice.
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
			return "You fabricate plate and repair %d hull." % healed
		&"fuel":
			Run.fuel += int(r.amount)
			return "Cracked feedstock into %d fuel." % int(r.amount)
		&"artifact":
			# Precursor tech is unbranded, rolled like a fauna drop and biased up by danger.
			var m := LootGen.roll_module(n.danger, &"", true)
			# Same again: `stow()` emits `ship_changed` itself.
			Run.stow(m)
			return "The fragment reads out as %s. It is in the hold." % m.name
		&"data":
			# DEVELOP FILM and READ FOR DATA (science, pick 1A): what went in is
			# gone and the readings are DATA. `add_data` emits
			# `resources_changed`, so the header's DATA moves with the press.
			Run.add_data(int(r.amount))
			return "The Lab got %d DATA out of it." % int(r.amount)
	return ""
