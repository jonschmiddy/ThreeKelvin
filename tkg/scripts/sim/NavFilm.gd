extends Node

## NAVIGATION AUDIT (Jon, Oct 17: "the movement between local > sector >
## starchart ... EXTREMELY disorienting"). Every move between the distances a
## player can make, made the way a player makes it -- a HUD tab clicked with a
## pointer, Tab pressed, the wheel turned -- filmed under the movie writer with
## sound, and every frame's state logged beside it for measuring.
##   godot --path . --resolution 1920x1080 --write-movie <dir>/film.avi --fixed-fps 60
##       -- sheet=NavFilm reel=<ladder|journey|dock|session> out=<dir> flow=c asrelease [seed=N] [at=nebula]
## Writes <out>/frames.jsonl (one line a process frame: the screen up, the
## ladder's phase, where your ship is on screen in game px, which HUD tab is lit,
## the side bar's and toolbar's opacity, the map's zoom) and <out>/marks.json;
## prints `mark <name> <drawn> <t>` at each action. The pointer is a software
## arrow (FirstRunFilm's), since pushed events move no hardware cursor.
##
## FILMED AT TRUE SPEED. The ladder, LOCAL and the side bar's swap all run on the
## process delta. Two clocks on the map and the chart read the wall instead
## (which races ~13x under the movie writer), so this harness drives their own
## overrides from the game clock every frame: the chart's `MapChart.clock_override`
## and the map view's `hclock`, and it re-bases the map's `_glide` start onto the
## game clock. Nothing in the game is changed.

var _args: PackedStringArray
var _dir := ""
var _t := 0.0
var _marks: Array = []
var _ptr := Vector2(480, 300)
var _ptr_down := false
var _cursor: Ptr = null
var _log: FileAccess = null
var _live := true
var _hop_n := 0


class Ptr extends Control:
	var at := Vector2.ZERO

	func _draw() -> void:
		var rows := [
			"X", "XX", "XWX", "XWWX", "XWWWX", "XWWWWX", "XWWWWWX", "XWWWWWWX",
			"XWWWWXXXX", "XWXWWX", "XX XWWX", "X   XWWX", "     XX",
		]
		for y in rows.size():
			var r: String = rows[y]
			for x in r.length():
				var ch := r[x]
				if ch == "X":
					draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), Color("#05070a"))
				elif ch == "W":
					draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), Color("#f2f4f6"))


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	process_priority = 1000000
	process_mode = Node.PROCESS_MODE_ALWAYS
	var early := _Early.new()
	early.process_priority = -1000000
	early.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(early)
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


# ------------------------------------------------------------------ the log

func _scr(s: Control) -> String:
	if s == null or not is_instance_valid(s):
		return "-"
	if s is SectorScreen:
		return "L"
	if s is SystemMapScreen:
		return "M"
	if s is StarchartScreen:
		return "C"
	if s is StationScreen:
		return "S"
	var n: String = s.get_script().get_global_name() if s.get_script() != null else s.get_class()
	return n


func _v(p: Vector2) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.y, 0.1)]


## Where your ship is on the live screen, game px: on LOCAL the hull's ink, on
## the map the ship's marker, on the chart your star's mark, in the yard your
## ship on its stands.
func _ship_on(s: Control) -> Variant:
	if s == null or not is_instance_valid(s):
		return null
	if s is SectorScreen:
		var sc := s as SectorScreen
		if sc._view == null or sc._view.ship_view() == null or not sc._view.ship_view().is_visible_in_tree():
			return null
		return _v(sc._ladder_ship())
	if s is SystemMapScreen:
		var mp := s as SystemMapScreen
		if not mp.ladder_ready():
			return null
		return _v(mp._ladder_origin() + mp.overlay.ship_rel())
	if s is StarchartScreen:
		var ch := s as StarchartScreen
		if not ch.ladder_ready():
			return null
		return _v(ch.ladder_anchor(1, 1, "A"))
	if s is StationScreen:
		var st := s as StationScreen
		if st._mine_view != null and is_instance_valid(st._mine_view) and st._mine_view.is_visible_in_tree():
			return _v(st._mine_view.get_global_rect().get_center())
	return null


func _lit(b: Button) -> int:
	if b == null or not is_instance_valid(b):
		return -1
	return 1 if b.has_theme_stylebox_override("normal") else 0


## Runs before every other node a frame: the wall-clock readers on the map and
## the chart put on the game's clock for this frame (see the header).
class _Early extends Node:
	func _process(delta: float) -> void:
		var g := GameClock.now()
		StarchartScreen.MapChart.clock_override = g
		for s: Variant in [Router.current, ZoomLadder.prebuilt]:
			if s is SystemMapScreen and is_instance_valid(s):
				var mp := s as SystemMapScreen
				if mp.view != null:
					mp.view.hclock = g
				if not mp._glide.is_empty():
					var wall := float(Time.get_ticks_msec()) / 1000.0
					if not mp._glide.has("_g0"):
						# first sight: it began last frame, on the game's clock
						mp._glide["_g0"] = g - delta
					mp._glide["t0"] = wall - (g - float(mp._glide["_g0"]))


func _process(delta: float) -> void:
	if not _live:
		return
	_t += delta
	var cur := Router.current
	if _cursor != null:
		_cursor.at = _ptr
		_cursor.queue_redraw()
	_log_frame(cur)


