extends Node

## THE SIDE BAR NEVER GOES BLANK (Jon, Oct 13: "When going from local to sector
## or sector to starchart etc... the side bar goes blank and then draws the new
## side bar. Can we not have it go blank and just have it transition to the new
## side bar?"), headless:
##   godot --headless --path . -- sheet=SideBarTest [looks=A,B,C,D,E,F]
## Every hop that has a side bar at one end -- LOCAL -> map, map -> chart,
## chart -> map, map -> LOCAL -- through the Router's own doors with the
## animation on and the ladder's clock stepped 1/60 s a frame, for every look the
## swap has (`ZoomLadder.SIDE_LOOKS`). Each frame the screen up has a side bar,
## how much of its rect shows content is measured: the live panel's own opacity,
## or, while a swap is drawn over it (`SideSwap`), the swap's old and new at a
## grid of points across it. A frame under half is a BLANK frame, and any blank
## frame fails. Also: no more than the crossfade's middle shows both contents
## half and half; a click is only let through where the new content stands
## resolved (A: from the crossfade's middle on); and with the animation off
## (headless, reduced motion) the new side bar is whole the very frame it is
## asked for. Prints the blank frames per hop, which is the number on main.
## THE TOOLBAR the same (Jon: "these buttons" -- the chart's LAYER row, the
## map's DANGER strip, `ladder_bar`): never blank, decoded on every hop, and a
## click on a button in it before it has resolved eaten.
## Written to run on main too (it reaches the swap only by name), so it can be
## watched failing there.

var _fails := 0
var _tree: SceneTree
var _zl: Script = load("res://scripts/ui/ZoomLadder.gd")
## (a grid across the side bar's rect, for the swap's coverage)
const GX := 6
const GY := 24


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _idle() -> void:
	for i in 900:
		if not ZoomLadder.busy() and ZoomLadder.chain == &"" and _swap_now() == null and _bar_now() == null:
			await _tree.process_frame
			return
		await _tree.process_frame


## A screen's side bar: the panel down its right edge (none on LOCAL).
func _side_of(s: Variant) -> Control:
	if s == null or not is_instance_valid(s):
		return null
	if (s as Object).has_method(&"ladder_side"):
		return (s as Object).call(&"ladder_side") as Control
	if s is StarchartScreen:
		return (s as StarchartScreen)._ladder_side
	if s is SystemMapScreen and (s as SystemMapScreen).panel != null:
		return (s as SystemMapScreen).panel.get_parent() as Control
	return null


## How much of a canvas item is drawn: hidden 0, else its opacity through every
## parent.
func _eff(c: CanvasItem) -> float:
	if c == null or not is_instance_valid(c) or not c.is_inside_tree() or not c.is_visible_in_tree():
		return 0.0
	var a := c.self_modulate.a
	var n: Node = c
	while n != null and n is CanvasItem:
		a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	return a


## (by name, so this still runs on main, where there is no swap)
var _ss: Script = load("res://scripts/ui/SideSwap.gd") if ResourceLoader.exists("res://scripts/ui/SideSwap.gd") else null


func _live(which: StringName) -> Object:
	if _ss == null:
		return null
	var sw: Variant = _ss.call(which)
	if sw == null or not is_instance_valid(sw) or not (sw as Node).is_inside_tree():
		return null
	return sw


## The side bar's swap drawing now -- the ladder's, or one it handed on.
func _swap_now() -> Object:
	return _live(&"side_now")


## Where the scene starts this frame, viewport y: under the screen's toolbar
## band if it has one, under a band laid over it (`SideBand`), or the top of
## the screens' area.
var _sb: Script = load("res://scripts/ui/SideBand.gd") if ResourceLoader.exists("res://scripts/ui/SideBand.gd") else null
var _cs: Script = load("res://scripts/ui/ChromeSlide.gd") if ResourceLoader.exists("res://scripts/ui/ChromeSlide.gd") else null
## (the toolbar's height, where the build has one)
var _bar_h: float = float((load("res://scripts/ui/StarchartScreen.gd") as Script).get_script_constant_map().get("BAR_H", 17))


## The chrome on the move this frame (`ChromeSlide`): [kind, its rect now].
func _slides() -> Array:
	var out: Array = []
	if _cs != null:
		for pc: Variant in _cs.get("live"):
			if is_instance_valid(pc) and (pc as CanvasItem).is_visible_in_tree():
				var r: Rect2 = pc.call(&"at")
				out.append([StringName(pc.get("kind")), r.intersection(Router.content.get_global_rect())])
	return out


