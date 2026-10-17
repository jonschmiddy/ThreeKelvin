extends Node

## EACH PLACE KEEPS ITS OWN WRECKS (Jon, Oct 14: "each planet or POI you can
## visit should contain its own wrecks/fights").
##   godot --headless --path . -- sheet=WreckSiteTest
##
## A wreck lies where your ship was when its hull died (`Jetsam.site`: the body
## it orbited, -1 the star, -9 open space), and LOCAL draws the wrecks of the
## place you are parked at and no other's:
##   - two fights at a world leave their hulls at that world; the star next door
##     has none of them, and its own fight's hull is its alone;
##   - back at the world, its two are there again;
##   - the real LOCAL draws exactly the place's wrecks, each with the death roll
##     and fight marks of its number among the whole system's wrecks (what the
##     kill was keyed on), and open space with none draws the place picture;
##   - a save keeps each wreck's place; a wreck from a save before wrecks had a
##     place shows wherever you are, as it did then;
##   - and SECTOR LOOT (Jon, Oct 15: "When a wreck is opened, and all or some of
##     the parts are left behind, those should also show up in the sector loot
##     pool for that sector"): nothing of a wreck before it is opened; once it
##     has been, through LOCAL's own door, the button shows what is left in it,
##     from any place in the system; a take through SECTOR LOOT is the wreck's
##     own claim, a part put down goes on the pile, one put back that came out
##     of the wreck goes back into it; a save keeps which wrecks were opened;
##   - ONE PLACE, ONE FIGHT (Jon, Oct 15): the Hellbender and the core's
##     Custodian are engaged at their own place on the map and nowhere else --
##     LOCAL anywhere else sends you to the map -- and a jump arrives at the
##     edge, wherever the ship was left on the last visit;
##   - THE WRECKS STAY OFF YOU (Jon, Oct 17): after a fight won on LOCAL, every
##     door off it and back -- the cutaway with a part moved or a wreck emptied
##     in it first of all -- leaves every wreck where it lay, clear of your hull
##     (`_round_trips`);
##   - AND IN THEIR SYSTEM (Jon, Oct 17): a real jump to the next system draws
##     none of them there, and a save made where they lie keeps them there
##     (`_other_systems`);
##   - AND OFF THE WORLD YOU ORBIT (fit means nothing overlaps): their words
##     never on its disc, their pictures not either while the pile is a
##     fight's worth (`_off_the_world`).

var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	h.seed_run(2718)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n: MapGen.MapNode = null
	for c: MapGen.MapNode in Run.map:
		if c.type == MapGen.NodeType.SYSTEM and c.region != MapGen.Region.FAUNA:
			n = c
			break
	Run.at = n.index
	var parked := SystemMapScreen._parked

	parked[n.index] = {"at": 0}
	_win(n, &"cutter", [&"lancer"])
	h._ok("two hulls lie at the world fought over (%d)" % Run.wrecks_here(n).size(), Run.wrecks_here(n).size() == 2)
	parked[n.index] = {"at": -1}
	h._ok("the star next door has none of them (%d)" % Run.wrecks_here(n).size(), Run.wrecks_here(n).is_empty())
	_win(n, &"hulk")
	var at_star := Run.wrecks_here(n)
	h._ok("its own fight's hull is its alone (%d)" % at_star.size(), at_star.size() == 1 and at_star[0].site == -1)
	h._ok("and is the system's third wreck", Run.wreck_ordinal(n, at_star[0]) == 2)
	parked[n.index] = {"at": 0}
	h._ok("back at the world, its two are there (%d)" % Run.wrecks_here(n).size(), Run.wrecks_here(n).size() == 2)
	parked.erase(n.index)
	h._ok("open space, where a system starts, has none", Run.wrecks_here(n).is_empty())

	# the real LOCAL at each place
	for site in [0, -1, -9]:
		if site == -9:
			parked.erase(n.index)
		else:
			parked[n.index] = {"at": site}
		Router.show_local()
		for i in 6:
			await get_tree().process_frame
		var sc := Router.current as SectorScreen
		var ev: EncounterView = sc._view if sc != null else null
		var want := Run.wrecks_here(n)
		if ev == null:
			h._fail("LOCAL did not come up at site %d" % site)
			continue
		var drawn: int = ev._made.size() if ev._slots_mode == &"wrecks" and ev._slots.visible else 0
		h._ok("LOCAL at %d draws its %d wrecks (%d)" % [site, want.size(), drawn], drawn == want.size())
		for i in mini(drawn, want.size()):
			var k := Run.wreck_ordinal(n, want[i])
			h._ok("  wreck %d keeps its fight's marks and death (system's #%d)" % [i, k],
				ev._made[i].wreck_id == n.index * 64 + k
				and ev._made[i].death_style == EnemyArt.death_style(DB.enemies[want[i].art], n.index, k))
		if want.is_empty():
			h._ok("  and the place picture instead", ev._area.visible or LocalSubject.of(ev) != null)

	# the save
	var back := SaveGame._node_from(SaveGame._node_to(n))
	var sites: Array = []
	for raw in back.jetsam:
		if (raw as MapGen.Jetsam).is_wreck():
			sites.append((raw as MapGen.Jetsam).site)
	h._ok("a save keeps every wreck's place %s" % [sites], sites == [0, 0, -1])
	var row: Dictionary = SaveGame._node_to(n)
	for j in (row.jetsam as Array):
		(j as Dictionary).erase("site")
	var old := SaveGame._node_from(row)
	Run.map[n.index] = old
	parked[n.index] = {"at": 3}
	h._ok("a wreck from before places shows wherever you are (%d)" % Run.wrecks_here(old).size(),
		Run.wrecks_here(old).size() == 3)
	Run.map[n.index] = n
	await _sector_loot()
	await _one_place()
	await _round_trips()
	await _other_systems()
	await _off_the_world()
	h.verdict("wrecksitetest")
	get_tree().quit(h.code())


