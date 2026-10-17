extends Node

## ONE MOTION EVERYWHERE (Jon picked A of the nav audit's three directions, Oct
## 17: "the movement between local > sector > starchart ... EXTREMELY
## disorienting"), headless with the animation on, the ladder's clock stepped
## 1/60 s a frame:
##   godot --headless --path . -- sheet=CalmLadderTest
## Every hop between LOCAL, the map and the chart -- by its HUD tab (a real
## click), by Tab, by NEXT SCREEN rebound to N, both ways where the route goes
## both ways, from a world's orbit and from the system's edge -- watched frame by
## frame for what the audit measured going wrong:
##   - ONE SHIP: wherever the picture held from the screen left and the screen
##     arriving both show, they show your ship in the same place (4 px);
##   - ONE STRAIGHT LINE: your ship's place on screen keeps within 4 px of the
##     line from where it rested to where it rests, never turning back on it,
##     never more than 40 px in a frame, never under the side bar;
##   - NO ONE-FRAME SWAP: the held picture never leaves (or comes) by more than a
##     fifth in one frame, and the screens change hands under it whole;
##   - THE CHROME STILL WHILE THE CAMERA MOVES: no side bar or toolbar decode, no
##     sliding column or band, no side bar or toolbar moving or fading, on any
##     frame your ship is moving (one frame's grace at the landing);
##   - THE HOP'S LENGTH within 10% of its target (`ZoomLadder.calm_length`, or
##     A's 1.55 s where there is none);
##   - A PRESS MID-MOVE: a key, a click on the picture, Tab -- the move hurries
##     to its end (under 0.45 s from the press), no frame of it a cut, and the
##     press is not lost (Tab goes on to the next distance).
## Written to run on main too (the ship's place read by the hooks every build
## has), so it can be watched failing there.

var _fails := 0
var _tree: SceneTree
var _zl: GDScript = load("res://scripts/ui/ZoomLadder.gd")
const JUMP_PX := 40.0
const LINE_PX := 4.0
const SAME_PX := 4.0
const SIDE_X := 689.0


func _ok(what: String, c: bool) -> bool:
	if not c:
		print("  FAIL %s" % what)
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _settled() -> bool:
	return not ZoomLadder.busy() and ZoomLadder.chain == &"" and SideSwap.live.is_empty() \
		and ChromeSlide.live.is_empty() and SideBand.live.is_empty()


func _rest() -> void:
	for i in 600:
		if _settled():
			break
		await _tree.process_frame
	await _frames(20)


## Your ship's place on screen, as the screen `s` draws it now (or INF).
func _ship(s: Control) -> Vector2:
	if s == null or not is_instance_valid(s) or not s.call(&"ladder_ready"):
		return Vector2.INF
	if s is SectorScreen:
		return (s as SectorScreen)._ladder_ship()
	if s is SystemMapScreen:
		var m := s as SystemMapScreen
		return m._ladder_origin() + m.overlay.ship_rel()
	if s is StarchartScreen:
		return (s as StarchartScreen).ladder_anchor(1, 1, "A")
	return Vector2.INF


func _rank(s: Control) -> int:
	return ZoomLadder.rank_of(s)


func _target_s(a: int, b: int) -> float:
	for m: Dictionary in _zl.get_script_method_list():
		if String(m.name) == "calm_length":
			return float(_zl.call(&"calm_length", a, b))
	return 1.55


func _chrome_state() -> String:
	var out := PackedStringArray()
	for sw: Variant in SideSwap.live:
		if is_instance_valid(sw):
			out.append("sw%d:%.3f" % [(sw as Object).get_instance_id(), float((sw as Object).get("t"))])
	for p: Variant in ChromeSlide.live:
		if is_instance_valid(p):
			out.append("cs%d:%.3f" % [(p as Object).get_instance_id(), float((p as Object).get("k"))])
	for b: Variant in SideBand.live:
		if is_instance_valid(b):
			out.append("sb%d:%.1f" % [(b as Object).get_instance_id(), (b as Control).size.y])
	var cur := Router.current
	for c: Variant in [ZoomLadder.side_of(cur), ZoomLadder.bar_of(cur)]:
		if c != null and is_instance_valid(c) and (c as Control).is_visible_in_tree():
			var r := (c as Control).get_global_rect()
			out.append("ui%d:%.0f,%.0f,%.2f" % [(c as Object).get_instance_id(), r.position.x, r.position.y, (c as CanvasItem).modulate.a])
	return ",".join(out)


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)


func _click(at: Vector2) -> void:
	var vp := GameShell.input_target(_tree)
	for down in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = at
		mb.global_position = at
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		vp.push_input(mb)


func _tab_at(rank: int) -> Vector2:
	var h := Router.hud
	var b: Button = h._tab_sector if rank == ZoomLadder.LOCAL else (h._tab_system if rank == ZoomLadder.MAP else h._tab_chart)
	return b.get_global_rect().get_center()


