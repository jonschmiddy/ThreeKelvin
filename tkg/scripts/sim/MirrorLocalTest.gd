extends Node

## LOCAL MOORED ON THE STATION'S RIGHT (Jon's (c), Nov 13) and the partners in it
## (his co-op rules, Nov 13), on the station's LOCAL drawn both ways: what a click
## lands on, where the partners sit and which way they face, that their names read,
## and how they come and go -- out of the mouth, into it, or faded.
## `-- sheet=MirrorLocalTest` (headless, `--fixed-fps 60`).
## Why: docs/why/MirrorLocalTest.md

var h := Harness.new()
var _tree: SceneTree
var _st := -1


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	# (the zoom ladder on, as in play: the station's side on LOCAL is the ladder's)
	ZoomLadder.force = 1
	Rng.forced = 7
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for raw in Run.map:
		if (raw as MapGen.MapNode).type == MapGen.NodeType.STATION:
			_st = (raw as MapGen.MapNode).index
			break
	if not _ok("the run has a station", _st >= 0):
		_end()
		return
	Run.at = _st
	Run.map[_st].visited = true
	SectorScreen._approached_at = _st
	Router.park_at_station()
	SectorScreen.arrived_here()
	# (headless, the window is 64 px square and a click past it goes nowhere)
	if _tree.root.size.x < 1000:
		_tree.root.size = Vector2i(1920, 1080)
	load("res://scripts/sim/ConvoyTest.gd").fake_party(2)
	await _layout(false)
	await _layout(true)
	await _moves(false)
	await _moves(true)
	await _saved()
	await _clicks(false)
	await _clicks(true)
	_end()


func _end() -> void:
	ZoomLadder.force = -1
	SectorScreen.mirrored_at = -1
	Net.roster.clear()
	h.verdict("mirrorlocaltest")
	_tree.quit(h.code())


## LOCAL at the station, on its left (`right` false) or moored on its right.
func _local(right: bool) -> SectorScreen:
	SectorScreen.moor_right(_st if right else -1)
	Router.show_local()
	for i in 120:
		await _tree.process_frame
	var loc := Router.current as SectorScreen
	# (the partners' comings settled: out of the mouth takes `ConvoySlot.OUT_S`)
	for i in 200:
		await _tree.process_frame
		var busy := false
		for s in _slots(loc):
			if not s._move.is_empty():
				busy = true
		if not busy:
			break
	return loc


func _slots(loc: SectorScreen) -> Array[ConvoySlot]:
	var out: Array[ConvoySlot] = []
	if loc != null and loc._view != null:
		for s in loc._view._made_convoy:
			if is_instance_valid(s):
				out.append(s)
	return out


## A hull's drawn box on screen, flips and all.
func _hull(art: ShipView) -> Rect2:
	var r := Rect2(art.ink_rect())
	var xf := art.get_global_transform()
	var a := xf * art.canvas_to_local(r.position)
	var b := xf * art.canvas_to_local(r.end)
	return Rect2(a, b - a).abs()


## WHERE EVERYONE IS: the station, your hull, the partners' column, which way they
## face, that their names read, nothing over the station or off the screen.
func _layout(right: bool) -> void:
	var side := "moored right" if right else "moored left"
	var loc := await _local(right)
	if not _ok("%s: LOCAL at the station, its side up" % side, loc != null and loc._face != null):
		return
	_ok("%s: LOCAL drawn %s" % [side, "mirrored" if right else "as ever"], loc._view.mirrored == right)
	var screen := UiRect.of(loc._view)
	# (the station from its mouth out to the screen's side)
	var edge: float = (loc._view.mouth_g.call() as Vector2).x
	var face := Rect2(screen.position.x, screen.position.y, edge - screen.position.x, screen.size.y) if right 		else Rect2(edge, screen.position.y, screen.end.x - edge, screen.size.y)
	var mine := _hull(loc._view.ship_view())
	var faces_right := loc._view.ship_view().get_global_transform().x.x > 0.0
	_ok("%s: your ship faces right" % side, faces_right)
	_ok("%s: the station on the %s of your ship (station %s, ship %s)" % [side, "left" if right else "right", face, mine],
		(face.get_center().x < mine.get_center().x) == right)
	_ok("%s: your ship clear of the station and the screen's sides (%s in %s)" % [side, mine, screen],
		not mine.intersects(face) and mine.position.x >= screen.position.x + 16.0 and mine.end.x <= screen.end.x - 16.0)
	var slots := _slots(loc)
	_ok("%s: both partners out on LOCAL (%d)" % [side, slots.size()], slots.size() == 2)
	for s in slots:
		var hr := _hull(s.art)
		var who := "%s, partner %d" % [side, s.peer]
		_ok("%s: faces right" % who, s.art.get_global_transform().x.x > 0.0)
		_ok("%s: on the moored side, beyond your ship (%s; yours %s)" % [who, hr, mine],
			(hr.get_center().x > mine.get_center().x) == right)
		_ok("%s: clear of the station and on the screen (%s)" % [who, hr],
			not hr.intersects(face) and screen.grow(-2.0).encloses(hr))
		# the name: drawn flipped back where the view is mirrored, so it reads
		var xf := s.get_global_transform()
		var reads := (xf.x.x > 0.0) != s.flipped
		_ok("%s: its name reads left to right" % who, reads and s._label != "")


