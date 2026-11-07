extends Harness

## Overlaps are invisible in the data and show only on
## screen; run on every hull, as the grid is the hull's.
## Why: docs/why/HoldTest.md#hold-overlap-test


func run() -> void:
	for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
		_fill(w)
	_shapes()
	_swaps()
	_turn_materials()
	_moving_day()
	_changed_your_mind()
	_legible()
	_card_law()
	_no_twins()
	_no_echoes()
	_korvan_runs_cold()
	_solari_runs_hot()
	_solari_heat_not_waste()
	verdict("holdtest")


## Checks authored card rarities, as the derived path
## cannot fail. It needs no window, so it is gated.
## Why: docs/why/HoldTest.md#card-rarity-law
func _card_law() -> void:
	var bad := ""
	var pairs := 0
	var shared := 0
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		var law := m.card_rarities()
		var got := m.resolved_cards()
		# Order-insensitive: reading the first card as an
		# ordered pair failed two modules for typing order.
		# Why: docs/why/HoldTest.md#card-rarity-law
		var names := {}
		var top_seen := false
		for c in got:
			names[c.name] = true
		for c in got:
			if not top_seen and c.rarity == law[0]:
				top_seen = true
				continue
			if c.rarity > law[1]:
				bad += " %s/%s(%d>%d)" % [m.name, c.name, c.rarity, law[1]]
		if not top_seen and not got.is_empty():
			bad += " %s(nothing at grade %d)" % [m.name, law[0]]
		if got.size() > 1 and names.size() == 1:
			pairs += 1
			# Pairs on 1-2 cell parts above common pass, as the
			# second copy is stamped lower: printed, not failed.
			# Why: docs/why/HoldTest.md#card-rarity-law
			if m.cells() < 3 and int(m.rarity) > 0:
				print("  warn: %s is a pair on a %d-cell %s part" % [m.name, m.cells(),
					ModuleData.Rarity.keys()[m.rarity].to_lower()])
		for c in m.cards:
			if DB.SHARED.values().any(func(d: Dictionary) -> bool:
					return d.get("name", "") == (c as CardData).name):
				shared += 1
				break
	_ok("every module obeys the card rarity law" if bad == ""
		else "off the ladder:%s" % bad, bad == "")
	var n := DB.modules.size()
	print("  shape: %d of %d modules grant a pair (%d%%), %d draw on shared cards (%d%%)"
		% [pairs, n, roundi(100.0 * pairs / n), shared, roundi(100.0 * shared / n)])


## Rarity ground and manufacturer art must stay apart: 49 pairings, so it is gated.
## Why: docs/why/HoldTest.md#plate-legibility
func _legible() -> void:
	var worst := 99.0
	var who := ""
	for id in DB.manufacturers:
		var m: ManufacturerData = DB.manufacturers[id]
		for r in ModuleData.Rarity.size():
			var ground: Color = ModuleData.rarity_colour(r).lerp(
				UITheme.VOID, ModuleIcon.GROUND)
			var c := _contrast(m.colour, ground)
			if c < worst:
				worst = c
				who = "%s on %s" % [m.name, ModuleData.rarity_name(r)]
	_ok("art on ground: worst pairing is %s at %.2f:1, floor 3.0" % [who, worst],
		worst >= 3.0)

	# Grade names must read on the VOID too; contraband
	# is black on purpose, so this guards its name.
	# Why: docs/why/HoldTest.md#plate-legibility
	var dimmest := 99.0
	var grade := ""
	for r in ModuleData.Rarity.size():
		var c := _contrast(ModuleData.rarity_ink(r), UITheme.VOID)
		if c < dimmest:
			dimmest = c
			grade = ModuleData.rarity_name(r)
	_ok("ink on void: faintest grade is %s at %.2f:1, floor 3.0" % [grade, dimmest],
		dimmest >= 3.0)


## WCAG contrast, not `Color.get_luminance()`, which reads colours further apart than an eye does.
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
	seed_run(4242 + int(w))
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


## A 5-wide part in a 4-wide grid can never be picked up by a light and is silently left behind.
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
	seed_run(99)
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


