extends Node

## UNDOCK IS THE ONLY WAY OUT OF A STATION (Jon, Oct 27, on Jeremy's "LOCAL
## lets you leave a station too easily"):
##   godot --headless --fixed-fps 60 --path . -- sheet=DockFlyTest
## Headless, the ladder on and its clock stepped 1/30 s (`LadderTest`'s rig).
## Docked in the berth (`route=berth`): the HUD's first tab reads LOCAL, greyed,
## and says "Docked. Press UNDOCK to leave."; pressed anyway it goes nowhere.
## Tab goes round the berth, the map and the chart and never lands on LOCAL; the
## map and the chart are views: FLY HERE and GO read DOCKED with the same words,
## and FLY HERE, WASD, GO and the chart's JUMP are refused; the HUD's STATION,
## the map's DOCK and PARTY's LEAVE (co-op) go straight back in, docked
## throughout and never by LOCAL. UNDOCK still leaves.
## Then every route that used to leave without UNDOCK -- the map to another
## world, the star, a belt or open space, then the HUD's tab or Tab round the
## chart; the chart's JUMP; a jump on and GO -- is tried from the berth and
## refused, back in the berth and never on LOCAL, and made again after UNDOCK:
## LOCAL arrived on with nothing of the station left (`Router.docked`, its
## powered decks, no StationScreen in the tree, the ladder idle with nothing
## built ahead and no chain), the sky composed for where the ship is. The rule:
## `Router.cast_off` refuses every move from the berth.
##
## `shots=<dir>` (windowed) writes a still of each LOCAL arrived on.
## `route=<name>` runs one route (with `--write-movie` and `--fixed-fps 30`: a
## film of it at true speed; `proper` films its UNDOCK-first half alone).

var _fails := 0
var _tree: SceneTree
var _st := -1
var _shots := ""
var _only := ""
var _proper_only := false
## where each route leaves the ship (`Run.site_here`)
var _want := {}
## JON'S WORDS (Oct 27), held here rather than read off `Router.DOCKED_LINE`, so
## the sheet says what the ruling says and runs on a build from before it
const DOCKED_LINE := "Docked. Press UNDOCK to leave."
## WHAT WAS SEEN WHILE WATCHING, frame by frame (`_watch_on`): the ship off the
## berth ("undocked") or LOCAL up, either of which is the station left
var _watching := false
var _seen: Array[String] = []


func _process(_d: float) -> void:
	if not _watching:
		return
	if not Router.docked and not _seen.has("undocked"):
		_seen.append("undocked")
	if Router.current is SectorScreen and not _seen.has("LOCAL"):
		_seen.append("LOCAL")


func _watch_on() -> void:
	_seen = []
	_watching = true


## What was seen since `_watch_on`: empty when the ship never left the berth.
func _watch_off() -> Array[String]:
	_watching = false
	return _seen.duplicate()


func _name_of(c: Control) -> String:
	if c == null or not is_instance_valid(c):
		return "null"
	return c.get_script().get_global_name() if c.get_script() != null else c.get_class()


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("shots="):
			_shots = s.substr(6)
		elif s.begins_with("route="):
			_only = s.substr(6)
		elif s == "proper":
			_proper_only = true
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


func _shot(name: String) -> void:
	if _shots == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_shots)
	im.save_png(_shots.path_join(name + ".png"))
	print("  shot %s" % name)


## A real key, through Main's own Tab.
func _tab() -> void:
	var k := InputEventKey.new()
	k.keycode = KEY_TAB
	k.physical_keycode = KEY_TAB
	k.pressed = true
	Input.parse_input_event(k)
	await _frames(1)
	var u := InputEventKey.new()
	u.keycode = KEY_TAB
	u.physical_keycode = KEY_TAB
	u.pressed = false
	Input.parse_input_event(u)
	await _frames(1)
	await _idle()


## The HUD's second tab (STATION while docked, LOCAL flying), pressed.
func _here_tab() -> void:
	Router.hud._tab_sector.pressed.emit()
	await _frames(1)
	await _idle()
	# (LOCAL's own arrival at a place flown to, watched out as a player would:
	# a key mid-way parks it, and is spent doing so, `SectorScreen._flyin`)
	for i in 900:
		await _tree.process_frame
		var sc := Router.current as SectorScreen
		if sc == null or (not sc._flyin and not sc._flyin_wait):
			break


func _count(cls: Script) -> int:
	var n := 0
	var stack: Array[Node] = [_tree.root]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		if x.get_script() == cls and not x.is_queued_for_deletion():
			n += 1
		stack.append_array(x.get_children())
	return n


