extends Node

## THE SIDE AND WAY ROUND A FLIGHT ARRIVES, headless at a fixed 60 fps: the real map (Jon,
## Nov 11: every click arrives on the lit side with the spin, on either half, Shift up or held;
## the tag says nothing of sides), then the solver alone over a few real systems (every sided
## flight lands on its side, every sensed one goes its way, and how much longer they are is
## printed). Why: docs/why/ArriveSideTest.md#arrive-side-test

const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")
const SEEDS := [4242, 7]
## systems a seed in the solver sweep, line-ups a pair
const SYSTEMS := 3
const LINEUPS := 2
## the least share of sided (or sensed) asks the solver must find and fly clean
const FOUND_MIN := 0.9

var h := Harness.new()
var _shots := ""
var _tree: SceneTree


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	_shots = Harness.arg("shots")
	if _shots != "":
		DirAccess.make_dir_recursive_absolute(_shots)
	if Harness.arg("map", "1") != "0":
		await _map_part()
	if Harness.arg("solver", "1") != "0":
		_solver_sweep()
	h.verdict("arrivesidetest")
	_tree.quit(h.code())


# ---------------------------------------------------------------- the solver alone
## The variants asked of every pair: what the wish holds.
const ASKS := {
	"free": {},
	"lit": {"side": 1},
	"dark": {"side": -1},
	"with": {"sense": 1},
	"against": {"sense": -1},
	"dark against": {"side": -1, "sense": -1},
}


## One sun, then two (a twin: the light the shader blends is handed to the solver as `lit`).
func _solver_sweep() -> void:
	var n_sys := int(Harness.arg("systems", str(SYSTEMS)))
	for twin: bool in [false, true]:
		var stats := {}
		for k in ASKS:
			stats[k] = {"n": 0, "found": 0, "T": [], "dT": [], "longer": 0, "off": 0, "fell": 0, "ms": 0.0}
		var systems := 0
		for sd: int in SEEDS:
			Rng.forced = sd
			Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
			var done := 0
			for raw in Run.map:
				var n: MapGen.MapNode = raw
				if n.type != MapGen.NodeType.SYSTEM or n.twin != twin:
					continue
				OptionTable.ensure(n)
				var L := SystemLayout.of(n)
				if L.twin != twin:
					continue
				var worlds: Array[int] = []
				for b in L.bodies:
					if b.world != &"":
						worlds.append(b.index)
				if worlds.size() < 2:
					continue
				_sweep_system(L, worlds, stats, "seed %d %s" % [sd, MapGen.star_name(n)])
				done += 1
				systems += 1
				if done >= (1 if twin else n_sys):
					break
		print("  solver, %s (%d systems): click to arrival (map s), from every world's ring to every other, %d line-ups" % ["two suns" if twin else "one sun", systems, LINEUPS])
		var free_found := float(stats.free.found) / maxf(1.0, float(stats.free.n))
		for k: String in ASKS:
			var s: Dictionary = stats[k]
			var T: Array = s.T
			var dT: Array = s.dT
			var found := float(s.found) / maxf(1.0, float(s.n))
			print("    %-13s %3d asked, found and clean %5.1f%%, T median %5.2f p90 %5.2f worst %5.2f; vs free: median %+5.2f s, p90 %+5.2f, %d of %d longer by over 1 s; %d fell back to any side; solve median %.0f ms" % [
				k, s.n, 100.0 * found, _pct(T, 0.5), _pct(T, 0.9), _pct(T, 1.0), _pct(dT, 0.5), _pct(dT, 0.9), s.longer, dT.size(), s.fell, float(s.ms)])
			if k != "free" and systems > 0:
				h._ok("%s, %s: every flight found lands as asked (%d off)" % [k, "two suns" if twin else "one sun", s.off], int(s.off) == 0)
				h._ok("%s, %s: found and clean in at least %.0f%% (%.1f%%; free %.1f%%)" % [k, "two suns" if twin else "one sun", 100.0 * FOUND_MIN, 100.0 * found, 100.0 * free_found], found >= FOUND_MIN)


