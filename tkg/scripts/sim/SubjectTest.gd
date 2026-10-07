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
## NOTHING IS DRAWN ACROSS ANYTHING ELSE (`LocalSubject.clear_of`): no two pieces'
## opaque pixels come within the drift they can travel apart, but a piece on its
## own rock or round its own body, and a declared `dock`, which must touch along
## an edge (its clamps drawn over the seam).
##
## THE SHIPS (`role:<name>`, or a pool ship by name): every role names kept pool
## ships; an encounter resolves to the same ships every time; the ships vary
## between the encounters that share a role. LOCAL NEVER DRAWS THE FIGHT'S CODED
## SHIP (Jon picked kept pool ships on LOCAL only): no subject names `foe`, and
## an armed encounter's scene shows pool ships, then goes the moment its fight
## opens, so the fight's own ship (`EnemyArt`) flies in alone.

const STAGES := [&"single", &"row", &"tether", &"field", &"herd", &"line", &"around", &"on_rock", &"strewn", &"ring", &"group"]
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
	var piled: Array[String] = []
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
		# NEVER THE FIGHT'S CODED SHIP: LOCAL draws pool art only
		if "\"foe\"" in str(o.subject):
			bad_piece.append("%s: names `foe` (the fight's coded ship; LOCAL shows pool ships only)" % id)
		var planned := LocalSubject.plan(o.subject, o.id, 5)
		var b := LocalSubject.bounds_of(planned)
		var placed := Rect2(b.position + (box.get_center() - b.get_center()).round(), b.size)
		# a few px of drift either way, as it moves
		if not box.encloses(placed.grow(-1.0)):
			bad_fit.append("%s (%dx%d at %d,%d)" % [id, placed.size.x, placed.size.y, placed.position.x, placed.position.y])
		if placed.grow(6.0).intersects(ship):
			on_ship.append(id)
		# NOTHING DRAWN ACROSS ANYTHING ELSE: no two pieces' opaque pixels within
		# the drift they can travel apart, but for a piece on its own rock or
		# round its own body, and a docked pair, which touches along an edge
		for c: String in LocalSubject.clear_of(planned):
			piled.append("%s: %s" % [id, c])
		if not LocalSubject.short.is_empty():
			print("  ..   fewer shown, to stand clear: %s: %s" % [id, ", ".join(LocalSubject.short)])
	print("  ..   %d encounters carry a subject" % with_subject)
	_ok("some encounters carry a subject (%d)" % with_subject, with_subject > 0)
	_ok("every stage is one LocalSubject stages (%s)" % (", ".join(bad_stage) if not bad_stage.is_empty() else "all"), bad_stage.is_empty())
	_ok("every piece resolves to art (%s)" % (", ".join(bad_piece) if not bad_piece.is_empty() else "all"), bad_piece.is_empty())
	_ok("every staging fits the subject's box, above the event's band (%s)" % (", ".join(bad_fit) if not bad_fit.is_empty() else "all"), bad_fit.is_empty())
	_ok("and none reaches your ship (%s)" % (", ".join(on_ship) if not on_ship.is_empty() else "none"), on_ship.is_empty())
	for line in piled:
		print("  ..   piled: %s" % line)
	_ok("no piece is drawn across another (%d pairs too close)" % piled.size(), piled.is_empty())
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

	# LOCAL DRAWS WHAT THE SHIP ORBITS NOW, after a flight on the map
	await _orbit_switch()
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
	# THE HANDOVER: the scene before the fight shows pool ships, never the fight's
	# coded one; the fight opens with the scene gone and its own ship flying in
	await _handover(&"hostile_contact")
	_finish()


## Why a piece will not draw, or "".
func _piece_wrong(pid: StringName) -> String:
	if not LocalSubject.has_piece(pid):
		return "not in the index"
	var p: Dictionary = LocalSubject.piece_info(pid)
	if String(p.get("kind", "")) == "painter":
		return "" if Worlds.WORLD.has(StringName(p.get("world", ""))) else "the painter has no world %s" % p.get("world", "")
	var f := String(p.get("file", ""))
	if not ResourceLoader.exists(f):
		return "no picture at %s" % f
	return ""