## Where the scene's picture ends on the right this frame, viewport x: where
## the side bar's column begins -- a piece of it on the move, the screen's own
## side bar or a swap drawing over where it was (less the 5 px gap beside the
## picture's frame) -- or the screens' own right edge.
func _side_edge() -> float:
	var c := Router.content.get_global_rect()
	var e := c.end.x
	for sl: Array in _slides():
		if sl[0] == &"side" and (sl[1] as Rect2).has_area():
			e = minf(e, (sl[1] as Rect2).position.x)
	var sd := _side_of(Router.current)
	if sd != null and _eff(sd) > 0.5:
		e = minf(e, sd.get_global_rect().position.x - 5.0)
	var sw := _swap_now()
	if sw != null:
		e = minf(e, (sw.call(&"rect") as Rect2).position.x - 5.0)
	return e


func _bands() -> Array:
	var out: Array = []
	var c := Router.content.get_global_rect()
	var b := _bar_of(Router.current)
	if b != null and _eff(b) > 0.5:
		out.append(Rect2(c.position.x, b.get_global_rect().position.y, c.size.x, _bar_h + 4))
	for sl: Array in _slides():
		if sl[0] == &"band" and (sl[1] as Rect2).has_area():
			out.append(sl[1])
	if _sb != null:
		for sb: Variant in _sb.get("live"):
			if is_instance_valid(sb) and (sb as CanvasItem).is_visible_in_tree():
				var top: float = sb.get("top")
				out.append(Rect2(c.position.x, top, c.size.x, float(sb.call(&"edge")) - top))
	return out


func _scene_top() -> float:
	var e := Router.content.get_global_rect().position.y
	for r: Rect2 in _bands():
		e = maxf(e, r.end.y)
	return e


func _in_band(r: Rect2) -> bool:
	for b: Rect2 in _bands():
		if b.encloses(r.grow(-1.0)):
			return true
	return false


func _bar_now() -> Object:
	return _live(&"bar_now")


## A screen's toolbar along the top (none on LOCAL).
func _bar_of(s: Variant) -> Control:
	if s == null or not is_instance_valid(s):
		return null
	if (s as Object).has_method(&"ladder_bar"):
		return (s as Object).call(&"ladder_bar") as Control
	if s is StarchartScreen:
		return (s as StarchartScreen)._strip_row
	if s is SystemMapScreen:
		return (s as SystemMapScreen)._strip
	return null


## This frame: [coverage 0..1, both-at-once 0..1, clicks let through onto
## unresolved content (count of grid points)], or [] when the screen up has no
## side bar.
func _measure() -> Array:
	return _measure_region(_side_of(Router.current), _swap_now(), &"side")


## (a piece of it on the move, `ChromeSlide`, is it, drawn whole)
func _measure_region(side: Control, sw: Object, kind: StringName = &"") -> Array:
	if side == null and sw == null:
		return []
	if sw == null:
		var whole := _eff(side)
		for sl: Array in _slides():
			if sl[0] == kind and (sl[1] as Rect2).has_area():
				whole = 1.0
		# (and the band coming on, empty, its row to decode in once it lands)
		if kind == &"band" and _sb != null:
			for sb: Variant in _sb.get("live"):
				if is_instance_valid(sb) and (sb as CanvasItem).is_visible_in_tree():
					whole = 1.0
		return [whole, 0.0, 0]
	# THE SWAP DRAWN OVER IT: its own account of each point (old, new, how
	# settled the new is there), checked to be drawn at all first
	var ov := sw as CanvasItem
	if not ov.visible and ZoomLadder.busy() and ZoomLadder.active._rect.visible:
		# (not laid out yet: the held picture still stands over the rect)
		return [1.0, 0.0, 0]
	if _eff(ov) < 0.99 or (ov as CanvasItem).material == null:
		return [0.0, 0.0, 0]
	var r: Rect2 = sw.call(&"rect")
	var cov := 0.0
	var both := 0.0
	var leaks := 0
	for j in GY:
		for i in GX:
			var p := r.position + Vector2((float(i) + 0.5) / GX * r.size.x, (float(j) + 0.5) / GY * r.size.y)
			var st: Vector3 = sw.call(&"state_at", p)
			cov += minf(1.0, st.x + st.y)
			both += minf(st.x, st.y)
			if not bool(sw.call(&"blocks", p)) and st.z < float(sw.call(&"click_floor")):
				leaks += 1
	var n := float(GX * GY)
	return [cov / n, both / n, leaks]