func _win(n: MapGen.MapNode, lead: StringName, extras: Array[StringName] = []) -> void:
	var more: Array = []
	for id in extras:
		more.append(DB.enemies[id])
	var cb := Combat.new()
	cb.start(DB.enemies[lead], n.danger, more)
	for e in cb.enemies:
		cb.damage_enemy(9999, 1, "test", e)


func _parts(k: int) -> Array:
	var out: Array = []
	for id in DB.modules:
		var m := DB.modules[id] as ModuleData
		if m.starter_only:
			continue
		out.append(m.duplicate(true))
		if out.size() >= k:
			break
	return out


## The button on LOCAL's bottom bar, and the number on it (0 when it is not there).
func _button() -> int:
	var sc := Router.current as SectorScreen
	if sc == null:
		return -1
	var b := sc.find_child("SectorLoot", true, false) as Button
	if b == null or not b.is_visible_in_tree():
		return 0
	return int(b.text.get_slice("·", 1).strip_edges())


func _sector_loot() -> void:
	Rng.forced = 99
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n: MapGen.MapNode = null
	for c: MapGen.MapNode in Run.map:
		if c.type == MapGen.NodeType.SYSTEM and c.region != MapGen.Region.FAUNA:
			n = c
			break
	Run.at = n.index
	SystemMapScreen._parked[n.index] = {"at": 0}
	_win(n, &"cutter")
	var w: MapGen.Jetsam = Run.wrecks_here(n)[0]
	w.items.assign(_parts(3))
	Router.show_local()
	for i in 6:
		await get_tree().process_frame
	h._ok("an unopened wreck is not under SECTOR LOOT", Run.sector_loot(n) == null and _button() == 0)
	# opened through LOCAL's own door, one part taken there, then shut
	var sc := Router.current as SectorScreen
	sc._open_jetsam(w)
	await get_tree().process_frame
	h._ok("opening it marks it opened", w.opened)
	await Run.take_from_jetsam(n, w, 0)
	sc._close_transfer()
	for i in 4:
		await get_tree().process_frame
	h._ok("SECTOR LOOT shows the two left in it (%d)" % _button(), _button() == 2)
	# from another place in the system too
	SystemMapScreen._parked[n.index] = {"at": -1}
	Router.show_local()
	for i in 6:
		await get_tree().process_frame
	h._ok("and from the star, where the wreck is not (%d)" % _button(), _button() == 2)
	# a take through SECTOR LOOT is the wreck's own claim
	var v := Run.sector_loot(n)
	var i1 := -1
	for i in v.items.size():
		if not n.taken.has(v.option(i)):
			i1 = i
			break
	var m1: HoldItem = v.items[i1]
	await Run.take_from_jetsam(n, v, i1)
	h._ok("taken through SECTOR LOOT, it is gone from the wreck (%d left)" % Run.jetsam_left(n, w),
		Run.jetsam_left(n, w) == 1 and Run.cargo.has(m1))
	# one put back goes back into the wreck; one put down goes on the pile
	Run.put_in(n, v, m1)
	h._ok("put back, it is in the wreck again (%d)" % Run.jetsam_left(n, w), Run.jetsam_left(n, w) == 2)
	var mine: HoldItem = _parts(4)[3]
	Run.place_in_hold(mine)
	Run.put_in(n, v, mine)
	var pile := Run.sector_jetsam(n, false)
	h._ok("a part put down goes on the system's pile", pile != null and pile.items.has(mine)
		and not w.items.has(mine))
	h._ok("and SECTOR LOOT shows all three (%d)" % Run.jetsam_left(n, Run.sector_loot(n)),
		Run.jetsam_left(n, Run.sector_loot(n)) == 3)
	var back := SaveGame._node_from(SaveGame._node_to(n))
	var opened := false
	for raw in back.jetsam:
		if (raw as MapGen.Jetsam).is_wreck():
			opened = (raw as MapGen.Jetsam).opened
	h._ok("a save keeps the wreck opened", opened)