## R turned only module plates: `HoldGrid.icon_at` found nothing for a 4x1 crate under the pointer.
## Why: docs/why/HoldTest.md#turning-materials
func _turn_materials() -> void:
	seed_run(77)
	# A HEAVY: a light's hold can be three rows deep, and a 4x1 stood on end
	# needs four.
	Run.start_new_run(&"korvan", int(HullData.Weight.HEAVY))
	Run.cargo.clear()
	var g := Run.hold_grid()
	var long := _material_shaped(Vector2i(4, 1))
	var block := _material_shaped(Vector2i(2, 2))
	if not _ok("turn: a 4x1 and a 2x2 material in the catalogue, a hold %dx%d" % [g.x, g.y],
			long != null and block != null and g.x >= 4 and g.y >= 4):
		return
	# Out of the tree: this runs inside Main's `_ready`, when the root takes no
	# children, and a grid at the origin measures the same either way.
	var grid := HoldGrid.new()

	Run.place_in_hold(long, Vector2i.ZERO)
	grid.refresh()
	var mid := _middle(grid, long)
	ShipScreen.turn_in_hold(grid, mid)
	_ok("turn: R turns a 4x1 material in the hold (%s, now %dx%d at %s)" % [long.name,
		long.footprint().x, long.footprint().y, str(long.hold_at)],
		long.turned and long.footprint() == Vector2i(1, 4) and Run.cargo.has(long)
		and Run.can_place(long, long.hold_at))
	var drawn := _icon_of(grid, long)
	_ok("turn: and the hold draws it standing (%s)" % (str(drawn.size) if drawn != null else "nowhere"),
		drawn != null and drawn.size == ModuleIcon.footprint_box(long))
	ShipScreen.turn_in_hold(grid, _middle(grid, long))
	_ok("turn: R again lays it back down", not long.turned and Run.cargo.has(long))

	# NO ROOM: every other row full of 1x1 crates, so a 1x4 fits no column
	Run.cargo.clear()
	long.turned = false
	Run.place_in_hold(long, Vector2i.ZERO)
	for y in range(1, g.y):
		for x in g.x:
			Run.place_in_hold(_material_shaped(Vector2i.ONE), Vector2i(x, y))
	grid.refresh()
	var home := long.hold_at
	ShipScreen.turn_in_hold(grid, _middle(grid, long))
	_ok("turn: with no room to stand it up, it stays where it was, lying down",
		not long.turned and long.hold_at == home and Run.cargo.has(long))

	# SQUARE: turning it would change nothing, so nothing is changed
	Run.cargo.clear()
	Run.place_in_hold(block, Vector2i.ZERO)
	grid.refresh()
	ShipScreen.turn_in_hold(grid, _middle(grid, block))
	_ok("turn: a 2x2 material is left as it is", not block.turned and block.hold_at == Vector2i.ZERO)

	grid.free()
	Run.cargo.clear()


## A fresh material of this authored shape from the catalogue, or null.
func _material_shaped(want: Vector2i) -> MaterialData:
	for row in MaterialTable.all():
		var m := MaterialData.of(row)
		if m != null and m.size == want:
			return m
	return null


func _icon_of(grid: HoldGrid, m: HoldItem) -> ItemIcon:
	for c in grid.get_children():
		if c is ItemIcon and (c as ItemIcon).held_item() == m:
			return c
	return null


## The middle of an item's icon on screen, where R is pressed.
func _middle(grid: HoldGrid, m: HoldItem) -> Vector2:
	var ic := _icon_of(grid, m)
	return ic.get_global_rect().get_center() if ic != null else Vector2(-1, -1)