func _station_body() -> int:
	for b in SystemLayout.of(Run.map[_st]).bodies:
		if b.kind == &"station":
			return b.index
	return -9


## The places to fly to in the station's system: a world, a belt, the star.
func _places() -> Dictionary:
	var out := {"world": -9, "belt": -9, "star": -1}
	var sb := _station_body()
	for b in SystemLayout.of(Run.map[_st]).bodies:
		if b.index == sb:
			continue
		if b.kind == &"belt" and int(out.belt) < -1:
			out.belt = b.index
		elif b.world != &"" and b.kind != &"belt" and int(out.world) < -1:
			out.world = b.index
	return out


## Back in the berth at the station, the ship parked at the station's own body,
## LOCAL beside it first and DOCK pressed, as a player docks.
func _to_berth() -> bool:
	if Router.current is StationScreen and Router.docked:
		Router.show_sector()
		await _idle()
	Run.at = _st
	Run.map[_st].visited = true
	SystemMapScreen._parked[_st] = {"at": _station_body(), "mode": &"rail"}
	SectorScreen._approached_at = _st
	if not (Router.current is SectorScreen):
		Router.show_local()
		await _idle()
	await _frames(4)
	Router.show_station()
	await _idle()
	await _frames(10)
	return Router.current is StationScreen and Router.docked


## Fly the map's ship to place `p` (-1 the star, -3 open space: thrust out of
## the orbit and coast), and wait for it to get there.
func _fly(p: int) -> bool:
	var m := Router.current as SystemMapScreen
	if m == null:
		return false
	for i in 300:
		if m.flight != null and m.flight.can_fly():
			break
		await _tree.process_frame
	if p == -3:
		m.harness_keys = true
		m._wasd.w = true
		await _frames(45)
		m._wasd.w = false
		await _frames(90)
		m.harness_keys = false
		return m.flight.reached() == -9
	m.fly_to_body(p)
	for i in 3600:
		await _tree.process_frame
		if not is_instance_valid(m):
			return false
		if m.flight.reached() == p and m.flight.can_fly():
			await _frames(10)
			return true
	return false


## LOCAL as it stands, everything the trip could have left behind.
func _local() -> Dictionary:
	# (the hull's bob held at one moment, so both trips are measured on it)
	ShipView.shot_clock = 0.0
	await _frames(3)
	var d := _local_now()
	ShipView.shot_clock = -1.0
	return d


func _local_now() -> Dictionary:
	var d := {"screen": Router.current.get_class() if Router.current != null else "null"}
	if Router.current != null and Router.current.get_script() != null:
		d.screen = Router.current.get_script().get_global_name()
	d.docked = Router.docked
	d.powered = Router.powered.size()
	d.dock = Router.dock != null and is_instance_valid(Router.dock)
	d.stations = _count(StationScreen)
	d.ladder = ZoomLadder.busy() or _count(ZoomLadder) > 0
	d.prebuilt = ZoomLadder.prebuilt != null and is_instance_valid(ZoomLadder.prebuilt)
	d.chain = String(ZoomLadder.chain)
	d.site = Run.site_here()
	d.at = Run.at
	var l := Router.current as SectorScreen
	if l == null:
		return d
	d.zs = l._lad_zs
	d.lad = l._lad.size()
	var sky: LocalSky = l._view.backdrop
	d.sky_zoom = sky.zoom if sky != null else -1.0
	d.sky_place = sky.orbit_target if sky != null else -99
	d.sky_node = sky.node.index if sky != null and sky.node != null else -1
	d.face = l._face != null and is_instance_valid(l._face)
	d.face_power = l._face.power if d.face else 0.0
	d.row = l._view._row.get_child_count() if l._view._row != null else 0
	var sub := LocalSubject.of(l._view)
	d.subject = sub != null and is_instance_valid(sub) and sub.visible
	var art := l._view.ship_view()
	if art != null:
		var ink := Rect2(art.ink_rect())
		var xf := art.get_global_transform()
		var a := xf * art.canvas_to_local(ink.position)
		var b := xf * art.canvas_to_local(ink.end)
		d.ship = Rect2(a, b - a).abs()
		d.ship_vis = art.is_visible_in_tree()
		d.ship_scale = art.scale
	d.events = l._events != null and is_instance_valid(l._events) and l._events.page != &""
	d.hud = Router.hud._tab_sector.text if Router.hud != null else ""
	return d