func _one_place() -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var parked := SystemMapScreen._parked
	# the Hellbender
	if not Run.hellbender_alive():
		h._fail("no Hellbender in this run")
		return
	var n: MapGen.MapNode = Run.map[Run.hellbender_at]
	Run.at = n.index
	var hp := SystemLayout.of(n).hellbender_place()
	parked.erase(n.index)
	var away: Array = EncounterDrawer.quiet_lines(n)
	h._ok("at the edge, LOCAL sends you to the Hellbender's place (%s)" % away[1], String(away[1]) == EncounterDrawer.TO_SECTOR)
	Router.show_local()
	for i in 4:
		await get_tree().process_frame
	(Router.current as SectorScreen)._on_action()
	for i in 4:
		await get_tree().process_frame
	h._ok("and pressing it starts no fight", not Router.in_combat())
	parked[n.index] = {"at": hp}
	var there: Array = EncounterDrawer.quiet_lines(n)
	h._ok("at its place, ENGAGE THE HELLBENDER (%s)" % there[1], String(there[1]) == "ENGAGE THE HELLBENDER" and Router.at_hellbender(n))
	# the core
	var core: MapGen.MapNode = null
	for raw in Run.map:
		if (raw as MapGen.MapNode).type == MapGen.NodeType.CORE:
			core = raw
	Run.at = core.index
	parked.erase(core.index)
	h._ok("at the core's edge, LOCAL sends you to the Custodian", String(EncounterDrawer.quiet_lines(core)[1]) == EncounterDrawer.TO_SECTOR)
	parked[core.index] = {"at": SystemLayout.of(core).core_place()}
	h._ok("at the Custodian, ENGAGE", String(EncounterDrawer.quiet_lines(core)[1]) == "ENGAGE" and Router.at_custodian(core))
	# a jump arrives at the edge
	var m: MapGen.MapNode = null
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		if c.type == MapGen.NodeType.SYSTEM and c.index != n.index:
			m = c
			break
	OptionTable.ensure(m)
	m.ambush_rolled = true
	m.ambush_pending = false
	parked[m.index] = {"at": 0}
	Run.at = m.index
	Router._on_jumped(m.index)
	for i in 4:
		await get_tree().process_frame
	h._ok("a jump arrives at the edge, not where the ship was left (%d)" % Run.site_here(m), Run.site_here(m) == -9)