var _looks: PackedStringArray = []


func _set_look(l: String) -> void:
	for m in _zl.get_script_method_list():
		if m.name == "force_side_look":
			_zl.call(&"force_side_look", l)


## One hop, every frame until the ladder is idle: the blank frames (the screen up
## has a side bar and under half of it shows), the frames both contents show
## half and half, the frames a click would have gone through onto content not
## yet resolved, and how many frames the swap drew.
func _hop(label: String, call: Callable, want: Script) -> int:
	call.call()
	var blank := 0
	var mixed := 0
	var leaked := 0
	var swap_frames := 0
	var low := 1.0
	var frames := 0
	# THE TOOLBAR: never blank, and its decode seen
	var bar_blank := 0
	var bar_low := 1.0
	var bar_frames := 0
	# THE SCENE'S TOP EDGE (Jon: "the window drops abruptly"), and the letters
	# of a decode held to a band (Jon on the toolbar's over LOCAL: "weird")
	var edge0 := _scene_top()
	var side0 := _side_edge()
	var side_jump := 0.0
	var band_frames := 0
	var edge_jump := 0.0
	var loose := 0
	var landed_at := -1
	var letter_frames := 0
	var decode_end := -1
	for i in 900:
		var m := _measure()
		if not m.is_empty():
			if float(m[0]) < 0.5:
				blank += 1
			low = minf(low, float(m[0]))
			if float(m[1]) > 0.35:
				mixed += 1
			if int(m[2]) > 0:
				leaked += 1
		var sn := _swap_now()
		if sn != null:
			swap_frames += 1
			# (E's letters: until the last of them has resolved)
			if not sn.has_method(&"scrambling") or not (sn.call(&"scrambling") as Array).is_empty():
				letter_frames += 1
				decode_end = frames
		var mb := _measure_region(_bar_of(Router.current), _bar_now(), &"band")
		if not mb.is_empty():
			if float(mb[0]) < 0.5:
				bar_blank += 1
			bar_low = minf(bar_low, float(mb[0]))
		if (_sb != null and not (_sb.get("live") as Array).is_empty()) or not _slides().is_empty():
			band_frames += 1
		var bw := _bar_now()
		if bw != null and (bw as CanvasItem).visible:
			bar_frames += 1
			if bw.has_method(&"scrambling"):
				for lr: Rect2 in bw.call(&"scrambling"):
					if not _in_band(lr):
						loose += 1
		var e := _scene_top()
		edge_jump = maxf(edge_jump, absf(e - edge0))
		edge0 = e
		var se := _side_edge()
		side_jump = maxf(side_jump, absf(se - side0))
		side0 = se
		if landed_at < 0 and (not ZoomLadder.busy() or ZoomLadder.active.phase == ZoomLadder.Phase.UI_IN):
			landed_at = frames
		frames += 1
		if not ZoomLadder.busy() and ZoomLadder.chain == &"" and _swap_now() == null and _bar_now() == null:
			break
		await _tree.process_frame
	await _frames(2)
	_ok("%s lands on %s" % [label, want.get_global_name()], Router.current != null and Router.current.get_script() == want)
	_ok("%s: no blank side bar (%d of %d frames blank, least %.2f)" % [label, blank, frames, low], blank == 0)
	# (A's crossfade is allowed its middle: under 40% of its frames half and half)
	# (and E leaving for LOCAL, its empty panel fading out over `OUT_FADE`)
	var allow := int(ceil(swap_frames * 0.4)) if (_looks.size() == 0 or _cur_look == "A") 		else (9 if _cur_look == "E" and want == SectorScreen else 2)
	_ok("%s: both contents half and half for %d frames (allowed %d)" % [label, mixed, allow], mixed <= allow)
	_ok("%s: no click let through onto unresolved content (%d frames)" % [label, leaked], leaked == 0)
	var side := _side_of(Router.current)
	_ok("%s: the side bar whole at rest" % label, side == null or _eff(side) > 0.99)
	if _ss != null:
		# THE TOOLBAR: never blank, swapped in place on every hop, whole at rest
		_ok("%s: no blank toolbar (%d frames blank, least %.2f)" % [label, bar_blank, bar_low], bar_blank == 0)
		# (or, from LOCAL on band A, comes up with its band: the band is the move)
		_ok("%s: the toolbar swaps in place (%d frames, band %d)" % [label, bar_frames, band_frames], bar_frames > 0 or band_frames > 0)
		var bar := _bar_of(Router.current)
		_ok("%s: the toolbar whole at rest" % label, bar == null or _eff(bar) > 0.99)
		_ok("%s: the scene's top edge never moves more than 3 px in a frame (most %.0f)" % [label, edge_jump], edge_jump <= 3.0)
		# (the side bar's column crosses 265 px in the camera's half of the move:
		# at most 8 px a frame at its fastest, never at once)
		_ok("%s: the side bar's left edge, the picture's right, never more than 10 px in a frame (most %.0f)" % [label, side_jump], side_jump <= 10.0)
		_ok("%s: no decoded letter off a band (%d rows)" % [label, loose], loose == 0)
	if _cur_look == "E" and letter_frames > 0:
		# E, SLOW (Jon: "happen slowly and not so fast"): the side bar decodes for
		# a second or more, and is done within 0.35 s of the camera landing --
		# or, on a hop shorter than that, runs on past it no longer than it needs
		var secs := letter_frames / 60.0
		var past := (decode_end - landed_at) / 60.0
		_ok("%s: E decodes slowly (%.2f s) and is done %.2f s after the landing" % [label, secs, past],
			secs >= 0.9 and (past <= 0.35 or secs <= 1.45))
	print("  [sidebar] %s %s: blank %d, swap %d frames, mixed %d" % [_cur_look, label, blank, swap_frames, mixed])
	return blank