## Swapping destroys nothing and moves nothing: the old frame keeps its guns and crates in place.
## Why: docs/why/HoldTest.md#moving-day
func _moving_day() -> void:
	seed_run(1234)
	Run.start_new_run(&"korvan", int(HullData.Weight.HEAVY))
	for i in 6:
		Run.place_in_hold(LootGen.roll_module(3 + i, &"", true))
	var before: Array[HoldItem] = []
	before.append_array(Run.installed)
	before.append_array(Run.cargo)
	var was_fitted := Run.installed.size()
	var deck_before := Run.deck_size()
	if not _ok("moving day: a heavy with a loadout and a hold",
			was_fitted >= 3 and Run.cargo.size() >= 3):
		return

	var light: HullData = null
	for f in DB.hull_frames:
		if (f as HullData).weight == HullData.Weight.LIGHT:
			light = f
			break
	if not _ok("moving day: a light frame exists to move into", light != null):
		return
	Run.transfer_to_hull(light)

	_ok("moving day: nothing is destroyed by the move",
		Run.pad.size() == before.size())
	var missing := 0
	for m in before:
		if not Run.pad.has(m):
			missing += 1
	_ok("moving day: every object you owned is still yours", missing == 0)

	# THE NEW SHIP IS EMPTY UNTIL A HAND FILLS IT. Anything else and the screen
	# that draws this would be reporting a decision it did not make.
	_ok("moving day: the new frame arrives bare", Run.installed.is_empty())
	_ok("moving day: and with an empty hold", Run.cargo.is_empty())
	_ok("moving day: the deck went with it",
		deck_before > 0 and Run.deck_size() == 0)
	_ok("moving day: the dock will not let you fly",
		not Run.ready_to_fly().is_empty())
	_ok("moving day: the old frame is remembered",
		Run.old_hull != null and Run.old_hull.weight == HullData.Weight.HEAVY)

	# Everything stays where it was, so the transfer screen's left side is the ship you flew.
	var mounted := 0
	var stowed := 0
	for raw in Run.pad:
		var mod := raw as ModuleData
		if mod != null and mod.mount >= 0:
			mounted += 1
		elif raw.hold_at.x >= 0:
			stowed += 1
	_ok("moving day: the guns remember their hardpoints (%d)" % mounted,
		mounted == was_fitted)
	_ok("moving day: the crates remember their cells (%d)" % stowed,
		stowed == before.size() - was_fitted)

	# --- AND THE TWO WAYS ACROSS BOTH WORK.
	var gun: ModuleData = null
	for raw in Run.pad:
		var mod := raw as ModuleData
		if mod != null and mod.mount >= 0 and Run.can_power(mod) 				and Run.slots_for(mod.slot) > 0:
			gun = mod
			break
	if gun != null:
		var slot := gun.slot
		_ok("moving day: a gun goes mount to mount without being put down",
			Run.pad_to_mount(gun, slot, 0) and Run.installed.has(gun)
			and not Run.pad.has(gun))

	var crate: HoldItem = null
	for raw in Run.pad:
		var mod2 := raw as ModuleData
		if mod2 == null or mod2.mount < 0:
			crate = raw
			break
	if crate != null:
		var ok_stow := Run.pad_to_hold(crate)
		_ok("moving day: a crate crosses into the new hold",
			ok_stow and Run.cargo.has(crate) and not Run.pad.has(crate))

	# STOWING A GUN TAKES IT OFF THE HARDPOINT IT REMEMBERS. Without this the
	# old ship would go on drawing a part that is sitting in the new hold.
	var spare: ModuleData = null
	for raw in Run.pad:
		var mod3 := raw as ModuleData
		if mod3 != null and mod3.mount >= 0:
			spare = mod3
			break
	if spare != null and Run.pad_to_hold(spare):
		_ok("moving day: a stowed gun stops claiming a hardpoint",
			spare.mount < 0)

	var g := Run.hold_grid()
	_in_bounds("moving day", g)
	_no_overlap("moving day", g)


