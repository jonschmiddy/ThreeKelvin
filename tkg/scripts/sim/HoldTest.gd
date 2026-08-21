extends Harness

## The hold never overlaps itself and never spills out of the grid:
##   godot --headless --path . -- holdtest
##
## Written because the failure is INVISIBLE IN THE DATA. Two parts sharing a cell
## still add up to a sensible "17 of 28", still save and load, still sell for the
## right price. The only symptom is on screen, where one plate is drawn over
## another — and reading that off a screenshot means measuring plate edges and
## inferring column indices, which is guesswork about a thing the code can just
## be asked.
##
## Every hull, because the grid is a property of the hull: a light is 4x5 and a
## heavy 4x10, and a placement rule that only ever ran against one of them has
## only ever been tested at one shape.


func run() -> void:
	for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
		_fill(w)
	_shapes()
	_swaps()
	verdict("holdtest")


## Stuff a hull's hold until nothing more fits, then check what landed.
func _fill(w: HullData.Weight) -> void:
	Rng.reseed(4242 + int(w), 0)
	Run.start_new_run(&"korvan", int(w))
	var g := Run.hold_grid()
	var name := HullData.weight_name(w)
	var guard := 0
	while guard < 200:
		guard += 1
		var m := LootGen.roll_module(3 + (guard % 6), &"", true)
		if not Run.place_in_hold(m):
			break
	_ok("%s: %d parts in a %dx%d hold" % [name, Run.cargo.size(), g.x, g.y],
		Run.cargo.size() > 0)
	_no_overlap(name, g)
	_in_bounds(name, g)
	_ok("%s: cargo_used never exceeds the grid" % name,
		Run.cargo_used() <= g.x * g.y)


## No cell is claimed twice.
func _no_overlap(name: String, _g: Vector2i) -> void:
	var seen := {}
	var clashes := 0
	for m in Run.cargo:
		for dy in maxi(1, m.size.y):
			for dx in maxi(1, m.size.x):
				var c := m.hold_at + Vector2i(dx, dy)
				if seen.has(c):
					clashes += 1
				seen[c] = m.id
	_ok("%s: no two parts share a cell" % name, clashes == 0)


## Nothing hangs off an edge.
func _in_bounds(name: String, g: Vector2i) -> void:
	var out := 0
	for m in Run.cargo:
		if m.hold_at.x < 0 or m.hold_at.y < 0:
			out += 1
			continue
		if m.hold_at.x + maxi(1, m.size.x) > g.x:
			out += 1
		elif m.hold_at.y + maxi(1, m.size.y) > g.y:
			out += 1
	_ok("%s: every part is inside the grid" % name, out == 0)


## Every catalogue part has a shape that could fit the smallest hold.
##
## A 5-wide part in a 4-wide grid can never be picked up by anyone flying a
## light, and would fail by being silently left behind at every wreck.
func _shapes() -> void:
	var worst := Vector2i(4, 5)
	var bad: Array[String] = []
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.size.x < 1 or m.size.y < 1:
			bad.append("%s has no size" % id)
		elif m.size.x > worst.x or m.size.y > worst.y:
			bad.append("%s is %dx%d" % [id, m.size.x, m.size.y])
	_ok("all %d parts fit the smallest hold" % DB.modules.size(), bad.is_empty())
	for b in bad:
		_fail(b)


## Taking a part out frees exactly its own cells, and putting it back at a named
## cell puts it there.
func _swaps() -> void:
	Rng.reseed(99, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for i in 4:
		Run.place_in_hold(LootGen.roll_module(3 + i, &"", true))
	if not _ok("swaps: hold has parts", Run.cargo.size() >= 2):
		return
	var m: ModuleData = Run.cargo[0]
	var before := Run.cargo_used()
	var home := m.hold_at
	Run.take_from_hold(m)
	_ok("taking a part out frees exactly its cells",
		Run.cargo_used() == before - m.cells())
	_ok("a removed part claims no cell", m.hold_at == -Vector2i.ONE)
	_ok("it goes back where it was", Run.place_in_hold(m, home) and m.hold_at == home)
	# ...and cannot be put somewhere occupied.
	var other: ModuleData = Run.cargo[1] if Run.cargo[1] != m else Run.cargo[0]
	_ok("a cell already claimed is refused",
		other == m or not Run.can_place(m, other.hold_at))