func _log_frame(cur: Control) -> void:
	if _log == null:
		return
	var o := {"f": Engine.get_process_frames(), "d": Engine.get_frames_drawn(), "t": snappedf(GameClock.now(), 0.0001),
		"s": _scr(cur), "ptr": _v(_ptr), "down": _ptr_down}
	o["ship"] = _ship_on(cur)
	if ZoomLadder.busy():
		var L := ZoomLadder.active
		o["ph"] = int(L.phase)
		o["seam"] = L.seam
		o["dz"] = L.design
		o["fade"] = L._fade
		o["from"] = L.r_old
		o["to"] = L.r_new
		if L._black != null and is_instance_valid(L._black):
			o["black"] = snappedf(L._black.color.a, 0.001)
		if L._rect.visible:
			var m := L._mat
			o["held_t"] = snappedf(1.0 - L.held_alpha(), 0.001)
			o["held_from"] = _v(m.get_shader_parameter(&"from_pt"))
			o["held_to"] = _v(m.get_shader_parameter(&"to_pt"))
			o["held_scl"] = snappedf((m.get_shader_parameter(&"scl") as Vector2).x, 0.0001)
		# the screen being left, while it is still up (its camera moving)
		if L.old != null and is_instance_valid(L.old) and L.old != cur:
			o["old"] = _scr(L.old)
	else:
		o["ph"] = -1
	if Router.hud != null and is_instance_valid(Router.hud):
		var h := Router.hud
		o["tabs"] = [_lit(h._tab_sector), _lit(h._tab_system), _lit(h._tab_chart)]
		o["tab0"] = h._tab_sector.text if h._tab_sector != null else ""
	var sd := ZoomLadder.side_of(cur)
	if sd != null and is_instance_valid(sd):
		o["side"] = [snappedf(sd.modulate.a, 0.01), snappedf(sd.get_global_rect().position.x, 0.1), sd.is_visible_in_tree()]
	var br := ZoomLadder.bar_of(cur)
	if br != null and is_instance_valid(br):
		o["bar"] = [snappedf(br.modulate.a, 0.01), br.is_visible_in_tree()]
	if cur is SystemMapScreen and (cur as SystemMapScreen).view != null:
		o["zoom"] = snappedf((cur as SystemMapScreen).view.zoom, 0.0001)
		var fl = (cur as SystemMapScreen).flight
		if fl != null:
			o["fly"] = String(fl.mode)
	if cur is SectorScreen:
		var sc := cur as SectorScreen
		o["fight"] = sc.fighting()
		if sc._quiet_holder != null and is_instance_valid(sc._quiet_holder):
			o["lbar"] = snappedf(sc._quiet_holder.modulate.a, 0.01)
	o["sw"] = SideSwap.live.size()
	o["cs"] = ChromeSlide.live.size()
	o["modal"] = snappedf(cur.modulate.a, 0.01) if cur != null and is_instance_valid(cur) else -1.0
	_log.store_line(JSON.stringify(o))


func _mark(name: String, extra: Dictionary = {}) -> void:
	var d := {name = name, f = Engine.get_process_frames(), d = Engine.get_frames_drawn(), t = snappedf(_t, 0.001),
		screen = _scr(Router.current)}
	d.merge(extra)
	_marks.append(d)
	print("mark %s %d %.3f %s" % [name, Engine.get_frames_drawn(), _t, JSON.stringify(extra) if not extra.is_empty() else ""])
	if _log != null:
		_log.store_line(JSON.stringify({"mark": name, "f": Engine.get_process_frames(), "d": Engine.get_frames_drawn(), "x": extra}))


# ------------------------------------------------------------------ hands

func _wait(s: float) -> void:
	var until := _t + s
	while _t < until:
		await get_tree().process_frame


func _until(cond: Callable, max_s: float = 30.0) -> bool:
	var until := _t + max_s
	while _t < until:
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _settled() -> bool:
	return not ZoomLadder.busy() and ZoomLadder.chain == &"" and SideSwap.live.is_empty() and ChromeSlide.live.is_empty()


func _settle(extra: float = 1.5, max_s: float = 20.0) -> void:
	await _until(_settled, max_s)
	_mark("settled")
	await _wait(extra)


func _push(at: Vector2, down: bool, button: bool) -> void:
	var vp := GameShell.input_target(get_tree())
	if button:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = at
		mb.global_position = at
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		vp.push_input(mb)
		_ptr_down = down
	else:
		var mm := InputEventMouseMotion.new()
		mm.position = at
		mm.global_position = at
		mm.relative = at - _ptr
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT if _ptr_down else 0
		vp.push_input(mm)
	_ptr = at


func _glide(to: Vector2, s: float = 0.45) -> void:
	var from := _ptr
	var n := maxi(1, int(s * 60.0))
	for i in n:
		var u := float(i + 1) / float(n)
		var e := u * u * (3.0 - 2.0 * u)
		_push(from.lerp(to, e).round(), false, false)
		await get_tree().process_frame


