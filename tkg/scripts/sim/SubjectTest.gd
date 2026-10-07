extends Harness

## EVERY ENCOUNTER'S SUBJECT IS REAL AND FITS, headless:
##   godot --headless --path . -- subjecttest
##
## An option's `subject` (`OptionTable`, drawn by `LocalSubject`) names pieces of
## art and a staging. A misspelt piece draws nothing and says nothing; a staging
## one tank too wide runs under the event's band or off the view. So, for every
## option that has one:
##  - every stage is a kind `LocalSubject` stages, with what that kind needs;
##  - every piece is in `art/subjects/index.json`, and its picture loads (or its
##    painter recipe names a world the painter has);
##  - the whole staging fits the subject's box on LOCAL's own view (right of
##    centre, above the band) and keeps off your ship.
## Then once on the real LOCAL: an event with a subject opened there draws it,
## inside its box, off the ship and above the band. And with the wrecks a fight
## leaves there (one, two, three of them, measured where the view puts them):
## the subject keeps clear of every one, there and then, and every other
## subject would too (`LocalSubject.fit`).
##
## THE SHIPS (`role:<name>`, `foe`): every role names kept pool ships; an
## encounter resolves to the same ships every time; the ships vary between the
## encounters that share a role; and a staging with the fight's own ship fits
## whichever ship that fight could bring (every one in the pools, drawn by
## `EnemyArt`).

const STAGES := [&"single", &"row", &"tether", &"field", &"herd", &"line", &"around", &"on_rock", &"strewn", &"ring", &"group"]
## Every ship an event's fight can bring (`DB.fight_pool`, every danger).
const FOES := [&"cutter", &"lancer", &"hulk", &"marauder", &"sentinel"]