## A swap moves nothing, so undo is an exact snapshot; checked after carrying something across.
## Why: docs/why/HoldTest.md#calling-off-a-move
func _changed_your_mind() -> void:
	seed_run(4321)
	Run.start_new_run(&"korvan", int(HullData.Weight.HEAVY))
	for i in 4:
		Run.place_in_hold(LootGen.roll_module(3 + i, &"", true))
	var frame := Run.hull
	var hp_was := Run.hp
	# Add enough credits to pay: `add_credits` floors
	# at zero, so the refund would overshoot the start.
	Run.add_credits(1000)
	var purse := Run.credits
	var was: Dictionary = {}
	for m in Run.installed:
		was[m] = [m.mount, m.hold_at]
	for m in Run.cargo:
		var mod := m as ModuleData
		was[m] = [mod.mount if mod != null else -1, m.hold_at]
	var owned := was.size()
	if not _ok("back out: a ship worth keeping", owned >= 5):
		return

	var light: HullData = null
	for f in DB.hull_frames:
		if (f as HullData).weight == HullData.Weight.LIGHT:
			light = f
			break
	Run.transfer_to_hull(light, 250, null)
	Run.add_credits(-250)
	_ok("back out: the offer can be refused", Run.can_abandon_move())

	# CARRY SOMETHING FIRST, so the undo has real work to do.
	var moved := 0
	for raw in Run.pad.duplicate():
		var mod2 := raw as ModuleData
		if mod2 == null or mod2.mount < 0:
			continue
		for i in Run.slots_for(mod2.slot):
			if Run.pad_to_mount(mod2, mod2.slot, i):
				moved += 1
				break
		if moved > 0:
			break
	_ok("back out: something crossed before the change of heart", moved > 0)

	Run.abandon_move()
	_ok("back out: you are flying the old frame again", Run.hull == frame)
	_ok("back out: with the hull points you had", Run.hp == hp_was)
	_ok("back out: and the credits back", Run.credits == purse)
	_ok("back out: the dock is empty", Run.pad.is_empty()
		and Run.old_hull == null and not Run.can_abandon_move())
	_ok("back out: nothing was lost",
		Run.installed.size() + Run.cargo.size() == owned)

	var wrong := 0
	for m in Run.installed:
		if not was.has(m) or int((was[m] as Array)[0]) != m.mount:
			wrong += 1
	for m in Run.cargo:
		if not was.has(m) or (was[m] as Array)[1] != m.hold_at:
			wrong += 1
	_ok("back out: every part is where it was", wrong == 0)
	_ok("back out: and the ship can fly", Run.ready_to_fly().is_empty())