## THE WRECKS STAY CLEAR OF YOU, WHEREVER YOU HAVE BEEN (Jon, Oct 17: "fix
## destroyed ships from going on top of you when you edit your ship after a
## fight"). A two-ship fight won on the real LOCAL, then every door off LOCAL
## and back, and each time every wreck's drawn boxes -- its picture's ink, its
## name and its SALVAGE / STRIPPED tag -- against your hull and its plate. The
## cutaway is the one that broke: a part moved or a wreck emptied with the scene
## zoomed 2x laid the wrecks out in the zoomed picture's room, and shut, they
## stood across your bow.
func _round_trips() -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n: MapGen.MapNode = null
	for c: MapGen.MapNode in Run.map:
		if c.type == MapGen.NodeType.SYSTEM and not c.cleared and not Router.no_fights_at(c):
			n = c
			break
	Run.at = n.index
	n.visited = true
	SectorScreen._approached_at = n.index
	SystemMapScreen._parked[n.index] = {"at": 0}
	Router.show_local()
	await _frames(8)
	Router.start_combat(DB.enemies[&"cutter"], [DB.enemies[&"lancer"]], false, false)
	await _frames(8)
	var cb: Combat = Router.combat
	if cb == null:
		h._fail("no fight opened on LOCAL")
		return
	for e in cb.enemies:
		cb.damage_enemy(9999, 1, "test", e)
	await _frames(20)
	if not h._ok("the fight is won and LOCAL is up", not Router.in_combat() and Router.current is SectorScreen):
		return
	await _clear_of_you("after the win", 2)

	# THE CUTAWAY, animated as in play: opened and shut; a part off the hull
	# into the hold while it is open; a wreck emptied while it is open
	for what in ["open and shut", "a part lifted into the hold", "a wreck emptied"]:
		var sc := Router.current as SectorScreen
		Router.animate_in_harness = true
		var cut := sc.open_cutaway()
		if not h._ok("the cutaway opens on LOCAL (%s)" % what, cut != null):
			Router.animate_in_harness = false
			continue
		await _open_full(cut)
		var held: Array = []
		for sl in sc._view._made:
			held.append((sl as EnemySlot).position)
		if what == "a part lifted into the hold":
			var lifted := -1
			for m in Run.installed:
				if (m as ModuleData).slot == ModuleData.Slot.WEAPON:
					lifted = Run.lift_part(m)
					break
			h._ok("  a weapon came off the hull into the hold", lifted >= 0)
		elif what == "a wreck emptied":
			await _empty(n, Run.wrecks_here(n)[0])
		await _frames(12)
		var still := true
		for i in held.size():
			still = still and (sc._view._made[i] as EnemySlot).position.distance_to(held[i]) <= 1.0
		h._ok("  the wrecks hold their places in the zoomed scene", still)
		cut.close()
		await _gone(cut)
		Router.animate_in_harness = false
		await _clear_of_you("the cutaway: " + what, 2)

	# A WRECK OPENED THROUGH ITS OWN DOOR and picked clean (STRIPPED)
	var sc2 := Router.current as SectorScreen
	var w2: MapGen.Jetsam = Run.wrecks_here(n)[1]
	sc2._open_jetsam(w2)
	await _frames(2)
	await _empty(n, w2)
	sc2._close_transfer()
	await _clear_of_you("a wreck opened and picked clean", 2)

	# EVERY OTHER DOOR OFF LOCAL, and back
	for door: String in ["the ship screen", "CARDS", "MODULES", "the map", "the star chart", "SAVE & EXIT, CONTINUE"]:
		match door:
			"the ship screen":
				Router.show_ship()
				await _frames(4)
				# a part moved on the refit screen too
				for m in Run.installed:
					if (m as ModuleData).slot == ModuleData.Slot.WEAPON:
						Run.lift_part(m)
						break
			"CARDS":
				Router.show_cards()
			"MODULES":
				Router.show_modules()
			"the map":
				Router.show_system()
			"the star chart":
				Router.show_starchart()
			"SAVE & EXIT, CONTINUE":
				SaveGame.save()
				Run.start_new_run(&"korvan", int(HullData.Weight.LIGHT))
				SaveGame.load_into_run()
		await _frames(6)
		Router.show_local()
		await _frames(6)
		await _clear_of_you("back from " + door, 2)


