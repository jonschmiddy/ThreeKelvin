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

##
## A BIG STRUCTURE (`structure`, Jon's "Pulling up to it"): pinned to the view's
## right edge instead of placed in the box -- it runs off the top, the right and
## the bottom, from about x 540, its nearest part at your ship's height and clear
## of your ship; what goes with it inside the view, above the band and off your
## ship. On the real LOCAL it is drawn there, behind the hulls; a fight's wreck
## does not move it, it dims behind the wreck, and the wreck is still clicked
## through it (its hold opens); and in the cutaway it zooms with the scene, under
## the blur, and comes back to its place. Its moving parts glide (Jon: "can the
## motion be more smooth?"): a cradle's arms go open, shut, open again with no
## jump between frames, and every part turns about a pivot inside its picture.

const STAGES := [&"single", &"row", &"tether", &"field", &"herd", &"line", &"around", &"on_rock", &"strewn", &"ring", &"group", &"structure", &"ring_arc", &"none", &"fx"]
## The effects `LocalFx` draws (`fx` stages).
const FX := [&"beam", &"glare", &"wind", &"dust", &"front", &"stream", &"drift", &"gas", &"buoy", &"marks", &"moor"]
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
	# (a structure is pinned level with your ship's slot's middle, as LOCAL pins it)
	var ship_mid := art.get_global_rect().get_center().y - sc._view.global_position.y
	print("  ..   LOCAL's view %dx%d, the subject's box %s, your ship %s (its middle row %d)" % [view_size.x, view_size.y, box, ship, ship_mid])
	var bad_struct: Array[String] = []
	var n_struct := 0

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
			# (an effect is drawn in code, and `none` only takes the stand-in's place)
			if kind == &"fx":
				if not StringName(st.get("fx", &"")) in FX:
					bad_stage.append("%s: no effect %s" % [id, st.get("fx", &"")])
				for k2: String in ["tether", "on", "from", "to"]:
					if st.has(k2) and (st[k2] is StringName or st[k2] is String):
						ids.append(st[k2])
			if ids.is_empty() and not kind in [&"none", &"fx"]:
				bad_stage.append("%s: no pieces" % id)
			for pid in ids:
				var why := _piece_wrong(StringName(pid))
				if why != "":
					bad_piece.append("%s: %s (%s)" % [id, pid, why])
		# NEVER THE FIGHT'S CODED SHIP: LOCAL draws pool art only
		if "\"foe\"" in str(o.subject):
			bad_piece.append("%s: names `foe` (the fight's coded ship; LOCAL shows pool ships only)" % id)
		var planned := LocalSubject.plan(o.subject, o.id, 5)
		if LocalSubject.has_structure(o.subject):
			n_struct += 1
			bad_struct.append_array(_structure_wrong(id, planned, view_size, ship, ship_mid))
		else:
			var b := LocalSubject.box_bounds(planned)
			var placed := Rect2(b.position + (box.get_center() - b.get_center()).round(), b.size)
			# (nothing placed in the box: an effect, a stage stood on the sky, or none)
			if b.size == Vector2.ZERO:
				placed = Rect2(box.get_center(), Vector2.ONE * 2.0)
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
	_ok("every big structure (%d) is pinned to the right edge, runs off the top, right and bottom, clear of your ship, its near part at your height, what goes with it in view (%s)" % [n_struct,
		", ".join(bad_struct) if not bad_struct.is_empty() else "all"], bad_struct.is_empty())
	_cycle_checks()
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

	# EVERY WORLD TURNS WITH ITS SURFACE'S MEMORY, and still turns
	await _world_memory()
	# LOCAL DRAWS WHAT THE SHIP ORBITS NOW, after a flight on the map
	await _orbit_switch()
	# AND WHERE IT WAS LEFT SURVIVES A SAVE AND A RELOAD
	await _orbit_reload()
	# ONCE ON THE REAL LOCAL: the six tanks on their tether, opened there
	await _live(&"the_fuel_cache")
	# AND WITH A FIGHT'S WRECKS THERE: the subject makes room (a wreck is a door,
	# so it keeps its place)
	var sets := await _live_wrecks(&"the_fuel_cache")
	var crossed: Array[String] = []
	var outside: Array[String] = []
	var halves := 0
	for o: Dictionary in OptionTable.all():
		# (a big structure is not moved for wrecks: it stays behind them, `_live_structure`)
		if not o.has("subject") or LocalSubject.has_structure(o.subject):
			continue
		var planned := LocalSubject.plan(o.subject, o.id, 5)
		var b := LocalSubject.box_bounds(planned)
		if b.size == Vector2.ZERO:
			continue
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
	# A BIG STRUCTURE ON THE REAL LOCAL: pinned, behind the hulls, behind a wreck
	# that still opens through it, and zoomed with the scene in the cutaway
	await _live_structure(&"cold_labour")
	# THE HANDOVER: the scene before the fight shows pool ships, never the fight's
	# coded one; the fight opens with the scene gone and its own ship flying in
	await _handover(&"hostile_contact")
	# THE BARE EVENTS BUILT (Jon's "Forty-three bare events" plan): where they
	# sit, what each shows, and that none of it covers your ship
	_site_rule()
	await _bare_events()
	# ROUND THREE'S KEEPS (Jon's verdicts on the bare events' takes): each wired
	# encounter shows its kept art, every kept take fits, the per-system pick
	await _kept_round3(view_size, box, ship, ship_mid)
	# ROUND FOUR'S DOCK FACES: every take in every berth event, its pieces on
	# that take's own parts, the clamp's jaws on your bow
	await _dock_faces(view_size, ship, ship_mid)
	# and a plate with a moving part, pinned and behind a fight's wreck
	await _live_structure(&"the_automatic_dock")
	_finish()


## WHAT EACH BUILT EVENT SHOWS, as its plan says (Jon's "Forty-three bare
## events", every one said yes to): [the effects drawn in code, the kept pieces
## (pool ships by role count as theirs)]. The_uncollected_order is not here: its
## art is being made.
const BUILT := {
	&"slipping_orbit": [[], [&"r5_scatter_spar_1", &"r4_scatter_torn_plate_1"]],
	&"the_scoop": [[], []],
	&"the_storm": [[], [&"ship_bored"]],
	&"the_rings": [[], [&"place_derelict", &"ship_cl_drums", &"r3_frame_gutted_frame_2", &"ship_lattice"]],
	&"the_breaking_moon": [[], [&"paint_moon_ice", &"paint_rock_a1", &"paint_rock_a2", &"paint_rock_b3"]],
	&"corona": [[], [&"ship_cl_stack"]],
	&"flare_shelter": [[], [&"paint_rock_a1", &"r2_drone_delivery_drone_2"]],
	&"the_dust_cloud": [[&"dust"], [&"ship_scoop"]],
	&"the_century_log": [[], [&"ship_science"]],
	&"the_comet": [[], [&"paint_moon_ice"]],
	&"the_glare": [[&"glare"], [&"ship_lrshuttle"]],
	&"the_wind": [[&"wind"], []],
	&"the_beacon_job": [[&"buoy"], [&"r2_container_freight_box_2"]],
	&"the_sorting": [[&"drift"], [&"r4_scatter_cabin_section_1", &"r4_scatter_tank_half_1", &"r4_scatter_drive_nozzle_1"]],
	&"the_sweep": [[&"beam"], [&"ship_rly_dishes"]],
	&"dead_boards": [[&"beam"], [&"ship_cl_tree"]],
	&"the_timekeeper": [[&"beam"], [&"ship_bigdish"]],
	&"thin_glaze": [[&"beam"], [&"r4_cache_tether_anchor_1", &"r2_minedrift_broken_strut_1", &"r2_minedrift_cable_coil_1", &"r5_scatter_spar_2"]],
	&"the_quiet_beam": [[], [&"r3_frame_gutted_frame_2", &"place_derelict", &"r5_split_derelict_1", &"ship_courier2", &"ship_catamaran"]],
	&"no_stars": [[&"gas"], []],
	&"silt": [[&"dust"], [&"ship_lattice", &"r4_scatter_torn_plate_1", &"r4_minedrift_cable_coil_1", &"r2_minedrift_broken_strut_1"]],
	&"the_front": [[&"front"], []],
	&"the_ice_stream": [[&"stream"], [&"paint_rock_a1", &"paint_moon_ice"]],
	&"ice": [[], [&"paint_moon_europa"]],
	&"the_last_turn": [[&"marks"], [&"paint_rock_a1"]],
	&"salvage_rights": [[&"moor"], [&"r3_frame_gutted_frame_1", &"ship_catamaran"]],
	&"the_split_loop": [[], [&"ship_orbitarms"]],
	&"receipted_twice": [[], [&"ship_forked"]],
	&"ghost_signal": [[], []],
	&"distress_beacon": [[], []],
	&"lost_in_the_gas": [[], []],
}
## ROUND THREE'S KEEPS (Jon's Keep on the bare events' generated takes), what
## each encounter draws: its kept takes (one drawn per system where he kept more
## than one, `pick`) and the kept pieces that go with them. The four berth
## events share round four's four dock faces ("all look great").
const KEPT3 := {
	&"the_thrower": [[&"st_the_thrower"], [&"r2_thrower_canister_on_sled_2"]],
	&"the_automatic_dock": [[&"st_the_automatic_dock"], []],
	&"the_glass_ring": [[&"st_the_glass_ring_1", &"st_the_glass_ring_2"], []],
	&"counterweight": [[&"t3_counterweight_1", &"t3_counterweight_2", &"t3_counterweight_4"], []],
	&"counting_backwards": [[&"t3_counting_backwards_a_2", &"t3_counting_backwards_b_1", &"t3_counting_backwards_b_2"], []],
	&"the_auction": [[&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], [&"r2_holding_old_container_2", &"ship_mkt_slung", &"ship_courier2", &"ship_hp_wards"]],
	&"seized_clamp": [[&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], []],
	&"paid_in_full": [[&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], []],
	&"the_parted_line": [[&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], [&"ship_lightfreighter"]],
}
## Which of them are big structures pinned to the right edge (plates).
const PLATES3 := [&"the_thrower", &"the_automatic_dock", &"the_glass_ring", &"the_auction", &"seized_clamp", &"paid_in_full", &"the_parted_line"]