var _tree: SceneTree


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	# LOCAL's own view, measured, and your ship on it
	Rng.reseed(4242, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := _a_system()
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	Router.show_local()
	for i in 30:
		await tree.process_frame
	var sc := Router.current as SectorScreen
	if not _ok("LOCAL is up", sc != null):
		return _finish()
	var view_size: Vector2 = sc._view.size
	var box := LocalSubject.box_for(view_size)
	var art := sc._view.ship_view()
	var ship := Rect2(art.ship_rect().position + art.global_position - sc._view.global_position, art.ship_rect().size)
	print("  ..   LOCAL's view %dx%d, the subject's box %s, your ship %s" % [view_size.x, view_size.y, box, ship])

	var with_subject := 0
	## role -> {encounter: a ship it drew}
	var roles_used := {}
	var bad_stage: Array[String] = []
	var bad_piece: Array[String] = []
	var bad_fit: Array[String] = []
	var on_ship: Array[String] = []
	for o: Dictionary in OptionTable.all():
		if not o.has("subject"):
			continue
		with_subject += 1
		var id := String(o.id)
		var resolved: Variant = LocalSubject.resolve(o.subject, o.id, 5)
		if str(resolved) != str(LocalSubject.resolve(o.subject, o.id, 5)):
			bad_stage.append("%s: its ships change from one look to the next" % id)
		for st: Dictionary in LocalSubject.stages_of(resolved):
			var kind := StringName(st.get("stage", &""))
			if not kind in STAGES:
				bad_stage.append("%s: %s" % [id, kind])
			if kind in [&"around", &"on_rock"] and not LocalSubject.has_piece(StringName(st.get("base", &""))):
				bad_stage.append("%s: %s without a base" % [id, kind])
			var ids: Array = st.get("pieces", []).duplicate()
			ids.append_array(st.get("ends", []))
			if st.has("base"):
				ids.append(st.base)
			if st.has("clamp"):
				ids.append(st.clamp)
			for sh: Dictionary in st.get("ships", []):
				ids.append(sh.get("piece", &""))
			for pid in ids:
				var ps := String(pid)
				if ps.begins_with("ship_"):
					for r: String in _role_of(ps):
						if not roles_used.has(r):
							roles_used[r] = {}
						# the encounter's own set of ships in that role
						var mine: Array = (roles_used[r] as Dictionary).get(id, [])
						if not ps in mine:
							mine.append(ps)
							mine.sort()
						(roles_used[r] as Dictionary)[id] = mine
			if ids.is_empty():
				bad_stage.append("%s: no pieces" % id)
			for pid in ids:
				var why := _piece_wrong(StringName(pid))
				if why != "":
					bad_piece.append("%s: %s (%s)" % [id, pid, why])
		# with each ship its fight could bring, when it stages the fight's own
		var foes: Array = FOES if "\"foe\"" in str(o.subject) else [&""]
		for foe: StringName in foes:
			LocalSubject.foe_override = foe
			var planned := LocalSubject.plan(o.subject, o.id, 5)
			var b := LocalSubject.bounds_of(planned)
			var placed := Rect2(b.position + (box.get_center() - b.get_center()).round(), b.size)
			var tag := id if foe == &"" else "%s with a %s" % [id, foe]
			# a few px of drift either way, as it moves
			if not box.encloses(placed.grow(-1.0)):
				bad_fit.append("%s (%dx%d at %d,%d)" % [tag, placed.size.x, placed.size.y, placed.position.x, placed.position.y])
			if placed.grow(6.0).intersects(ship):
				on_ship.append(tag)
		LocalSubject.foe_override = &""
	print("  ..   %d encounters carry a subject" % with_subject)
	_ok("some encounters carry a subject (%d)" % with_subject, with_subject > 0)
	_ok("every stage is one LocalSubject stages (%s)" % (", ".join(bad_stage) if not bad_stage.is_empty() else "all"), bad_stage.is_empty())
	_ok("every piece resolves to art (%s)" % (", ".join(bad_piece) if not bad_piece.is_empty() else "all"), bad_piece.is_empty())
	_ok("every staging fits the subject's box, above the event's band (%s)" % (", ".join(bad_fit) if not bad_fit.is_empty() else "all"), bad_fit.is_empty())
	_ok("and none reaches your ship (%s)" % (", ".join(on_ship) if not on_ship.is_empty() else "none"), on_ship.is_empty())
	# THE SHIPS VARY: every role two or more encounters draw on shows more than
	# one ship among them
	var empty_roles: Array[String] = []
	for r: String in ["hauler", "barge", "small", "survey", "mining", "passenger", "family", "tender", "armed"]:
		if LocalSubject.role_ships(r).is_empty():
			empty_roles.append(r)
	_ok("every role names kept ships (%s)" % (", ".join(empty_roles) if not empty_roles.is_empty() else "all"), empty_roles.is_empty())
	var same: Array[String] = []
	for r: String in roles_used:
		var by: Dictionary = roles_used[r]
		var distinct := {}
		for e: String in by:
			distinct[str(by[e])] = true
		print("  ..   role %s: %d encounters, %d different casts" % [r, by.size(), distinct.size()])
		if by.size() >= 2 and distinct.size() < 2:
			same.append(r)
	_ok("the ships vary between encounters (%s)" % (", ".join(same) if not same.is_empty() else "every role"), same.is_empty())

	# ONCE ON THE REAL LOCAL: the six tanks on their tether, opened there
	await _live(&"the_fuel_cache")
	# AND WITH A FIGHT'S WRECKS THERE: the subject makes room (a wreck is a door,
	# so it keeps its place)
	var sets := await _live_wrecks(&"the_fuel_cache")
	var crossed: Array[String] = []
	var outside: Array[String] = []
	var halves := 0
	for o: Dictionary in OptionTable.all():
		if not o.has("subject"):
			continue
		var planned := LocalSubject.plan(o.subject, o.id, 5)
		var b := LocalSubject.bounds_of(planned)
		for k in sets.size():
			var avoid: Array[Rect2] = sets[k]
			var f := LocalSubject.fit(box, b, avoid)
			var fs := float(f.scale)
			var placed := Rect2((f.centre as Vector2) + b.position * fs, b.size * fs)
			if fs < 1.0:
				halves += 1
			if not box.encloses(placed.grow(-1.0)):
				outside.append("%s with %d (%s in %s)" % [o.id, k + 1, placed, f.clear])
			for w in avoid:
				if placed.intersects(w):
					crossed.append("%s with %d" % [o.id, k + 1])
					break
	print("  ..   with wrecks there: %d of %d placements drawn at half size to keep clear" % [halves, with_subject * sets.size()])
	_ok("with 1-3 wrecks there, every subject keeps clear of them (%s)" % (", ".join(crossed) if not crossed.is_empty() else "all"), crossed.is_empty() and not sets.is_empty())
	_ok("and still inside its box (%s)" % (", ".join(outside) if not outside.is_empty() else "all"), outside.is_empty())
	# THE FIGHT'S OWN SHIP: the scene before it shows the ship the fight brings,
	# and hands over (the subject goes; the fight draws its own)
	await _handover(&"hostile_contact")
	_finish()


## Why a piece will not draw, or "".
func _piece_wrong(pid: StringName) -> String:
	if not LocalSubject.has_piece(pid):
		return "not in the index"
	var p: Dictionary = LocalSubject.piece_info(pid)
	if String(p.get("kind", "")) == "foe":
		return "" if p.get("tex") != null else "EnemyArt drew nothing"
	if String(p.get("kind", "")) == "painter":
		return "" if Worlds.WORLD.has(StringName(p.get("world", ""))) else "the painter has no world %s" % p.get("world", "")
	var f := String(p.get("file", ""))
	if not ResourceLoader.exists(f):
		return "no picture at %s" % f
	return ""


func _live(oid: StringName) -> void:
	Rng.reseed(4242, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := _a_system()
	Run.at = idx
	var n: MapGen.MapNode = Run.node_at()
	n.visited = true
	SectorScreen._approached_at = idx
	n.options.clear()
	n.options.append(oid)
	SystemMapScreen._parked.erase(idx)
	LocalEventDrawer.quiet = true
	LocalEventDrawer.request(idx, 0)
	Router.show_local()
	for i in 40:
		await _tree.process_frame
	var sc := Router.current as SectorScreen
	if not _ok("LOCAL is up with %s open" % oid, sc != null):
		return
	var sub := LocalSubject.of(sc._view)
	_ok("its subject is drawn on LOCAL (%s)" % (sub.key if sub != null else "none"), sub != null and not sub.drawn_rects().is_empty())
	if sub == null:
		return
	var vr := sc._view.get_global_rect()
	var box := LocalSubject.box_for(sc._view.size)
	var gbox := Rect2(vr.position + box.position, box.size).grow(8.0)
	var art := sc._view.ship_view()
	var ship := Rect2(art.ship_rect().position + art.global_position, art.ship_rect().size)
	var out := 0
	var hits := 0
	for r in sub.drawn_rects():
		if not gbox.encloses(r):
			out += 1
		if r.intersects(ship):
			hits += 1
	_ok("every piece inside its box (%d out), none on your ship (%d)" % [out, hits], out == 0 and hits == 0)
	var band: Control = sc._events.panel if sc._events != null else null
	if band != null and band.is_visible_in_tree():
		var under := 0
		for r in sub.drawn_rects():
			if r.intersects(band.get_global_rect()):
				under += 1
		_ok("and none under the event's band (%d)" % under, under == 0)
	_ok("in the scene's depth: behind the hulls", sub.get_index() < sc._view._row.get_index())
	_ok("and it takes the place of LOCAL's drawn stand-in (hidden)", sc._view._area == null or not sc._view._area.visible)
	LocalEventDrawer.quiet = false


## Wrecks left at the system one at a time, as fights there would: each time,
## the live subject keeps clear of every wreck. Returns where the wrecks stood
## each time, in the view's own space.
func _live_wrecks(oid: StringName) -> Array:
	var sets: Array = []
	var sc := Router.current as SectorScreen
	if sc == null:
		return sets
	LocalEventDrawer.quiet = true
	var n: MapGen.MapNode = Run.node_at()
	var foes: Array = DB.enemies.keys()
	foes.sort()
	for k in 3:
		Run.new_wreck(n, DB.enemies[foes[(k * 7 + 3) % foes.size()]])
		sc._refresh()
		for i in 20:
			await _tree.process_frame
		var sub := LocalSubject.of(sc._view)
		if not _ok("%d wreck(s) at %s, its subject still up" % [k + 1, oid], sub != null and sc._view._slots.visible):
			break
		var avoid: Array[Rect2] = []
		var at := sc._view.get_global_rect().position
		for e: EnemySlot in sc._view._made:
			avoid.append(Rect2(e.holder_rect().position - at, e.holder_rect().size))
		sets.append(avoid)
		var hits := 0
		for r in sub.drawn_rects():
			for e: EnemySlot in sc._view._made:
				if r.intersects(e.holder_rect()):
					hits += 1
		_ok("  and none of its pieces on a wreck (%d), drawn at %sx" % [hits, sub._scale], hits == 0)
	LocalEventDrawer.quiet = false
	return sets


## An armed encounter opened on LOCAL, then its fight started as the event
## starts it (`Router.start_ambush`): the ship the scene showed is the ship the
## fight brought, and the scene's own is gone once the fight is up.
func _handover(oid: StringName) -> void:
	Rng.reseed(4242, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# a deep system, where the fight's pool holds more than one ship, so the
	# match is not luck
	var idx := _a_system()
	for m: MapGen.MapNode in Run.map:
		if m.type == MapGen.NodeType.SYSTEM and DB.fight_pool(m.danger, false).size() >= 3:
			idx = m.index
			break
	Run.at = idx
	var n: MapGen.MapNode = Run.node_at()
	n.visited = true
	n.options.clear()
	n.options.append(oid)
	print("  ..   danger %d, the fight's pool %s" % [n.danger, DB.fight_pool(n.danger, false)])
	SectorScreen._approached_at = idx
	SystemMapScreen._parked.erase(idx)
	LocalEventDrawer.quiet = true
	LocalEventDrawer.request(idx, 0)
	Router.show_local()
	for i in 30:
		await _tree.process_frame
	var sc := Router.current as SectorScreen
	var sub := LocalSubject.of(sc._view) if sc != null else null
	var shown := &""
	if sub != null:
		for c in sub.cast:
			if String(c).begins_with("foe:"):
				shown = StringName(String(c).substr(4))
	_ok("%s shows the fight's ship before it (%s)" % [oid, shown], shown != &"")
	Router.start_ambush()
	for i in 30:
		await _tree.process_frame
	var brought := &""
	if Router.combat != null and not Router.combat.enemies.is_empty():
		brought = Router.combat.enemies[0].template.id
	_ok("  and the fight brings that ship (%s)" % brought, brought != &"" and brought == shown)
	var sc2 := Router.current as SectorScreen
	_ok("  and the scene's own is gone in the fight", sc2 != null and LocalSubject.of(sc2._view) == null)
	LocalEventDrawer.quiet = false


## The roles a pool ship is in.
func _role_of(ship: String) -> Array[String]:
	var out: Array[String] = []
	for r: String in ["hauler", "barge", "small", "survey", "mining", "passenger", "family", "tender", "armed"]:
		if ship in LocalSubject.role_ships(r):
			out.append(r)
	return out


func _a_system() -> int:
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not n.cleared:
			return n.index
	return 0


func _finish() -> void:
	verdict("subjecttest")
	_tree.quit(code())