var _cur_look := "-"


## The hops with the animation off: the new side bar whole on the frame asked.
func _instant(why: String) -> void:
	for h in [[Router.show_system, SystemMapScreen], [Router.show_starchart, StarchartScreen],
			[Router.show_system, SystemMapScreen], [Router.show_local, SectorScreen]]:
		var was := Router.current
		(h[0] as Callable).call()
		var side := _side_of(Router.current)
		var swapped: bool = Router.current != was and Router.current.get_script() == h[1]
		_ok("%s: %s at once, its side bar whole on that frame (%.2f)" % [why, (h[1] as Script).get_global_name(),
			_eff(side) if side != null else 1.0], swapped and not ZoomLadder.busy() and (side == null or _eff(side) > 0.99))
		await _tree.process_frame
		side = _side_of(Router.current)
		_ok("%s: and the frame after (%.2f)" % [why, _eff(side) if side != null else 1.0], side == null or _eff(side) > 0.99)
		await _frames(3)


## A click on the side bar in the middle of a swap, map -> chart, at the
## chart's JUMP while it is not yet resolved under the pointer: the move ends,
## and the press reaches no control in the new side bar.
func _click_mid_swap() -> void:
	Router.show_starchart()
	var sw: Object = null
	for i in 300:
		await _tree.process_frame
		sw = _swap_now()
		if sw != null and (sw.call(&"rect") as Rect2).has_area():
			break
	if not _ok("%s: a swap is drawn on map -> chart" % _cur_look, sw != null):
		await _idle()
		return
	var ch := ZoomLadder.active.new as StarchartScreen
	var jump: Button = ch._jump if ch != null else null
	if not _ok("%s: the chart's JUMP is there to aim at" % _cur_look, jump != null):
		await _idle()
		return
	var p := jump.get_global_rect().get_center()
	var blocked := bool(sw.call(&"blocks", p))
	var heard := [0]
	var probe := func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			heard[0] += 1
	for b in _buttons(_side_of(ch)):
		b.gui_input.connect(probe)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		jump.get_viewport().push_input(ev)
		await _tree.process_frame
	_ok("%s: a click on the side bar mid-swap ends the move" % _cur_look, not ZoomLadder.busy())
	_ok("%s: and on JUMP not yet resolved, it was eaten (blocked %s, heard %d)" % [_cur_look, blocked, heard[0]],
		blocked and heard[0] == 0)
	for b in _buttons(_side_of(ch)):
		if b.gui_input.is_connected(probe):
			b.gui_input.disconnect(probe)
	await _idle()
	await _frames(4)