## ROUND THREE'S KEEPS, wired:
##  - every kept take of each encounter is drawn by it at some system, and each
##    one, forced, stages as the rest do: a plate pinned to the right edge (off
##    the top, right and bottom, clear of your ship, its near part at your
##    height, what goes with it in view), an object inside the box and off your
##    ship, nothing drawn across anything;
##  - THE PER-SYSTEM PICK (`LocalSubject.pick_of`): the same system draws the same
##    take every time it is asked, and across the run's systems every take turns up;
##  - on the real LOCAL, at a system it could be rolled at: it draws its kept
##    art (one of its takes; its pieces), the plate pinned and behind the hulls,
##    nothing of it on your ship -- but the seized clamp's arm, whose jaws touch
##    your bow and never cross it -- or under the band; and the same encounter at
##    another system that picks another take draws that one, and back at the
##    first system, the first take again.
func _kept_round3(view_size: Vector2, box: Rect2, ship: Rect2, ship_mid: float) -> void:
	var bad: Array[String] = []
	var n_take := 0
	for oid: StringName in KEPT3:
		var o := OptionTable.by_id(oid)
		if not o.has("subject"):
			bad.append("%s: no subject" % oid)
			continue
		var takes: Array = KEPT3[oid][0]
		for k in takes.size():
			LocalSubject.force_pick = k
			var planned := LocalSubject.plan(o.subject, oid, 5, 0)
			LocalSubject.force_pick = -1
			var ids: Array = []
			for m: Dictionary in planned:
				ids.append(StringName(m.id))
			if not takes[k] in ids:
				bad.append("%s: take %d (%s) not drawn when picked (%s)" % [oid, k, takes[k], ids])
				continue
			for other: StringName in takes:
				if other != takes[k] and other in ids:
					bad.append("%s: two takes of one thing drawn at once (%s, %s)" % [oid, takes[k], other])
			for pid: StringName in KEPT3[oid][1]:
				if not pid in ids:
					bad.append("%s: %s not in its scene" % [oid, pid])
			if oid in PLATES3:
				if not LocalSubject.has_structure(o.subject):
					bad.append("%s: not pinned as a plate" % oid)
				bad.append_array(_structure_wrong("%s take %d" % [oid, k], planned, view_size, ship, ship_mid))
			else:
				var b := LocalSubject.box_bounds(planned)
				var placed := Rect2(b.position + (box.get_center() - b.get_center()).round(), b.size)
				if not box.encloses(placed.grow(-1.0)):
					bad.append("%s take %d: out of its box (%s)" % [oid, k, placed])
				if placed.grow(6.0).intersects(ship):
					bad.append("%s take %d: on your ship" % [oid, k])
			for c: String in LocalSubject.clear_of(planned):
				bad.append("%s take %d: piled %s" % [oid, k, c])
			n_take += 1
	_ok("round three's keeps: every kept take (%d) drawn by its encounter, each staged clear, plates pinned, objects in their box (%s)" % [n_take,
		", ".join(bad) if not bad.is_empty() else "all"], bad.is_empty() and n_take == 26)
	# THE PER-SYSTEM PICK
	Rng.reseed(4242, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var unstable: Array[String] = []
	var unseen: Array[String] = []
	var spread := []
	for oid: StringName in KEPT3:
		var n := (KEPT3[oid][0] as Array).size()
		if n < 2:
			continue
		var seen := {}
		var systems := 0
		for node: MapGen.MapNode in Run.map:
			if node.type != MapGen.NodeType.SYSTEM:
				continue
			systems += 1
			var p := LocalSubject.pick_of(n, oid, node.index)
			if p != LocalSubject.pick_of(n, oid, node.index):
				unstable.append("%s at %d" % [oid, node.index])
			seen[p] = int(seen.get(p, 0)) + 1
		if seen.size() < n:
			unseen.append("%s (%d of %d over %d systems)" % [oid, seen.size(), n, systems])
		spread.append("%s %s" % [oid, seen])
	print("  ..   takes per system over the run: %s" % "; ".join(spread))
	_ok("the per-system pick is the same every time at a system (%s)" % (", ".join(unstable) if not unstable.is_empty() else "all"), unstable.is_empty())
	_ok("  and every kept take turns up somewhere across the run's systems (%s)" % (", ".join(unseen) if not unseen.is_empty() else "all"), unseen.is_empty())
	# ON THE REAL LOCAL
	var live_bad: Array[String] = []
	var n_live := 0
	LocalEventDrawer.quiet = true
	for oid: StringName in KEPT3:
		var got := await _open_at(oid, -1)
		var sub: LocalSubject = got.sub
		var sc: SectorScreen = got.sc
		if sub == null:
			live_bad.append("%s: nothing on LOCAL" % oid)
			continue
		n_live += 1
		var takes: Array = KEPT3[oid][0]
		var drew: Array = takes.filter(func(t: StringName) -> bool: return t in sub.cast)
		if drew.size() != 1:
			live_bad.append("%s: drew %s, not one of its takes" % [oid, sub.cast])
		for pid: StringName in KEPT3[oid][1]:
			if not pid in sub.cast:
				live_bad.append("%s: %s not drawn" % [oid, pid])
		var vr := sc._view.get_global_rect()
		var art := sc._view.ship_view()
		var ship_g := Rect2(art.ship_rect().position + art.global_position, art.ship_rect().size)
		var band_top := vr.end.y - LocalSubject.BAND
		if oid in PLATES3:
			var sr := sub.st_rect
			var vs: Vector2 = sc._view.size
			if sub._st.is_empty() or sr.end.x < vs.x or sr.position.y >= 0.0 or sr.end.y < vs.y:
				live_bad.append("%s: its plate not pinned off the right, top and bottom (%s)" % [oid, sr])
			if sub.get_index() >= sc._view._row.get_index():
				live_bad.append("%s: its plate not behind the hulls" % oid)
		for rec: Dictionary in sub._placed:
			var spr: Sprite2D = rec.sprite
			if spr.texture == null:
				continue
			var sz := spr.texture.get_size() * spr.scale
			var c := spr.get_global_transform().origin
			var r := Rect2(c - sz * 0.5, sz)
			# (the plate itself runs under the band and off the view: pinned, checked above)
			if bool(rec.get("structure", false)):
				if r.intersects(ship_g.grow(4.0)):
					live_bad.append("%s: its plate on your ship" % oid)
				continue
			if r.intersects(ship_g.grow(4.0)):
				live_bad.append("%s: a piece on your ship (%s)" % [oid, r])
			if r.end.y > band_top + 4.0:
				live_bad.append("%s: a piece under the band (%s)" % [oid, r])
		# THE CLAMP'S ARM: its jaws on your bow, touching, never across it
		var gr := sub.grip_rect()
		if oid == &"seized_clamp":
			var bow := sub.bow_point()
			if gr.size.x <= 0.0 or not bow.is_finite():
				live_bad.append("seized_clamp: no clamp arm drawn to your bow")
			elif absf(gr.position.x - roundf(bow.x)) > 0.5 or gr.position.y > bow.y or gr.end.y < bow.y:
				live_bad.append("seized_clamp: its jaws not on your bow (arm %s, bow %s)" % [gr, bow])
			else:
				var sl := sub.get_global_transform() * Rect2(bow, Vector2.ONE)
				print("  ..   seized_clamp: the arm %s, its jaws at your bow %s (%s on screen)" % [gr, bow, sl.position])
		elif gr.size.x > 0.0:
			live_bad.append("%s: a clamp arm it should not have" % oid)
	# THE PICK ON LOCAL: the glass ring at two systems that pick its two takes,
	# then back at the first
	Rng.reseed(4242, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var by_take := {}
	for node: MapGen.MapNode in Run.map:
		if node.type == MapGen.NodeType.SYSTEM and not by_take.has(LocalSubject.pick_of(2, &"the_glass_ring", node.index)):
			by_take[LocalSubject.pick_of(2, &"the_glass_ring", node.index)] = node.index
	var shown: Array = []
	if by_take.size() == 2:
		for sys: int in [by_take[0], by_take[1], by_take[0]]:
			var got := await _open_at(&"the_glass_ring", sys, false)
			var sub: LocalSubject = got.sub
			shown.append(sub.cast[0] if sub != null and not sub.cast.is_empty() else &"")
	LocalEventDrawer.quiet = false
	Router.show_local()
	await _frames(3)
	_ok("on the real LOCAL every wired encounter (%d of %d) draws its kept art, plates pinned behind the hulls, nothing on your ship but the clamp's jaws on your bow, nothing under the band (%s)" % [n_live, KEPT3.size(),
		", ".join(live_bad) if not live_bad.is_empty() else "all"], live_bad.is_empty() and n_live == KEPT3.size())
	_ok("  the glass ring at two systems draws its two takes, and the first system its first again (%s)" % str(shown),
		shown.size() == 3 and shown[0] == &"st_the_glass_ring_1" and shown[1] == &"st_the_glass_ring_2" and shown[2] == shown[0])


## THE FOUR KEPT DOCK FACES in the four berth events (the auction, the seized
## clamp, paid in full, the parted line):
##  - every part an encounter names (`anchors`: cargo, collar, lug0/1/2) is on
##    that take's own metal (within 3 px of an opaque pixel of its picture);
##  - every take forced in every event puts its pieces there: the lot at the
##    cargo berth, the lit berth's lamp at the collar, the lighter under the
##    mast's lugs with its lines from them and the parted one from the head, the
##    clamp's arm leaving from the collar -- and stages as a plate must;
##  - on the real LOCAL, each take in each event: nothing of it on your ship or
##    under the band; the clamp's arm leaves from that take's metal on its row
##    and its jaws touch your bow without crossing it.
func _dock_faces(view_size: Vector2, ship: Rect2, ship_mid: float) -> void:
	var bad: Array[String] = []
	var n := 0
	var ev: Array[StringName] = [&"the_auction", &"seized_clamp", &"paid_in_full", &"the_parted_line"]
	var takes: Array = KEPT3[&"the_auction"][0]
	for k in takes.size():
		var p := LocalSubject.piece_info(StringName(takes[k]))
		var img := LocalSubject._image_of(String(p.get("file", "")))
		if img != null and img.is_compressed():
			img.decompress()
		var an: Dictionary = p.get("anchors", {})
		var pts := {}
		for role: String in ["cargo", "collar", "lug0", "lug1", "lug2"]:
			if not an.has(role):
				bad.append("%s: no %s" % [takes[k], role])
				continue
			pts[role] = Vector2(float(an[role][0]), float(an[role][1]))
			if img == null or not _near_metal(img, pts[role], 3):
				bad.append("%s: its %s %s is not on its metal" % [takes[k], role, an[role]])
		if pts.size() < 5:
			continue
		var c := Vector2(float(p.w), float(p.h)) * 0.5
		for oid: StringName in ev:
			LocalSubject.force_pick = k
			var planned := LocalSubject.plan(OptionTable.by_id(oid).subject, oid, 5, 0)
			LocalSubject.force_pick = -1
			var st := LocalSubject.structure_in(planned)
			if StringName(st.get("id", &"")) != StringName(takes[k]):
				bad.append("%s take %d: draws %s" % [oid, k + 1, st.get("id", &"")])
				continue
			n += 1
			match oid:
				&"the_auction":
					for m: Dictionary in planned:
						if StringName(m.id) == &"r2_holding_old_container_2" and ((m.at as Vector2) + c).distance_to((pts.cargo as Vector2) + Vector2(-26, 0)) > 1.0:
							bad.append("the_auction take %d: the lot at %s, not at its cargo berth %s" % [k + 1, (m.at as Vector2) + c, an.cargo])
				&"paid_in_full":
					var l: Dictionary = (st.get("st_add_lights", [{}]) as Array)[0]
					var la: Array = l.get("at", [-99, -99])
					if Vector2(float(la[0]), float(la[1])).distance_to(pts.collar) > 3.0:
						bad.append("paid_in_full take %d: its lit berth at %s, not its collar %s" % [k + 1, la, an.collar])
				&"seized_clamp":
					var g: Dictionary = st.get("st_grip", {})
					if absf(float(g.get("from_x", -99)) - float(an.collar[0])) > 0.5:
						bad.append("seized_clamp take %d: the arm from x %s, not its collar %s" % [k + 1, g.get("from_x"), an.collar])
				&"the_parted_line":
					var ls: Array = st.get("st_lines", [])
					var pl: Dictionary = st.get("st_parted", {})
					var ok := ls.size() == 2 and pl.has("from")
					if ok:
						ok = Vector2(float(ls[0].from[0]), float(ls[0].from[1])) == pts.lug0 \
							and Vector2(float(ls[1].from[0]), float(ls[1].from[1])) == pts.lug1 \
							and Vector2(float(pl.from[0]), float(pl.from[1])) == pts.lug2
					if not ok:
						bad.append("the_parted_line take %d: its lines not from its lugs" % (k + 1))
					for m: Dictionary in planned:
						if StringName(m.id) == &"ship_lightfreighter" and ((m.at as Vector2) + c).distance_to((pts.lug0 as Vector2) + Vector2(-8, 69)) > 1.0:
							bad.append("the_parted_line take %d: the lighter not under its mast" % (k + 1))
			bad.append_array(_structure_wrong("%s take %d" % [oid, k + 1], planned, view_size, ship, ship_mid))
	_ok("the four dock faces (%d placings): every named part on its take's metal, and every take in every berth event puts its pieces there (%s)" % [n,
		", ".join(bad) if not bad.is_empty() else "all"], bad.is_empty() and n == 16)
	# ON THE REAL LOCAL, every take in every berth event
	var live: Array[String] = []
	var n_live := 0
	LocalEventDrawer.quiet = true
	for k in takes.size():
		for oid: StringName in ev:
			LocalSubject.force_pick = k
			var got := await _open_at(oid, -1)
			LocalSubject.force_pick = -1
			var sub: LocalSubject = got.sub
			var sc: SectorScreen = got.sc
			if sub == null or sub._st.is_empty() or StringName((sub._st as Dictionary).id) != StringName(takes[k]):
				live.append("%s take %d: not drawn" % [oid, k + 1])
				continue
			n_live += 1
			var vr := sc._view.get_global_rect()
			var art := sc._view.ship_view()
			var ship_g := Rect2(art.ship_rect().position + art.global_position, art.ship_rect().size)
			for rec: Dictionary in sub._placed:
				if bool(rec.get("structure", false)):
					continue
				var spr: Sprite2D = rec.sprite
				if spr.texture == null:
					continue
				var sz := spr.texture.get_size() * spr.scale
				var r := Rect2(spr.get_global_transform().origin - sz * 0.5, sz)
				if r.intersects(ship_g.grow(4.0)):
					live.append("%s take %d: %s on your ship" % [oid, k + 1, rec.id])
				if r.end.y > vr.end.y - LocalSubject.BAND + 4.0:
					live.append("%s take %d: %s under the band" % [oid, k + 1, rec.id])
			var gr := sub.grip_rect()
			if oid == &"seized_clamp":
				var bow := sub.bow_point()
				var gimg := sub._grip_img()
				if gr.size.x <= 0.0 or not bow.is_finite() or gimg == null:
					live.append("seized_clamp take %d: no arm" % (k + 1))
					continue
				var row := int(roundf(bow.y - sub.st_rect.position.y))
				var root := int(gr.end.x - sub.st_rect.position.x)
				if absf(gr.position.x - roundf(bow.x)) > 0.5 or gr.position.y > bow.y or gr.end.y < bow.y:
					live.append("seized_clamp take %d: its jaws not on your bow (arm %s, bow %s)" % [k + 1, gr, bow])
				elif root < 0 or root >= gimg.get_width() or row < 0 or row >= gimg.get_height() or gimg.get_pixel(root, row).a < 0.5:
					live.append("seized_clamp take %d: its arm leaves from the air (x %d, row %d)" % [k + 1, root, row])
				else:
					print("  ..   seized_clamp take %d: arm %s from x %d of the take, jaws on your bow %s" % [k + 1, gr, root, bow])
			elif gr.size.x > 0.0:
				live.append("%s take %d: a clamp arm it should not have" % [oid, k + 1])
	LocalEventDrawer.quiet = false
	Router.show_local()
	await _frames(3)
	_ok("  on the real LOCAL, every take in every berth event (%d of 16): nothing on your ship or under the band, the clamp's arm from the take's metal to your bow, touching it (%s)" % [n_live,
		", ".join(live) if not live.is_empty() else "all"], live.is_empty() and n_live == 16)


## Whether `img` has an opaque pixel within `r` px of `q`.
func _near_metal(img: Image, q: Vector2, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := int(q.x) + dx
			var y := int(q.y) + dy
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and img.get_pixel(x, y).a > 0.5:
				return true
	return false


## `oid` opened on the real LOCAL at system `sys` (-1: the first one free), the
## system given the sky its gates ask for and the ship parked where it sits.
## {sc, sub}. `fresh`: a new run first.
func _open_at(oid: StringName, sys: int, fresh: bool = true) -> Dictionary:
	var o := OptionTable.by_id(oid)
	if fresh:
		Rng.reseed(4242, 0)
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := _a_system() if sys < 0 else sys
	var node: MapGen.MapNode = Run.map[idx]
	node.visited = true
	if o.has("needs_star"):
		node.star = int(o.needs_star)
	node.gas_giant = bool(o.get("needs_giant", node.gas_giant))
	node.near_pulsar = bool(o.get("needs_pulsar", node.near_pulsar))
	node.in_nebula = bool(o.get("needs_nebula", node.in_nebula))
	node.options.clear()
	node.options.append(oid)
	Run.at = idx
	SectorScreen._approached_at = idx
	var place := LocalEventDrawer.body_of(node, 0)
	SystemMapScreen._parked[idx] = {"at": place, "p": Vector2(900.0, -210.0), "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}
	LocalEventDrawer.request(idx, 0)
	Router.show_local()
	await _frames(25)
	var sc := Router.current as SectorScreen
	return {sc = sc, sub = LocalSubject.of(sc._view) if sc != null else null}


## Which of them sit on the giant and which on the star (`site`).
const ON_GIANT := [&"slipping_orbit", &"the_scoop", &"the_storm", &"the_rings", &"the_breaking_moon"]
const ON_STAR := [&"corona", &"flare_shelter", &"the_dust_cloud", &"the_century_log", &"the_comet", &"the_glare", &"the_wind", &"the_beacon_job", &"the_sorting"]


## THE GIANT AND THE STAR RULE (`SystemLayout`, an option's `site`): an event
## whose text has the giant filling the sky sits on the giant, one in a red or
## blue star's glare on the star -- in a system with that giant or star, beside
## other options; where it has none, it takes a place by its tags as before.
## And the map and LOCAL agree where it is (`LocalEventDrawer.body_of`).
func _site_rule() -> void:
	Rng.reseed(4242, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var bad: Array[String] = []
	var n_ok := 0
	var host: MapGen.MapNode = null
	for m: MapGen.MapNode in Run.map:
		if m.type == MapGen.NodeType.SYSTEM:
			host = m
			break
	var keep := {gas_giant = host.gas_giant, star = host.star, options = host.options.duplicate()}
	for oid: StringName in ON_GIANT + ON_STAR:
		var o := OptionTable.by_id(oid)
		var want_giant := oid in ON_GIANT
		if StringName(o.get("site", &"")) != (&"giant" if want_giant else &"star"):
			bad.append("%s: no site %s" % [oid, "giant" if want_giant else "star"])
			continue
		for with_it: bool in [true, false]:
			host.gas_giant = want_giant and with_it
			host.star = int(o.get("needs_star", MapGen.Star.RED)) if (not want_giant and with_it) else MapGen.Star.ORDINARY
			host.options.clear()
			host.options.append(&"dropped_load")
			host.options.append(oid)
			var L := SystemLayout.of(host)
			var at := L.place_of(1)
			var gi := -1
			for bi in L.bodies.size():
				if L.bodies[bi].kind == &"giant":
					gi = bi
			var want := (gi if want_giant else -1) if with_it else -99
			if with_it and at != want:
				bad.append("%s: on %d, wanted %d" % [oid, at, want])
			elif not with_it and at < 0:
				bad.append("%s: with no %s it is on no body (%d)" % [oid, "giant" if want_giant else "hot star", at])
			elif LocalEventDrawer.body_of(host, 1) != at or L.place_of(0) < 0:
				bad.append("%s: the map and LOCAL disagree, or its neighbour lost its place" % oid)
			else:
				n_ok += 1
	host.gas_giant = keep.gas_giant
	host.star = keep.star
	host.options.assign(keep.options)
	_ok("the giant's events sit on the giant and the hot star's on the star, where there is one; elsewhere by their tags (%d checks; %s)" % [n_ok,
		", ".join(bad) if not bad.is_empty() else "all"], bad.is_empty())


## EVERY BUILT EVENT ON THE REAL LOCAL, at a system it could be rolled at, the
## ship parked where it sits: it shows what its plan says (its effects and its
## pieces), LOCAL's stand-in goes, nothing of it is on your ship or under the
## band -- its pieces, its effects' own light (every shader rect is told your
## ship and the band; every streak and speck drawn is clear of them) -- and the
## beam is eased light: its flat core outlasts a frame's turn at 30 a second (so
## a pixel's peak never goes A, B, A: the flicker budget), it fades as it turns
## toward you rather than flashing, and it is not drawn with reduced motion.
func _bare_events() -> void:
	var bad: Array[String] = []
	var n := 0
	var gas_after := -1.0
	LocalEventDrawer.quiet = true
	for oid: StringName in BUILT:
		var o := OptionTable.by_id(oid)
		if not o.has("subject"):
			bad.append("%s: no subject" % oid)
			continue
		# what it shows, from its plan
		var want: Array = BUILT[oid]
		var fxs: Array = []
		for st: Dictionary in LocalSubject.stages_of(o.subject):
			if StringName(st.get("stage", &"")) == &"fx":
				fxs.append(StringName(st.fx))
		for f: StringName in want[0]:
			if not f in fxs:
				bad.append("%s: no %s" % [oid, f])
		var planned := LocalSubject.plan(o.subject, oid, 5)
		var ids: Array = []
		for m: Dictionary in planned:
			ids.append(StringName(m.id))
		for pid: StringName in want[1]:
			if not pid in ids:
				bad.append("%s: %s not in its scene" % [oid, pid])
		if (want[0] as Array).is_empty() and (want[1] as Array).is_empty() and not planned.is_empty():
			bad.append("%s: should be bare, draws %d pieces" % [oid, planned.size()])
		# on the real LOCAL
		Rng.reseed(4242, 0)
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var idx := _a_system()
		var node: MapGen.MapNode = Run.map[idx]
		node.visited = true
		if o.has("needs_star"):
			node.star = int(o.needs_star)
		node.gas_giant = bool(o.get("needs_giant", node.gas_giant))
		node.near_pulsar = bool(o.get("needs_pulsar", node.near_pulsar))
		node.in_nebula = bool(o.get("needs_nebula", node.in_nebula))
		node.options.clear()
		node.options.append(oid)
		Run.at = idx
		SectorScreen._approached_at = idx
		var place := LocalEventDrawer.body_of(node, 0)
		SystemMapScreen._parked[idx] = {"at": place, "p": Vector2(900.0, -210.0), "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}
		LocalEventDrawer.request(idx, 0)
		Router.show_local()
		await _frames(25)
		var sc := Router.current as SectorScreen
		var sub := LocalSubject.of(sc._view) if sc != null else null
		if sub == null:
			bad.append("%s: nothing on LOCAL" % oid)
			continue
		n += 1
		if sc._view._area != null and sc._view._area.visible:
			bad.append("%s: LOCAL's stand-in still shows" % oid)
		var sky := sc._view.backdrop as LocalSky
		if oid in ON_STAR and (sky == null or sky.orbit_target != -1):
			bad.append("%s: LOCAL not in the star's close orbit" % oid)
		if oid in ON_GIANT and (sky == null or sky.orbit_target < 0 or sky.layout.bodies[sky.orbit_target].kind != &"giant"):
			bad.append("%s: LOCAL not at the giant" % oid)
		var vr := sc._view.get_global_rect()
		var art := sc._view.ship_view()
		var ship := Rect2(art.ship_rect().position + art.global_position, art.ship_rect().size)
		var band_top := vr.end.y - LocalSubject.BAND
		# (a stage stood on the giant's face or its rings is placed from the giant
		# as drawn: headless draws no sky, so there it stands in the box instead
		# and only its fit is checked, by the planning above)
		var on_sky := sky != null and not sky.near_info().is_empty()
		var stood := false
		for st2: Dictionary in LocalSubject.stages_of(o.subject):
			if st2.has("anchor") or StringName(st2.get("stage", &"")) == &"ring_arc":
				stood = true
		for r in sub.drawn_rects():
			if r.intersects(ship.grow(4.0)):
				bad.append("%s: a piece on your ship (%s)" % [oid, r])
			if stood and not on_sky and oid in ON_GIANT:
				continue
			if r.end.y > band_top + 4.0 or r.position.x < vr.position.x - 4.0 or r.end.x > vr.end.x + 4.0:
				bad.append("%s: a piece out of view or under the band (%s)" % [oid, r])
		var fx := sub.fx
		if not (want[0] as Array).is_empty() and fx == null:
			bad.append("%s: its effects are not drawn" % oid)
		if fx != null:
			bad.append_array(_fx_wrong(oid, sub, fx))
		if &"gas" in want[0] and sky != null:
			if not is_equal_approx(sky.closed, 1.0):
				bad.append("%s: the gas has not closed in (%.2f)" % [oid, sky.closed])
			# and opens again once the event is no longer up here
			LocalEventDrawer.last = []
			sc._refresh()
			await _frames(4)
			gas_after = sky.closed
		# a stage stood on the giant's face or its rings: on the view, off your ship
		if &"beam" in want[0]:
			bad.append_array(await _beam_wrong(oid, sub, fx))
	LocalEventDrawer.quiet = false
	Router.show_local()
	await _frames(3)
	_ok("every built bare event (%d of %d) shows its plan on LOCAL, its stand-in gone, nothing on your ship or under the band, its beam eased (%s)" % [n, BUILT.size(),
		", ".join(bad) if not bad.is_empty() else "all"], bad.is_empty() and n == BUILT.size())
	_ok("  and the closed-in gas opens again when its event goes (%.2f)" % gas_after, gas_after == 0.0)


## What is wrong with an event's effects on LOCAL: every shader rect told your
## ship and the band as this frame has them; every streak, speck and grit drawn
## clear of your ship and above the band.
func _fx_wrong(oid: StringName, sub: LocalSubject, fx: LocalFx) -> Array[String]:
	var out: Array[String] = []
	var s := sub.ship_l
	if s.size.x <= 0.0:
		out.append("%s: the effects do not know where your ship is" % oid)
	for e: Dictionary in fx._rects:
		var m: ShaderMaterial = e.mat
		if DisplayServer.get_name() != "headless":
			var sv: Vector4 = m.get_shader_parameter("ship")
			if not Rect2(sv.x, sv.y, sv.z, sv.w).is_equal_approx(s):
				out.append("%s: %s not told your ship" % [oid, e.kind])
	for t: float in [0.0, 1.3, 4.7, 9.1]:
		for q: Vector2 in fx.lit_points(t):
			if s.grow(8.0).has_point(q) or q.y > sub.band_y:
				out.append("%s: light at %s on your ship or under the band (t %.1f)" % [oid, q, t])
				break
	return out


## THE BEAM: its flat core outlasts the most it turns in a frame at 30 a second
## (a pixel's peak lasts frames, never A, B, A); toward you it fades (never
## brighter than it is crossing the sky); with reduced motion it is not drawn.
func _beam_wrong(oid: StringName, sub: LocalSubject, fx: LocalFx) -> Array[String]:
	var out: Array[String] = []
	var st: Dictionary = {}
	for s2: Dictionary in fx.stages:
		if StringName(s2.get("fx", &"")) == &"beam":
			st = s2
	var period := float(st.get("period", 11.0))
	var worst := 0.0
	var prev := NAN
	var k_max := 0.0
	var k_min := 9.0
	var t := 0.0
	var prev_k := 0.0
	while t < period:
		fx._step_beam(st, t)
		# (only while it is seen: turning through you, where it has faded out,
		# its far end comes round to the other side)
		if not is_nan(prev) and fx.beam_k > 0.02 and prev_k > 0.02:
			worst = maxf(worst, absf(wrapf(fx.beam_ang - prev, -PI, PI)))
		prev = fx.beam_ang
		prev_k = fx.beam_k
		k_max = maxf(k_max, fx.beam_k)
		k_min = minf(k_min, fx.beam_k)
		t += 1.0 / 30.0
	if worst >= fx.beam_core:
		out.append("%s: the beam turns %.3f rad a frame, its core %.3f" % [oid, worst, fx.beam_core])
	if k_min > 0.01 or k_max > 1.0:
		out.append("%s: the beam never fades turning toward you (%.2f..%.2f)" % [oid, k_min, k_max])
	var keep := DisplaySettings.reduced_motion
	DisplaySettings.reduced_motion = true
	await _frames(2)
	if fx.beam_hit(Vector2(700.0, 160.0)) > 0.0:
		out.append("%s: the beam still lights things with reduced motion" % oid)
	for e: Dictionary in fx._rects:
		if StringName(e.kind) == &"beam" and (e.rect as ColorRect).visible:
			out.append("%s: the beam still drawn with reduced motion" % oid)
	DisplaySettings.reduced_motion = keep
	return out


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


## What is wrong with a big structure's staging on LOCAL's view (`view_size`,
## your ship at `ship`, its slot's middle row `ship_mid`), or nothing.
func _structure_wrong(id: String, planned: Array, view_size: Vector2, ship: Rect2, ship_mid: float) -> Array[String]:
	var out: Array[String] = []
	var m := LocalSubject.structure_in(planned)
	if m.is_empty():
		out.append("%s: no structure piece" % id)
		return out
	var sr := LocalSubject.structure_rect(StringName(m.id), view_size, ship_mid)
	if sr.end.x < view_size.x:
		out.append("%s: short of the right edge (%d < %d)" % [id, sr.end.x, view_size.x])
	if sr.position.y >= 0.0:
		out.append("%s: does not run off the top (%d)" % [id, sr.position.y])
	if sr.end.y < view_size.y:
		out.append("%s: stops short of the bottom (%d < %d)" % [id, sr.end.y, view_size.y])
	if sr.position.x < ship.end.x + 8.0:
		out.append("%s: reaches your ship (from x %d, your ship to %d)" % [id, sr.position.x, ship.end.x])
	if sr.position.x < view_size.x * 0.5:
		out.append("%s: starts left of the middle (x %d)" % [id, sr.position.x])
	# ITS NEAR PART AT YOUR HEIGHT: some of it on your ship's middle row, in the
	# near half of it
	var mk := LocalSubject.mask_of(m)
	var row := int(ship_mid - sr.position.y)
	var hits := 0
	if row >= 0 and row < int(mk.h):
		var bits: PackedByteArray = mk.bits
		for x in int(int(mk.w) * 0.5):
			hits += int(bits[row * int(mk.w) + x])
	if hits == 0:
		out.append("%s: nothing of it at your ship's height (row %d)" % [id, row])
	# WHAT GOES WITH IT: in view, above the band, off your ship, drift and all
	var room := Rect2(0.0, 0.0, view_size.x, view_size.y - LocalSubject.BAND)
	for w: Dictionary in planned:
		if bool(w.get("structure", false)):
			continue
		var r := LocalSubject.rect_of(w)
		r.position += sr.get_center()
		var d := LocalSubject.drift_of(w)
		r = r.grow_individual(d.x, d.y, d.x, d.y)
		if not room.encloses(r):
			out.append("%s: %s out of view or under the band (%s)" % [id, w.id, r])
		if r.intersects(ship.grow(6.0)):
			out.append("%s: %s on your ship" % [id, w.id])
	return out


## A STRUCTURE'S MOVING PARTS GLIDE: every picture there, each part's pivot
## inside the structure; a cradle's arms go open, shut, open over a cycle, easing
## through many in-between turns with no jump between two frames at 30 a second
## (never stepped), and its lamp is dark while they rest open and lit while they
## move.
func _cycle_checks() -> void:
	var bad: Array[String] = []
	var n := 0
	for id: String in LocalSubject.index():
		var p: Dictionary = LocalSubject.piece_info(StringName(id))
		if String(p.get("kind", "")) != "structure":
			continue
		var files: Array = [String(p.file)]
		if p.has("caps"):
			files.append(String(p.caps))
		for g: Dictionary in p.get("glows", []):
			files.append(String(g.file))
		for d: Dictionary in p.get("parts", []):
			files.append(String(d.file))
			var pv: Array = d.get("pivot", [])
			if pv.size() != 2 or float(pv[0]) < 0.0 or float(pv[1]) < 0.0 or float(pv[0]) > float(p.w) or float(pv[1]) > float(p.h):
				bad.append("%s: a part's pivot %s outside it" % [id, pv])
		for f: String in files:
			if not ResourceLoader.exists(f):
				bad.append("%s: no picture %s" % [id, f])
		# A CUTTING HEAD AT WORK keeps its rim on the plating: under where it
		# touches, all along its part's slide, the structure has metal
		var sp: Dictionary = p.get("sparks", {})
		if sp.has("part") and ResourceLoader.exists(String(p.file)):
			var img := LocalSubject._image_of(String(p.file))
			if img.is_compressed():
				img.decompress()
			var parts: Array = p.get("parts", [])
			var dx: Array = (parts[int(sp.part)] as Dictionary).get("dx", [0, 0]) if int(sp.part) < parts.size() else [0, 0]
			var at: Array = sp.at
			for x in range(int(at[0]) + int(dx[0]), int(at[0]) + int(dx[1]) + 1):
				var on := false
				for y in range(int(at[1]) - 1, int(at[1]) + 3):
					if img.get_pixel(x, y).a > 0.5:
						on = true
				if not on:
					bad.append("%s: its cutting head off the plating at x %d" % [id, x])
					break
		var cyc: Dictionary = p.get("cycle", {})
		if cyc.is_empty():
			continue
		n += 1
		var t := 0.0
		var prev := LocalSubject.cycle_close(cyc, 0.0)
		var top := 0.0
		var jump := 0.0
		var between := {}
		var lamp_open := 0.0
		var lamp_moving := 0.0
		while t < float(cyc.get("period", 12.0)):
			var f := LocalSubject.cycle_close(cyc, t)
			jump = maxf(jump, absf(f - prev))
			top = maxf(top, f)
			if f > 0.01 and f < 0.99:
				between[snappedf(f, 0.001)] = true
				lamp_moving = maxf(lamp_moving, LocalSubject.cycle_lamp(cyc, t))
			if t < float(cyc.get("open", 5.0)) - 1.0:
				lamp_open = maxf(lamp_open, LocalSubject.cycle_lamp(cyc, t))
			prev = f
			t += 1.0 / 30.0
		var end := LocalSubject.cycle_close(cyc, float(cyc.get("period", 12.0)) - 0.01)
		if top < 0.999 or end > 0.001 or LocalSubject.cycle_close(cyc, 0.0) > 0.001:
			bad.append("%s: its arms do not go open, shut and open again (shut %.2f, at the end %.2f)" % [id, top, end])
		if jump > 0.06 or between.size() < 40:
			bad.append("%s: its arms jump %.3f in a frame, %d turns between open and shut" % [id, jump, between.size()])
		if lamp_open > 0.0 or lamp_moving <= 0.0:
			bad.append("%s: its lamp %.2f at rest, %.2f moving" % [id, lamp_open, lamp_moving])
	_ok("a structure's moving parts glide: every picture there, pivots inside, a cutting head on the plating all along its slide, the cradle's arms (%d) open, shut and open with no jump, its lamp with them (%s)" % [n,
		", ".join(bad) if not bad.is_empty() else "all"], bad.is_empty() and n > 0)


## A BIG STRUCTURE ON THE REAL LOCAL (`oid`'s): drawn pinned to the right edge,
## behind the hulls and taking no clicks; still there with the band folded; a
## fight's wreck does not move it and dims it, sits in front of it, and a click
## on the wreck opens the wreck's hold through it; the cutaway zooms it with the
## scene under the blur, and it comes back to its own size and place.
func _live_structure(oid: StringName) -> void:
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
		LocalEventDrawer.quiet = false
		return
	var sub := LocalSubject.of(sc._view)
	if not _ok("%s draws its structure on LOCAL" % oid, sub != null and not sub._st.is_empty()):
		LocalEventDrawer.quiet = false
		return
	var vs: Vector2 = sc._view.size
	var sr := sub.st_rect
	var art := sc._view.ship_view()
	var ship := Rect2(art.ship_rect().position + art.global_position - sc._view.global_position, art.ship_rect().size)
	print("  ..   %s's structure at %s in a %dx%d view; your ship %s" % [oid, sr, vs.x, vs.y, ship])
	_ok("  pinned: past the right edge (%d >= %d), off the top (%d) and the bottom (%d >= %d)" % [sr.end.x, vs.x, sr.position.y, sr.end.y, vs.y],
		sr.end.x >= vs.x and sr.position.y < 0.0 and sr.end.y >= vs.y)
	_ok("  clear of your ship (%d px of sky between)" % (sr.position.x - ship.end.x), sr.position.x >= ship.end.x + 8.0)
	_ok("  behind the hulls, and it takes no clicks", sub.get_index() < sc._view._row.get_index() and sub.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	if sc._events != null:
		sc._events.not_now()
	for i in 30:
		await _tree.process_frame
	sub = LocalSubject.of(sc._view)
	if not _ok("  parked at it with the band folded, still drawn and pinned", sub != null and not sub._st.is_empty()
			and sub.st_rect.end.x >= vs.x and sub.st_rect.end.y >= vs.y):
		LocalEventDrawer.quiet = false
		return
	sr = sub.st_rect
	# A FIGHT'S WRECK THERE
	var foes: Array = DB.enemies.keys()
	foes.sort()
	Run.new_wreck(n, DB.enemies[foes[3 % foes.size()]])
	sc._refresh()
	for i in 30:
		await _tree.process_frame
	sub = LocalSubject.of(sc._view)
	var made: Array = sc._view._made
	if not _ok("  a wreck there: the structure does not move for it (%s), dimmed behind it" % (sub.st_rect if sub != null else Rect2()),
			sub != null and sub.st_rect == sr and sub._dimmed and not made.is_empty()):
		LocalEventDrawer.quiet = false
		return
	var slot := made[0] as EnemySlot
	var over := slot.holder_rect().intersects(Rect2(sub.get_global_transform() * sr.position, sr.size))
	_ok("  and the wreck in front of it (%s)" % ("over it" if over else "beside it"), sc._view._row.get_index() > sub.get_index())
	var wp := _wreck_point(slot)
	if _ok("  a point on the wreck's own metal to click (%s)" % wp, wp.x < INF):
		await _click(wp, sc)
		_ok("  a click on the wreck opens its hold, structure or not (TransferView)", sc._transfer != null)
		if sc._transfer != null:
			sc._close_transfer()
		for i in 4:
			await _tree.process_frame
	# THE CUTAWAY: zoomed with the scene, under the blur, then back
	Router.animate_in_harness = true
	var cut := sc.open_cutaway()
	var t0 := Time.get_ticks_msec()
	while cut != null and is_instance_valid(cut) and cut.t < 1.0 and Time.get_ticks_msec() - t0 < 3000:
		await _tree.process_frame
	if _ok("  the cutaway opens over it", cut != null and is_instance_valid(cut)):
		var zs := sub.get_global_transform().get_scale().x
		_ok("  in the cutaway it zooms with the scene (%.1fx), under the blur (%.2f), pinned in it as before" % [zs, float(cut._scrim_mat.get_shader_parameter(&"amount"))],
			cut.scenes.has(sub) and zs > 1.5 and float(cut._scrim_mat.get_shader_parameter(&"amount")) > 0.99 and sub.st_rect == sr)
		cut.close()
		t0 = Time.get_ticks_msec()
		while is_instance_valid(cut) and Time.get_ticks_msec() - t0 < 3000:
			await _tree.process_frame
		for i in 4:
			await _tree.process_frame
		_ok("  shut, it is back at its own size and place (%.2fx, %s)" % [sub.get_global_transform().get_scale().x, sub.st_rect],
			is_equal_approx(sub.get_global_transform().get_scale().x, 1.0) and sub.st_rect == sr)
	Router.animate_in_harness = false
	LocalEventDrawer.quiet = false


## A point on a wreck's own metal, on screen (the slot reads it as its hull).
func _wreck_point(slot: EnemySlot) -> Vector2:
	var view := slot.get_viewport().get_visible_rect()
	var r := slot.art.get_global_rect() if slot.art != null else slot.get_global_rect()
	for yy in range(int(r.position.y), int(r.end.y), 2):
		for xx in range(int(r.end.x) - 1, int(r.position.x), -2):
			var p := Vector2(xx, yy)
			if view.has_point(p) and slot._on_hull(slot.get_global_transform().affine_inverse() * p):
				return p
	return Vector2.INF


## A left click at a point on screen, pressed and let go, pushed into the
## viewport `on` is drawn in (`CutawayTest._click`'s way).
func _click(gp: Vector2, on: Node) -> void:
	var vp: Viewport = on.get_viewport()
	if vp == _tree.root and _tree.root.size.x < 1000:
		_tree.root.size = Vector2i(1920, 1080)
		for i in 2:
			await _tree.process_frame
	for down in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = gp
		mb.global_position = gp
		vp.push_input(mb)
		await _tree.process_frame
	for i in 2:
		await _tree.process_frame


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


## THE WORLDS TURN BLENDED (`PixelTurn.world_mode`, Jon: "THESE LOOK GREAT!!!"):
## every world the painter draws carries its surface's memory with no flag --
## LOCAL's orbited world and its moons, the map's worlds, and a world in pieces
## (`ShatteredView`) on the map and in orbit on LOCAL, where it must turn -- wired
## to read itself last frame. And it must still TURN: a memory that held everything
## would show a dead world with no shimmer at all. So one world is filmed
## turning a third of a pixel a frame, with the memory and (as the game was
## before) without: its pixels change on most frames and over the run, and
## pixels going A, B, A stay under a few a second. The filming needs a
## renderer: headless (the merge gate) checks the wiring and says the pixels
## went unchecked; `godot --path . -- subjecttest` in a window checks both.
func _world_memory() -> void:
	_ok("worlds turn blended by default (%s)" % PixelTurn.Mode.keys()[PixelTurn.world_mode], PixelTurn.world_mode == PixelTurn.Mode.BLENDED)
	# ON THE REAL SCREENS: LOCAL in orbit of a world, and the map
	Rng.reseed(4242, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# (the system with the most worlds, orbiting one with moons if there is one)
	var idx := -1
	var at := -1
	var most := 0
	for m: MapGen.MapNode in Run.map:
		if m.type != MapGen.NodeType.SYSTEM:
			continue
		var L := SystemLayout.of(m)
		var ws: Array[int] = []
		for bi in L.bodies.size():
			if L.bodies[bi].world != &"" and L.bodies[bi].world != &"shattered":
				ws.append(bi)
		if ws.size() > most:
			most = ws.size()
			idx = m.index
			at = ws[0]
			for bi in ws:
				if int(Worlds.spec(L.bodies[bi].world, L.bodies[bi].seed, 20.0).get("moons", 0)) > 0:
					at = bi
					break
	if not _ok("a system with worlds to orbit (%d, %d worlds)" % [idx, most], idx >= 0):
		return
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	SystemMapScreen._parked.erase(idx)
	var map := await _map_up()
	if not _ok("the map is up", map != null):
		return
	var on_map: Array[String] = []
	var n_map := 0
	for v: Variant in map.view._views.values():
		if v is PlanetView or v is ShatteredView:
			n_map += 1
			var w := _mem_wrong(v as Node2D)
			if w != "":
				on_map.append(w)
	_ok("the map's %d worlds carry the memory (%s)" % [n_map, ", ".join(on_map) if not on_map.is_empty() else "all"], n_map > 0 and on_map.is_empty())
	map.flight.place_at(at, map.view.t)
	Router.show_local()
	await _frames(10)
	var sky := _local_sky()
	var on_local: Array[String] = []
	var n_local := 0
	if sky != null:
		for e: Array in sky._near:
			if e[0] is PlanetView or e[0] is ShatteredView:
				n_local += 1
				var w := _mem_wrong(e[0] as Node2D)
				if w != "":
					on_local.append(w)
	# (LOCAL builds no sky at all headless, `LocalSky.headless`)
	if LocalSky.headless():
		print("  ..   world memory: LOCAL's sky not checked (headless builds none)")
	else:
		_ok("LOCAL's world and its moons, %d, carry the memory (%s; in orbit of %s)" % [n_local, ", ".join(on_local) if not on_local.is_empty() else "all", _orbit_name(sky)], n_local > 0 and on_local.is_empty())
	Router.show_local()
	await _frames(3)
	SystemMapScreen._parked.erase(idx)
	# A WORLD IN PIECES CARRIES IT TOO (`ShatteredView`, its own two passes): built
	# as the map, the panel and LOCAL build one, in 2x2 blocks
	var shards := ShatteredView.new()
	shards.set_world(&"shattered", 4242, 24.0)
	shards.set_cell(2)
	var sw := _mem_wrong(shards)
	_ok("a shattered world carries the memory (%s)" % (sw if sw != "" else "built, keeps last frame"), sw == "")
	shards.free()
	# ...ON THE MAP, AND IN ORBIT OF ONE ON LOCAL, where it must turn (it was
	# never stepped there: it stood still, its rubble frozen)
	await _shattered_in_orbit()
	# AND THE HARNESS'S SWITCH TAKES IT OFF (`worldmem=off`, to measure against)
	var keep := PixelTurn.world_mode
	PixelTurn.world_mode = PixelTurn.Mode.SMOOTH
	var plain := PlanetView.new()
	plain.set_world(&"moon", 4242, 30.0)
	var plain_s := ShatteredView.new()
	plain_s.set_world(&"shattered", 4242, 24.0)
	plain_s.set_cell(2)
	PixelTurn.world_mode = keep
	_ok("with the worlds' memory switched off, a world is drawn as before (no memory)", plain._mem_vp == null and plain._mem_mat == null)
	_ok("and a shattered world too", plain_s._mem_vp == null and plain_s._mem_mat == null)
	plain.free()
	plain_s.free()
	# STILL TURNING, AND NOT FLICKERING
	if DisplayServer.get_name() == "headless":
		print("  ..   world memory: pixels not checked (headless has no renderer; run subjecttest in a window)")
		return
	var with_mem := await _film_world(true)
	var without := await _film_world(false)
	print("  ..   a moon turning 1/3 px a frame, %d frames: memory: %s; without: %s" % [WM_FRAMES, str(with_mem), str(without)])
	_ok("with the memory a turning world still moves: something changes on %d of %d frames, %.0f%% of its pixels over the run (%.0f%% without)" % [
		int(with_mem.moving), WM_FRAMES - 1, 100.0 * float(with_mem.moved), 100.0 * float(without.moved)],
		int(with_mem.moving) >= (WM_FRAMES - 1) * 3 / 4 and float(with_mem.moved) >= 0.15 and float(with_mem.moved) >= 0.35 * float(without.moved))
	_ok("and it does not flicker: %.1f pixels a second go A, B, A (under %.0f; %.1f without the memory)" % [
		float(with_mem.flips_ps), WM_FLIPS, float(without.flips_ps)], float(with_mem.flips_ps) < WM_FLIPS)
	var s_mem := await _film_world(true, true)
	var s_without := await _film_world(false, true)
	print("  ..   a shattered world turning 1/3 px a frame, %d frames: memory: %s; without: %s" % [WM_FRAMES, str(s_mem), str(s_without)])
	_ok("with the memory a shattered world still moves: something changes on %d of %d frames, %.0f%% of its pixels over the run (%.0f%% without)" % [
		int(s_mem.moving), WM_FRAMES - 1, 100.0 * float(s_mem.moved), 100.0 * float(s_without.moved)],
		int(s_mem.moving) >= (WM_FRAMES - 1) * 3 / 4 and float(s_mem.moved) >= 0.15 and float(s_mem.moved) >= 0.35 * float(s_without.moved))
	_ok("and flickers less: %.1f pixels a second go A, B, A (under %.0f, and no more than %.1f without the memory)" % [
		float(s_mem.flips_ps), WM_FLIPS, float(s_without.flips_ps)], float(s_mem.flips_ps) < WM_FLIPS and float(s_mem.flips_ps) <= float(s_without.flips_ps))


## THE SHATTERED WORLD ON THE MAP AND ON LOCAL: the first system of the run with
## one, the ship parked in orbit of it. On the map it carries the memory; on
## LOCAL (with a renderer: headless builds no sky) it carries it and turns.
func _shattered_in_orbit() -> void:
	var sidx := -1
	var sat := -1
	for m: MapGen.MapNode in Run.map:
		if m.type != MapGen.NodeType.SYSTEM:
			continue
		var L := SystemLayout.of(m)
		for bi in L.bodies.size():
			if L.bodies[bi].world == &"shattered":
				sidx = m.index
				sat = bi
				break
		if sidx >= 0:
			break
	if not _ok("a system with a shattered world (%d, world %d)" % [sidx, sat], sidx >= 0):
		return
	Run.at = sidx
	Run.map[sidx].visited = true
	SectorScreen._approached_at = sidx
	SystemMapScreen._parked.erase(sidx)
	var map := await _map_up()
	if not _ok("the map is up over it", map != null):
		return
	var on_map: Variant = map.view._views.get(sat)
	var mw := _mem_wrong(on_map as Node2D) if on_map is ShatteredView else "not drawn as a shattered world"
	_ok("the map's shattered world carries the memory (%s)" % (mw if mw != "" else "yes"), mw == "")
	map.flight.place_at(sat, map.view.t)
	Router.show_local()
	await _frames(10)
	if LocalSky.headless():
		print("  ..   world memory: LOCAL's shattered world not checked (headless builds none)")
	else:
		var sky := _local_sky()
		var sv: ShatteredView = null
		if sky != null:
			for e: Array in sky._near:
				if e[0] is ShatteredView:
					sv = e[0]
		var lw := _mem_wrong(sv) if sv != null else "none drawn"
		_ok("LOCAL in orbit of a shattered world draws it with the memory (%s; in orbit of %s)" % [lw if lw != "" else "yes", _orbit_name(sky)], lw == "")
		if sv != null:
			var t0 := sv._t
			await _frames(10)
			_ok("and it turns there (its clock %.2f, then %.2f)" % [t0, sv._t], sv._t != t0)
	Router.show_local()
	await _frames(3)
	SystemMapScreen._parked.erase(sidx)


## How many frames `_world_memory` films, and the A, B, A pixels a second it allows.
const WM_FRAMES := 90
const WM_FLIPS := 3.0


## Why this world is not drawn with its memory, or "". (Its shaders' settings
## read back only with a renderer: headless keeps none.) A `PlanetView` or a
## `ShatteredView`: both keep the memory in the same fields.
func _mem_wrong(pv: Node2D) -> String:
	var nm := String((pv.get("spec") as Dictionary).get("world", "?"))
	var vp: SubViewport = pv.get("_mem_vp")
	var copy: SubViewport = pv.get("_mem_copy")
	var mm: ShaderMaterial = pv.get("_mem_mat")
	var mat: ShaderMaterial = pv.get("_mat")
	if vp == null or mm == null or copy == null:
		return "%s: none built" % nm
	var last := copy.get_child(0) as TextureRect
	if vp.get_parent() != pv or copy.get_parent() != vp or last == null or last.texture != vp.get_texture():
		return "%s: it does not keep last frame" % nm
	if DisplayServer.get_name() == "headless":
		return ""
	if int(mat.get_shader_parameter("mem_mode")) != 2 or mat.get_shader_parameter("mem_now") != vp.get_texture():
		return "%s: not drawn from it" % nm
	if int(mm.get_shader_parameter("mem_mode")) != 1 or mm.get_shader_parameter("mem_prev") != copy.get_texture():
		return "%s: it does not read itself last frame" % nm
	return ""


## A cratered moon (or, `shards`, a world in pieces) filmed turning a third of a
## pixel a frame at its equator, in 2x2 blocks as LOCAL draws it, with its memory
## or without: how often it moves, how much of it moved, and its A, B, A pixels a
## second (at 30 frames a second).
func _film_world(mem: bool, shards: bool = false) -> Dictionary:
	var keep := PixelTurn.world_mode
	PixelTurn.world_mode = PixelTurn.Mode.BLENDED if mem else PixelTurn.Mode.SMOOTH
	# (a world in pieces as big as LOCAL draws the one you orbit: at the map's size
	# its few blocks hardly go A, B, A with the memory or without)
	var S := 192 if shards else 96
	var R := 56.0 if shards else 30.0
	var vp := SubViewport.new()
	vp.size = Vector2i(S, S)
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_tree.root.add_child(vp)
	var pv: Node2D = ShatteredView.new() if shards else PlanetView.new()
	pv.call("set_world", &"shattered" if shards else &"moon", 4242, R)
	pv.call("set_cell", 2)
	pv.position = Vector2(S, S) * 0.5
	vp.add_child(pv)
	PixelTurn.world_mode = keep
	var spin := absf(float((pv.get("spec") as Dictionary).spin))
	# (the pieces turn at 0.6 of the spin, round a ball `ShatteredView.SCALE` of the radius)
	var dt := (1.0 / 3.0) / (30.0 * maxf(spin, 0.01)) if not shards \
		else (1.0 / 3.0) / (30.0 * maxf(spin * 0.6 * R * ShatteredView.SCALE, 0.01))
	var frames: Array[PackedByteArray] = []
	for k in WM_FRAMES + 3:
		pv.call("step", 20.0 + dt * float(k), Vector3(-0.83, -0.31, 0.47))
		await RenderingServer.frame_post_draw
		if k >= 3:
			frames.append(vp.get_texture().get_image().get_data())
	vp.queue_free()
	var bpp := frames[0].size() / (S * S)
	var moving := 0
	var flips := 0
	var ever := {}
	var lit := {}
	for i in range(1, frames.size()):
		var a := frames[i - 1]
		var b := frames[i]
		var c: PackedByteArray = frames[i + 1] if i + 1 < frames.size() else PackedByteArray()
		var any := false
		for p in S * S:
			var o := p * bpp
			var diff := a[o] != b[o] or a[o + 1] != b[o + 1] or a[o + 2] != b[o + 2]
			# (the world: anything not the box's empty colour, its corner's)
			if b[o] != b[0] or b[o + 1] != b[1] or b[o + 2] != b[2]:
				lit[p] = true
			if diff:
				any = true
				ever[p] = true
				if not c.is_empty() and a[o] == c[o] and a[o + 1] == c[o + 1] and a[o + 2] == c[o + 2]:
					flips += 1
		if any:
			moving += 1
	var secs := float(frames.size() - 2) / 30.0
	var moved := 0
	for p: int in ever:
		if lit.has(p):
			moved += 1
	return {moving = moving, moved = snappedf(float(moved) / float(maxi(lit.size(), 1)), 0.001), flips_ps = snappedf(float(flips) / secs, 0.1)}


## A RELOAD PUTS YOU BACK IN ORBIT WHERE YOU WERE, LOCAL INCLUDED. Where the
## ship was left lived only in memory (`SystemMapScreen._parked`), so SAVE &
## EXIT then CONTINUE dropped it at the system's edge and LOCAL drew the warp-in
## instead of the world (alpha gap). Twice, as a player leaves: SAVE & EXIT
## from LOCAL in orbit of one world, and SAVE & EXIT from the map itself in
## orbit of another (the map writes its record only as it is put away, so this
## one is the save reaching in for it). Each time the run goes to the title,
## the memory of where the ship was is wiped as a fresh launch would have it,
## and CONTINUE must land on the map in orbit of that world, with LOCAL drawing it.
func _orbit_reload() -> void:
	Rng.reseed(4242, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := -1
	var worlds: Array[int] = []
	for m: MapGen.MapNode in Run.map:
		if m.type != MapGen.NodeType.SYSTEM or (Run.hellbender_alive() and Run.hellbender_at == m.index):
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
	if not _ok("a system with two worlds to park at (%d)" % idx, idx >= 0):
		return
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	SystemMapScreen._parked.erase(idx)
	for leg in 2:
		var w := worlds[worlds.size() - 1] if leg == 0 else worlds[0]
		var map := await _map_up()
		if not _ok("the map is up", map != null):
			return
		map.flight.place_at(w, map.view.t)
		var from := "LOCAL"
		if leg == 0:
			Router.show_local()
			await _frames(5)
		else:
			from = "the map"
		# SAVE & EXIT, as the escape menu does it (`Main`): the save, then the
		# run let go and the title up
		SaveGame.save()
		Run.hull = null
		Router.show_launcher()
		await _frames(3)
		# a fresh launch has no record in memory; something stale in its place
		# must not survive the load either
		SystemMapScreen._parked = {idx: {"at": -9, "p": Vector2.ZERO, "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}}
		Router.continue_run()
		var back: SystemMapScreen = null
		for i in 120:
			await _tree.process_frame
			back = Router.current as SystemMapScreen
			if back != null and back.flight != null:
				break
		var got: int = back.flight.reached() if back != null and back.flight != null else -99
		_ok("saved from %s in orbit of world %d, CONTINUE lands on the map in orbit of it (%d)" % [from, w, got], got == w)
		if back != null:
			back.frozen = true
		Router.show_local()
		await _frames(10)
		var sky := _local_sky()
		_ok("  and LOCAL draws that world (%s)" % _orbit_name(sky), sky != null and sky.orbit_target == w)
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
