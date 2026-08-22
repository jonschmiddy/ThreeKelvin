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
	_legible()
	verdict("holdtest")


## EVERY HOUSE'S ART STAYS READABLE ON EVERY RARITY'S GROUND.
##
## A plate says two things at once: rarity is the ground it is painted on and
## the manufacturer is the art standing on it. That only works while the two
## palettes stay apart, and nothing keeps them apart except this — 7 makers by 7
## rarities is 49 pairings and a new house is one line of a table.
##
## Here rather than in `-- fittest`, which is where the rest of the plate is
## tested, because this is arithmetic on two colour tables and needs no window.
## It belongs in the gate; that one cannot be.
func _legible() -> void:
	var worst := 99.0
	var who := ""
	for id in DB.manufacturers:
		var man: ManufacturerData = DB.manufacturers[id]
		for r in ModuleData.Rarity.size():
			var ground: Color = ModuleData.rarity_colour(r).lerp(
				UITheme.VOID, ModuleIcon.GROUND)
			var c := _contrast(man.colour, ground)
			if c < worst:
				worst = c
				who = "%s on %s" % [man.name, ModuleData.rarity_name(r)]
	_ok("art on ground: worst pairing is %s at %.2f:1, floor 3.0" % [who, worst],
		worst >= 3.0)


## WCAG relative luminance contrast. Not Color.get_luminance(), which is a
## straight weighted average of the sRGB values and answers a different question
## — it reads two colours as further apart than an eye does.
func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _lum(c: Color) -> float:
	var v := [c.r, c.g, c.b]
	for i in 3:
		v[i] = v[i] / 12.92 if v[i] <= 0.03928 else pow((v[i] + 0.055) / 1.055, 2.4)
	return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]


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
