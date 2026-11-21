extends Node

## The catch on the real map (Phase 13, `CometCatch`), headless at a fixed clock: the race
## shown, a spot flown to and waited at, the pass into LOCAL with its reading, the ship put
## back on its spot, and a spot it cannot make refused as TOO LATE.
## Why: docs/why/CometCatchTest.md#comet-catch-test

const READING := &"comet_coma"
var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _idle() -> void:
	for i in 900:
		if not ZoomLadder.busy() and ZoomLadder.chain == &"":
			return
		await get_tree().process_frame


## The map, shown fresh for the system the ship is at.
func _map() -> SystemMapScreen:
	Router.show_system()
	await _idle()
	for i in 240:
		var m := Router.current as SystemMapScreen
		if m != null and m.flight != null and m.view.layout != null:
			await Harness.frames(get_tree(), 4)
			return m
		await get_tree().process_frame
	return null


func _run() -> void:
	await get_tree().process_frame
	CometPath._force = 1
	h.seed_run(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n: MapGen.MapNode = null
	var w := -1
	for raw in Run.map:
		var m0: MapGen.MapNode = raw
		if m0.type != MapGen.NodeType.SYSTEM or m0.twin:
			continue
		OptionTable.ensure(m0)
		if not m0.options.has(READING):
			m0.options.append(READING)
		var L0 := SystemLayout.of(m0)
		if L0.comet == null:
			continue
		for b in L0.bodies:
			if b.world != &"":
				w = b.index
				break
		if w >= 0:
			n = m0
			break
	if not h._ok("a system with a comet and its reading (%s)" % (MapGen.star_name(n) if n != null else "none"), n != null):
		_end()
		return
	var L := SystemLayout.of(n)
	var c := L.comet
	var opt := n.options.find(READING)
	Run.at = n.index
	n.visited = true
	ParkedShips.spots[n.index] = {"at": w, "mode": &"rail"}
	Run.map_clock[n.index] = c.t_in + 0.5
	var m := await _map()
	if not h._ok("the map comes up there, in orbit of world %d" % w, m != null and m.flight.reached() == w):
		_end()
		return
	var cc = m.comet_catch()
	# THE RACE: every spot planned off the main thread, YOU against IT
	for i in 600:
		if float(cc.you[0]) != INF and float(cc.you[2]) != INF:
			break
		await get_tree().process_frame
	h._ok("the race is planned for all three spots: YOU %s, IT %s" % [_secs(cc.you), _secs([cc.it_in(0), cc.it_in(1), cc.it_in(2)])],
		float(cc.you[0]) != INF and float(cc.you[1]) != INF and float(cc.you[2]) != INF)
	# HIDDEN TILL CLICKED (Jon, Nov 11): neither the path nor a spot drawn while unselected
	var rc = m.view._weather.real_comet
	var hc: Dictionary = m.overlay.hit(m.overlay.comet_scr())
	m.overlay.hover = hc
	await Harness.frames(get_tree(), 3)
	h._ok("unselected (pointed at): no path dot and no spot drawn (%d dots, %d spots), the comet still clickable at %s" % [rc.dots, m.overlay.spots_drawn, m.overlay.comet_scr()],
		not rc.path_on and rc.dots == 0 and m.overlay.spots_drawn == 0 and hc.get("kind", &"") == &"comet")
	m.tap(hc)
	await Harness.frames(get_tree(), 3)
	h._ok("selected: the path and the three spots are drawn (%d dots%s, %d spots)" % [rc.dots, "" if rc.is_visible_in_tree() else ", not drawn headless", m.overlay.spots_drawn],
		rc.path_on and (rc.dots > 0 or not rc.is_visible_in_tree()) and m.overlay.spots_drawn == 3)
	var b1 := m.panel.find_child("Spot1", true, false) as Button
	h._ok("the comet's page offers its spots: \"%s\"" % (b1.text if b1 != null else "none"), b1 != null and "IT" in b1.text and "YOU" in b1.text)
	# GO TO A SPOT and wait there
	var k := 1 if cc.can_make(1) else 2
	h._ok("spot %d is flown to" % (k + 1), cc.go_spot(k, opt))
	for i in 3600:
		if int(cc.waiting) == k:
			break
		await get_tree().process_frame
	var spot := c.spot_at(L, k)
	m.panel_back()
	await Harness.frames(get_tree(), 3)
	h._ok("deselected while it waits: only that spot drawn (%d), no path (%d dots)" % [m.overlay.spots_drawn, rc.dots], m.overlay.spots_drawn == 1 and rc.dots == 0)
	h._ok("the ship settles on spot %d before the comet (%.2f px off, %.1f s to spare)" % [k + 1, (m.flight.f.p as Vector2).distance_to(spot), c.spot_in(k, float(m.view.t))],
		int(cc.waiting) == k and (m.flight.f.p as Vector2).distance_to(spot) <= 0.5 and c.spot_in(k, float(m.view.t)) > 0.0)
	# THE PASS: down to LOCAL with the reading open as the comet reaches the spot
	var local := false
	for i in 3600:
		if Router.current != m and LocalEventDrawer.last.size() >= 2 and int(LocalEventDrawer.last[1]) == opt:
			local = true
			break
		if Router.current != m and LocalEventDrawer.pending.size() >= 2 and int(LocalEventDrawer.pending[1]) == opt:
			local = true
			break
		await get_tree().process_frame
	h._ok("the comet reaches the spot and LOCAL opens on its reading, met at spot %d" % (CometPath.caught_at(n) + 1),
		local and CometPath.caught_at(n) == k and LocalEventDrawer.here_now(n, opt))
	await _idle()
	await _pass_once(n, opt)
	# BACK ON THE MAP: on its spot again, not at the edge
	m = await _map()
	h._ok("back on the map the ship is on its spot (%.2f px off, mode %s)" % [(m.flight.f.p as Vector2).distance_to(spot) if m != null else INF, m.flight.mode if m != null else &""],
		m != null and m.flight.mode == &"keep" and (m.flight.f.p as Vector2).distance_to(spot) <= 0.5)
	# TOO LATE: the far spot, gone by; and a spot the ship cannot reach first
	n.remove_meta(&"comet_spot")
	ParkedShips.spots[n.index] = {"at": w, "mode": &"rail"}
	Run.map_clock[n.index] = c.spot_t(0) + 1.0
	m = await _map()
	cc = m.comet_catch()
	h._ok("spot 1, gone by, is TOO LATE and is not flown to", cc.too_late(0) and not cc.go_spot(0, opt) and m.flight.mode != &"fly")
	Run.map_clock[n.index] = c.spot_t(2) - 1.0
	m = await _map()
	cc = m.comet_catch()
	for i in 600:
		if float(cc.you[2]) != INF:
			break
		await get_tree().process_frame
	h._ok("spot 3, a second off with YOU %s, is TOO LATE and is not flown to" % CometPath.clock(float(cc.you[2])),
		cc.too_late(2) and not cc.go_spot(2, opt) and m.flight.mode != &"fly")
	_end()


## ONE PASS (Jon, Nov 21: "it keeps passing by over and over"): the close pass comes alongside,
## the reading is taken, it goes, and it never comes in again. LOCAL's sky builds no scene
## headless, so its comet is stepped here against the real node. Why: docs/why/CometCatchTest.md#one-pass
func _pass_once(n: MapGen.MapNode, opt: int) -> void:
	var sky := _Sky.new()
	sky.node = n
	var lc: Node2D = LocalCometS.new()
	lc.sky = sky
	const DT := 1.0 / 60.0
	for i in 60:
		lc._step_pass(DT)
	if not h._ok("LOCAL's comet comes alongside for the open reading (pass at spot %d)" % (int(lc._pass_k) + 1), int(lc._pass_k) >= 0):
		lc.free()
		return
	var site := MapGen.OPTION_SITE + opt
	n.taken.append(site)
	var starts := 0
	var was := int(lc._pass_k)
	# (ARRIVE_S + LEAVE_S is 5 s: 15 s is room for three more passes)
	for i in 900:
		lc._step_pass(DT)
		var now := int(lc._pass_k)
		if was < 0 and now >= 0:
			starts += 1
		was = now
	h._ok("reading taken: the comet goes once and does not come by again (%d more passes, pass %d)" % [starts, was],
		starts == 0 and was == -2)
	# (a LOCAL opened again later, its comet made fresh: no pass for a taken reading)
	var lc2: Node2D = LocalCometS.new()
	lc2.sky = sky
	for i in 300:
		lc2._step_pass(DT)
	h._ok("LOCAL opened again: no close pass for the taken reading (pass %d)" % int(lc2._pass_k), int(lc2._pass_k) < 0)
	lc.free()
	lc2.free()
	# (open again for the TOO LATE checks below, which plan only for an open reading)
	n.taken.remove_at(n.taken.find(site))


## What `LocalComet._step_pass` reads of its sky.
class _Sky extends RefCounted:
	var node: MapGen.MapNode


const LocalCometS := preload("res://scripts/ui/LocalComet.gd")


static func _secs(a: Array) -> String:
	var out := PackedStringArray()
	for x in a:
		out.append("--" if float(x) == INF else "%.1f" % float(x))
	return "/".join(out)


func _end() -> void:
	CometPath._force = 0
	h.verdict("cometcatchtest")
	get_tree().quit(h.code())