## A click on a control, as a hand makes it: the pointer there, a moment's
## hover, down, up. Falls back to `pressed` if the pushed press missed.
func _click(c: Control, why: String, glide_s: float = 0.45) -> bool:
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		_mark("click_missing", {why = why})
		return false
	var at := c.get_global_rect().get_center().round()
	await _glide(at, glide_s)
	c.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _wait(0.15)
	var fired := [false]
	var b := c as Button
	var on_press := func() -> void: fired[0] = true
	if b != null:
		b.pressed.connect(on_press)
	_mark("click", {why = why, what = b.text if b != null else c.get_class(), at = _v(at)})
	_push(at, true, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_push(at, false, true)
	await get_tree().process_frame
	if b != null and is_instance_valid(b):
		b.notification(Control.NOTIFICATION_MOUSE_EXIT)
		if not fired[0] and not b.disabled and b.is_visible_in_tree():
			_mark("click_fallback", {why = why})
			b.pressed.emit()
		if b.pressed.is_connected(on_press):
			b.pressed.disconnect(on_press)
	return true


func _click_at(at: Vector2, why: String, glide_s: float = 0.45) -> void:
	await _glide(at.round(), glide_s)
	await _wait(0.15)
	_mark("click", {why = why, at = _v(at)})
	_push(at.round(), true, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_push(at.round(), false, true)
	await get_tree().process_frame


func _key(code: Key, why: String) -> void:
	_mark("key", {why = why, key = OS.get_keycode_string(code)})
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _wheel(at: Vector2, up: bool, n: int, why: String, gap_s: float = 0.07) -> void:
	await _glide(at.round(), 0.3)
	_mark("wheel", {why = why, dir = "in" if up else "out", n = n})
	var vp := GameShell.input_target(get_tree())
	for i in n:
		for down in [true, false]:
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
			mb.pressed = down
			mb.factor = 1.0
			mb.position = at
			mb.global_position = at
			vp.push_input(mb)
		await _wait(gap_s)


func _find_button(root: Node, text: String) -> Button:
	if root == null:
		return null
	if root is Button and (root as Button).text == text and (root as Button).is_visible_in_tree() and not (root as Button).disabled:
		return root
	for c in root.get_children():
		var b := _find_button(c, text)
		if b != null:
			return b
	return null


func _tab(which: String) -> Button:
	var h := Router.hud
	match which:
		"LOCAL":
			return h._tab_sector
		"SECTOR":
			return h._tab_system
		"STARCHART":
			return h._tab_chart
	return null


## One hop by a HUD tab, named for the film: `<from>_<to>_<route>`.
func _hop_tab(which: String, label: String, settle_s: float = 2.0) -> void:
	_hop_n += 1
	_mark("hop", {n = _hop_n, label = label, route = "tab", from = _scr(Router.current)})
	await _click(_tab(which), "tab " + which)
	await _settle(settle_s)


func _hop_key(label: String, settle_s: float = 2.0) -> void:
	_hop_n += 1
	_mark("hop", {n = _hop_n, label = label, route = "key", from = _scr(Router.current)})
	await _key(KEY_TAB, "Tab")
	await _settle(settle_s)


# ------------------------------------------------------------------ setup

func _overlay() -> void:
	var vp := GameShell.input_target(get_tree())
	var layer := CanvasLayer.new()
	layer.layer = 127
	vp.add_child(layer)
	_cursor = Ptr.new()
	_cursor.size = Vector2(960, 540)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_cursor)


## No ladder for a set-up step (a teleport the film does not show).
func _quietly(call: Callable) -> void:
	ZoomLadder.hold_off = true
	call.call()
	ZoomLadder.hold_off = false


## Your ship parked in orbit of the first world of system `sys`.
func _park(sys: int) -> int:
	var lay := SystemLayout.of(Run.map[sys])
	for b in lay.bodies:
		if b.world != &"" and b.kind != &"belt":
			SystemMapScreen._parked[sys] = {"at": b.index, "mode": &"rail"}
			return b.index
	return -1


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	_dir = _arg("out", "user://navfilm")
	DirAccess.make_dir_recursive_absolute(_dir)
	_log = FileAccess.open(_dir + "/frames.jsonl", FileAccess.WRITE)
	Router.animate_in_harness = true
	Audio.taping = true
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", HullData.Weight.MEDIUM)
	StarchartScreen._primed_for = Run.galaxy_seed
	_overlay()
	# (`at=nebula`: the run moved to the first system that sits in a cloud, so a
	# reel films the map's and LOCAL's gas)
	if _arg("at", "") == "nebula":
		for n: MapGen.MapNode in Run.map:
			if n.in_nebula and n.type == MapGen.NodeType.SYSTEM:
				Run.at = n.index
				break
	Sig.screen_changed.connect(func() -> void: _mark("screen", {screen = _scr(Router.current)}))
	var sys := Run.at
	_park(sys)
	SectorScreen._approached_at = sys
	Run.map[sys].visited = true
	_quietly(Router.show_local)
	await _wait(3.0)
	_mark("start", {seed = Rng.forced, sys = sys})
	match _arg("reel", "ladder"):
		"ladder":
			await _reel_ladder()
		"short":
			await _reel_short()
		"drift":
			await _reel_drift()
		"journey":
			await _reel_journey()
		"dock":
			await _reel_dock()
		"session":
			await _reel_session()
		"probe":
			await _wait(2.0)
	_mark("end")
	await _wait(0.5)
	_finish()


func _finish() -> void:
	_live = false
	var fa := FileAccess.open(_dir + "/marks.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(_marks, "  "))
	fa.close()
	if _log != null:
		_log.close()
	print("navfilm: %d marks" % _marks.size())
	get_tree().quit()


# ------------------------------------------------------------------ reels

## Every hop between the three distances by tab, then by Tab, then the wheel at
## the end of each zoom, then moves interrupted and doubled.
func _reel_ladder() -> void:
	# BY TAB, each way
	await _hop_tab("SECTOR", "L_M_tab")
	await _hop_tab("STARCHART", "M_C_tab")
	await _hop_tab("SECTOR", "C_M_tab")
	await _hop_tab("LOCAL", "M_L_tab")
	await _hop_tab("STARCHART", "L_C_tab")
	await _hop_tab("LOCAL", "C_L_tab")
	# BY TAB KEY, round the ring (it only goes one way)
	await _glide(Vector2(470, 300), 0.4)
	await _hop_key("L_M_key")
	await _hop_key("M_C_key")
	await _hop_key("C_L_key")
	# THE WHEEL on each, past the end of its zoom
	_mark("wheel_local")
	await _wheel(Vector2(470, 280), false, 8, "LOCAL wheel out")
	await _wait(1.2)
	await _wheel(Vector2(470, 280), true, 8, "LOCAL wheel in")
	await _wait(1.5)
	await _hop_tab("SECTOR", "L_M_tab_b")
	_mark("wheel_map_out")
	await _wheel(Vector2(380, 280), false, 14, "map wheel out to the end")
	await _wait(2.0)
	# (zoomed out to the end: the chart from here)
	await _hop_tab("STARCHART", "M_C_tab_zoomedout")
	_mark("wheel_chart")
	await _wheel(Vector2(380, 280), true, 12, "chart wheel in to the end")
	await _wait(2.0)
	await _wheel(Vector2(380, 280), false, 12, "chart wheel out to the end")
	await _wait(2.0)
	await _hop_tab("SECTOR", "C_M_tab_b")
	_mark("wheel_map_in")
	await _wheel(Vector2(380, 280), true, 16, "map wheel in to the end")
	await _wait(2.0)
	# (zoomed in to the end: LOCAL from here)
	await _hop_tab("LOCAL", "M_L_tab_zoomedin")
	# INTERRUPTED: Tab twice quickly (LOCAL -> map, cut short, -> chart)
	_hop_n += 1
	_mark("hop", {n = _hop_n, label = "L_M_C_doubletab", route = "key2", from = _scr(Router.current)})
	await _key(KEY_TAB, "Tab")
	await _wait(0.45)
	await _key(KEY_TAB, "Tab again")
	await _settle(2.0)
	# CHANGED MIND: SECTOR clicked, then LOCAL half a second later
	_hop_n += 1
	_mark("hop", {n = _hop_n, label = "C_M_L_changemind", route = "tab2", from = _scr(Router.current)})
	await _click(_tab("SECTOR"), "tab SECTOR", 0.35)
	await _wait(0.3)
	await _click(_tab("LOCAL"), "tab LOCAL", 0.25)
	await _settle(2.0)


## The ladder reel's tab and Tab hops and the double Tab only: for another
## flow (`flow=legacy`) or design (`flow2=A`) beside today's.
func _reel_short() -> void:
	await _hop_tab("SECTOR", "L_M_tab")
	await _hop_tab("STARCHART", "M_C_tab")
	await _hop_tab("SECTOR", "C_M_tab")
	await _hop_tab("LOCAL", "M_L_tab")
	await _hop_tab("STARCHART", "L_C_tab")
	await _hop_tab("LOCAL", "C_L_tab")
	await _glide(Vector2(470, 300), 0.4)
	await _hop_key("L_M_key")
	await _hop_key("M_C_key")
	await _hop_key("C_L_key")
	_hop_n += 1
	_mark("hop", {n = _hop_n, label = "L_M_C_doubletab", route = "key2", from = _scr(Router.current)})
	await _key(KEY_TAB, "Tab")
	await _wait(0.45)
	await _key(KEY_TAB, "Tab again")
	await _settle(2.0)


## THE FIELD'S DRIFT (Jon: "Why is the parallax gone from the sector and
## starchart views?"): on the chart a slow drag one way and back and the wheel
## in and out, then the same on the map, then LOCAL -- each drag a mark of its
## own (`drag_chart`, `drag_map`) to cut clips at.
func _reel_drift() -> void:
	await _hop_tab("STARCHART", "L_C_tab")
	await _drag(Vector2(420, 300), Vector2(250, 340), 1.6, "drag_chart")
	await _drag(Vector2(250, 340), Vector2(430, 260), 1.6, "drag_chart_back")
	await _wheel(Vector2(400, 300), true, 4, "chart wheel in", 0.12)
	await _wait(0.6)
	await _wheel(Vector2(400, 300), false, 4, "chart wheel out", 0.12)
	await _settle(1.0)
	await _hop_tab("SECTOR", "C_M_tab")
	await _drag(Vector2(380, 300), Vector2(220, 260), 1.6, "drag_map")
	await _drag(Vector2(220, 260), Vector2(400, 330), 1.6, "drag_map_back")
	await _wheel(Vector2(380, 300), true, 4, "map wheel in", 0.12)
	await _wait(0.6)
	await _wheel(Vector2(380, 300), false, 4, "map wheel out", 0.12)
	await _settle(1.0)
	await _hop_tab("LOCAL", "M_L_tab")
	await _settle(1.0)


## A drag, as a hand makes one: down at `from`, an eased slide to `to` over `s`,
## up, a breath after.
func _drag(from: Vector2, to: Vector2, s: float, name: String) -> void:
	await _glide(from.round(), 0.35)
	await _wait(0.1)
	_push(from.round(), true, true)
	await get_tree().process_frame
	_mark(name, {from = _v(from), to = _v(to), s = s})
	await _glide(to.round(), s)
	_push(to.round(), false, true)
	_mark(name + "_end")
	await _wait(0.5)


## A flight across the system (LOCAL mid-flight, and on arrival), GO on an
## event, a jump from the chart (departure, arrival at the edge, LOCAL there),
## and a fight entered and left.
func _reel_journey() -> void:
	await _rich_system()
	await _hop_tab("SECTOR", "L_M_tab")
	await _journey_rest()


## (a system with two worlds or more and an event that is not a fight, near
## where the run starts: moved there quietly, parked at its first world)
func _rich_system() -> void:
	var here0 := Run.node_at()
	var best := INF
	var pick0 := -1
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type != MapGen.NodeType.SYSTEM:
			continue
		var worlds := 0
		for b in SystemLayout.of(n).bodies:
			if b.world != &"" and b.kind != &"belt":
				worlds += 1
		OptionTable.ensure(n)
		var calm := false
		for oid in n.options:
			if EncounterDrawer.lead_tag(OptionTable.by_id(oid)) != &"fight":
				calm = true
		var dd: float = (n.gal - here0.gal).length()
		if worlds >= 2 and calm and dd < best:
			best = dd
			pick0 = n.index
	if pick0 >= 0 and pick0 != Run.at:
		Run.at = pick0
		Run.map[pick0].visited = true
		SectorScreen._approached_at = pick0
		_park(pick0)
		_quietly(Router.show_local)
		await _wait(3.0)
	_mark("system_at", {sys = Run.at})


func _journey_rest() -> void:
	var mp := Router.current as SystemMapScreen
	# FLY TO ANOTHER WORLD: click it, FLY HERE
	var here := mp._ladder_body()
	var to := -1
	for b in mp.view.layout.bodies:
		if b.index != here and b.world != &"" and b.kind != &"belt":
			to = b.index
			break
	if to >= 0:
		var at: Vector2 = mp._ladder_origin() + mp.overlay.place_rel(to)
		await _click_at(at, "a world on the map")
		await _wait(1.2)
		var fly := _find_button(mp, "FLY HERE")
		if fly != null:
			await _click(fly, "FLY HERE")
		else:
			_mark("fly_fallback")
			mp.fly_to_body(to)
		_mark("flying")
		await _wait(1.6)
		# LOCAL mid-flight, and back
		await _hop_tab("LOCAL", "M_L_tab_midflight", 1.5)
		await _hop_tab("SECTOR", "L_M_tab_midflight", 0.5)
		mp = Router.current as SystemMapScreen
		# (the rest of the flight at 8x: cut from the films)
		await _wait(1.0)
		_mark("warp_on")
		Engine.time_scale = 8.0
		await _until(func() -> bool: return mp == null or not is_instance_valid(mp) or mp.flight.mode == &"rail", 300.0)
		Engine.time_scale = 1.0
		_mark("warp_off")
		_mark("arrived_world")
		await _wait(1.5)
		await _hop_tab("LOCAL", "M_L_tab_arrived")
		await _hop_tab("SECTOR", "L_M_tab_2")
	# GO ON AN EVENT: the flight and the zoom down by itself
	mp = Router.current as SystemMapScreen
	if mp != null:
		var go := await _open_event(mp, false)
		if go != null:
			_hop_n += 1
			_mark("hop", {n = _hop_n, label = "M_L_go", route = "go", from = "M"})
			await _click(go, "GO")
			await _until(func() -> bool:
				var s := Router.current as SectorScreen
				return s != null and _settled(), 40.0)
			_mark("settled")
			await _wait(3.0)
			# put the event away: the first choice that is not a fight
			var sc := Router.current as SectorScreen
			if sc != null and sc._events != null and is_instance_valid(sc._events):
				await _until(func() -> bool: return sc._events.text == null or sc._events.text.done, 10.0)
				await _wait(1.0)
				await _leave_event(sc)
	# A JUMP: the chart, a star with a fight, JUMP
	await _hop_tab("STARCHART", "L_C_tab")
	var chart := Router.current as StarchartScreen
	var pick := _pick_star(true)
	if chart != null and pick != null:
		var mc: Control = chart._chart
		var at2: Vector2 = mc.get_global_transform() * mc._screen_pos(pick)
		await _click_at(at2, "a star")
		await _wait(0.4)
		if chart._selected != pick.index:
			chart._on_node_picked(pick.index)
			_mark("pick_fallback")
		await _wait(1.8)
		_hop_n += 1
		_mark("hop", {n = _hop_n, label = "C_jump", route = "jump", from = "C"})
		await _click(chart._jump, "JUMP")
		var j0 := Run.jumps
		await _until(func() -> bool:
			return Run.jumps > j0 and (_in_fight() or Router.current is SystemMapScreen) and _settled(), 60.0)
		_mark("arrived_system", {screen = _scr(Router.current), fighting = _in_fight()})
		await _wait(2.5)
		if Router.current is SystemMapScreen:
			# LOCAL at the edge, just arrived, and back
			await _hop_tab("LOCAL", "M_L_tab_edge")
			await _hop_tab("SECTOR", "L_M_tab_edge")
	# A FIGHT: GO on a fight, the fight, its end
	if not _in_fight():
		mp = Router.current as SystemMapScreen
		if mp == null:
			await _hop_tab("SECTOR", "L_M_tab_3")
			mp = Router.current as SystemMapScreen
		if mp != null:
			var go2 := await _open_event(mp, true)
			if go2 != null:
				_hop_n += 1
				_mark("hop", {n = _hop_n, label = "M_L_go_fight", route = "go", from = "M"})
				await _click(go2, "GO (fight)")
				await _until(func() -> bool:
					var s := Router.current as SectorScreen
					return s != null and s._events != null and is_instance_valid(s._events) and s._events.page == &"event" \
						and s._events.text != null and s._events.text.done, 40.0)
				await _wait(2.0)
				await _choose_fight(Router.current as SectorScreen)
	if _in_fight():
		await _fight()
	else:
		_mark("no_fight")


func _in_fight() -> bool:
	var s := Router.current as SectorScreen
	return s != null and s.fighting()


## The map's list: the first open event (a fight if `fight`), its page, its GO.
func _open_event(map: SystemMapScreen, fight: bool) -> Button:
	var pick_card: Control = null
	for c in map.find_children("*", "", true, false):
		if c is PanelContainer and c.has_method("set_doomed") and not c.get("doomed") and not c.get("finished") \
				and (c.get("press") as Callable).is_valid() and (c as Control).is_visible_in_tree():
			var is_fight: bool = c.get("stripe_col") == UITheme.LEAVE
			if fight and not is_fight:
				continue
			if not fight and is_fight:
				if pick_card == null:
					pick_card = c
				continue
			pick_card = c
			break
	if pick_card == null:
		_mark("no_event", {fight = fight})
		return null
	await _click(pick_card, "event card")
	await _until(func() -> bool: return _first_go(map) != null, 5.0)
	await _wait(2.0)
	return _first_go(map)


func _first_go(map: SystemMapScreen) -> Button:
	for c in map.find_children("Go", "Button", true, false):
		var b := c as Button
		if b != null and b.is_visible_in_tree() and not b.disabled:
			return b
	return null


func _leave_event(sc: SectorScreen) -> void:
	var d := sc._events
	var o := OptionTable.by_id(d.node.options[d.opt])
	var choices: Array = o.get("choices", [])
	var j := 0
	for k in choices.size():
		if not bool((choices[k] as Dictionary).get("fight", false)) and OptionResolve.affordable(choices[k]):
			j = k
			break
	var card := d.find_child("Choice%d" % j, true, false) as Control
	if card != null:
		await _click(card, "choice %d" % j)
	await _wait(0.5)
	if is_instance_valid(d) and d.page == &"event":
		d.choose(j)
	await _until(func() -> bool: return not is_instance_valid(d) or d.page == &"result" or _in_fight(), 10.0)
	if is_instance_valid(d) and d.page == &"result":
		await _until(func() -> bool: return d.text == null or d.text.done, 20.0)
		await _wait(2.0)
		var fire := d.find_child("TheyAreFiring", true, false) as Button
		if fire != null:
			await _click(fire, "THEY ARE FIRING")
			return
		var cont := d.find_child("Continue", true, false) as Button
		if cont != null:
			await _click(cont, "CONTINUE")
	await _settle(1.0)


func _choose_fight(sc: SectorScreen) -> void:
	if sc == null or sc._events == null:
		return
	var d := sc._events
	var o := OptionTable.by_id(d.node.options[d.opt])
	var choices: Array = o.get("choices", [])
	var j := 0
	for k in choices.size():
		if bool((choices[k] as Dictionary).get("fight", false)) and OptionResolve.affordable(choices[k]):
			j = k
			break
	var card := d.find_child("Choice%d" % j, true, false) as Control
	await _click(card, "choice %d (fight)" % j)
	await _wait(0.5)
	if is_instance_valid(d) and d.page == &"event":
		d.choose(j)
	await _until(func() -> bool: return not is_instance_valid(d) or d.page == &"result" or _in_fight(), 10.0)
	if is_instance_valid(d) and d.page == &"result":
		await _until(func() -> bool: return d.text == null or d.text.done, 20.0)
		await _wait(2.5)
		var fire := d.find_child("TheyAreFiring", true, false) as Button
		if fire != null:
			_mark("fight_enter")
			await _click(fire, "THEY ARE FIRING")
			await _until(func() -> bool: return _in_fight(), 15.0)


func _pick_star(want_fight: bool) -> MapGen.MapNode:
	var pick: MapGen.MapNode = null
	var best := INF
	var here := Run.node_at()
	for raw in Run.in_range():
		var n: MapGen.MapNode = raw
		if n == here or not Run.can_jump_to(n) or n.type != MapGen.NodeType.SYSTEM:
			continue
		var dd: float = (n.gal - here.gal).length()
		OptionTable.ensure(n)
		var has_fight := false
		for oid in n.options:
			if EncounterDrawer.lead_tag(OptionTable.by_id(oid)) == &"fight":
				has_fight = true
		if want_fight and not has_fight:
			dd += 1000.0
		if dd < best:
			best = dd
			pick = n
	return pick


func _fight() -> void:
	var sc := Router.current as SectorScreen
	var cb: Combat = Router.combat
	_mark("fight_start")
	# the opening plays; then the bar and the hand
	await _until(func() -> bool: return cb.finished or (not sc._hold and not sc._opening and sc._end_button != null \
		and sc._end_button.is_visible_in_tree() and not sc._end_button.disabled), 30.0)
	_mark("hand_up")
	await _wait(2.0)
	# TAB IN A FIGHT, and the locked SECTOR tab clicked
	_hop_n += 1
	_mark("hop", {n = _hop_n, label = "fight_tab_key", route = "key", from = "L"})
	await _key(KEY_TAB, "Tab in a fight")
	await _wait(2.5)
	_hop_n += 1
	_mark("hop", {n = _hop_n, label = "fight_sector_tab", route = "tab", from = "L"})
	await _click(_tab("SECTOR"), "tab SECTOR (locked)")
	await _wait(2.0)
	sc = Router.current as SectorScreen
	# (shortened: every foe one hit from dead, so the film reaches the end)
	for e in cb.enemies:
		(e as Combat.EnemyState).hp = mini((e as Combat.EnemyState).hp, 1)
	var pol := Policy.new()
	var turns := 0
	while not cb.finished and turns < 6:
		await _until(func() -> bool: return cb.finished or (not sc._hold and not sc._opening and sc._end_button != null \
			and sc._end_button.is_visible_in_tree() and not sc._end_button.disabled), 30.0)
		if cb.finished:
			break
		var pick := pol.best_card(cb)
		if pick < 0:
			await _click(sc._end_button, "END TURN")
			turns += 1
			await _wait(1.5)
			continue
		await _play(sc, cb, pick)
		await _wait(0.8)
	_mark("fight_done", {result = String(cb.result)})
	await _until(func() -> bool: return Router.combat == null and Router.current is SectorScreen, 30.0)
	sc = Router.current as SectorScreen
	await _wait(2.0)
	var cont := _find_button(sc, "CONTINUE")
	if cont != null:
		await _wait(2.0)
		_hop_n += 1
		_mark("hop", {n = _hop_n, label = "fight_leave_continue", route = "click", from = "L"})
		await _click(cont, "CONTINUE (victory)")
	await _wait(2.5)
	await _hop_tab("SECTOR", "L_M_tab_afterfight")


func _view_of(sc: SectorScreen, card: CardData) -> CardView:
	for v in sc._hand._views:
		if v != null and is_instance_valid(v) and v.card == card:
			return v
	return null


func _play(sc: SectorScreen, cb: Combat, pick: int) -> void:
	var card: CardData = cb.hand[pick]
	var v := _view_of(sc, card)
	if v == null:
		cb.play(pick, 0)
		return
	var aim_enemy := card.damage > 0 or card.damage_equals_heat or card.evoke > 0
	var target := Vector2.ZERO
	if aim_enemy:
		var tgt := 0
		for i in cb.enemies.size():
			if (cb.enemies[i] as Combat.EnemyState).hp > 0:
				tgt = i
				break
		target = sc._view.slot(tgt).holder_rect().get_center()
	else:
		target = sc._view.ship_view().get_global_rect().get_center()
	var r := v.get_global_rect()
	var on := Vector2(r.get_center().x, r.position.y + r.size.y * 0.55).round()
	await _glide(on, 0.4)
	v.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _wait(0.4)
	if not is_instance_valid(v):
		return
	r = v.get_global_rect()
	on = Vector2(r.get_center().x, r.position.y + r.size.y * 0.55).round()
	_push(on, true, true)
	await _wait(0.1)
	await _glide(Vector2(on.x, sc._hand.get_global_rect().position.y - 30.0), 0.25)
	await _glide(target.round(), 0.4)
	await _wait(0.4)
	_push(_ptr, false, true)
	await _wait(0.1)
	await _glide(Vector2(_ptr.x, 470), 0.3)


## A station: DOCK on LOCAL, the yard, UNDOCK; docked, Tab round the ring; the
## map's DOCK (two distances in one).
func _reel_dock() -> void:
	var st := -1
	var best := INF
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.STATION:
			var dd: float = (n.gal - Run.node_at().gal).length()
			if dd < best:
				best = dd
				st = n.index
	if st < 0:
		_mark("no_station")
		return
	Run.at = st
	Run.map[st].visited = true
	SectorScreen._approached_at = st
	_quietly(Router.show_local)
	await _wait(3.0)
	_mark("at_station")
	var sc := Router.current as SectorScreen
	_hop_n += 1
	_mark("hop", {n = _hop_n, label = "L_S_dock", route = "click", from = "L"})
	await _click(_find_button(sc, "DOCK"), "DOCK")
	await _settle(3.0, 40.0)
	_hop_n += 1
	_mark("hop", {n = _hop_n, label = "S_L_undock", route = "click", from = "S"})
	await _click(_find_button(Router.current, "UNDOCK"), "UNDOCK")
	await _settle(2.5, 40.0)
	await _hop_tab("SECTOR", "L_M_tab_station")
	await _hop_tab("STARCHART", "M_C_tab_station")
	await _hop_tab("LOCAL", "C_L_tab_station")
	# docked again, quietly, then Tab round from the berth
	_quietly(Router.show_station)
	await _wait(3.0)
	await _glide(Vector2(470, 300), 0.3)
	await _hop_key("S_M_key")
	await _hop_key("M_C_key_docked")
	await _hop_key("C_S_key")
	# the map's DOCK: undock quietly, the map, its DOCK
	_quietly(Router.show_sector)
	await _wait(2.0)
	await _hop_tab("SECTOR", "L_M_tab_station2")
	var mp := Router.current as SystemMapScreen
	if mp != null:
		var dk := _find_button(mp, "DOCK")
		if dk == null:
			# the station's place picked first, its page has DOCK
			for b in mp.view.layout.bodies:
				for bc in b.beacons:
					if bc.dock:
						mp.select_body(b.index)
			await _wait(1.5)
			dk = _find_button(mp, "DOCK")
		if dk != null:
			_hop_n += 1
			_mark("hop", {n = _hop_n, label = "M_S_dock", route = "click", from = "M"})
			await _click(dk, "DOCK (map)")
			# (a flight to the station first, if any, at 8x: cut from the films)
			await _wait(1.0)
			if not ZoomLadder.busy() and Router.current is SystemMapScreen:
				_mark("warp_on")
				Engine.time_scale = 8.0
				await _until(func() -> bool: return ZoomLadder.busy() or not Router.current is SystemMapScreen, 300.0)
				Engine.time_scale = 1.0
				_mark("warp_off")
			await _until(func() -> bool: return Router.current is StationScreen and _settled(), 60.0)
			await _settle(3.0, 40.0)
		else:
			_mark("no_map_dock")


## A minute and a half as a player plays it: looking, hopping, flying.
func _reel_session() -> void:
	await _rich_system()
	_mark("session_start")
	var sc0 := Router.current as SectorScreen
	if sc0 != null:
		await _glide(Vector2(sc0._ladder_ship()).round(), 0.9)
	await _wait(2.5)
	await _glide(Vector2(600, 200), 0.7)
	await _wait(1.0)
	await _click(_tab("SECTOR"), "tab SECTOR")
	await _wait(3.0)
	var mp := Router.current as SystemMapScreen
	if mp != null:
		var here := mp._ladder_body()
		var bodies: Array = []
		for b in mp.view.layout.bodies:
			if b.world != &"" and b.kind != &"belt" and b.index != here:
				bodies.append(b.index)
		if not bodies.is_empty():
			# point at a couple of worlds
			for i in mini(2, bodies.size()):
				await _glide((mp._ladder_origin() + mp.overlay.place_rel(bodies[i])).round(), 0.6)
				await _wait(0.9)
		await _wheel(Vector2(400, 260), false, 3, "a look round", 0.12)
		await _wait(1.5)
	await _click(_tab("STARCHART"), "tab STARCHART")
	await _wait(2.0)
	var ch := Router.current as StarchartScreen
	if ch != null:
		var p := _pick_star(false)
		if p != null:
			var mc: Control = ch._chart
			await _glide((mc.get_global_transform() * mc._screen_pos(p)).round(), 0.7)
			await _wait(1.2)
	await _key(KEY_TAB, "Tab (to LOCAL)")
	await _wait(2.5)
	await _key(KEY_TAB, "Tab (to the map)")
	await _wait(2.0)
	mp = Router.current as SystemMapScreen
	if mp != null:
		var here2 := mp._ladder_body()
		var to := -1
		for b in mp.view.layout.bodies:
			if b.world != &"" and b.kind != &"belt" and b.index != here2:
				to = b.index
		if to >= 0:
			await _click_at(mp._ladder_origin() + mp.overlay.place_rel(to), "a world")
			await _wait(1.0)
			var fly := _find_button(mp, "FLY HERE")
			if fly != null:
				await _click(fly, "FLY HERE")
			else:
				mp.fly_to_body(to)
			await _wait(2.0)
	# LOCAL mid-flight, a look, back to the map
	await _click(_tab("LOCAL"), "tab LOCAL")
	await _wait(3.5)
	await _key(KEY_TAB, "Tab (to the map)")
	await _wait(3.0)
	await _wheel(Vector2(400, 260), true, 3, "a closer look", 0.12)
	await _wait(2.0)
	await _click(_tab("STARCHART"), "tab STARCHART")
	await _wait(3.0)
	await _click(_tab("SECTOR"), "tab SECTOR")
	await _wait(2.5)
	# quickly through: the chart, then LOCAL
	await _key(KEY_TAB, "Tab (to the chart)")
	await _wait(1.6)
	await _key(KEY_TAB, "Tab (to LOCAL)")
	await _wait(3.0)
	await _click(_tab("STARCHART"), "tab STARCHART")
	await _wait(2.5)
	await _click(_tab("LOCAL"), "tab LOCAL")
	await _wait(2.5)
	await _click(_tab("SECTOR"), "tab SECTOR")
	await _wait(2.5)
	await _click(_tab("LOCAL"), "tab LOCAL")
	await _wait(3.0)
	await _key(KEY_TAB, "Tab (to the map)")
	await _wait(3.0)
	await _click(_tab("LOCAL"), "tab LOCAL")
	await _wait(3.0)
	_mark("session_end")