## Nothing of the station left on the LOCAL arrived on.
func _clean(what: String, d: Dictionary) -> void:
	_ok("%s: lands on LOCAL (on %s)" % [what, d.screen], d.screen == "SectorScreen")
	_ok("%s: undocked, no deck powered, no dock open (docked %s, powered %d)" % [what, d.docked, d.powered],
		not d.docked and d.powered == 0 and not d.dock)
	_ok("%s: no StationScreen in the tree (%d)" % [what, d.stations], d.stations == 0)
	_ok("%s: the ladder idle, nothing built ahead, no chain" % what, not d.ladder and not d.prebuilt and d.chain == "")
	if d.screen == "SectorScreen":
		_ok("%s: the scene and the sky at their own size (%.2f, %.2f)" % [what, d.zs, d.sky_zoom],
			is_equal_approx(d.zs, 1.0) and d.lad == 0 and is_equal_approx(d.sky_zoom, 1.0))
		_ok("%s: the sky composed for where the ship is (sky %d, ship %d)" % [what, d.sky_place, d.site],
			d.sky_place == (d.site if d.site >= -1 else -9) and d.sky_node == d.at)
		_ok("%s: your hull shown, the tab reads LOCAL (%s)" % [what, d.hud], d.get("ship_vis", false) and d.hud == "LOCAL")
		_ok("%s: the station's lights on standby (%.2f)" % [what, d.face_power], d.face_power <= 0.001)


## One trip, both ways: `go` tried from the berth as it stands (docked), where
## it is refused and ends back in the berth, never on LOCAL; and made again from
## LOCAL after UNDOCK, where it lands with nothing of the station left.
func _route(name: String, go: Callable) -> void:
	if _only != "" and _only != name:
		return
	print("route %s" % name)
	if not _proper_only:
		if not _ok("%s: docked in the berth" % name, await _to_berth()):
			return
		_watch_on()
		await go.call(false)
		await _frames(20)
		var seen := _watch_off()
		_ok("%s: from the berth, refused and back in the berth, docked throughout and never on LOCAL (seen: %s; on %s, at %d)" % [
			name, "nothing" if seen.is_empty() else ", ".join(seen), _name_of(Router.current), Run.at],
			seen.is_empty() and Router.current is StationScreen and Router.docked and Run.at == _st)
	if _only != "" and not _proper_only:
		return
	if not _ok("%s: docked in the berth (for the trip after UNDOCK)" % name, await _to_berth()):
		return
	Router.show_sector()
	await _idle()
	_ok("%s: UNDOCK lands on LOCAL" % name, Router.current is SectorScreen and not Router.docked)
	await _frames(10)
	await go.call(true)
	await _frames(20)
	var b := await _local()
	print("    after UNDOCK: %s" % b)
	await _shot("%s_proper" % name)
	_clean(name, b)
	_ok("%s: the ship where the map left it (site %d)" % [name, b.site], b.site == int(_want.get(name, b.site)))


## Tab to the map (from the berth or LOCAL), fly to `p`, then back by `back`
## ("hud": the HUD's first tab; "tab": Tab round the chart). From the berth the
## flight is refused, and `back` goes back in: STATION, or the chart and on.
func _map_trip(p: int, back: String) -> Callable:
	return func(proper: bool) -> void:
		await _tab()
		var m := Router.current as SystemMapScreen
		if not _ok("  Tab goes to the map", m != null):
			return
		if not proper:
			for i in 300:
				if m.flight != null and m.flight.can_fly():
					break
				await _tree.process_frame
			var at0: int = m.flight.reached()
			if p == -3:
				m.harness_keys = true
				m._wasd.w = true
				await _frames(45)
				m._wasd.w = false
				m.harness_keys = false
			else:
				m.fly_to_body(p)
			await _frames(30)
			_ok("  from the berth the flight to %d is refused: still docked, the ship where it was (at %d, was %d)" % [p, m.flight.reached(), at0],
				Router.docked and Router.current == m and m.flight.reached() == at0)
		else:
			_ok("  flown to %d" % p, await _fly(p))
			_ok("  flying, the tab reads LOCAL (docked %s, tab %s)" % [Router.docked, Router.hud._tab_sector.text],
				not Router.docked and Router.hud._tab_sector.text == "LOCAL")
		if back == "hud":
			await _here_tab()
		else:
			await _tab()
			await _tab()