## THE PARTNERS' MOVES: a dock and an undock, and one arriving into the system.
func _moves(right: bool) -> void:
	var side := "moored right" if right else "moored left"
	var loc := await _local(right)
	if loc == null or _slots(loc).size() < 2:
		_ok("%s: partners to move" % side, false)
		return
	var mouth: Vector2 = loc._view.mouth_g.call()
	_ok("%s: the station's mouth is on the %s" % [side, "left" if right else "right"], (mouth.x < UiRect.of(loc._view).get_center().x) == right)
	# A PARTNER DOCKS
	var s: ConvoySlot = _slots(loc)[0]
	var id := s.peer
	var x0 := _hull(s.art).get_center().x
	Net.roster[id].docked = true
	Sig.party_changed.emit()
	var xs: Array[float] = []
	var alpha := 1.0
	for i in 200:
		await _tree.process_frame
		if not is_instance_valid(s):
			break
		xs.append(_hull(s.art).get_center().x)
		alpha = minf(alpha, s.modulate.a)
	var gone := not is_instance_valid(s)
	if right:
		_ok("%s: a partner docking fades out where it sits (moved %.1f px, faded to %.2f, gone %s)" % [
			side, _span(xs, x0), alpha, gone], gone and _span(xs, x0) < 1.0 and alpha < 0.2)
	else:
		_ok("%s: a partner docking flies into the mouth, right, behind your ship (from x %.0f to %.0f; mouth %.0f; gone %s)" % [
			side, x0, xs[-1] if not xs.is_empty() else -1.0, mouth.x, gone],
			gone and not xs.is_empty() and xs[-1] > x0 + 100.0 and absf(xs[-1] - mouth.x) < 40.0)
	_ok("%s: docked, it is off LOCAL" % side, _slot_of(loc, id) == null)
	# AND UNDOCKS: out of the mouth to its place, nose right
	Net.roster[id].docked = false
	Sig.party_changed.emit()
	await _tree.process_frame
	await _tree.process_frame
	var back := _slot_of(loc, id)
	xs = []
	for i in 240:
		await _tree.process_frame
		if back == null or not is_instance_valid(back):
			break
		if back.art.visible:
			xs.append(_hull(back.art).get_center().x)
		if back._move.is_empty() and xs.size() > 2:
			break
	var ok_out := back != null and xs.size() > 10 and absf(xs[0] - mouth.x) < 60.0
	if right:
		_ok("%s: a partner undocking comes out of the mouth nose first, left to right, to its place (x %.0f to %.0f)" % [
			side, xs[0] if not xs.is_empty() else -1.0, xs[-1] if not xs.is_empty() else -1.0],
			ok_out and _rising(xs) and back.art.get_global_transform().x.x > 0.0)
	else:
		_ok("%s: a partner undocking backs out of the mouth, right to left, to its place (x %.0f to %.0f)" % [
			side, xs[0] if not xs.is_empty() else -1.0, xs[-1] if not xs.is_empty() else -1.0],
			ok_out and _falling(xs) and back.art.get_global_transform().x.x > 0.0)
	# ONE ARRIVING INTO THE SYSTEM: through the dock where you are moored right, the
	# jump's flash where you are moored left
	var nid := 9
	var b0: ShipBuild = Net.build_of(2)
	Net.roster[nid] = {"id": nid, "name": "ORIN", "hull": &"korvan", "ready": true, "order": 9,
		"build": b0.to_wire() if b0 != null else {}, "at": _st, "docked": false}
	Sig.party_changed.emit()
	await _tree.process_frame
	await _tree.process_frame
	var arr := _slot_of(loc, nid)
	if arr != null:
		if right:
			_ok("%s: a partner arriving comes in through the dock, out of the mouth (moving %s)" % [side, not arr._move.is_empty()],
				not arr._move.is_empty())
		else:
			_ok("%s: a partner arriving jumps in, its flash (playing %s)" % [side, arr.flare.visible],
				arr._move.is_empty() and arr.flare.visible)
	else:
		_ok("%s: the arrival has a place" % side, false)
	Net.roster.erase(nid)
	Sig.party_changed.emit()
	for i in 90:
		await _tree.process_frame