## Four duplicates were found by eye; the fingerprint is every card field but six, by reflection.
## Why: docs/why/HoldTest.md#no-twin-cards
func _no_twins() -> void:
	var all: Array[CardData] = []
	for id in DB.modules:
		for c in (DB.modules[id] as ModuleData).resolved_cards():
			all.append(c)
	for row in DB.MALFUNCTIONS:
		all.append(DB.malfunction(row[0]))

	var skip := {&"name": true, &"copies": true, &"rarity": true, &"lane": true,
		&"source_rarity": true, &"shared": true}
	var by_effect := {}
	var by_name := {}
	for c in all:
		var bits: Array[String] = []
		for prop in c.get_property_list():
			if not (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var key: StringName = prop.name
			if skip.has(key):
				continue
			if key == &"hits" and c.damage == 0:
				continue
			var v: Variant = c.get(key)
			if typeof(v) == TYPE_BOOL:
				if v:
					bits.append(String(key))
			elif typeof(v) == TYPE_INT:
				if v != 0:
					bits.append("%s=%d" % [key, v])
		bits.sort()
		var sig := ",".join(bits)
		if not by_effect.has(sig):
			by_effect[sig] = {}
		by_effect[sig][c.name] = true
		if not by_name.has(c.name):
			by_name[c.name] = {}
		by_name[c.name][sig] = true

	var twins: Array[String] = []
	for sig in by_effect:
		var names: Array = (by_effect[sig] as Dictionary).keys()
		if names.size() > 1:
			names.sort()
			twins.append("%s all do %s" % [" = ".join(names), sig])
	var forks: Array[String] = []
	for n in by_name:
		if (by_name[n] as Dictionary).size() > 1:
			forks.append("%s is %d different cards" % [n, (by_name[n] as Dictionary).size()])
	twins.sort()
	forks.sort()

	_ok("no two names share one effect", twins.is_empty())
	for t in twins:
		_fail(t)
	_ok("no two effects share one name", forks.is_empty())
	for f in forks:
		_fail(f)

	# Near misses among single-verb cards are printed,
	# not failed: differing numbers make them legitimate.
	# Why: docs/why/HoldTest.md#no-twin-cards
	var solo := {}
	for c in all:
		var verbs: Array[String] = []
		for prop in c.get_property_list():
			if not (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var key: StringName = prop.name
			if skip.has(key) or key == &"energy" or key == &"heat":
				continue
			# `hits` defaults to 1, so counting it made every
			# card two-verb and the report print nothing.
			if key == &"hits" and c.damage == 0:
				continue
			var v: Variant = c.get(key)
			if (typeof(v) == TYPE_INT and v != 0) or (typeof(v) == TYPE_BOOL and v):
				verbs.append(String(key))
		if verbs.size() != 1:
			continue
		if not solo.has(verbs[0]):
			solo[verbs[0]] = {}
		solo[verbs[0]][c.name] = true
	var crowd: Array[String] = []
	for verb in solo:
		var names: Array = (solo[verb] as Dictionary).keys()
		if names.size() < 3:
			continue
		names.sort()
		crowd.append("%s: %s" % [verb, ", ".join(names)])
	crowd.sort()
	for line in crowd:
		print("  one verb, %s" % line)


## A card named after its keyword says one thing twice; the glossary is collected from the cards.
## Why: docs/why/HoldTest.md#no-echo-names
func _no_echoes() -> void:
	var all: Array[CardData] = []
	for id in DB.modules:
		for c in (DB.modules[id] as ModuleData).resolved_cards():
			all.append(c)
	for row in DB.MALFUNCTIONS:
		all.append(DB.malfunction(row[0]))

	var glossary := {}
	for c in all:
		for pair in c.keywords():
			glossary[String(pair[0]).to_lower()] = true

	var named: Array[String] = []
	var echoed: Array[String] = []
	var seen := {}
	for c in all:
		if seen.has(c.name):
			continue
		seen[c.name] = true
		var low := c.name.to_lower()
		if glossary.has(low):
			named.append(c.name)
		# The weaker form: the name inside its own effect line, as 'Launch Drone' got in.
		if c.describe().to_lower().contains(low):
			echoed.append("%s — %s" % [c.name, c.describe()])
	named.sort()
	echoed.sort()

	_ok("no card is named after a keyword", named.is_empty())
	for n in named:
		_fail("%s is a keyword" % n)
	_ok("no card repeats its own name in its effect", echoed.is_empty())
	for e in echoed:
		_fail(e)
	print("  glossary: %d keywords across %d cards" % [glossary.size(), seen.size()])


## A Korvan attack may cost heat only if it charges: ballistic cards fire, ordnance banks the shot.
## Why: docs/why/HoldTest.md#korvan-runs-cold
func _korvan_runs_cold() -> void:
	var bad: Array[String] = []
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.manufacturer != &"korvan" or m.slot != ModuleData.Slot.WEAPON:
			continue
		for c in m.resolved_cards():
			var cd: CardData = c
			if cd.damage <= 0 or cd.heat <= 0:
				continue
			if cd.charge_turns > 0:
				continue
			bad.append("%s (%s) costs %d heat and does not charge"
				% [cd.name, m.name, cd.heat])
	_ok("Korvan ballistics run cold; only its ordnance runs hot", bad.is_empty())
	for b in bad:
		_fail(b)


## Solari attacks cost heat or read it; a cold Solari
## gun is a worse Korvan gun. Shared cards exempt.
func _solari_runs_hot() -> void:
	var bad: Array[String] = []
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.manufacturer != &"solari":
			continue
		for cd: CardData in m.cards:
			if cd.shared or (cd.damage <= 0 and not cd.damage_equals_heat):
				continue
			if cd.heat > 0 or cd.heat_scale > 0 or cd.damage_equals_heat or cd.flashpoint > 0:
				continue
			bad.append("%s (%s) attacks cold" % [cd.name, m.name])
	_ok("Solari attacks run hot", bad.is_empty())
	for b in bad:
		_fail(b)


## A Solari card that vents also does something else; a bare vent is the shared Bleed Heat's job.
func _solari_heat_not_waste() -> void:
	var bad: Array[String] = []
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.manufacturer != &"solari":
			continue
		for cd: CardData in m.cards:
			if cd.shared or (cd.vent <= 0 and not cd.vent_all):
				continue
			if cd.damage > 0 or cd.damage_equals_heat or cd.brace > 0 or cd.brace_from_heat \
					or cd.block > 0 or cd.draw > 0 or cd.heal > 0 or cd.heal_scale > 0 \
					or cd.lock_on > 0 or cd.energy_gain > 0:
				continue
			bad.append("%s (%s) vents and does nothing else" % [cd.name, m.name])
	_ok("Solari heat is never waste", bad.is_empty())
	for b in bad:
		_fail(b)