## The chart's JUMP from the berth (or LOCAL), then GO on an event at the
## system arrived at: LOCAL there, its subject up.
func _jump_trip(go_event: bool) -> Callable:
	return func(proper: bool) -> void:
		await _tab()
		await _tab()
		_ok("  Tab Tab goes to the chart", Router.current is StarchartScreen)
		var to := _jump_target(go_event)
		if not _ok("  a system in reach to jump to (%d)" % to, to >= 0):
			return
		if not proper:
			var ch := Router.current as StarchartScreen
			if ch != null:
				ch._on_node_picked(to)
				await _frames(2)
				_ok("  from the berth JUMP reads DOCKED, greyed, and says \"%s\" (%s, %s)" % [DOCKED_LINE, ch._jump.text, ch._jump.tooltip_text.replace("\n", " ")],
					ch._jump.disabled and ch._jump.text == "DOCKED" and ch._jump.tooltip_text.replace("\n", " ").contains(DOCKED_LINE))
			Router.begin_jump(to)
			await _frames(30)
			_ok("  the jump refused: still at the station, docked, on the chart (at %d, on %s)" % [Run.at, _name_of(Router.current)],
				Run.at == _st and Router.docked and Router.current is StarchartScreen)
			await _tab()
			return
		Router.begin_jump(to)
		for i in 1800:
			await _tree.process_frame
			if Run.at == to and not ZoomLadder.busy() and (Router.current is SystemMapScreen or Router.current is SectorScreen) \
					and Router._post_arrive == false:
				break
		await _idle()
		await _frames(30)
		_ok("  arrived at %d (at %d, on %s)" % [to, Run.at, Router.current.get_script().get_global_name()], Run.at == to)
		if not go_event:
			if Router.current is SystemMapScreen:
				await _here_tab()
			return
		var m := Router.current as SystemMapScreen
		if m == null:
			return
		var k := _an_event(Run.node_at())
		if not _ok("  an event to GO on (%d)" % k, k >= 0):
			return
		for i in 600:
			if m.flight != null and m.flight.can_fly():
				break
			await _tree.process_frame
		m.go_event(k)
		for i in 3600:
			await _tree.process_frame
			if Router.current is SectorScreen and not ZoomLadder.busy():
				break
		await _idle()
		await _frames(60)