## One hop, watched. `press`: [kind, at what share of the hop's target] to press
## mid-move ("key", "click", "tab").
func _hop(label: String, go: Callable, want: int, press: Array = []) -> void:
	var from := _rank(Router.current)
	var target := _target_s(from, want)
	var p0 := _ship(Router.current)
	var pts: Array = []
	var bad: Array = []
	var held_last := -1.0
	var chrome_last := _chrome_state()
	var chrome_moved := 0
	var last_old_pt := p0
	var was := Router.current
	var frames := 0
	var pressed_at := -1
	var press_done := false
	var steps := 0.0
	var steps_at := -1
	var swap_seen := false
	var max_apart := 0.0
	var under_side := 0
	go.call()
	for i in 900:
		await _tree.process_frame
		frames += 1
		var cur := Router.current
		var live := _ship(cur)
		var live_a := cur.modulate.a if is_instance_valid(cur) else 0.0
		var held_a := 0.0
		var held_pt := Vector2.INF
		if ZoomLadder.busy():
			var L := ZoomLadder.active
			if L.get("_rect") != null and (L._rect as CanvasItem).visible:
				held_a = L.held_alpha()
				var m: ShaderMaterial = L._mat
				var fp: Variant = m.get_shader_parameter(&"from_pt")
				var tp: Variant = m.get_shader_parameter(&"to_pt")
				var sc: Variant = m.get_shader_parameter(&"scl")
				if fp is Vector2 and tp is Vector2 and sc is Vector2 and last_old_pt != Vector2.INF:
					held_pt = (tp as Vector2) + (last_old_pt - (fp as Vector2)) * (sc as Vector2).x
		if cur == was:
			last_old_pt = live
		elif not swap_seen:
			swap_seen = true
			# THE SCREENS CHANGE HANDS UNDER THE HELD PICTURE, WHOLE
			if held_a < 0.95:
				bad.append("the screens changed hands with the held picture at %.2f (a one-frame swap)" % held_a)
		# ONE SHIP
		if held_a > 0.05 and live_a > 0.05 and held_pt != Vector2.INF and live != Vector2.INF:
			var apart := held_pt.distance_to(live)
			max_apart = maxf(max_apart, apart)
		# NO ONE-FRAME SWAP
		if held_last >= 0.0 and absf(held_a - held_last) > (0.35 if pressed_at >= 0 else 0.2):
			bad.append("the held picture went %.2f -> %.2f in one frame" % [held_last, held_a])
		held_last = held_a if (held_a > 0.0 or ZoomLadder.busy()) else -1.0
		var pt := held_pt if held_a >= 0.5 and held_pt != Vector2.INF else live
		if pt != Vector2.INF:
			if not pts.is_empty():
				var d: float = pt.distance_to(pts[-1])
				if d > JUMP_PX:
					bad.append("your ship jumped %.0f px in a frame" % d)
				# THE CHROME STILL WHILE THE CAMERA MOVES
				var ch := _chrome_state()
				if d > 0.25 and ch != chrome_last:
					chrome_moved += 1
				chrome_last = ch
			else:
				chrome_last = _chrome_state()
			if pt.x > SIDE_X and (_rank(cur) != ZoomLadder.LOCAL or held_a >= 0.5):
				under_side += 1
			pts.append(pt)
		# A PRESS MID-MOVE
		if not press.is_empty() and not press_done and frames >= int(float(press[1]) * target * 60.0):
			press_done = true
			pressed_at = frames
			match String(press[0]):
				"key":
					_key(KEY_SHIFT)
				"click":
					var c := Router.content.get_global_rect()
					_click(Vector2(c.position.x + 120.0, c.end.y - 60.0))
				"tab":
					_key(KEY_TAB)
		if _settled() and frames > 2:
			break
	var p1 := _ship(Router.current)
	var secs := frames / 60.0
	_ok("%s lands on the screen asked (%s)" % [label, Router.current], _rank(Router.current) == want)
	var uniq: Array = []
	for b in bad:
		if not b in uniq:
			uniq.append(b)
	_ok("%s: no cut, no jump, no one-frame swap%s" % [label, "" if uniq.is_empty() else " (" + "; ".join(PackedStringArray(uniq.slice(0, 4))) + ")"], uniq.is_empty())
	_ok("%s: one ship -- the held picture and the screen arriving put it in the same place (%.1f px apart at most)" % [label, max_apart], max_apart <= SAME_PX)
	# ONE STRAIGHT LINE, never turning back
	var off := 0.0
	var back := 0.0
	if p0 != Vector2.INF and p1 != Vector2.INF and pts.size() > 1:
		var dir := p1 - p0
		var len := dir.length()
		for q: Vector2 in pts:
			if len > 0.5:
				var n := dir / len
				off = maxf(off, absf((q - p0).cross(n)))
			else:
				off = maxf(off, q.distance_to(p0))
		if len > 10.0:
			var n2 := dir / len
			var best := -INF
			for q: Vector2 in pts:
				var s := (q - p0).dot(n2)
				back = maxf(back, best - s)
				best = maxf(best, s)
	_ok("%s: your ship on one straight line from where it rested to where it rests (%.1f px off it at most)" % [label, off], off <= LINE_PX)
	_ok("%s: and never turning back along it (%.1f px back at most)" % [label, back], back <= 1.5)
	_ok("%s: and never under the side bar (%d frames)" % [label, under_side], under_side == 0)
	_ok("%s: the side bar, the toolbar, the column and the band still while the camera moves (%d frames moving)" % [label, chrome_moved], chrome_moved <= 1)
	if press.is_empty():
		_ok("%s: %.2f s, within 10%% of its %.2f s" % [label, secs, target], absf(secs - target) <= target * 0.1)
	else:
		var after := (frames - pressed_at) / 60.0
		_ok("%s: the press hurried the move to its end in %.2f s (under 0.45)" % [label, after], after <= 0.45)
	print("  [calm] %s: %.2f s (target %.2f), off line %.1f, back %.1f, apart %.1f, chrome %d" % [label, secs, target, off, back, max_apart, chrome_moved])