## A click on the toolbar before it has resolved: map -> chart, on the
## chart's first button along its top (HIDE SYSTEMS in dev mode) while the
## toolbar decodes -- eaten, the button never hears it.
func _click_bar_mid_decode() -> void:
	Router.show_starchart()
	var bw: Object = null
	for i in 300:
		await _tree.process_frame
		bw = _bar_now()
		if bw != null and (bw as CanvasItem).visible:
			break
	if not _ok("%s: the toolbar decodes on map -> chart" % _cur_look, bw != null):
		await _idle()
		return
	var ch := Router.current as StarchartScreen
	var bs := _buttons(_bar_of(ch))
	var target: Control = bs[0] if not bs.is_empty() else _bar_of(ch)
	var p := target.get_global_rect().get_center()
	var blocked := bool(bw.call(&"blocks", p))
	var heard := [0]
	var probe := func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			heard[0] += 1
	for b in bs:
		b.gui_input.connect(probe)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		target.get_viewport().push_input(ev)
		await _tree.process_frame
	for b in bs:
		if b.gui_input.is_connected(probe):
			b.gui_input.disconnect(probe)
	await _idle()
	await _frames(4)
	_ok("%s: a click on the toolbar (%s) before it resolved was eaten (blocked %s, heard %d)" % [_cur_look,
		(target as Button).text if target is Button else "its row", blocked, heard[0]], blocked and heard[0] == 0)


## THE MAP'S TOOLBAR IS THE CHART'S ROW (Jon: "the same style as the layer
## bar ... the same height as the button bar for the starchart"): the two rows
## the same height and at the same place to the pixel, the danger pips the
## chart's own blocks, and its toggles -- HIDE NAMES, HIDE ORBITS -- reaching
## the overlay and the view and kept across a visit to the chart and back.
func _toolbar_rows() -> void:
	ZoomLadder.force = 0
	Router.show_system()
	await _frames(6)
	var m := Router.current as SystemMapScreen
	var mr: Rect2 = m._strip.get_global_rect()
	var m_pips := m._danger_cells.get_child_count()
	var m_pip: Vector2 = (m._danger_cells.get_child(0) as Control).size if m_pips > 0 else Vector2.ZERO
	Router.show_starchart()
	await _frames(6)
	var c := Router.current as StarchartScreen
	var cr: Rect2 = c._strip_row.get_global_rect()
	var c_pip: Vector2 = (c._layer_cells.get_child(0) as Control).size
	_ok("the map's toolbar is the chart's row to the pixel (map %s, chart %s)" % [mr, cr],
		is_equal_approx(mr.size.y, cr.size.y) and is_equal_approx(mr.position.y, cr.position.y)
		and is_equal_approx(mr.size.y, float(StarchartScreen.BAR_H)))
	_ok("its danger pips are the chart's blocks (%d of %s; the chart's %s)" % [m_pips, m_pip, c_pip],
		m_pips == MapGen.DANGER_MAX and m_pip == c_pip)
	Router.show_system()
	await _frames(6)
	m = Router.current as SystemMapScreen
	var n0 := SystemMapScreen.names_on
	var o0 := SystemMapScreen.orbits_on
	m._names_btn.pressed.emit()
	m._orbits_btn.pressed.emit()
	_ok("HIDE NAMES and HIDE ORBITS reach the overlay and the view (%s, %s)" % [m.overlay.names_on, m.view.orbits_on],
		m.overlay.names_on == not n0 and m.view.orbits_on == not o0
		and m._names_btn.text == ("HIDE NAMES" if not n0 else "SHOW NAMES"))
	Router.show_starchart()
	await _frames(6)
	Router.show_system()
	await _frames(6)
	m = Router.current as SystemMapScreen
	_ok("and they are kept across the chart and back (%s, %s, \"%s\")" % [m.overlay.names_on, m.view.orbits_on, m._names_btn.text],
		m.overlay.names_on == not n0 and m.view.orbits_on == not o0
		and m._orbits_btn.text == ("HIDE ORBITS" if not o0 else "SHOW ORBITS"))
	m._names_btn.pressed.emit()
	m._orbits_btn.pressed.emit()
	_ok("and back on again", SystemMapScreen.names_on == n0 and SystemMapScreen.orbits_on == o0)
	Router.show_local()
	await _frames(6)
	ZoomLadder.force = 1