func _sweep_system(L: SystemLayout, worlds: Array[int], stats: Dictionary, label: String) -> void:
	var G := MapGravity.from_layout(L)
	var fs = ShipFlightS.new()
	fs.setup(L, Vector2(L.edge, 0.0), 0.0)
	var o: Dictionary = ShipFlightS.flight_opts()
	var ms: Array = []
	for a: int in worlds:
		for b: int in worlds:
			if a == b:
				continue
			for lu in LINEUPS:
				var t := 40.0 + 37.0 * float(lu)
				var rr: float = fs.orbit_r(a)
				var ang := fposmod(2.39996 * float(lu) + 1.1 * float(a) + 0.7 * float(b), TAU)
				var dep := {"kind": &"ring", "place": a, "rt": rr, "ang": ang, "w": ShipFlightS.RAIL_V / rr}
				var tf := -1.0
				for k: String in ASKS:
					fs.wish = (ASKS[k] as Dictionary).duplicate()
					if fs.wish.has("side"):
						fs.wish.merge(ArriveSide.light_wish(L, b, t))
					var tg: Dictionary = fs._tgt_of(b)
					var t0 := Time.get_ticks_usec()
					var r := FlightSolve.solve(G, dep, tg, t, {}, o)
					var fell := false
					if not r.found and tg.has("side"):
						r = ArriveSide.unsided_solve(G, dep, tg, t, {}, o)
						fell = true
					ms.append(float(Time.get_ticks_usec() - t0) / 1000.0)
					var s: Dictionary = stats[k]
					s.n += 1
					if not (r.found and r.clean) or fell:
						if fell and r.found:
							s.fell += 1
						continue
					s.found += 1
					var T := float(r.end.t) - t
					(s.T as Array).append(T)
					if k == "free":
						tf = T
					elif tf >= 0.0:
						(s.dT as Array).append(T - tf)
						if T - tf > 1.0:
							s.longer += 1
					# on its side, by the map's own light at its arrival; its way round
					var arel: Vector2 = r.end.arel
					var side := int(tg.get("side", 0))
					var d := arel.normalized().dot(ArriveSide.lit_dir(L, b, float(r.end.t)))
					var on_side := side == 0 or d * float(side) >= 0.05
					var sense := int(tg.get("sense", 0))
					var its_way := sense == 0 or signi(int(roundf(float(r.end.sense)))) == sense
					if not on_side or not its_way:
						s.off += 1
						print("    OFF %s: %s world %d to %d line-up %d: side %d (dot %.2f), sense %d (got %.0f)" % [k, label, a, b, lu, side, d, sense, float(r.end.sense)])
	for k: String in ASKS:
		(stats[k] as Dictionary).ms = _pct(ms, 0.5)


static func _pct(v: Array, q: float) -> float:
	if v.is_empty():
		return NAN
	var s := v.duplicate()
	s.sort()
	return float(s[clampi(int(floor(q * float(s.size() - 1) + 0.5)), 0, s.size() - 1)])


# ---------------------------------------------------------------- the real map
func _idle() -> void:
	for i in 900:
		if not ZoomLadder.busy() and ZoomLadder.chain == &"":
			return
		await _tree.process_frame


func _map() -> SystemMapScreen:
	Router.show_system()
	await _idle()
	for i in 240:
		var m := Router.current as SystemMapScreen
		if m != null and m.flight != null and m.view.layout != null:
			await Harness.frames(_tree, 4)
			return m
		await _tree.process_frame
	return null


