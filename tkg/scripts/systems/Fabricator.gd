class_name Fabricator
extends RefCounted

## Recipes are data: add a `kind`, not a branch. Every station has all five decks (Nov 3).
## Why: docs/why/Fabricator.md#bench-rules

## Shows what you cannot afford too: a visible recipe is a reason to find one more exotic.
static func available(n: MapGen.MapNode) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if n.type == MapGen.NodeType.CORE:
		return out
	for r in DB.RECIPES:
		if int(n.development) >= int(r.dev):
			out.append(r)
	return out

static func has_bench(n: MapGen.MapNode) -> bool:
	return not available(n).is_empty()

## Scrap is priced by the local labour index; materials are not, or the recipe seems to change.
static func price(n: MapGen.MapNode, r: Dictionary) -> int:
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
		_:
			return true

## What the bill reads, as one line. Materials first: they are the part you
## cannot go and earn in the next ten minutes.
static func cost_line(n: MapGen.MapNode, r: Dictionary) -> String:
	var bits: PackedStringArray = []
	for id in (r.mats as Dictionary).keys():
		bits.append("%d %s" % [int(r.mats[id]),
			str(MaterialTable.by_id(id).get("name", id)).to_lower()])
	bits.append("%d credits" % price(n, r))
	return " · ".join(bits)

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
			if not Run.stow(m):
				# A part that does not fit goes on the sector pile, never into nothing.
				Run.sector_jetsam(n).items.append(m)
				Sig.map_changed.emit()
				return "The fragment reads out as %s. The hold is full, so it is on the floor." % m.name
			return "The fragment reads out as %s. It is in the hold." % m.name
	return ""
