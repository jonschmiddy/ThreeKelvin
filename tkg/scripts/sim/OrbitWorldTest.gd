extends Node

## LOCAL SHOWS THE WORLD YOU ORBIT, BIG, FROM ITS FIRST FRAME, headless:
##   godot --headless --fixed-fps 60 --path . -- sheet=OrbitWorldTest [seeds=7,11,...] [quick]
## Jon, Oct 21: "Does the local view show the planet you are orbiting the first
## time you go to a planet? That was an issue before. I want the planet you are
## orbiting to be large in the background (you are close to it)."
## Through the real doors with the ladder on (its clock stepped 1/30 s): a new
## run launched onto LOCAL; then in each system visited -- the start, a jump on,
## a station's -- every world flown to on the map for the first time (FLY HERE,
## and GO on an event where one is) and LOCAL by the HUD's tab, Tab round the
## chart, or the GO's own zoom down. On the FIRST frame LOCAL is up (or built
## ahead and handed in), its sky's world is the one the ship orbits (the body,
## its kind and seed), never the world before and never none; open space, the
## star and a station keep no world. After SAVE & EXIT and CONTINUE, still it.
## Every world drawn at least `LocalSky.near_r_min()` across its radius,
## behind your ship (the sky under the scene), and clear of the HUD and the
## goal line.

var _fails := 0
var _tree: SceneTree
var _seeds: Array[int] = [7, 11, 23, 42]
var _quick := false
## `shots=<dir>` (windowed, `--resolution 1920x1080`): each LOCAL's first frame
## and its rest, saved at 960x540
var _shots := ""
var _label := ""
## GO taken on a world's event where it has one
var _go_ok := true
## `film`: every frame of each trip down to LOCAL saved (with `shots=`)
var _film := false
var _filming := ""
var _film_n := 0
## the first frame of each LOCAL: what its sky drew
var _first := {}
var _watch := false
var _kinds := {}
var _sizes: Array = []


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("seeds="):
			_seeds.clear()
			for p in s.substr(6).split(","):
				_seeds.append(int(p))
		elif s == "quick":
			_quick = true
		elif s == "film":
			_film = true
		elif s.begins_with("shots="):
			_shots = s.substr(6)
		elif s.begins_with("nearsize="):
			LocalSky.near_size = StringName(s.substr(9))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _idle() -> int:
	for i in 900:
		if not ZoomLadder.busy() and ZoomLadder.chain == &"":
			await _tree.process_frame
			return i
		await _tree.process_frame
	return -1


## A real key, through Main's own Tab.
func _tab() -> void:
	for pressed in [true, false]:
		var k := InputEventKey.new()
		k.keycode = KEY_TAB
		k.physical_keycode = KEY_TAB
		k.pressed = pressed
		Input.parse_input_event(k)
		await _frames(1)
	await _idle()


## The HUD's LOCAL tab, pressed.
func _here_tab() -> void:
	Router.hud._tab_sector.pressed.emit()
	await _frames(1)
	await _idle()


## THE FIRST FRAME: every process frame, the LOCAL up or the one built ahead,
## and its sky as it stands the first time it is seen.
func _process(_d: float) -> void:
	if not _watch:
		return
	if _filming != "":
		_film_frame()
	for c: Variant in [Router.current, ZoomLadder.prebuilt]:
		if c == null or not is_instance_valid(c) or not (c is SectorScreen):
			continue
		var sc := c as SectorScreen
		if _first.has(sc.get_instance_id()) or sc._view == null or sc._view.backdrop == null:
			continue
		var sky: LocalSky = sc._view.backdrop
		if sky.node == null:
			continue
		_first[sc.get_instance_id()] = _sky_now(sky)
		if c == Router.current and _shots != "":
			_shot("first")


func _sky_now(sky: LocalSky) -> Dictionary:
	var d := {"node": sky.node.index, "at": sky.orbit_target, "world": &"", "seed": -1, "R": 0.0}
	var nw: Node2D = sky._near_world
	if nw != null and is_instance_valid(nw) and nw.get("spec") != null:
		var sp: Dictionary = nw.get("spec")
		d.world = StringName(sp.get("world", &""))
		d.seed = int(nw.get("_seed")) if nw.get("_seed") != null else -1
		d.vis = nw.is_visible_in_tree()
	var plan := sky.near_plan()
	if not plan.is_empty():
		d.R = float(plan.R)
		d.c = plan.at
		# (headless the sky draws nothing: its plan is where `_build_near` puts it)
		if LocalSky.headless():
			d.world = StringName(plan.world)
			d.seed = int(plan.seed)
	return d


