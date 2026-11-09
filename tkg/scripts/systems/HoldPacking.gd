class_name HoldPacking
extends RefCounted

## The hold's grid arithmetic, on arrays and a grid size so it needs no run. `Run` keeps the
## doors into `cargo` and forwards its old names here (`hold_taken`, `fits_at`, `find_hold_slot`).

## Every cell a part covers at a given origin.
static func cells_of(m: HoldItem, at: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var f := m.footprint()
	for dy in f.y:
		for dx in f.x:
			out.append(at + Vector2i(dx, dy))
	return out

## Public so drag paths build the occupancy map once instead of once per probed cell.
## Why: docs/why/HoldPacking.md#cells-taken
static func taken(cargo: Array[HoldItem], m: HoldItem = null, leaving: HoldItem = null) -> Dictionary:
	var out := {}
	for other in cargo:
		if other == m or other == leaving or other.hold_at.x < 0:
			continue
		for c in cells_of(other, other.hold_at):
			out[c] = true
	return out


## Whether `m` at `at` stays inside the grid `g` and off the `taken` cells.
static func fits_at(g: Vector2i, taken_cells: Dictionary, m: HoldItem, at: Vector2i) -> bool:
	if at.x < 0 or at.y < 0:
		return false
	var f := m.footprint()
	if at.x + f.x > g.x or at.y + f.y > g.y:
		return false
	for c in cells_of(m, at):
		if taken_cells.has(c):
			return false
	return true


## First cell the part fits, row-major, or (-1,-1). First fit, not best fit: a
## predictable rule beats one that rearranges your hold.
static func find_slot(g: Vector2i, cargo: Array[HoldItem], m: HoldItem,
		leaving: HoldItem = null) -> Vector2i:
	var taken_cells := taken(cargo, m, leaving)
	for y in g.y:
		for x in g.x:
			var at := Vector2i(x, y)
			if fits_at(g, taken_cells, m, at):
				return at
	return -Vector2i.ONE


## Largest first after the grid shrinks, since first fit strands big parts behind small ones.
## Re-seats `cargo` in place and returns what no longer fits, for the caller to put on the pad.
## Why: docs/why/HoldPacking.md#repacking-the-hold
static func repack(g: Vector2i, cargo: Array[HoldItem]) -> Array[HoldItem]:
	var all := cargo.duplicate()
	# Typed `HoldItem`, not `ModuleData`: the hold carries materials, and a narrower
	# lambda type fails the whole sort at runtime.
	all.sort_custom(func(a: HoldItem, b: HoldItem) -> bool:
		return a.cells() > b.cells())
	cargo.clear()
	var lost: Array[HoldItem] = []
	for m in all:
		m.hold_at = -Vector2i.ONE
	for m in all:
		var cell := find_slot(g, cargo, m)
		if cell == -Vector2i.ONE:
			lost.append(m)
			continue
		m.hold_at = cell
		cargo.append(m)
	return lost