## A click on the side bar's column while it slides off LOCAL (map -> LOCAL):
## the move ends and the click reaches nothing under it -- LOCAL's scene, which
## it was about to uncover, never hears it.
func _click_moving_chrome() -> void:
	if _cs == null:
		return
	Router.show_system()
	await _idle()
	await _frames(4)
	Router.show_local()
	var pc: Object = null
	for i in 400:
		await _tree.process_frame
		for p: Variant in _cs.get("live"):
			if is_instance_valid(p) and StringName(p.get("kind")) == &"side" and float(p.get("k")) < 0.8 and float(p.get("k")) > 0.2:
				pc = p
		if pc != null:
			break
	if not _ok("the side bar's column is seen sliding off LOCAL", pc != null):
		await _idle()
		return
	var r: Rect2 = (pc.call(&"at") as Rect2).intersection(Router.content.get_global_rect())
	var at := r.get_center()
	var loc := Router.current as SectorScreen
	var heard := [0]
	var probe := func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			heard[0] += 1
	loc._view.gui_input.connect(probe)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		loc.get_viewport().push_input(ev)
		await _tree.process_frame
	loc._view.gui_input.disconnect(probe)
	_ok("a click on it mid-slide ends the move and lands on nothing (heard %d)" % heard[0], heard[0] == 0 and not ZoomLadder.busy())
	await _idle()
	await _frames(4)


func _buttons(n: Node) -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	if n == null:
		return out
	if n is BaseButton:
		out.append(n as BaseButton)
	for k in n.get_children():
		out.append_array(_buttons(k))
	return out


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 60.0
	Rng.forced = 7
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	StarchartScreen._primed_for = Run.galaxy_seed
	var sys := Run.at
	var lay := SystemLayout.of(Run.node_at())
	for b in lay.bodies:
		if b.world != &"" and b.kind != &"belt":
			SystemMapScreen._parked[sys] = {"at": b.index, "mode": &"rail"}
			break
	SectorScreen._approached_at = sys
	Router.show_local()
	await _frames(40)
	_ok("a run opens on LOCAL", Router.current is SectorScreen)
	var has_looks := _zl.get_script_constant_map().has("SIDE_LOOKS")
	if has_looks:
		_looks = PackedStringArray(_zl.get_script_constant_map()["SIDE_LOOKS"])
	var want := ""
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("looks="):
			want = (a as String).substr(6)
	var run_looks: Array = Array(_looks) if not _looks.is_empty() else ["-"]
	if want != "":
		run_looks = Array(want.split(","))
	var total := 0
	for l: String in run_looks:
		_cur_look = l
		_set_look(l)
		total += await _hop("LOCAL -> map", Router.show_system, SystemMapScreen)
		total += await _hop("map -> chart", Router.show_starchart, StarchartScreen)
		total += await _hop("chart -> map", Router.show_system, SystemMapScreen)
		total += await _hop("map -> LOCAL", Router.show_local, SectorScreen)
	# a click in the middle of a swap, every look
	if has_looks:
		for l: String in run_looks:
			_cur_look = l
			_set_look(l)
			Router.show_system()
			await _idle()
			await _frames(4)
			await _click_mid_swap()
			Router.show_system()
			await _idle()
			await _frames(4)
			await _click_bar_mid_decode()
		Router.show_system()
		await _idle()
		Router.show_local()
		await _idle()
	_set_look("")
	print("  [sidebar] blank frames over every hop: %d" % total)
	# THE DIVES TOO (Tab: LOCAL to the chart and back, through black), the
	# chrome sliding in them as in the moves
	_cur_look = "E"
	_set_look("E")
	total += await _hop("LOCAL -> chart (dive)", Router.show_starchart, StarchartScreen)
	total += await _hop("chart -> LOCAL (dive)", Router.show_local, SectorScreen)
	if _ss != null:
		await _toolbar_rows()
	await _click_moving_chrome()

	# THE ANIMATION OFF: headless as the game runs it, and reduced motion
	Router.animate_in_harness = false
	ZoomLadder.force = -1
	await _instant("headless")
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	DisplaySettings.reduced_motion = true
	await _instant("reduced motion")
	DisplaySettings.reduced_motion = false
	ZoomLadder.force = -1
	ZoomLadder.fixed_dt = -1.0
	print("sidebartest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