## Your ship's parts' layer on LOCAL, or null.
func _mounts_of(sc: SectorScreen) -> MountPoints:
	if sc == null or sc._view == null or sc._view.ship_view() == null:
		return null
	for c in sc._view.ship_view().get_children():
		if c is MountPoints:
			return c
	return null


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
	# YOUR SHIP'S PARTS ON ITS HULL FROM THE FIRST FRAME DRAWN (the review page's
	# shots caught them where the hull would be in a narrower view: LOCAL's ship
	# slot is laid out at its minimum width first in some frames)
	var early: Array[String] = []
	for i in 40:
		await _tree.process_frame
		var mp0 := _mounts_of(Router.current as SectorScreen)
		if mp0 != null:
			for nm in mp0.strays():
				early.append("frame %d: %s" % [i, nm])
	var sc := Router.current as SectorScreen
	if not _ok("LOCAL is up with %s open" % oid, sc != null):
		return
	_ok("your ship's parts are on its hull on every frame as LOCAL comes up (%s)" % (", ".join(early.slice(0, 4)) if not early.is_empty() else "all"), early.is_empty())
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
	# YOUR SHIP'S PARTS ON ITS HULL while the event is up, and once its band has
	# folded away and LOCAL laid the scene out again (the review page's shots
	# caught them left where the hull had been)
	var mp := _mounts_of(sc)
	if mp != null:
		var off := mp.strays()
		_ok("your ship's parts are on its hull with the event up (%s)" % (", ".join(off) if not off.is_empty() else "all"), off.is_empty())
		if sc._events != null:
			sc._events.not_now()
			var off2: Array[String] = []
			for i in 30:
				await _tree.process_frame
				for nm in mp.strays():
					off2.append("frame %d: %s" % [i, nm])
			_ok("and on every frame as its band folds away (%s)" % (", ".join(off2.slice(0, 4)) if not off2.is_empty() else "all"), off2.is_empty())
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
## starts it (`Router.start_ambush`). The scene shows kept pool ships only: no
## `foe:` in its cast, nothing `EnemyArt` drew. On the fight's first frame the
## scene is already gone, so there are never two ships for one (the pool ship
## and the fight's own), and the fight's ship is flying in from the right.
func _handover(oid: StringName) -> void:
	Rng.reseed(4242, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
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
	SectorScreen._approached_at = idx
	SystemMapScreen._parked.erase(idx)
	LocalEventDrawer.quiet = true
	LocalEventDrawer.request(idx, 0)
	Router.show_local()
	for i in 30:
		await _tree.process_frame
	var sc := Router.current as SectorScreen
	var sub := LocalSubject.of(sc._view) if sc != null else null
	var coded: Array[String] = []
	var pool := 0
	if sub != null:
		for c in sub.cast:
			if String(c).begins_with("foe:") or not LocalSubject.has_piece(c):
				coded.append(String(c))
			elif String(LocalSubject.piece_info(c).get("kind", "")) == "ship":
				pool += 1
	_ok("%s shows kept pool ships, never the fight's coded ship (%d pool, %s)" % [oid, pool, ", ".join(coded) if not coded.is_empty() else "none coded"],
		sub != null and pool > 0 and coded.is_empty())
	Router.start_ambush()
	await _tree.process_frame
	var sc1 := Router.current as SectorScreen
	_ok("  and on the fight's first frame the scene is gone (no second ship)", sc1 != null and LocalSubject.of(sc1._view) == null)
	var slot: EnemySlot = null
	if sc1 != null:
		for e: Variant in sc1._view.get("_made"):
			if e is EnemySlot:
				slot = e
	_ok("  and the fight's own ship is flying in (%s)" % (("%d px right of its place, alpha %.2f" % [slot.art.position.x, slot.modulate.a]) if slot != null else "no slot"),
		slot != null and slot.art.position.x > 0.0 and slot.modulate.a < 1.0)
	for i in 30:
		await _tree.process_frame
	var brought := &""
	if Router.combat != null and not Router.combat.enemies.is_empty():
		brought = Router.combat.enemies[0].template.id
	_ok("  and the fight brings its own ship (%s), drawn by EnemyArt" % brought, brought != &"")
	var sc2 := Router.current as SectorScreen
	_ok("  and the scene's own stays gone in the fight", sc2 != null and LocalSubject.of(sc2._view) == null)
	LocalEventDrawer.quiet = false


## LOCAL SHOWS THE WORLD YOU ORBIT NOW (Jon: "when transitioning from one planet
## to another I have to go to the local and then the system and then the local
## again for the local to update"). LOCAL composes its sky from where the map
## left the ship (`SystemMapScreen._parked`), and the map wrote that only on its
## way out of the tree -- after the screen replacing it had already been built
## from the old record. Through the real Router, as the HUD's tab goes: in orbit
## of world A, LOCAL; the map; a flight to world B, flown on the map's own
## clock; LOCAL once, and it must draw B. Then the map again, which must put the
## ship back at B.
func _orbit_switch() -> void:
	Rng.reseed(4242, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := -1
	var worlds: Array[int] = []
	for m: MapGen.MapNode in Run.map:
		if m.type != MapGen.NodeType.SYSTEM:
			continue
		var L := SystemLayout.of(m)
		var ws: Array[int] = []
		for bi in L.bodies.size():
			if L.bodies[bi].world != &"":
				ws.append(bi)
		if ws.size() >= 2:
			idx = m.index
			worlds = ws
			break
	if not _ok("a system with two worlds to fly between (%d)" % idx, idx >= 0):
		return
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	SystemMapScreen._parked.erase(idx)
	var a := worlds[0]
	var b := worlds[worlds.size() - 1]
	var map := await _map_up()
	if not _ok("the map is up", map != null):
		return
	map.flight.place_at(a, map.view.t)
	Router.show_local()
	await _frames(10)
	var sky := _local_sky()
	_ok("in orbit of world %d, LOCAL draws it (%s)" % [a, _orbit_name(sky)], sky != null and sky.orbit_target == a)
	map = await _map_up()
	if not _ok("the map again, the ship still at world %d (%d)" % [a, map.flight.reached() if map != null else -9], map != null and map.flight.reached() == a):
		return
	# FLOWN, not placed: the map's own clock and flight, to the orbit at B
	map.frozen = false
	map.select_body(b)
	map.fly_to_body(b)
	var t0 := Time.get_ticks_msec()
	while map.flight.reached() != b and Time.get_ticks_msec() - t0 < 30000:
		await _tree.process_frame
	if not _ok("flown to world %d in %.1f s" % [b, (Time.get_ticks_msec() - t0) / 1000.0], map.flight.reached() == b):
		map.flight.place_at(b, map.view.t)
	await _frames(5)
	# LOCAL ONCE, by the HUD's tab: B, not A
	Router.show_local()
	await _frames(10)
	sky = _local_sky()
	var L2 := SystemLayout.of(Run.node_at())
	var want := "%s (%s %s, seed %d)" % [L2.bodies[b].name, L2.bodies[b].kind, L2.bodies[b].world, L2.bodies[b].seed]
	_ok("after flying A -> B, LOCAL draws B on its first showing: %s, wanted %s" % [_orbit_name(sky), want], sky != null and sky.orbit_target == b)
	map = await _map_up()
	_ok("and the map puts the ship back at world %d (%d)" % [b, map.flight.reached() if map != null else -9], map != null and map.flight.reached() == b)
	# off the map and its record dropped, so the next check's LOCAL is its own
	Router.show_local()
	await _frames(3)
	SystemMapScreen._parked.erase(idx)


## The map through the Router, its ship set up (`show_system` awaits its view).
func _map_up() -> SystemMapScreen:
	Router.show_system()
	for i in 120:
		await _tree.process_frame
		var m := Router.current as SystemMapScreen
		if m != null and m.flight != null:
			m.frozen = true
			return m
	return null


func _local_sky() -> LocalSky:
	var sc := Router.current as SectorScreen
	if sc == null or sc._view == null:
		return null
	return sc._view.backdrop


func _orbit_name(sky: LocalSky) -> String:
	if sky == null:
		return "no LOCAL"
	if sky.orbit_target < 0:
		return "orbit %d" % sky.orbit_target
	var bd: SystemLayout.Body = sky.layout.bodies[sky.orbit_target]
	return "world %d, %s (%s %s, seed %d)" % [sky.orbit_target, bd.name, bd.kind, bd.world, bd.seed]


func _frames(k: int) -> void:
	for i in k:
		await _tree.process_frame


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