## Everything left in a wreck, taken.
func _empty(n: MapGen.MapNode, w: MapGen.Jetsam) -> void:
	while Run.jetsam_left(n, w) > 0:
		var i := -1
		for k in w.items.size():
			if not n.taken.has(w.option(k)):
				i = k
				break
		if i < 0:
			return
		await Run.take_from_jetsam(n, w, i)


## Where each wreck lay after the win (its slot's box), to hold the rest to.
var _rest: Array = []


## Every wreck's drawn boxes on the real LOCAL against your ship's; `want` of them.
func _clear_of_you(tag: String, want: int) -> void:
	await _frames(6)
	var sc := Router.current as SectorScreen
	if sc == null:
		h._fail("%s: LOCAL is not up (%s)" % [tag, Router.current])
		return
	var ev: EncounterView = sc._view
	var drawn: int = ev._made.size() if ev._slots_mode == &"wrecks" and ev._slots.visible else 0
	h._ok("%s: LOCAL draws the %d wrecks (%d)" % [tag, want, drawn], drawn == want)
	# your hull's own pixels, and every line on its plate
	var sv := ev.ship_view()
	var you: Array[Rect2] = [sv.get_global_transform() * sv.ship_rect()]
	you.append_array(ev.player_boxes())
	var bad: Array[String] = []
	for i in drawn:
		for b in _wreck_boxes(ev._made[i]):
			for y in you:
				if (b[1] as Rect2).intersects(y):
					bad.append("wreck %d's %s %s on your %s" % [i, b[0], b[1], y])
					break
	h._ok("%s: every wreck's picture, name and tag clear of your ship%s" % [tag,
		"" if bad.is_empty() else ": " + "; ".join(bad)], bad.is_empty())
	# and each where it lay after the win, at the size it was drawn at
	var now: Array = []
	for i in drawn:
		now.append((ev._made[i] as EnemySlot).get_global_rect())
	if _rest.is_empty():
		_rest = now
		return
	var moved: Array[String] = []
	for i in mini(now.size(), _rest.size()):
		var a: Rect2 = _rest[i]
		var b: Rect2 = now[i]
		if a.position.distance_to(b.position) > 1.0 or a.size.distance_to(b.size) > 1.0:
			moved.append("wreck %d %s -> %s" % [i, a, b])
	h._ok("%s: every wreck where it lay after the win%s" % [tag,
		"" if moved.is_empty() else ": " + "; ".join(moved)], moved.is_empty())


## A wreck's picture (its ink where it rests), its name and its tag, global.
func _wreck_boxes(sl: EnemySlot) -> Array:
	var out: Array = []
	var art: EnemyArt = sl.art
	var holder: Control = sl.get("_art_holder")
	var base: Vector2 = sl.get("_art_base") if sl.get("_art_base") != null else Vector2.ZERO
	var u := Rect2(art.ink_rect())
	var at := holder.get_global_rect().position + base
	out.append(["picture", Rect2(at + u.position, u.size)])
	for key in ["_name", "_hp"]:
		var l: Label = sl.get(key)
		if l != null and l.is_visible_in_tree() and l.text.strip_edges() != "":
			out.append([l.text, EnemySlot.text_rect(l)])
	return out


## DESTROYED SHIPS STAY IN THEIR SYSTEM (Jon, Oct 17: "destroyed ships still
## show up in other systems"). Hulls killed at a world and at the star of system
## A; then every other place in A draws none of them, a save made in A and
## loaded keeps them in A at their own places, and a real jump to system B
## arrives where none of them is drawn, at B's edge or at any of B's places.
func _other_systems() -> void:
	h.seed_run(1618)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var a: MapGen.MapNode = null
	for c: MapGen.MapNode in Run.map:
		if c.type == MapGen.NodeType.SYSTEM and c.region != MapGen.Region.FAUNA \
				and not Router.no_fights_at(c) and SystemLayout.of(c).bodies.size() >= 2:
			a = c
			break
	Run.at = a.index
	a.visited = true
	SectorScreen._approached_at = a.index
	var parked := SystemMapScreen._parked
	parked[a.index] = {"at": 0}
	_win(a, &"cutter", [&"lancer"])
	parked[a.index] = {"at": -1}
	_win(a, &"hulk")
	var sites := {0: 2, -1: 1}
	await _each_place(a, sites, "system A")
	SaveGame.save()
	Run.start_new_run(&"korvan", int(HullData.Weight.LIGHT))
	h._ok("a save made in A loads", SaveGame.load_into_run())
	a = Run.map[Run.at]
	await _each_place(a, sites, "system A, saved and loaded")
	# a real jump to a neighbour
	var b: MapGen.MapNode = null
	for c: MapGen.MapNode in Run.map:
		if c.index != a.index and c.type == MapGen.NodeType.SYSTEM and Run.can_jump_to(c):
			b = c
			break
	if not h._ok("a system B in range of A", b != null):
		return
	OptionTable.ensure(b)
	b.ambush_rolled = true
	b.ambush_pending = false
	Router.commit_jump(b.index)
	await _frames(10)
	h._ok("the jump lands in B", Run.at == b.index)
	var held := 0
	for raw in b.jetsam:
		if (raw as MapGen.Jetsam).is_wreck():
			held += 1
	h._ok("B holds no wreck (%d)" % held, held == 0)
	await _each_place(b, {}, "system B")