## UNDOCK IS THE ONLY WAY OUT (Jon, Oct 27, on Jeremy's "LOCAL lets you leave a
## station too easily"). Docked, every other door is shut and says how to leave,
## or goes back in without leaving: the HUD's first tab, Tab round the screens,
## the map's FLY HERE, WASD and GO, the chart's JUMP, the HUD's STATION and the
## map's DOCK from the map, and PARTY's LEAVE (co-op). Then UNDOCK, which leaves.
func _berth_shut(p: int) -> void:
	if _only != "" and _only != "berth":
		return
	print("route berth")
	if not _ok("berth: docked in the berth", await _to_berth()):
		return
	var tab: Button = Router.hud._tab_sector
	Router.hud.refresh()
	# THE HUD: LOCAL, greyed, and the words for the way out
	_ok("berth: the HUD's first tab reads LOCAL, greyed (%s, disabled %s)" % [tab.text, tab.disabled],
		tab.text == "LOCAL" and tab.disabled)
	_ok("berth: its tooltip says \"%s\" (%s)" % [DOCKED_LINE, tab.tooltip_text.replace("\n", " ")],
		tab.tooltip_text.replace("\n", " ").contains(DOCKED_LINE))
	_ok("berth: greyed, not lit as the page you are on", not tab.has_theme_stylebox_override("disabled"))
	var st := Router.current as StationScreen
	_watch_on()
	# (a press it will not take, sent by hand: the door behind it is shut too)
	tab.pressed.emit()
	await _frames(30)
	await _idle()
	var seen := _watch_off()
	_ok("berth: LOCAL pressed anyway goes nowhere: the station still up, docked, never LOCAL (seen: %s)" % ", ".join(seen),
		seen.is_empty() and Router.current == st and Router.docked)
	# THE KEYBOARD: Tab round the berth, the map and the chart, never LOCAL
	_watch_on()
	await _tab()
	var m := Router.current as SystemMapScreen
	if _ok("berth: Tab goes to the map, still docked", m != null and Router.docked):
		Router.hud.refresh()
		_ok("berth: on the map the tab reads STATION and can be pressed (%s, disabled %s)" % [tab.text, tab.disabled],
			tab.text == "STATION" and not tab.disabled)
		for i in 300:
			if m.flight.can_fly():
				break
			await _tree.process_frame
		var at0: int = m.flight.reached()
		m.select_body(p)
		await _frames(2)
		var fly: Button = null
		for b in m.panel.find_children("*", "Button", true, false):
			if (b as Button).is_visible_in_tree() and (b as Button).text in ["DOCKED", "FLY HERE", "CANNOT UNDOCK"]:
				fly = b as Button
		_ok("berth: the world's page offers no flight: DOCKED, greyed, saying \"%s\" (%s)" % [DOCKED_LINE,
			"none" if fly == null else "%s, disabled %s, %s" % [fly.text, fly.disabled, fly.tooltip_text.replace("\n", " ")]],
			fly != null and fly.text == "DOCKED" and fly.disabled and fly.tooltip_text.replace("\n", " ").contains(DOCKED_LINE))
		if fly != null:
			_ok("berth: DOCKED sits whole inside the panel and the screen (%s in %s)" % [fly.get_global_rect(), (m.panel as Control).get_global_rect()],
				(m.panel as Control).get_global_rect().encloses(fly.get_global_rect()) and get_viewport().get_visible_rect().encloses(fly.get_global_rect()))
		m.fly_to_body(p)
		await _frames(30)
		_ok("berth: FLY HERE refused, still docked, the ship where it was (%d)" % m.flight.reached(),
			Router.docked and m.flight.reached() == at0 and m.flight.can_fly())
		_ok("berth: the panel offers no flight", not m.panel._can_go() and m.panel._held())
		m.harness_keys = true
		m._wasd.w = true
		await _frames(20)
		m.harness_keys = false
		_ok("berth: WASD refused (still docked, at %d, keys let go)" % m.flight.reached(),
			Router.docked and m.flight.reached() == at0 and not m._wasd.w)
		# GO: an event here (planted, as a station rolls none), taken from the
		# berth. It went down to LOCAL and undocked there, with no flight to refuse
		var n: MapGen.MapNode = Run.map[_st]
		var kept := n.options.duplicate()
		var ev := _any_event()
		if _ok("berth: an event to plant for GO (%s)" % ev, ev != &""):
			n.options.append(ev)
			m.go_event(n.options.size() - 1)
			await _frames(30)
			_ok("berth: GO refused: still docked, on the map, no event waiting for LOCAL (on %s)" % _name_of(Router.current),
				Router.docked and Router.current == m and LocalEventDrawer.pending.is_empty())
			n.options = kept
			LocalEventDrawer.pending = []
	await _tab()
	var ch := Router.current as StarchartScreen
	var to := _jump_target(false)
	if _ok("berth: Tab goes on to the chart, still docked", ch != null and Router.docked) and to >= 0:
		ch._on_node_picked(to)
		await _frames(2)
		_ok("berth: JUMP reads DOCKED, greyed, saying \"%s\" (%s, %s)" % [DOCKED_LINE, ch._jump.text, ch._jump.tooltip_text.replace("\n", " ")],
			ch._jump.disabled and ch._jump.text == "DOCKED" and ch._jump.tooltip_text.replace("\n", " ").contains(DOCKED_LINE))
		_ok("berth: the chart's DOCKED button whole on screen (%s)" % ch._jump.get_global_rect(),
			get_viewport().get_visible_rect().encloses(ch._jump.get_global_rect()))
		Router.begin_jump(to)
		await _frames(30)
		_ok("berth: the chart's JUMP refused (at %d, still docked, on %s)" % [Run.at, _name_of(Router.current)],
			Run.at == _st and Router.docked and Router.current is StarchartScreen)
	await _tab()
	seen = _watch_off()
	_ok("berth: Tab from the chart goes back to the berth", Router.current is StationScreen and Router.docked)
	_ok("berth: round the berth, the map and the chart by Tab: docked throughout, never LOCAL (seen: %s)" % ", ".join(seen), seen.is_empty())
	# BACK IN FROM THE MAP: the HUD's STATION, then the map's DOCK. Both went
	# down to LOCAL first (undocking) and played the dock again
	for how in ["the HUD's STATION", "the map's DOCK"]:
		await _tab()
		m = Router.current as SystemMapScreen
		if not _ok("berth: Tab to the map again (for %s)" % how, m != null and Router.docked):
			continue
		var powered := Router.powered.duplicate()
		_watch_on()
		if how == "the HUD's STATION":
			tab.pressed.emit()
		else:
			var bc = null
			for b in m.view.layout.bodies[_station_body()].beacons:
				if b.dock:
					bc = b
			m.take_action(bc)
		for i in 900:
			await _tree.process_frame
			if Router.current is StationScreen and not ZoomLadder.busy() and ZoomLadder.chain == &"":
				break
		await _frames(5)
		seen = _watch_off()
		_ok("berth: %s goes straight back in: docked throughout, never LOCAL (seen: %s; on %s)" % [how, ", ".join(seen), _name_of(Router.current)],
			seen.is_empty() and Router.current is StationScreen and Router.docked)
		_ok("berth: %s: the decks powered on stay on (%s, now %s)" % [how, powered.keys(), Router.powered.keys()],
			powered.keys().all(func(k: Variant) -> bool: return Router.powered.has(k)))
	# PARTY (co-op): its LEAVE went to the map, undocking on the way
	_watch_on()
	Router.show_party()
	await _frames(5)
	var leave: Button = null
	if Router.current is PartyScreen:
		for b in Router.current.find_children("*", "Button", true, false):
			if (b as Button).text == "LEAVE":
				leave = b as Button
	if _ok("berth: PARTY opens from the berth, with LEAVE", leave != null):
		leave.pressed.emit()
		await _idle()
		await _frames(10)
		seen = _watch_off()
		_ok("berth: PARTY's LEAVE goes back to the berth, docked throughout (seen: %s; on %s)" % [", ".join(seen), _name_of(Router.current)],
			seen.is_empty() and Router.current is StationScreen and Router.docked)
	_watching = false
	# AND UNDOCK STILL LEAVES: the station's own button
	st = Router.current as StationScreen
	if _ok("berth: on the station, UNDOCK on its rail", st != null and st._undock != null and not st._undock.disabled):
		st._undock.pressed.emit()
		await _idle()
		await _frames(10)
		Router.hud.refresh()
		_ok("berth: UNDOCK leaves: on LOCAL, undocked, the tab reads LOCAL, lit (on %s, docked %s, %s)" % [_name_of(Router.current), Router.docked, tab.text],
			Router.current is SectorScreen and not Router.docked and tab.text == "LOCAL" and tab.disabled
				and tab.has_theme_stylebox_override("disabled"))


