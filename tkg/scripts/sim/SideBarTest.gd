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
		if not ZoomLadder.busy() and ZoomLadder.chain == &"" and _swap_now() == null and _tabs_now() == null:
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


func _tabs_now() -> Object:
	return _live(&"tabs_now")


## This frame: [coverage 0..1, both-at-once 0..1, clicks let through onto
## unresolved content (count of grid points)], or [] when the screen up has no
## side bar.
func _measure() -> Array:
	var cur := Router.current
	var side := _side_of(cur)
	var sw := _swap_now()
	if side == null and sw == null:
		return []
	if sw == null:
		return [_eff(side), 0.0, 0]
	# THE SWAP DRAWN OVER IT: its own account of each point (old, new, how
	# settled the new is there), checked to be drawn at all first
	var ov := sw as CanvasItem
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
	# THE TABS: the decode seen, over the tab lit before and the one lit after
	var was_tab: Control = Router.hud.tab_for_rank(ZoomLadder.rank_of(Router.current)) if Router.hud.has_method(&"tab_for_rank") else null
	var tab_rect := Rect2()
	var tab_frames := 0
	var landed_at := -1
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
		if _swap_now() != null:
			swap_frames += 1
			decode_end = frames
		var tw := _tabs_now()
		if tw != null and (tw as CanvasItem).visible:
			tab_frames += 1
			var tr: Rect2 = tw.call(&"rect")
			tab_rect = tr if tab_rect.size.x <= 0.0 else tab_rect.merge(tr)
		if landed_at < 0 and (not ZoomLadder.busy() or ZoomLadder.active.phase == ZoomLadder.Phase.UI_IN):
			landed_at = frames
		frames += 1
		if not ZoomLadder.busy() and ZoomLadder.chain == &"" and _swap_now() == null and _tabs_now() == null:
			break
		await _tree.process_frame
	await _frames(2)
	_ok("%s lands on %s" % [label, want.get_global_name()], Router.current != null and Router.current.get_script() == want)
	_ok("%s: no blank side bar (%d of %d frames blank, least %.2f)" % [label, blank, frames, low], blank == 0)
	# (A's crossfade is allowed its middle: under 40% of its frames half and half)
	var allow := int(ceil(swap_frames * 0.4)) if (_looks.size() == 0 or _cur_look == "A") else 2
	_ok("%s: both contents half and half for %d frames (allowed %d)" % [label, mixed, allow], mixed <= allow)
	_ok("%s: no click let through onto unresolved content (%d frames)" % [label, leaked], leaked == 0)
	var side := _side_of(Router.current)
	_ok("%s: the side bar whole at rest" % label, side == null or _eff(side) > 0.99)
	if _ss != null:
		# THE TABS DECODE ON EVERY HOP, over the tab that was lit and the one
		# that is, and the highlight is the new one's once it is over
		var now_tab: Control = Router.hud.tab_for_rank(ZoomLadder.rank_of(Router.current))
		var over := was_tab != null and now_tab != null and tab_rect.has_point(was_tab.get_global_rect().get_center()) 			and tab_rect.has_point(now_tab.get_global_rect().get_center())
		_ok("%s: the top tabs decode (%d frames) over the tab lit before and the one lit after" % [label, tab_frames],
			tab_frames > 0 and over)
		_ok("%s: and the new tab is lit after, the old one not" % label, now_tab != null and now_tab.has_theme_stylebox_override("normal")
			and (was_tab == null or was_tab == now_tab or not was_tab.has_theme_stylebox_override("normal")))
	if _cur_look == "E":
		# E, SLOW (Jon: "happen slowly and not so fast"): the side bar decodes for
		# a second or more, and is done within 0.35 s of the camera landing --
		# or, on a hop shorter than that, runs on past it no longer than it needs
		var secs := swap_frames / 60.0
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


## A click on a tab that has not resolved: map -> chart, on SECTOR (lit
## before, a live door back once it is not) while the tabs decode -- eaten, and
## the chart stays up.
func _click_tab_mid_decode() -> void:
	Router.show_starchart()
	var tw: Object = null
	for i in 300:
		await _tree.process_frame
		tw = _tabs_now()
		if tw != null and (tw as CanvasItem).visible:
			break
	if not _ok("%s: the tabs decode on map -> chart" % _cur_look, tw != null):
		await _idle()
		return
	var b: Button = Router.hud.tab_for_rank(ZoomLadder.MAP)
	var p := b.get_global_rect().get_center()
	var blocked := bool(tw.call(&"blocks", p))
	var heard := [0]
	var probe := func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			heard[0] += 1
	b.gui_input.connect(probe)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		b.get_viewport().push_input(ev)
		await _tree.process_frame
	b.gui_input.disconnect(probe)
	await _idle()
	await _frames(4)
	_ok("%s: a click on SECTOR before it resolved was eaten (blocked %s, heard %d), the chart still up" % [_cur_look, blocked, heard[0]],
		blocked and heard[0] == 0 and Router.current is StarchartScreen)


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
			await _click_tab_mid_decode()
		Router.show_system()
		await _idle()
		Router.show_local()
		await _idle()
	_set_look("")
	print("  [sidebar] blank frames over every hop: %d" % total)

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