## The real LOCAL at every place of `n` (the edge, the star, each body): it
## draws exactly `sites[place]` wrecks there, none where it is not named.
func _each_place(n: MapGen.MapNode, sites: Dictionary, tag: String) -> void:
	var places: Array = [-9, -1]
	for i in SystemLayout.of(n).bodies.size():
		places.append(i)
	# (LOCAL up before any place is set by hand: a won fight's door may have
	# left the map up, and a map keeps where ITS ship is as it goes)
	Router.show_local()
	await _frames(4)
	for site in places:
		if site == -9:
			SystemMapScreen._parked.erase(n.index)
		else:
			SystemMapScreen._parked[n.index] = {"at": site}
		Router.show_local()
		await _frames(6)
		var sc := Router.current as SectorScreen
		var ev: EncounterView = sc._view if sc != null else null
		var drawn: int = ev._made.size() if ev != null and ev._slots_mode == &"wrecks" and ev._slots.visible else 0
		var want := int(sites.get(site, 0))
		var names: Array = []
		for i in drawn:
			names.append(ev._made[i]._name.text)
		h._ok("%s at %d: LOCAL draws %d wrecks (%d %s; here %d, at %s)" % [tag, site, want, drawn, names, Run.wrecks_here(n).size(), Run.node_at().index],
			ev != null and drawn == want and Run.wrecks_here(n).size() == want)
	SystemMapScreen._parked[n.index] = {"at": 0}


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


## Until the cutaway is fully open (3 s at most).
func _open_full(cut: CutawayView) -> void:
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(cut) and cut.t < 1.0 and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame


## WRECKS OFF THE WORLD YOU ORBIT (Jon's rule: fit means nothing overlaps). On
## the real LOCAL, parked at every world of four systems in each of six
## galaxies -- worlds and giants of every size, on either side of the view --
## with one to six wrecks there: no wreck's name, bar or tag on the world's
## disc, ever; no wreck's picture on it while the pile is a fight's worth (three
## or fewer); and a count of the bigger piles whose pictures had no room off it.
## The words draw over the world (the sky is the view's first child, the hulls
## its row), but a grey name on a lit yellow face cannot be read: it is kept
## off rather than drawn over.
func _off_the_world() -> void:
	var kinds: Array[StringName] = [&"cutter", &"lancer", &"hulk", &"marauder", &"cutter", &"lancer"]
	var counts: Array[int] = [1, 2, 3, 4, 6]
	var seeds: Array[int] = [4242, 2718, 1618, 777, 31337, 9001]
	# (`worldseeds=N` on the command line: N galaxies and piles up to eight, for
	# measuring how often a big pile has no room off the world; `worldbig` as
	# well draws every world at the largest size it can be)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("worldseeds="):
			seeds.clear()
			for i in int(a.get_slice("=", 1)):
				seeds.append(1000 + 37 * i)
			counts.assign([1, 2, 3, 4, 5, 6, 8])
	var big := OS.get_cmdline_user_args().has("worldbig")
	var cases := 0
	var words_on: Array[String] = []
	var art_small: Array[String] = []
	var art_big := {}
	var big_cases := {}
	var radii := {}
	var order_ok := true
	var word_places := 0
	var small_cases := 0
	for sd: int in seeds:
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var systems := 0
		for n: MapGen.MapNode in Run.map:
			if systems >= 4:
				break
			if n.type != MapGen.NodeType.SYSTEM or Router.no_fights_at(n):
				continue
			var L := SystemLayout.of(n)
			var worlds: Array[int] = []
			for i in L.bodies.size():
				if L.bodies[i].world != &"":
					worlds.append(i)
			if worlds.is_empty():
				continue
			systems += 1
			Run.at = n.index
			n.visited = true
			SectorScreen._approached_at = n.index
			for b in worlds.slice(0, 3):
				SystemMapScreen._parked[n.index] = {"at": b}
				for k: int in counts:
					var keep: Array = []
					for raw in n.jetsam:
						if not (raw as MapGen.Jetsam).is_wreck():
							keep.append(raw)
					n.jetsam.assign(keep)
					for j in k:
						Run.new_wreck(n, DB.enemies[kinds[(j + b) % kinds.size()]], j)
					Router.show_local()
					await _frames(4)
					var sc := Router.current as SectorScreen
					var ev: EncounterView = sc._view if sc != null else null
					if ev == null:
						h._fail("LOCAL did not come up")
						continue
					# (`worldbig`: every world at the biggest LOCAL draws -- the
					# sky's plan of it, which is what the pile is laid out round)
					if big and ev.backdrop.layout != null:
						ev.backdrop.layout.bodies[b].r *= 3.0
						ev._queue_pack()
						await _frames(3)
					var p := ev.backdrop.near_plan()
					if p.is_empty():
						continue
					cases += 1
					var c: Vector2 = p.at
					var R := float(p.R)
					radii[int(R)] = true
					var sub := LocalSubject.of(ev)
					order_ok = order_ok and ev.backdrop.get_index() < ev._row.get_index() \
						and (sub == null or sub.get_index() < ev._row.get_index())
					var tag := "seed %d system %d world %d (r %d, x %d) with %d" % [sd, n.index, b, int(R), int(c.x), k]
					var art_hit := false
					var had := words_on.size()
					for i in ev._made.size():
						var sl: EnemySlot = ev._made[i]
						for bx in _wreck_boxes(sl) + [["bar", (sl.get("_bar") as Control).get_global_rect()]]:
							if not _on_disc(bx[1], c, R):
								continue
							if bx[0] == "picture":
								art_hit = true
							else:
								words_on.append("%s: wreck %d's %s" % [tag, i, bx[0]])
					if words_on.size() > had:
						word_places += 1
					if art_hit:
						if k <= 3:
							art_small.append(tag)
						else:
							art_big[k] = int(art_big.get(k, 0)) + 1
					if k <= 3:
						small_cases += 1
					if k > 3:
						big_cases[k] = int(big_cases.get(k, 0)) + 1
	var radii_s: Array = radii.keys()
	radii_s.sort()
	print("  --   %d places parked at, world radii %s px" % [cases, radii_s])
	h._ok("the sky and any subject draw under the wrecks and their words", order_ok)
	h._ok("no wreck's name, bar or tag on the world you orbit (on it at %d of %d places)%s" % [word_places, cases,
		"" if words_on.is_empty() else ": " + "; ".join(words_on.slice(0, 4))], words_on.is_empty() and cases > 0)
	h._ok("no wreck's picture on it with three or fewer wrecks (on it at %d of %d)%s" % [art_small.size(), small_cases,
		"" if art_small.is_empty() else ": " + "; ".join(art_small.slice(0, 4))], art_small.is_empty())
	for k in big_cases:
		print("  --   %d wrecks: a picture on the world (no room off it) at %d of %d places" % [k, int(art_big.get(k, 0)), int(big_cases[k])])


## Whether a box comes onto a disc.
static func _on_disc(r: Rect2, c: Vector2, R: float) -> bool:
	var near := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return near.distance_to(c) < R


## Until the cutaway has shut and freed itself (3 s at most). A loop, not a
## lambda: a lambda holding the cutaway is handed null once it is freed, and
## the engine says so as an ERROR the gate counts.
func _gone(cut: CutawayView) -> void:
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(cut) and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