func _at(rank: int) -> void:
	if _rank(Router.current) == rank:
		return
	ZoomLadder.hold_off = true
	match rank:
		ZoomLadder.LOCAL:
			Router.show_local()
		ZoomLadder.MAP:
			Router.show_system()
		ZoomLadder.CHART:
			Router.show_starchart()
	ZoomLadder.hold_off = false
	await _frames(40)
	await _rest()


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 60.0
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	StarchartScreen._primed_for = Run.galaxy_seed
	var sys := Run.at
	for b in SystemLayout.of(Run.node_at()).bodies:
		if b.world != &"" and b.kind != &"belt":
			SystemMapScreen._parked[sys] = {"at": b.index, "mode": &"rail"}
			break
	SectorScreen._approached_at = sys
	Run.map[sys].visited = true
	ZoomLadder.hold_off = true
	Router.show_local()
	ZoomLadder.hold_off = false
	await _frames(60)
	await _rest()
	var L := ZoomLadder.LOCAL
	var M := ZoomLadder.MAP
	var C := ZoomLadder.CHART
	var tab := func(r: int) -> Callable:
		return func() -> void: _click(_tab_at(r))
	# BY THE HUD'S TABS, every way
	for h: Array in [[L, M], [M, C], [C, M], [M, L], [L, C], [C, L]]:
		await _at(h[0])
		await _hop("tab %s -> %s" % [_nm(h[0]), _nm(h[1])], tab.call(h[1]), h[1])
		await _rest()
	# BY TAB, and NEXT SCREEN rebound to N, round the ring
	Keys.set_key(&"next_screen", 1, KEY_N)
	for k: Array in [[KEY_TAB, "Tab"], [KEY_N, "N"]]:
		await _at(L)
		for h: Array in [[L, M], [M, C], [C, L]]:
			var code: Key = k[0]
			await _hop("%s %s -> %s" % [k[1], _nm(h[0]), _nm(h[1])], func() -> void: _key(code), h[1])
			await _rest()
	Keys.reset(&"next_screen")
	# A PRESS MID-MOVE
	await _at(L)
	await _hop("a key mid-move, LOCAL -> map", tab.call(M), M, ["key", 0.55])
	await _rest()
	await _hop("a click on the picture mid-move, map -> chart", tab.call(C), C, ["click", 0.45])
	await _rest()
	await _at(L)
	await _hop("Tab mid-move, LOCAL -> map, on to the chart", func() -> void: _key(KEY_TAB), C, ["tab", 0.3])
	await _rest()
	# AT THE SYSTEM'S EDGE (just jumped in, out of orbit): the audit's ship slid
	# under the side bar on its way to the map
	var edge := -1
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.index != sys and n.type == MapGen.NodeType.SYSTEM:
			edge = n.index
			break
	if edge >= 0:
		Run.at = edge
		Run.map[edge].visited = true
		SectorScreen._approached_at = edge
		SystemMapScreen._parked.erase(edge)
		await _at(M)
		var mp := Router.current as SystemMapScreen
		print("  [calm] at the edge: your ship at %s, flying %s" % [_ship(mp), mp.flight.mode if mp != null and mp.flight != null else &"-"])
		await _hop("tab map -> LOCAL, at the edge", tab.call(L), L)
		await _rest()
		await _hop("tab LOCAL -> map, at the edge", tab.call(M), M)
		await _rest()
	ZoomLadder.force = -1
	ZoomLadder.fixed_dt = -1.0
	print("calmladdertest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)


func _nm(r: int) -> String:
	return ["chart", "map", "LOCAL", "station"][r]