## DOCK ONLY AT THE STATION (Jon, Oct 18, "dock:A"), AND A JUMP IN ARRIVES AT
## IT ("arrive:B"): in a used run (docked and undocked here once, off to a
## neighbour by the chart and back), the ship arrives alongside the station:
## the map's DOCK card live and LOCAL with the station's side and DOCK. Flown
## to a world of the system, nothing offers DOCK -- LOCAL's bar, the station's
## side on LOCAL, the map's DOCK card (greyed, with the way to it on it) and its
## beacon, the fuel hint, `show_station` itself. Flown back to the station, DOCK
## again, and pressed it docks; from the berth the map's FLY HERE to the world
## is refused (UNDOCK is the only way out, Jon, Oct 27), and after UNDOCK the
## flight there leaves LOCAL with no berth and no DOCK.
func _only_at_station() -> void:
	if _only != "" and _only != "dockplace":
		return
	print("route dockplace")
	var world := int(_places().world)
	var sb := _station_body()
	if not _ok("dockplace: docked in the berth (the run's first visit)", await _to_berth()):
		return
	Router.show_sector()
	await _idle()
	_ok("dockplace: UNDOCK lands on LOCAL", Router.current is SectorScreen and not Router.docked)
	# off by the chart and back
	Run.chart_from(Run.map[_st])
	var away := _jump_target(false)
	if not _ok("dockplace: a neighbour to jump to (%d)" % away, away >= 0):
		return
	if not _ok("dockplace: jumped away (at %d)" % Run.at, await _jump_to(away)):
		return
	_ok("dockplace: a system with no station arrives at the edge (site %d)" % Run.site_here(), Run.site_here() < -1)
	if not _ok("dockplace: and back to the station's system (at %d)" % Run.at, await _jump_to(_st)):
		return
	# ARRIVED ALONGSIDE THE STATION: the map's DOCK live, then LOCAL with it
	if not Router.current is SystemMapScreen:
		await _tab()
	var m := Router.current as SystemMapScreen
	if _ok("dockplace: on the map", m != null):
		await _frames(10)
		_ok("dockplace: arrived alongside the station (the map's ship at %d, station %d)" % [m.flight.reached(), sb],
			m.flight.reached() == sb and Router.at_station())
		await _map_dock("dockplace: arrived", m, true)
		await _shot("dock_map_arrive")
	await _here_tab()
	await _at_dock("dockplace: LOCAL on arrival")
	await _shot("dock_local_arrive")
	# a world of the station's system: no DOCK
	await _tab()
	m = Router.current as SystemMapScreen
	if _ok("dockplace: to the map again", m != null) and _ok("dockplace: flown to the world %d" % world, await _fly(world)):
		await _map_dock("dockplace: at the world", m, false)
		await _shot("dock_map_world")
	await _here_tab()
	await _no_dock("dockplace: LOCAL at the world")
	await _shot("dock_local_world")
	# and back to the station: DOCK offered again
	await _tab()
	m = Router.current as SystemMapScreen
	if _ok("dockplace: to the map once more", m != null) and _ok("dockplace: flown back to the station %d" % sb, await _fly(sb)):
		await _map_dock("dockplace: back at the station", m, true)
		await _shot("dock_map_station")
	await _here_tab()
	var dk: Button = await _at_dock("dockplace: LOCAL back at the station")
	await _shot("dock_local_station")
	if dk == null:
		return
	dk.pressed.emit()
	await _idle()
	await _frames(10)
	_ok("dockplace: DOCK docks (on %s, docked %s)" % [Router.current.get_script().get_global_name(), Router.docked],
		Router.current is StationScreen and Router.docked)
	# docked, the map is a view: away to the world refused, back in by the tab
	await _tab()
	m = Router.current as SystemMapScreen
	if _ok("dockplace: Tab from the berth to the map", m != null):
		for i in 300:
			if m.flight.can_fly():
				break
			await _tree.process_frame
		var at0: int = m.flight.reached()
		m.fly_to_body(world)
		await _frames(30)
		_ok("dockplace: from the berth, FLY HERE to the world refused (docked %s, at %d, was %d)" % [Router.docked, m.flight.reached(), at0],
			Router.docked and m.flight.reached() == at0)
	await _here_tab()
	_ok("dockplace: the HUD's STATION goes back in (on %s, docked %s)" % [_name_of(Router.current), Router.docked],
		Router.current is StationScreen and Router.docked)
	# UNDOCK, then the world: no berth and no DOCK there
	Router.show_sector()
	await _idle()
	_ok("dockplace: UNDOCK lands on LOCAL again", Router.current is SectorScreen and not Router.docked)
	await _tab()
	m = Router.current as SystemMapScreen
	if _ok("dockplace: Tab from LOCAL to the map", m != null):
		_ok("dockplace: flown after UNDOCK to the world", await _fly(world))
		_ok("dockplace: flying, the tab reads LOCAL (docked %s, tab %s)" % [Router.docked, Router.hud._tab_sector.text],
			not Router.docked and Router.hud._tab_sector.text == "LOCAL")
		await _map_dock("dockplace: at the world after UNDOCK", m, false)
	await _here_tab()
	await _no_dock("dockplace: LOCAL at the world after UNDOCK")
	_clean("dockplace", await _local())