func _slot_of(loc: SectorScreen, id: int) -> ConvoySlot:
	for s in _slots(loc):
		if s.peer == id and not s.leaving():
			return s
	return null


func _span(xs: Array[float], x0: float) -> float:
	var w := 0.0
	for x in xs:
		w = maxf(w, absf(x - x0))
	return w


func _rising(xs: Array[float]) -> bool:
	for i in range(1, xs.size()):
		if xs[i] < xs[i - 1] - 0.5:
			return false
	return true


func _falling(xs: Array[float]) -> bool:
	for i in range(1, xs.size()):
		if xs[i] > xs[i - 1] + 0.5:
			return false
	return true


## SAVED: moored right comes back from a save; a new run and a jump drop it.
func _saved() -> void:
	SectorScreen.moor_right(_st)
	var d: Dictionary = SaveGame._snapshot()
	_ok("saved: the save writes where you are moored (%s)" % d.get("moored_right", "none"), int(d.get("moored_right", -9)) == _st)
	SectorScreen.mirrored_at = -1
	SectorScreen.moor_right(int(d.get("moored_right", -1)))
	_ok("saved: and reads it back, moored right", SectorScreen.mirrored())
	SectorScreen.moor_right(_st)
	Router._on_jumped(Run.at)
	_ok("a jump leaves it behind", not SectorScreen.mirrored())


## CLICKS LAND WHERE THEY ARE DRAWN: your hull opens it up, the station's mouth is
## not a button, DOCK on the bar docks (flying in from the left, black from the right).
func _clicks(right: bool) -> void:
	var side := "moored right" if right else "moored left"
	var loc := await _local(right)
	if loc == null:
		return
	# (still for a moment, so the hull may be pressed: `_still_pointer`)
	loc._still_pointer = Vector2.INF
	var art := loc._view.ship_view()
	var ink := Rect2(art.ink_rect())
	var c0 := art.canvas_to_local(ink.get_center())
	var on := Vector2.INF
	for rad in range(0, 200, 2):
		for p in [c0 + Vector2(rad, 0), c0 - Vector2(rad, 0), c0 + Vector2(0, rad), c0 - Vector2(0, rad)]:
			if on.x == INF and CutawayView.on_hull(art, p):
				on = art.get_global_transform() * p
	await _click_window(on)
	_ok("%s: a click on your hull opens it up (at %s)" % [side, on], loc._cutaway != null)
	if loc._cutaway != null:
		loc._cutaway.close_now()
		for i in 30:
			await _tree.process_frame
	var was := loc.denied_clicks
	await _click_window(loc._view.mouth_g.call())
	_ok("%s: a click on the station's mouth opens nothing and is no dead button" % side,
		loc._cutaway == null and loc.denied_clicks == was and Router.current == loc and not ZoomLadder.busy())
	var dk := loc.find_child("Dock", true, false) as Button
	if not _ok("%s: DOCK on the bar" % side, dk != null):
		return
	# (the bar's button takes its click through the window, as a hand's does: the
	# shell's frame hands it down to the game's view)
	await _click_window(UiRect.of(dk).get_center())
	var fade := ZoomLadder.dock_fade_only
	_ok("%s: a click on DOCK docks, %s" % [side, "black and the landing" if right else "flying in"],
		ZoomLadder.busy() and fade == right)
	for i in 900:
		await _tree.process_frame
		if Router.current is StationScreen and not ZoomLadder.busy() and ZoomLadder.chain == &"":
			break
	_ok("%s: docked" % side, Router.current is StationScreen and Router.docked)
	Router.show_sector()
	for i in 900:
		await _tree.process_frame
		if Router.current is SectorScreen and not ZoomLadder.busy():
			break
	_ok("%s: and UNDOCK moors it on the right" % side, SectorScreen.mirrored())


## A click at a point of the game's view, pushed into the window over it.
func _click_window(at_view: Vector2) -> void:
	var fr: SubViewportContainer = GameShell.instance._frame if GameShell.instance != null else null
	var at := at_view
	if fr != null:
		at = fr.get_global_transform() * (at_view * float(fr.stretch_shrink))
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	_tree.root.push_input(mm)
	await _tree.process_frame
	for down in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = at
		mb.global_position = at
		_tree.root.push_input(mb)
		await _tree.process_frame
	await _tree.process_frame
