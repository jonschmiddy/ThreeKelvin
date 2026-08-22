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
	_card_law()
	_no_twins()
	_no_echoes()
	verdict("holdtest")


## EVERY MODULE OBEYS THE CARD RARITY LAW, and the shape of the catalogue is
## reported rather than asserted.
##
## The law is a function of the part — see ModuleData.card_rarities — so a
## violation can only come from a card that DECLARED its own rarity and got it
## wrong. That is exactly the case worth checking: the derived path cannot fail
## and the authored one is the one a person types.
##
## In the gate because it is arithmetic on two tables and needs no window, and
## because a legendary 1x1 granting two legendary cards is the kind of mistake
## that reads as generosity rather than as a bug.
func _card_law() -> void:
	var bad := ""
	var pairs := 0
	var shared := 0
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		var law := m.card_rarities()
		var got := m.resolved_cards()
		# ORDER-INSENSITIVE. Which card a module lists first is arbitrary, so the
		# law is about the SET: one card at the part's own grade, and the rest at
		# or below whatever the second slot allows. Read as an ordered pair it
		# failed two modules for listing their shared card first, which is a
		# fact about typing rather than about the card.
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

	# AND EVERY GRADE'S NAME STAYS READABLE ON THE VOID. A separate claim from
	# the one above and it needed a separate check: the loop above asks whether
	# the ART can be seen on the PLATE, and a rarity whose ink vanished into the
	# page behind it would sail through it — the plate would be fine and the
	# card's name would be gone. Contraband is black on purpose, so this is the
	# only thing standing between that ruling and an invisible card name.
	var dimmest := 99.0
	var grade := ""
	for r in ModuleData.Rarity.size():
		var c := _contrast(ModuleData.rarity_ink(r), UITheme.VOID)
		if c < dimmest:
			dimmest = c
			grade = ModuleData.rarity_name(r)
	_ok("ink on void: faintest grade is %s at %.2f:1, floor 3.0" % [grade, dimmest],
		dimmest >= 3.0)


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


## NO TWO CARDS ARE THE SAME CARD.
##
## Written because four duplicates were found BY EYE, one at a time, by reading
## a list — Bolt On was Brace, Sight In was Load was Lay the Guns, Range Finding
## was Range, and a card called Hold Fast sat next to a different card called
## Hold Fast. Every one of them shipped, and every one of them was found by a
## person noticing. That is not a process; it is luck with a good reader.
##
## They hide because nothing in the game ever puts them next to each other. A
## card is authored on one module, drawn from a deck of fifteen, and rendered by
## its own name — so two cards with one effect look like a varied catalogue from
## every angle except the one nobody has: all of them, side by side.
##
## TWO FAILURES, opposite directions, both real:
##
##   one effect, two names — the catalogue claims 73 cards and has 69. The
##   player is offered a choice that is not one.
##   one name, two effects — worse. Two different things print the same word,
##   and the deck list is a lie.
##
## THE FINGERPRINT IS EVERY FIELD BUT FIVE, by reflection rather than by a hand
## written list, because a hand written list stops covering the catalogue the
## day somebody adds a field and does not think of this file. The five left out
## are the ones that are not the card's behaviour: `name` (the thing under
## test), `copies` and `rarity` (how much of it you get and what it is worth —
## the same card at two grades is still one card, and Range Finding was exactly
## that), `lane` (a label for set bonuses), and `source_rarity`, which is not a
## property of the card at all — it is stamped on at grant time with the grade of
## the part that handed it over, so one shared card carries seven of them.
func _no_twins() -> void:
	var all: Array[CardData] = []
	for id in DB.modules:
		for c in (DB.modules[id] as ModuleData).resolved_cards():
			all.append(c)
	for row in DB.MALFUNCTIONS:
		all.append(DB.malfunction(row[0]))

	var skip := {&"name": true, &"copies": true, &"rarity": true, &"lane": true,
		&"source_rarity": true}
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

	# THE NEAR MISSES, printed and not failed. A card that does exactly one
	# thing has nothing else to tell it apart from the next card that does that
	# one thing, so single-verb cards are the family duplicates keep coming out
	# of — Range, Range Finding, Lock On and Lay In were four of them under one
	# verb. Differing numbers make them legitimately different cards, which is
	# why this cannot be a failure; having four is still worth seeing.
	var solo := {}
	for c in all:
		var verbs: Array[String] = []
		for prop in c.get_property_list():
			if not (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var key: StringName = prop.name
			if skip.has(key) or key == &"energy" or key == &"heat":
				continue
			# `hits` DEFAULTS TO 1, so counting it made every card in the game a
			# two-verb card and this whole report unable to print a line. Caught by
			# writing it, seeing nothing, and not assuming that meant nothing was
			# there. Hits is a property of an attack; without damage there is no
			# attack for it to be a property of.
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


## NO CARD IS NAMED AFTER THE RULE IT PRINTS.
##
## A keyword is the rule; a card is a thing that uses it. When the two share a
## name the card says one thing twice and the glossary loses its referent —
## "Lock On — Lock on +4" tells a player nothing they could not read off the
## corner, and the word "lock on" now means both a mechanic and a particular
## piece of Korvan hardware.
##
## The catalogue already knew this and had written it down once: the shared
## brace card is called Bolt On "and not Brace — Brace is the KEYWORD". That
## comment held for one card and nothing enforced it for the rest, so four more
## walked in: Lock On, Evoke, Launch Drone and Wasp Screen. The last two are the
## sharpest version of it — their names were the effect line with the number
## taken off.
##
## THE GLOSSARY IS COLLECTED FROM THE CARDS, not typed here. `keywords()` is the
## only place a keyword is defined, and asking every card in the game what it
## explains is the only way this check keeps up with a keyword added next month.
## The one thing it cannot see is a keyword no card uses yet — which cannot
## collide with anything either, until a card uses it, at which point it can.
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
		# AND THE WEAKER FORM: the name inside its own effect line, which is how
		# "Launch Drone — Launch drone 3." got in without ever equalling a
		# glossary entry.
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