## LOCAL at the station: its side, DOCK, the bar, the fuel hint. DOCK, or null.
func _at_dock(what: String) -> Button:
	var loc := Router.current as SectorScreen
	var dk: Button = loc.find_child("Dock", true, false) as Button if loc != null else null
	_ok("%s: the station's side and DOCK (%s, face %s)" % [what, dk != null, loc != null and loc._face != null],
		loc != null and dk != null and loc._face != null and Router.at_station())
	_ok("%s: its bar says a station is here" % what, _bar_has(loc, "A STATION HERE"))
	_ok("%s: the fuel hint: \"%s\"" % [what, Hints.fuel_dock_line()], Hints.fuel_dock_line() == "Refuel here before you leave.")
	await _frames(1)
	return dk


## Fly the chart's JUMP to system `to` and wait for the arrival to settle.
func _jump_to(to: int) -> bool:
	if not Run.can_jump_to(Run.map[to]):
		return false
	Router.begin_jump(to)
	for i in 1800:
		await _tree.process_frame
		if Run.at == to and not ZoomLadder.busy() and (Router.current is SystemMapScreen or Router.current is SectorScreen) 				and Router._post_arrive == false:
			break
	await _idle()
	await _frames(30)
	return Run.at == to


## The map's DOCK card: woken (`there`), or greyed with the way to the station
## on its button; and its beacon taken from away is refused.
func _map_dock(what: String, m: SystemMapScreen, there: bool) -> void:
	m.panel.show_system()
	await _frames(2)
	var card = m.panel._cards.get(&"dock")
	var btn := (card._right as Button) if card != null else null
	if not _ok("%s: the map lists the DOCK card" % what, btn != null):
		return
	if there:
		_ok("%s: its DOCK can be pressed" % what, not btn.disabled)
		return
	_ok("%s: its DOCK is greyed, and says \"%s\" (%s)" % [what, Router.DOCK_AWAY, btn.tooltip_text.replace("
", " ")],
		btn.disabled and btn.tooltip_text.contains(Router.DOCK_AWAY))
	var bc = null
	for b in m.view.layout.bodies[_station_body()].beacons:
		if b.dock:
			bc = b
	var at0: int = m.flight.reached()
	m.take_action(bc)
	await _frames(20)
	_ok("%s: the DOCK beacon from here docks nothing and flies nowhere" % what,
		Router.current == m and not Router.docked and m.flight.reached() == at0 and m.flight.can_fly())


## LOCAL away from the station: no DOCK, no station side or ring, the bar says
## where to go, the fuel hint the same, and the door refuses.
func _no_dock(what: String) -> void:
	var loc := Router.current as SectorScreen
	if not _ok("%s: on LOCAL" % what, loc != null):
		return
	_ok("%s: no DOCK button" % what, loc.find_child("Dock", true, false) == null)
	_ok("%s: no station side, no ring" % what, loc._face == null and loc._view._area._place_name() == &"")
	_ok("%s: the bar says to fly to the station" % what, _bar_has(loc, "FLY TO THE STATION TO DOCK"))
	_ok("%s: the fuel hint: \"%s\"" % [what, Hints.fuel_dock_line()], Hints.fuel_dock_line() == "Fly to the station here to refuel.")
	Router.show_station()
	await _frames(20)
	_ok("%s: docking refused, still on LOCAL" % what, Router.current == loc and not Router.docked)


func _bar_has(loc: SectorScreen, words: String) -> bool:
	if loc == null:
		return false
	for l in loc.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and (l as Label).text.contains(words):
			return true
	return false


## A system the chart can jump to from the station (one holding an event, for GO).
func _jump_target(with_event: bool) -> int:
	var here: MapGen.MapNode = Run.map[_st]
	var best := -1
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.index == _st or not Run.can_jump_to(n):
			continue
		if n.type == MapGen.NodeType.STATION or n.type == MapGen.NodeType.CORE or n.type == MapGen.NodeType.PULSAR:
			continue
		if with_event:
			OptionTable.ensure(n)
			if _an_event(n) < 0:
				continue
		best = n.index
		break
	return best


## Any open event of the galaxy, by its id, wherever it stands.
func _any_event() -> StringName:
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type != MapGen.NodeType.SYSTEM:
			continue
		var k := _an_event(n)
		if k >= 0:
			return n.options[k]
	return &""


func _an_event(n: MapGen.MapNode) -> int:
	OptionTable.ensure(n)
	for i in n.options.size():
		var o := OptionTable.by_id(n.options[i])
		if o.is_empty() or n.taken.has(MapGen.OPTION_SITE + i):
			continue
		if LocalEventDrawer.body_of(n, i) >= -1 and not o.has("fight"):
			return i
	return -1


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 30.0
	Rng.forced = 7
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# (nothing jumps you on the way: the trip is the subject)
	for raw in Run.map:
		(raw as MapGen.MapNode).ambush_rolled = true
		(raw as MapGen.MapNode).ambush_pending = false
	for raw in Run.map:
		if (raw as MapGen.MapNode).type == MapGen.NodeType.STATION:
			_st = (raw as MapGen.MapNode).index
			break
	if not _ok("the run has a station", _st >= 0):
		_end()
		return
	Run.fuel = 99
	var pl := _places()
	print("station %d: its body %d, a world %d, a belt %d" % [_st, _station_body(), pl.world, pl.belt])
	_want = {"world_hud": pl.world, "world_tab": pl.world, "star_hud": -1, "belt_hud": pl.belt, "open_tab": -9}
	await _berth_shut(int(pl.world))
	await _only_at_station()
	await _route("world_hud", _map_trip(int(pl.world), "hud"))
	await _route("world_tab", _map_trip(int(pl.world), "tab"))
	await _route("star_hud", _map_trip(-1, "hud"))
	if int(pl.belt) >= 0:
		await _route("belt_hud", _map_trip(int(pl.belt), "hud"))
	await _route("open_tab", _map_trip(-3, "tab"))
	await _route("jump", _jump_trip(false))
	await _route("jump_go", _jump_trip(true))
	_end()


func _end() -> void:
	ZoomLadder.force = -1
	ZoomLadder.fixed_dt = -1.0
	print("dockflytest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