func _map_part() -> void:
	h.seed_run(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n: MapGen.MapNode = null
	var worlds: Array[int] = []
	for raw in Run.map:
		var m0: MapGen.MapNode = raw
		if m0.type != MapGen.NodeType.SYSTEM or m0.twin:
			continue
		OptionTable.ensure(m0)
		var L0 := SystemLayout.of(m0)
		worlds.clear()
		for b in L0.bodies:
			if b.world != &"":
				worlds.append(b.index)
		if worlds.size() >= 2:
			n = m0
			break
	if not h._ok("a one-sun system with two worlds (%s)" % (MapGen.star_name(n) if n != null else "none"), n != null):
		return
	var L := SystemLayout.of(n)
	var w0 := worlds[0]
	var w1 := worlds[1]
	Run.at = n.index
	n.visited = true
	SystemMapScreen._parked[n.index] = {"at": w0, "mode": &"rail"}
	Run.map_clock[n.index] = 30.0
	var m := await _map()
	if not h._ok("the map comes up in orbit of world %d" % w0, m != null and m.flight.reached() == w0):
		return
	# (`zoom=K`: the map zoomed in between the two worlds, for the stills)
	var z := float(Harness.arg("zoom", "1"))
	if z != 1.0:
		m._zoom_by(z, ((m.view.at[w0] as Vector2) + (m.view.at[w1] as Vector2)) * 0.5)
		for f in 300:
			if (m._glide as Dictionary).is_empty():
				break
			await _tree.process_frame
		await Harness.frames(_tree, 3)
	# EITHER HALF, SHIFT UP OR HELD: always the lit side, with the spin
	_shift(true)
	await _fly_side(m, L, w1, ArriveSide.DARK, "the dark half, Shift held")
	_shift(false)
	await _fly_side(m, L, w0, ArriveSide.LIT, "the lit half, Shift up")
	# THE POINTER OFF THE WORLD: no wish, the autopilot arrives as it likes
	m.select_body(w1)
	m._on_map_input(_motion(m, m.view.window.position + Vector2(8.0, 8.0)))
	await Harness.frames(_tree, 3)
	h._ok("pointing away from the world, nothing is asked of the arrival (wish %s)" % str(m.flight.wish), (m.flight.wish as Dictionary).is_empty())


## Shift through the input system, as a key (it used to turn the ship against the spin).
func _shift(down: bool) -> void:
	var k := InputEventKey.new()
	k.keycode = KEY_SHIFT
	k.physical_keycode = KEY_SHIFT
	k.pressed = down
	Input.parse_input_event(k)
	Input.flush_buffered_events()


func _motion(m: SystemMapScreen, map_p: Vector2) -> InputEventMouseMotion:
	var mm := InputEventMouseMotion.new()
	mm.position = map_p + m._box.position
	mm.global_position = mm.position
	return mm


## The screen point on world i's lit (+1) or dark (-1) half, inside its disc.
func _half_point(m: SystemMapScreen, L: SystemLayout, i: int, side: int) -> Vector2:
	var u := ArriveSide.lit_dir(L, i, float(m.view.t)) * float(side)
	var ds := Vector2(u.x, u.y * ArriveSide.SystemViewS.TILT).normalized()
	return (m.view.at[i] as Vector2) + ds * maxf(2.0, m.view.draw_r(L.bodies[i]) * 0.6)


func _fly_side(m: SystemMapScreen, L: SystemLayout, i: int, half: int, tag: String) -> void:
	var from: int = m.flight.reached()
	m.select_body(i)
	# (on its ring and able to leave: after a fast flight the ship spins down onto it first)
	for f in 600:
		if m.flight.can_fly():
			break
		await _tree.process_frame
	await Harness.frames(_tree, 3)
	var p := _half_point(m, L, i, half)
	m._on_map_input(_motion(m, p))
	await Harness.frames(_tree, 2)
	var want_sense := ArriveSide.spin_sense(m.view, L, i)
	var wish: Dictionary = m.flight.wish
	h._ok("%s: the map asks the autopilot for the lit side, sense %d (wish %s)" % [tag, want_sense, str(wish)],
		int(wish.get("side", 0)) == ArriveSide.LIT and int(wish.get("sense", 0)) == want_sense)
	# the preview for it, drawn before the click (planned on a worker)
	var drawn := false
	for f in 600:
		var pv = m.overlay._pv_plan
		if pv != null and int(pv.to) == i and ArriveSide.plan_matches(pv, m.flight.wish):
			drawn = true
			break
		await _tree.process_frame
	h._ok("%s: the flight drawn before the click is the one asked for" % tag, drawn)
	# THE TAG: nothing about sides, its last line CLICK AGAIN: FLY (Jon, Nov 11)
	var tl: Array = m.overlay.tip_lines(m.overlay.hover)[0]
	var words: Array = tl.map(func(l): return String(l[0]))
	h._ok("%s: the tag ends CLICK AGAIN: FLY, says nothing of sides or Shift, the line lit and the pointer a sight (%s; aimed %s, cursor %d)" % [tag, " / ".join(words), m.overlay.aimed(), m._frame.mouse_default_cursor_shape],
		String(words[-1]) == "CLICK AGAIN: FLY" and not words.any(func(w: String) -> bool: return w.contains("SIDE") or w.contains("SHIFT") or w.contains("SPIN"))
		and m.overlay.aimed() and m._frame.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND)
	await _shot("hover_%d" % i)
	# THE CLICK flies it (the world has moved on while the line was planned: pointed at again)
	p = _half_point(m, L, i, half)
	m._on_map_input(_motion(m, p))
	await Harness.frames(_tree, 2)
	var t_click := float(m.view.t)
	m.tap(m.overlay.hit(p))
	var arrived := false
	for f in 4800:
		if m.flight.reached() == i:
			arrived = true
			break
		await _tree.process_frame
	if not h._ok("%s: the click flies there and arrives (%.1f map s)" % [tag, float(m.view.t) - t_click], arrived):
		return
	var at_side := ArriveSide.side_now(m.flight, L, i, float(m.view.t))
	var dir := int(signf(float(m.flight.rail.get("dir", 0.0))))
	var a := float(m.flight.rail.ang)
	var d := Vector2(cos(a), sin(a)).dot(ArriveSide.lit_dir(L, i, float(m.view.t)))
	h._ok("%s: it arrives on the lit side of world %d (toward the light %.2f)" % [tag, i, d], at_side == ArriveSide.LIT)
	h._ok("%s: it goes round with the spin (rail dir %d, the spin's way %d)" % [tag, dir, want_sense], dir == want_sense)
	print("    %s: world %d to %d, %s, %.1f map s" % [tag, from, i, "replanned at the click" if m.flight.click_replanned else "flew the line drawn", float(m.view.t) - t_click])
	await _shot("arrived_%d" % i)


func _shot(name: String) -> void:
	if _shots == "":
		return
	await Harness.frames(_tree, 2)
	var im := get_viewport().get_texture().get_image()
	im.save_png(_shots.path_join(name + ".png"))