func _film_on() -> void:
	if _film and _shots != "":
		_filming = _label
		_film_n = 0


func _film_frame() -> void:
	var dir := _shots.path_join("film_" + _filming)
	var k := _film_n
	_film_n += 1
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	if im.get_width() != 960:
		im.resize(960, 540, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(dir)
	im.save_png(dir.path_join("f%03d.png" % k))


## The window as it is drawn this frame, halved to the game's 960x540.
func _shot(tag: String) -> void:
	if _shots == "" or DisplayServer.get_name() == "headless":
		return
	var name := "%s_%s" % [_label, tag]
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	if im.get_width() != 960:
		im.resize(960, 540, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(_shots)
	im.save_png(_shots.path_join(name + ".png"))
	print("  shot %s" % name)


## What the ship is at, as the run says it.
func _want(n: MapGen.MapNode) -> Dictionary:
	var L := SystemLayout.of(n)
	var at := Run.site_here(n)
	var d := {"at": at if at >= -1 else -9, "world": &"", "seed": -1, "kind": &"", "name": ""}
	if at >= 0 and at < L.bodies.size():
		d.world = L.bodies[at].world
		d.seed = L.bodies[at].seed
		d.kind = L.bodies[at].kind
		d.name = L.bodies[at].name
	return d


## LOCAL arrived on: its first frame and as it rests, against where the ship is.
func _check(what: String) -> void:
	var sc := Router.current as SectorScreen
	if not _ok("%s: on LOCAL (%s)" % [what, Router.current.get_script().get_global_name() if Router.current != null else "null"], sc != null):
		return
	var n := Run.node_at()
	var w := _want(n)
	var f: Dictionary = _first.get(sc.get_instance_id(), {})
	var now := _sky_now(sc._view.backdrop)
	var tag := "%s (%s %s seed %d, body %d)" % [w.name, w.kind, w.world, w.seed, w.at] if w.world != &"" else ("body %d" % w.at)
	if _shots != "":
		await _shot("rest")
	for pair in [["first frame", f], ["at rest", now]]:
		var s: Dictionary = pair[1]
		if s.is_empty():
			_ok("%s: %s seen" % [what, pair[0]], false)
			continue
		var good: bool = int(s.node) == n.index and int(s.at) == int(w.at) and StringName(s.world) == StringName(w.world) \
			and (w.world == &"" or int(s.seed) == int(w.seed))
		_ok("%s: %s draws %s (sky: node %d, body %d, %s seed %d, R %.0f)" % [what, pair[0], tag, s.node, s.at, s.world, s.seed, s.R], good)
	if w.world == &"":
		return
	_kinds[w.world] = int(_kinds.get(w.world, 0)) + 1
	var sky: LocalSky = sc._view.backdrop
	var info := sky.near_info()
	if LocalSky.headless():
		info = {"at": sc._view.backdrop.get_global_transform() * Vector2(now.get("c", Vector2.ZERO)), "r": float(now.R)}
	elif not _ok("%s: the world is drawn (near_info)" % what, not info.is_empty()):
		return
	var R := float(now.R)
	var c: Vector2 = now.get("c", Vector2.ZERO)
	var fill := _fill(c, R)
	_sizes.append([w.kind, w.world, R, fill])
	print("    %s R %.0f px at %s, %.0f%% of the frame" % [w.world, R, c, fill * 100.0])
	var rmin := float(sky.call(&"near_r_min", w.kind)) if sky.has_method(&"near_r_min") else 0.0
	_ok("%s: drawn at R %.0f, at least %.0f" % [what, R, rmin], R >= rmin - 0.5)
	# BEHIND YOUR SHIP: the sky is under the scene
	var ship := sc._view.ship_view()
	if ship != null:
		_ok("%s: behind your ship (sky drawn first)" % what, _before(sky, ship))
	# CLEAR OF THE HUD AND THE GOAL LINE: the disc's own bounds, in the game frame
	var disc := Rect2(Vector2(info.at) - Vector2.ONE * float(info.r), Vector2.ONE * 2.0 * float(info.r))
	var hud := Router.hud.get_global_rect() if Router.hud != null else Rect2()
	var goal := GoalLine.stack_rect(sc)
	_ok("%s: clear of the HUD (%s vs %s)" % [what, disc, hud], not _disc_hits(info, hud))
	if goal.size != Vector2.ZERO:
		_ok("%s: clear of the goal line (%s)" % [what, goal], not _disc_hits(info, goal))


func _disc_hits(info: Dictionary, r: Rect2) -> bool:
	if r.size == Vector2.ZERO:
		return false
	var c: Vector2 = info.at
	var q := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return q.distance_to(c) < float(info.r) - 1.0


## Whether `a` is drawn before `b` (a tree walk: the first found is under).
func _before(a: Node, b: Node) -> bool:
	var stack: Array[Node] = [_tree.root]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		if x == a:
			return true
		if x == b:
			return false
		var ch := x.get_children()
		ch.reverse()
		stack.append_array(ch)
	return false


## How much of the 960x540 frame the disc covers.
func _fill(c: Vector2, R: float) -> float:
	var hit := 0
	var tot := 0
	for y in range(0, 540, 4):
		for x in range(0, 960, 4):
			tot += 1
			if Vector2(x + 2, y + 2).distance_to(c) <= R:
				hit += 1
	return float(hit) / float(tot)


## Fly the map's ship to place `p` and wait for it to settle in orbit.
func _fly(p: int) -> bool:
	var m := Router.current as SystemMapScreen
	if m == null:
		return false
	for i in 600:
		if m.flight != null and m.flight.can_fly():
			break
		await _tree.process_frame
	if m.flight.reached() == p:
		return true
	m.fly_to_body(p)
	for i in 3600:
		await _tree.process_frame
		if not is_instance_valid(m):
			return false
		if m.flight.reached() == p and m.flight.can_fly():
			await _frames(10)
			return true
	return false


## An event on body `b` GO can take the ship to (no fight: the trip is the subject).
func _event_on(n: MapGen.MapNode, b: int) -> int:
	OptionTable.ensure(n)
	for i in n.options.size():
		var o := OptionTable.by_id(n.options[i])
		if o.is_empty() or n.taken.has(MapGen.OPTION_SITE + i) or o.has("fight"):
			continue
		if LocalEventDrawer.body_of(n, i) == b:
			return i
	return -1


## Every world (planets and giants) in this system, in orbit order.
func _worlds(n: MapGen.MapNode) -> Array[int]:
	var out: Array[int] = []
	var L := SystemLayout.of(n)
	for b in L.bodies:
		if b.world != &"" and b.kind != &"belt":
			out.append(b.index)
	return out


## THE SYSTEM, WORLD BY WORLD: Tab to the map, each world flown to for the first
## time, then LOCAL by the next door in turn.
func _tour(sd: int, label: String) -> void:
	var n := Run.node_at()
	var ws := _worlds(n)
	print("  %s: system %d (%s), worlds %s" % [label, n.index, MapGen.star_name(n), ws])
	var doors := ["hud", "tab", "go"]
	var k := 0
	var L := SystemLayout.of(n)
	for b: int in ws:
		var door: String = doors[k % doors.size()]
		k += 1
		_label = "s%d_%s_b%d_%s_%s" % [sd, label, b, L.bodies[b].kind, L.bodies[b].world]
		await _tab()
		# (a new run's first LOCAL let the harness's Tab go by: the map's own door)
		if not (Router.current is SystemMapScreen):
			Router.show_system()
			await _idle()
		var m := Router.current as SystemMapScreen
		if m == null:
			print("    (on %s, busy %s, combat %s, hellbender %s at %d, dead %s)" % [Router.current.get_script().get_global_name(), ZoomLadder.busy(),
				Router.in_combat(), Run.hellbender_alive(), Run.hellbender_at, Run.dead])
		if not _ok("seed %d %s: Tab to the map" % [sd, label], m != null):
			return
		var ev := _event_on(n, b)
		if ev >= 0 and _go_ok:
			door = "go"
		elif door == "go":
			door = "hud"
		if door == "go":
			for i in 600:
				if m.flight != null and m.flight.can_fly():
					break
				await _tree.process_frame
			LocalEventDrawer.quiet = true
			_film_on()
			m.go_event(ev)
			for i in 3600:
				await _tree.process_frame
				if Router.current is SectorScreen and not ZoomLadder.busy():
					break
			await _idle()
			await _frames(4)
		else:
			if not _ok("seed %d %s: flown to %s (body %d)" % [sd, label, L.bodies[b].name, b], await _fly(b)):
				continue
			_film_on()
			if door == "hud":
				await _here_tab()
			else:
				await _tab()
				await _tab()
			await _frames(4)
		await _check("seed %d %s: %s %s by %s" % [sd, label, L.bodies[b].kind, L.bodies[b].world, door])
		_filming = ""
		LocalEventDrawer.quiet = false
		if _quick:
			break


## LOCAL PRESSED AS THE SHIP ARRIVES: flown to world `p` and the HUD's LOCAL
## pressed the first frame the ship is burning onto its orbit (`inserting`, the
## map drawing it at the world), or still riding the orbit it is leaving
## (`phase`): LOCAL draws the world the ship is on or going onto, and the map
## put back where it was.
func _early(sd: int, label: String, when: String) -> void:
	var n := Run.node_at()
	var ws := _worlds(n)
	var from := Run.site_here(n)
	var to := -9
	for b: int in ws:
		if b != from:
			to = b
	if to < 0 or (when == "phase" and from < 0):
		print("  (%s %s: no second world)" % [label, when])
		return
	var L := SystemLayout.of(n)
	var shown := from if when == "phase" else to
	_label = "s%d_%s_%s_b%d_%s" % [sd, label, when, shown, L.bodies[shown].world]
	await _tab()
	if not (Router.current is SystemMapScreen):
		Router.show_system()
		await _idle()
	var m := Router.current as SystemMapScreen
	if not _ok("seed %d %s %s: on the map" % [sd, label, when], m != null):
		return
	for i in 600:
		if m.flight != null and m.flight.can_fly():
			break
		await _tree.process_frame
	m.fly_to_body(to)
	var f = m.flight
	var seen := false
	for i in 3600:
		await _tree.process_frame
		if when == "phase" and f.rail.has("phase"):
			seen = true
			break
		if when == "insert" and f.mode == &"rail" and f.orbit_body() == to and f.inserting():
			seen = true
			break
	if not _ok("seed %d %s %s: caught the ship %s (mode %s, on %d)" % [sd, label, when, "riding out" if when == "phase" else "burning onto the orbit", f.mode, f.orbit_body()], seen):
		return
	if when == "insert":
		print("    the burn onto the orbit: %.2f s of the map's clock left (s %.2f)" % [_burn_left(f), float(f.rail.get("s", 1.0))])
	var want := from if when == "phase" else to
	var onto: int = f.orbit_body()
	_here_tab.call()
	for i in 600:
		await _tree.process_frame
		if Router.current is SectorScreen and not ZoomLadder.busy():
			break
	await _idle()
	await _frames(4)
	var sc := Router.current as SectorScreen
	if not _ok("seed %d %s %s: on LOCAL" % [sd, label, when], sc != null):
		return
	var fs: Dictionary = _first.get(sc.get_instance_id(), {})
	var now := _sky_now(sc._view.backdrop)
	var wn := L.bodies[want].world
	for pair in [["first frame", fs], ["at rest", now]]:
		var sky_d: Dictionary = pair[1]
		_ok("seed %d %s %s: %s draws body %d %s (sky: body %d, %s; site %d, the map's ship on %d)" % [sd, label, when, pair[0], want, wn,
			sky_d.get("at", -99), sky_d.get("world", &""), Run.site_here(), onto],
			not sky_d.is_empty() and int(sky_d.at) == want and StringName(sky_d.world) == wn)
	if _shots != "":
		await _shot("rest")
	# and the map again: the ship where it was going, not at the edge
	await _tab()
	if not (Router.current is SystemMapScreen):
		Router.show_system()
		await _idle()
	m = Router.current as SystemMapScreen
	if m != null:
		await _frames(10)
		_ok("seed %d %s %s: the map again, the ship on %d (on %d, mode %s, reached %d)" % [sd, label, when, want, m.flight.orbit_body(), m.flight.mode, m.flight.reached()],
			m.flight.orbit_body() == want)
		for i in 1200:
			if m.flight.can_fly():
				break
			await _tree.process_frame
	Router.show_local()
	await _idle()
	await _frames(4)


## How long the burn onto the orbit has to go, by the map's clock.
func _burn_left(f) -> float:
	var ins: Dictionary = f.rail.get("ins", {})
	return (1.0 - float(f.rail.get("s", 1.0))) * float(ins.get("T", 0.0))


## A system in reach to jump to: a station's if `station`.
func _jump_target(station: bool) -> int:
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.index == Run.at or not Run.can_jump_to(n):
			continue
		if n.type == MapGen.NodeType.CORE or n.type == MapGen.NodeType.PULSAR:
			continue
		if (n.type == MapGen.NodeType.STATION) != station:
			continue
		return n.index
	return -1


func _jump_to(to: int) -> bool:
	if to < 0 or not Run.can_jump_to(Run.map[to]):
		return false
	Router.begin_jump(to)
	for i in 1800:
		await _tree.process_frame
		if Run.at == to and not ZoomLadder.busy() and (Router.current is SystemMapScreen or Router.current is SectorScreen) \
				and Router._post_arrive == false:
			break
	await _idle()
	await _frames(30)
	return Run.at == to


## Arrived in a system: LOCAL there (by the HUD's tab if the jump left you on the map).
func _arrival(sd: int, label: String) -> void:
	if Router.current is SystemMapScreen:
		await _here_tab()
	await _frames(4)
	_label = "s%d_%s_arrival" % [sd, label]
	await _check("seed %d %s: arrival" % [sd, label])


## SAVE & EXIT, then CONTINUE, as a player does, then LOCAL.
func _reload(sd: int) -> void:
	var w := _want(Run.node_at())
	_label = "s%d_continue" % sd
	SaveGame.save()
	Run.hull = null
	Router.show_launcher()
	await _frames(3)
	SystemMapScreen._parked = {}
	Router.continue_run()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		await _tree.process_frame
		if (Router.current is SectorScreen or Router.current is SystemMapScreen) and not ZoomLadder.busy():
			break
	await _idle()
	await _frames(6)
	if Router.current is SystemMapScreen:
		await _here_tab()
		await _frames(4)
	_ok("seed %d: CONTINUE keeps the ship at body %d (%d)" % [sd, w.at, Run.site_here()], Run.site_here() == int(w.at))
	_label = "s%d_continue" % sd
	await _check("seed %d: after CONTINUE" % sd)


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 30.0
	_watch = true
	for sd in _seeds:
		print("seed %d" % sd)
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		for raw in Run.map:
			(raw as MapGen.MapNode).ambush_rolled = true
			(raw as MapGen.MapNode).ambush_pending = false
		Run.fuel = 99
		SystemMapScreen._parked.clear()
		# LAUNCHED: a new run opens on LOCAL (`show_chassis_select`'s launched)
		_label = "s%d_launch" % sd
		Router.show_local()
		await _idle()
		await _frames(6)
		await _check("seed %d start: launch" % sd)
		await _tour(sd, "start")
		# a jump on, and the station's system
		for station in [false, true]:
			Run.chart_from(Run.node_at())
			var to := _jump_target(station)
			if to < 0:
				print("  (no %s in reach)" % ("station" if station else "system"))
				continue
			_label = "s%d_%s_arrival" % [sd, "station" if station else "jump"]
			if not _ok("seed %d: jumped to %d" % [sd, to], await _jump_to(to)):
				continue
			var label := "station" if station else "jump"
			_label = "s%d_%s_arrival" % [sd, label]
			await _arrival(sd, label)
			await _tour(sd, label)
			await _early(sd, label, "phase")
			await _early(sd, label, "insert")
		await _reload(sd)
		if _quick:
			break
	print("world kinds seen: %s" % _kinds)
	var by := {}
	for s: Array in _sizes:
		by[s[0]] = by.get(s[0], []) + [s[2]]
	print("radii by kind: %s" % by)
	_end()


func _end() -> void:
	_watch = false
	ZoomLadder.force = -1
	ZoomLadder.fixed_dt = -1.0
	print("orbitworldtest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
