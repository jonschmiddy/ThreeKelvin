extends Node

## One motion everywhere (Jon picked A, Oct 17): every hop is watched frame by frame.
## Run headless with `--fixed-fps 60`, so the goal line's tween steps with the ladder.
## Why: docs/why/CalmLadderTest.md#calm-ladder-checks

const SF := preload("res://scripts/ui/sysmap/ShipFlight.gd")
var _fails := 0
var _tree: SceneTree
var _zl: GDScript = load("res://scripts/ui/ZoomLadder.gd")
const JUMP_PX := 40.0
## (a few px: LOCAL's hull bobs 3 px either way, the map's ship keeps to its
## orbit and the chart's galaxy turns, all under the move)
const LINE_PX := 6.0
const SAME_PX := 4.0
const SIDE_X := 689.0
## (the chart draws your star on whole pixels as the galaxy turns under it, and
## the hull bobs)
const BACK_PX := 4.0
## (a frame at 60 a second: the ride round a ring and the world under it)
const RESUME_PX := 2.0


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


## THE FIELD AS IT STANDS: the same layer, on, under the screen, unfaded, as
## drawn ("" when so, else what is wrong).
func _field_wrong(f0: Variant, v0: int) -> String:
	var fv: Variant = Router.get("field")
	if fv == null or not is_instance_valid(fv):
		return "no field"
	var f := fv as Control
	if f != f0:
		return "a different field"
	if not bool(f.get("on")):
		return "the field off"
	if int(f.get("version")) != v0:
		return "the field redrawn (%d -> %d)" % [v0, int(f.get("version"))]
	if f.modulate.a < 0.999 or f.self_modulate.a < 0.999:
		return "the field faded"
	var cur := Router.current
	if cur != null and is_instance_valid(cur) and cur.get_parent() == f.get_parent() and cur.get_index() < f.get_index():
		return "the field over the screen"
	return ""


## Top plate this frame: drawn by the screen up, or held whole by an opaque picture.
func _plate_unsteady() -> String:
	var cur := Router.current
	var bar := ZoomLadder.bar_of(cur)
	if bar == null or not is_instance_valid(bar):
		return ""
	var r := bar.get_global_rect()
	var a := 1.0
	var n: Node = bar
	while n != null and n != Router.content:
		if n is CanvasItem:
			a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	var held := false
	if ZoomLadder.busy():
		var cv: Variant = ZoomLadder.active.get("_calm_covers")
		if cv is Array:
			for c: Variant in cv:
				if not is_instance_valid(c) or not (c as CanvasItem).is_visible_in_tree():
					continue
				var cr := (c as Control).get_global_rect()
				if not cr.intersects(r):
					continue
				if not cr.grow(1.0).encloses(r):
					return "held in part (%s over %s)" % [cr, r]
				var tex: Texture2D = (c as TextureRect).texture
				var img: Image = (tex as AtlasTexture).atlas.get_image() if tex is AtlasTexture else (tex.get_image() if tex != null else null)
				if img != null and img.detect_alpha() != Image.ALPHA_NONE:
					return "held see-through (its picture has alpha)"
				held = true
	if not held and a < 0.999 and a > 0.001:
		# (a hurried crossfade running on past the landing: the plate as held,
		# opaque, going as the live one comes -- the two adding to one)
		var L := ZoomLadder.active if ZoomLadder.busy() else null
		if L != null and (L._rect as CanvasItem).visible and absf(L.held_alpha() + a - 1.0) < 0.02:
			return ""
		return "drawn at %.2f" % a
	return ""


## The screens' own panels sliding (`PanelSlide`, by name: none on a build
## without it).
var _ps: Script = load("res://scripts/ui/PanelSlide.gd") if ResourceLoader.exists("res://scripts/ui/PanelSlide.gd") else null


func _panel_slides() -> Array:
	return (_ps.get("live") as Array) if _ps != null else []


## A moving panel must be the screen's own control, opaque, with words on it.
func _panel_blank(ps: Object) -> String:
	var t: Control = ps.get("target")
	if t == null or not is_instance_valid(t):
		return "gone"
	if not t.is_visible_in_tree():
		return "hidden"
	var a := 1.0
	var n: Node = t
	while n != null and n != Router.content:
		if n is CanvasItem:
			a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	if a < 0.99:
		return "faded to %.2f" % a
	var words := 0
	var stack: Array = [t]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is CanvasItem and not (c as CanvasItem).visible:
			continue
		if (c is Label and (c as Label).text.strip_edges() != "" and (c as Label).modulate.a > 0.9) \
				or (c is Button and (c as Button).text.strip_edges() != "" and (c as Button).modulate.a > 0.9) \
				or (c is RichTextLabel and (c as RichTextLabel).get_parsed_text().strip_edges() != ""):
			words += 1
		for k: Node in c.get_children():
			stack.append(k)
	if words == 0:
		return "no words on it"
	return ""


## A side panel or toolbar piece of the ladder's up this frame: a column or a
## band sliding (`ChromeSlide`, `SideBand`), or a decode drawn (`SideSwap`).
func _side_chrome_up() -> bool:
	for pc: Variant in ChromeSlide.live:
		if is_instance_valid(pc) and (pc as CanvasItem).is_visible_in_tree():
			return true
	for b: Variant in SideBand.live:
		if is_instance_valid(b) and (b as CanvasItem).is_visible_in_tree():
			return true
	for sw: Variant in SideSwap.live:
		if is_instance_valid(sw) and (sw as CanvasItem).is_visible_in_tree():
			return true
	for ps: Variant in _panel_slides():
		if is_instance_valid(ps) and not bool(ps.get("done")):
			return true
	return false


## The camera between distances is moving; not the UI beats either side of it.
func _camera_moving() -> bool:
	if not ZoomLadder.busy():
		return false
	var ph := int(ZoomLadder.active.phase)
	var names: Array = ZoomLadder.Phase.keys()
	var nm := String(names[ph]) if ph >= 0 and ph < names.size() else ""
	return nm in ["PRE", "WAIT", "MOVE", "C_CAM"]


func held_on_now() -> bool:
	return ZoomLadder.busy() and ZoomLadder.active.get("_rect") != null and (ZoomLadder.active._rect as CanvasItem).visible


func _rank(s: Control) -> int:
	return ZoomLadder.rank_of(s)


func _target_s(a: int, b: int) -> float:
	for m: Dictionary in _zl.get_script_method_list():
		if String(m.name) == "calm_length":
			return float(_zl.call(&"calm_length", a, b))
	return 1.55


## The chrome by piece id, with what would show it moving.
func _chrome_state() -> Dictionary:
	var out := {}
	for sw: Variant in SideSwap.live:
		if is_instance_valid(sw):
			out[(sw as Object).get_instance_id()] = "%.3f %s" % [float((sw as Object).get("t")), (sw as CanvasItem).visible]
	for p: Variant in ChromeSlide.live:
		if is_instance_valid(p):
			out[(p as Object).get_instance_id()] = "%.3f" % float((p as Object).get("k"))
	for b: Variant in SideBand.live:
		if is_instance_valid(b):
			out[(b as Object).get_instance_id()] = "%.1f" % (b as Control).size.y
	for ps: Variant in _panel_slides():
		if is_instance_valid(ps):
			out[(ps as Object).get_instance_id()] = "%.3f" % float(ps.get("k"))
	var cur := Router.current
	for c: Variant in [ZoomLadder.side_of(cur), ZoomLadder.bar_of(cur)]:
		if c != null and is_instance_valid(c) and (c as Control).is_visible_in_tree():
			var r := (c as Control).get_global_rect()
			out[(c as Object).get_instance_id()] = "%.0f,%.0f,%.2f" % [r.position.x, r.position.y, (c as CanvasItem).modulate.a]
	return out


## Whether any piece there both times changed.
func _chrome_changed(a: Dictionary, b: Dictionary) -> bool:
	for k: Variant in a:
		if b.has(k) and str(a[k]) != str(b[k]):
			return true
	return false


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)


## A real click, as a hand makes it (`NavFilm`'s): the pointer there, a
## moment's hover, down, two frames, up.
func _click(at: Vector2, c: Control = null) -> void:
	var vp := GameShell.input_target(_tree)
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	vp.push_input(mm)
	if c != null:
		c.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _frames(3)
	for down in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = at
		mb.global_position = at
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		vp.push_input(mb)
		if down:
			await _frames(2)
	if c != null and is_instance_valid(c):
		c.notification(Control.NOTIFICATION_MOUSE_EXIT)


func _tab_button(rank: int) -> Button:
	var h := Router.hud
	return h._tab_sector if rank == ZoomLadder.LOCAL else (h._tab_system if rank == ZoomLadder.MAP else h._tab_chart)


## Your ship's place at rest, the mean of 40 frames (its hull's bob averaged);
## the maps' holds watched on through them (`_watch_hold`) when given `seen`.
func _rest_pt(seen: Variant = null, was: Variant = null) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for i in 40:
		var q := _ship(Router.current)
		if q != Vector2.INF:
			sum += q
			n += 1
		await _tree.process_frame
		if seen is Dictionary:
			_watch_hold(seen, was)
	return sum / float(n) if n > 0 else Vector2.INF


## Measures how far the ship and clock move during the hold, on every map there is.
## Why: docs/why/CalmLadderTest.md#clock-hold
func _watch_hold(seen: Dictionary, was: Variant) -> void:
	var maps: Array = []
	for sv: Variant in [Router.current, ZoomLadder.prebuilt_screen(), was]:
		if is_instance_valid(sv) and sv is SystemMapScreen and not sv in maps:
			maps.append(sv)
	for m: SystemMapScreen in maps:
		if m.flight == null or m.view == null or not m.has_method(&"clock_held"):
			continue
		var p: Vector3 = m.flight.where3()
		var id := m.get_instance_id()
		# (from the second frame a map is seen: one built ahead is first seen
		# before its first step has put the ship on its ring)
		if not seen.has(id):
			seen[id] = {}
			continue
		var w: Dictionary = seen[id]
		if m.clock_held():
			if not w.has("p"):
				w = {"p": p, "t": float(m.view.t), "n": 0, "moved": 0.0, "ran": 0.0}
			w.n = int(w.n) + 1
			w.moved = maxf(float(w.moved), p.distance_to(w.p))
			w.ran = maxf(float(w.ran), absf(float(m.view.t) - float(w.t)))
			w.last = p
		elif w.has("p"):
			var last: Vector3 = w.get("last", w.p)
			w.resume = maxf(float(w.get("resume", 0.0)), p.distance_to(last))
			w.went = maxf(float(w.get("went", 0.0)), p.distance_to(w.p))
			w.last = p
			w.mode = m.flight.mode
		seen[id] = w


func _tab_at(rank: int) -> Vector2:
	var h := Router.hud
	var b: Button = h._tab_sector if rank == ZoomLadder.LOCAL else (h._tab_system if rank == ZoomLadder.MAP else h._tab_chart)
	return b.get_global_rect().get_center()


## One hop, watched. `press`: [kind, at what share of the hop's target] to press
## mid-move ("key", "click", "tab").
func _hop(label: String, go: Callable, want: int, press: Array = []) -> void:
	var from := _rank(Router.current)
	var target := _target_s(from, want)
	# (where it rests, over a bob's worth of frames: the line's two ends)
	var p0 := await _rest_pt()
	var pts: Array = []
	# (the camera's own path: from the last frame before it moves, to the end)
	var cam_pts: Array = []
	var cam_on := false
	var cam_done := false
	# Order (Jon, Oct 17): side panel in after the camera leaves LOCAL, out before it enters.
	var cam_first := -1
	var cam_last := -1
	# ONE FIELD: as it stood before the hop, and the frames it was not that
	var field0: Variant = Router.get("field")
	var field_v0: int = int((field0 as Object).get("version")) if field0 != null else -1
	var field_bad := 0
	var field_why := ""
	# THE PANELS DRAWN AS THEY MOVE: frames one moved, frames one moved blank
	var local_hop := from == ZoomLadder.LOCAL or want == ZoomLadder.LOCAL
	var panel_moving := 0
	var panel_blank := 0
	var blank_why := ""
	# THE TOP PLATE STEADY between the map and the chart (Jon: "the border on
	# the top panel flickers?"): frames it was not drawn by one opaque thing
	var map_chart := (from == ZoomLadder.MAP or from == ZoomLadder.CHART) and (want == ZoomLadder.MAP or want == ZoomLadder.CHART)
	var plate_shaky := 0
	var plate_why := ""
	# THE GOAL, a fixed piece of the HUD: frames it was not up in its place
	var goal_off := 0
	var goal_why := ""
	var gnode: Control = Router.hud.get("goal") if Router.hud != null else null
	var ghost := 0
	var ghost_why := ""
	var panel_first := -1
	var panel_last := -1
	var bad: Array = []
	var held_last := -1.0
	var chrome_last := _chrome_state()
	var chrome_moved := 0
	var last_old_pt := p0
	var was := Router.current
	var frames := 0
	var pressed_at := -1
	var press_done := false
	var swap_seen := false
	var max_apart := 0.0
	var under_side := 0
	var began := false
	var holds := {}
	go.call()
	for i in 900:
		await _tree.process_frame
		frames += 1
		_watch_hold(holds, was)
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
		if not held_on_now():
			last_old_pt = live
		elif not swap_seen:
			swap_seen = true
			# THE SCREENS CHANGE HANDS UNDER THE HELD PICTURE, WHOLE
			if held_a < 0.95:
				bad.append("the screens changed hands with the held picture at %.2f (a one-frame swap)" % held_a)
		# ONE SHIP: both drawn, the held picture part-way gone; whole, it covers the screen.
		if held_a > 0.05 and held_a < 0.999 and live_a > 0.05 and held_pt != Vector2.INF and live != Vector2.INF:
			var apart := held_pt.distance_to(live)
			max_apart = maxf(max_apart, apart)
			if apart > SAME_PX and OS.get_cmdline_user_args().has("debug"):
				var L2 := ZoomLadder.active
				print("    apart %.1f f%d held %s live %s (%s) old pt %s from %s to %s scl %s ph %s %s" % [apart, frames, held_pt, live, cur.get_class(), last_old_pt,
					L2._mat.get_shader_parameter(&"from_pt"), L2._mat.get_shader_parameter(&"to_pt"), L2._mat.get_shader_parameter(&"scl"), L2.phase,
					[(cur as SectorScreen)._lad.get("fixed"), (cur as SectorScreen)._lad_zs] if cur is SectorScreen else
					([(cur as StarchartScreen)._chart.size, (cur as StarchartScreen)._chart.zoom, (cur as StarchartScreen)._chart.pan, L2._calm_p(L2._calm_e), L2._calm_e] if cur is StarchartScreen else "")])
		# NO ONE-FRAME SWAP
		var held_on := ZoomLadder.busy() and ZoomLadder.active.get("_rect") != null and (ZoomLadder.active._rect as CanvasItem).visible
		if held_last >= 0.0 and absf((held_a if held_on else 0.0) - held_last) > (0.35 if pressed_at >= 0 else 0.2):
			bad.append("the held picture went %.2f -> %.2f in one frame" % [held_last, held_a if held_on else 0.0])
		held_last = held_a if held_on else -1.0
		var pt := held_pt if held_a >= 0.5 and held_pt != Vector2.INF else live
		if pt != Vector2.INF:
			if not pts.is_empty():
				var d: float = pt.distance_to(pts[-1])
				if d > JUMP_PX:
					bad.append("your ship jumped %.0f px in a frame" % d)
				# THE CHROME STILL WHILE THE CAMERA MOVES
				var ch := _chrome_state()
				if _camera_moving() and _chrome_changed(chrome_last, ch):
					chrome_moved += 1
					if OS.get_cmdline_user_args().has("debug"):
						print("    chrome f%d %s -> %s" % [frames, chrome_last, ch])
				chrome_last = ch
			else:
				chrome_last = _chrome_state()
			if pt.x > SIDE_X and (_rank(cur) != ZoomLadder.LOCAL or held_a >= 0.5):
				under_side += 1
			pts.append(pt)
			if _camera_moving() and not cam_on:
				cam_on = true
				if pts.size() > 1:
					cam_pts.append(pts[-2])
			if cam_on and not cam_done:
				cam_pts.append(pt)
				# (the line ends where the camera lands: the frame after its last)
				if not _camera_moving():
					cam_done = true
		if _camera_moving():
			if cam_first < 0:
				cam_first = frames
			cam_last = frames
		if _side_chrome_up():
			if panel_first < 0:
				panel_first = frames
			panel_last = frames
		var fw := _field_wrong(field0, field_v0)
		if fw != "":
			field_bad += 1
			if field_why == "":
				field_why = "%s at frame %d" % [fw, frames]
		# One goal: while the held picture is drawn, the goal is cut out of it, not carried twice.
		if gnode != null and gnode.visible and ZoomLadder.busy() and (ZoomLadder.active._rect as CanvasItem).visible:
			var gr := Rect2(gnode.position, gnode.size).grow(1.0)
			var cv: Variant = (ZoomLadder.active._mat as ShaderMaterial).get_shader_parameter(&"cut")
			var cut := Rect2((cv as Vector4).x, (cv as Vector4).y, (cv as Vector4).z, (cv as Vector4).w) if cv is Vector4 else Rect2()
			if not cut.encloses(gr):
				ghost += 1
				if ghost_why == "":
					ghost_why = "the held picture's cut %s, the goal %s, frame %d" % [cut, gr, frames]
		if gnode != null and _rank(Router.current) >= ZoomLadder.CHART and _rank(Router.current) <= ZoomLadder.LOCAL:
			var gok: bool = gnode.visible and gnode.modulate.a > 0.99 and gnode.position == GoalLine.fixed_at()
			if not gok:
				goal_off += 1
				if goal_why == "":
					goal_why = "%s at %s, alpha %.2f, frame %d" % ["up" if gnode.visible else "hidden", gnode.position, gnode.modulate.a, frames]
		if map_chart:
			var pw := _plate_unsteady()
			if pw != "":
				plate_shaky += 1
				if plate_why == "":
					plate_why = "%s at frame %d" % [pw, frames]
		for psv: Variant in _panel_slides():
			if not is_instance_valid(psv) or bool(psv.get("done")):
				continue
			panel_moving += 1
			var why := _panel_blank(psv)
			if why != "":
				panel_blank += 1
				if blank_why == "":
					blank_why = "%s %s at frame %d" % [psv.get("kind"), why, frames]
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
		if ZoomLadder.busy():
			began = true
		if _settled() and (began or frames > 40):
			break
	var secs := frames / 60.0
	var p1 := await _rest_pt(holds, was)
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
	# THE LINE: from where the camera set off (your ship goes round its orbit,
	# and bobs, before that as at rest) to where it rests
	if not cam_pts.is_empty():
		p0 = cam_pts[0]
		pts = cam_pts
		if cam_done:
			p1 = cam_pts[-1]
	if p0 != Vector2.INF and p1 != Vector2.INF and pts.size() > 1:
		var dir := p1 - p0
		var len := dir.length()
		var qi := 0
		for q: Vector2 in pts:
			qi += 1
			if len > 0.5:
				var n := dir / len
				var o := absf((q - p0).cross(n))
				if o > LINE_PX and OS.get_cmdline_user_args().has("debug"):
					print("    off %.1f at point %d of %d: %s (line %s -> %s)" % [o, qi, pts.size(), q, p0, p1])
				off = maxf(off, o)
			else:
				off = maxf(off, q.distance_to(p0))
		if len > 10.0:
			var n2 := dir / len
			var best := -INF
			for q: Vector2 in pts:
				var s := (q - p0).dot(n2)
				back = maxf(back, best - s)
				best = maxf(best, s)
	var two := not press.is_empty() and String(press[0]) == "tab"
	if not two:
		_ok("%s: your ship on one straight line from where it rested to where it rests (%.1f px off it at most)" % [label, off], off <= LINE_PX)
		_ok("%s: and never turning back along it (%.1f px back at most)" % [label, back], back <= BACK_PX)
	_ok("%s: and never under the side bar (%d frames)" % [label, under_side], under_side == 0)
	_ok("%s: the side bar, the toolbar, the column and the band still while the camera moves (%d frames moving)" % [label, chrome_moved], chrome_moved <= 1)
	if gnode != null:
		_ok("%s: the goal up in its one place on every frame (%d frames not%s)" % [label, goal_off, "" if goal_why == "" else ": " + goal_why], goal_off == 0)
		_ok("%s: one goal -- left out of the picture held on every frame it is drawn (%d frames not%s)" % [label, ghost, "" if ghost_why == "" else ": " + ghost_why], ghost == 0)
	if map_chart:
		_ok("%s: the top plate steady -- one opaque thing draws it every frame, the plate itself or it as held (%d frames not%s)" % [label, plate_shaky, "" if plate_why == "" else ": " + plate_why], plate_shaky == 0)
	_ok("%s: one field under it all -- the same layer, on, under the screens, never faded or redrawn (%d frames not%s)" % [label, field_bad, "" if field_why == "" else ": " + field_why], field_bad == 0)
	if local_hop:
		_ok("%s: the side panel and toolbar drawn on every frame they move, never an empty plate (%d of %d frames blank%s)" % [label, panel_blank, panel_moving, "" if blank_why == "" else ": " + blank_why], panel_blank == 0)
		if press.is_empty():
			_ok("%s: and they do move, the screen's own (%d frames)" % [label, panel_moving], panel_moving > 0)
	if press.is_empty() and from == ZoomLadder.LOCAL and want != ZoomLadder.LOCAL:
		_ok("%s: the side panel comes in only after the camera has landed (camera to frame %d, panel from %d)" % [label, cam_last, panel_first],
			cam_last >= 0 and panel_first > cam_last)
	if press.is_empty() and want == ZoomLadder.LOCAL and from != ZoomLadder.LOCAL:
		_ok("%s: the side panel is gone before the camera moves (panel to frame %d, camera from %d)" % [label, panel_last, cam_first],
			cam_first >= 0 and panel_last < cam_first)
	if press.is_empty():
		_ok("%s: %.2f s, within 10%% of its %.2f s" % [label, secs, target], absf(secs - target) <= target * 0.1)
	elif two:
		# (Tab mid-move: the move hurried to the map, then the map to the chart)
		var after2 := (frames - pressed_at) / 60.0
		var next := _target_s(ZoomLadder.MAP, want)
		_ok("%s: the press hurried the move and went on to the next distance in %.2f s (under %.2f)" % [label, after2, 0.45 + next * 1.1], after2 <= 0.45 + next * 1.1)
	else:
		var after := (frames - pressed_at) / 60.0
		_ok("%s: the press hurried the move to its end in %.2f s (under 0.45)" % [label, after], after <= 0.45)
	# THE SHIP HOLDS WITH THE MAP'S CLOCK, and goes on from where it held
	var held_n := 0
	var moved := 0.0
	var ran := 0.0
	var resume := -1.0
	var went := -1.0
	var riding := false
	for w: Dictionary in holds.values():
		if not w.has("p"):
			continue
		held_n += int(w.n)
		moved = maxf(moved, float(w.moved))
		ran = maxf(ran, float(w.ran))
		if w.has("resume"):
			resume = maxf(resume, float(w.resume))
			went = maxf(went, float(w.went))
			riding = riding or w.mode == &"rail"
	if from == ZoomLadder.MAP or want == ZoomLadder.MAP:
		_ok("%s: a map's clock held through the move (%d frames)" % [label, held_n], held_n > 0)
		_ok("%s: and your ship held with it (%.3f px and %.4f s on at most)" % [label, moved, ran], moved <= 0.001 and ran == 0.0)
	if want == ZoomLadder.MAP and _rank(Router.current) == ZoomLadder.MAP:
		_ok("%s: and on from where it held when the clock runs again (%.2f px a frame at most)" % [label, resume], resume >= 0.0 and resume <= RESUME_PX)
		if riding:
			_ok("%s: riding its ring again (%.2f px on from where it held)" % [label, went], went > 1.0)
	print("  [calm] %s: %.2f s (target %.2f), off line %.1f, back %.1f, apart %.1f, chrome %d, held %d frames, moved %.3f, then %.2f a frame, %.1f on" % [label, secs, target, off, back, max_apart, chrome_moved, held_n, moved, resume, went])


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
		return func() -> void: _click(_tab_at(r), _tab_button(r))
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
	await _preview_holds()
	# (a fast flight on each path, held by a move and landed after)
	await _flight_holds(&"curved")
	await _flight_holds(&"direct")
	# (while your ship is still on its ring)
	await _keys_let_go(&"d")
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
		# (arriving, as a jump does: in at the edge, the map's own arrival)
		if Router.current is SystemMapScreen:
			await _at(L)
		Router._post_arrive = true
		Router.show_system()
		await _frames(300)
		await _rest()
		var mp := Router.current as SystemMapScreen
		print("  [calm] at the edge: your ship at %s, flying %s" % [_ship(mp), mp.flight.mode if mp != null and mp.flight != null else &"-"])
		await _hop("tab map -> LOCAL, at the edge", tab.call(L), L)
		await _rest()
		await _hop("tab LOCAL -> map, at the edge", tab.call(M), M)
		await _rest()
	await _partner_holds()
	await _goal_line()
	await _no_box()
	await _field_drift()
	# (last: it flies your ship off its ring)
	await _keys_let_go(&"w")
	ZoomLadder.force = -1
	ZoomLadder.fixed_dt = -1.0
	print("calmladdertest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)


## A partner holds with the map clock as your ship does, easing on once the clock runs.
## Why: docs/why/CalmLadderTest.md#partner-hold
func _partner_holds() -> void:
	await _at(ZoomLadder.LOCAL)
	var L: SystemLayout = SystemLayout.of(Run.node_at())
	var w := -1
	for b in L.bodies:
		if b.world != &"" and b.kind != &"belt":
			w = b.index
			break
	if w < 0:
		_ok("a partner's hold: a world to put it off", false)
		return
	var id := 70011
	Net.roster[id] = {"id": id, "at": Run.at, "order": 95, "name": "Mercer"}
	Net.spots[id] = {"at": Run.at, "body": w, "x": 30.0, "z": 0.0, "ang": 0.0}
	_click(_tab_at(ZoomLadder.MAP), _tab_button(ZoomLadder.MAP))
	var held_n := 0
	var held_moved := 0.0
	var held_at := Vector2.INF
	var after_n := 0
	var after_step := 0.0
	var last := Vector2.INF
	var first := Vector2.INF
	var ended := Vector2.INF
	for i in 420:
		await _tree.process_frame
		if i % 10 == 9 and after_n == 0:
			Net.spots[id].x = float(Net.spots[id].x) + 6.0
		var m: SystemMapScreen = null
		for sv: Variant in [Router.current, ZoomLadder.prebuilt_screen()]:
			if is_instance_valid(sv) and sv is SystemMapScreen:
				m = sv
				break
		if m == null or not m.has_method(&"clock_held"):
			continue
		# (on the plane: the camera moves under it through the move)
		var drawn := Vector2.INF
		for e: Array in m.overlay.partner_at:
			if int(e[0]) == id:
				drawn = m.overlay._partner_plane.get(id, Vector2.INF)
		if drawn == Vector2.INF:
			continue
		if m.clock_held():
			# (from the second frame drawn: the first is where it is first put)
			if first == Vector2.INF:
				first = drawn
			else:
				held_n += 1
				held_moved = maxf(held_moved, drawn.distance_to(first))
			held_at = drawn
		elif held_at != Vector2.INF:
			if ended == Vector2.INF:
				ended = held_at
			after_n += 1
			after_step = maxf(after_step, drawn.distance_to(last))
			if after_n >= 120 and _settled():
				break
		last = drawn
	_ok("a partner drawn on the map while its clock holds for the move (%d frames)" % held_n, held_n > 20)
	_ok("and held there with your ship, its reports moving on meanwhile (%.2f px at most)" % held_moved, held_moved <= 0.01)
	_ok("and eased on to its latest report once the clock runs (%.1f px on, at most %.1f a frame)" % [last.distance_to(ended) if ended != Vector2.INF else -1.0, after_step],
		after_n > 0 and last.distance_to(ended) > 2.0 and after_step <= JUMP_PX)
	print("  [calm] a partner through LOCAL -> map: held %d frames, moved %.2f px, then %.1f px on, at most %.1f a frame" % [held_n, held_moved,
		last.distance_to(ended) if ended != Vector2.INF else -1.0, after_step])
	Net.roster.erase(id)
	Net.spots.erase(id)
	await _rest()


## A preview is kept through the hold; riding on frame time made each plan stale and re-asked.
## Why: docs/why/CalmLadderTest.md#preview-hold
func _preview_holds() -> void:
	await _at(ZoomLadder.MAP)
	var m := Router.current as SystemMapScreen
	if not _ok("a preview's hold: the map up", m != null and m.flight != null):
		return
	var at: int = m.flight.orbit_body()
	# (another place round the sun, else the sun's close orbit)
	var to := -1
	for b in m.view.layout.bodies:
		if b.index != at and SystemLayout.is_place(b.index) and b.kind != &"belt":
			to = b.index
			break
	if not _ok("a preview's hold: your ship on a ring and another place to fly to (on %d, to %d)" % [at, to], at >= 0 and to != at and m.flight.mode == &"rail"):
		return
	m.select_body(to)
	var ov = m.overlay
	for i in 240:
		await _tree.process_frame
		if ov._pv_plan != null:
			break
	await _frames(10)
	var drawn = ov._pv_plan
	if not _ok("a preview drawn before the move", drawn != null):
		m.select_body(-9)
		return
	var n0: int = m.flight.n_bg
	_click(_tab_at(ZoomLadder.CHART), _tab_button(ZoomLadder.CHART))
	var held_n := 0
	var taken := 0
	var kept := true
	for i in 300:
		await _tree.process_frame
		if not is_instance_valid(m) or not m.is_inside_tree():
			break
		if not m.clock_held():
			# (the press lands a few frames on; the hold is over once it was on)
			if held_n > 0 or i > 30:
				break
			continue
		held_n += 1
		taken = m.flight.n_bg - n0
		kept = kept and ov._pv_plan == drawn
	_ok("the map's clock held through the move (%d frames)" % held_n, held_n > 20)
	_ok("and the flight drawn kept through it, at most one more plan taken in (%d)" % taken, kept and taken <= 1)
	print("  [calm] a preview through map -> chart: held %d frames, %d plans taken in, the drawn flight kept %s" % [held_n, taken, kept])
	await _rest()


## A fast flight holds with the map's clock: mid-flight map -> chart, the ship stands still
## through the hold and is at its place back on the map.
## Why: docs/why/CalmLadderTest.md#fast-flight-holds
func _flight_holds(path: StringName) -> void:
	await _at(ZoomLadder.MAP)
	await _rest()
	var m := Router.current as SystemMapScreen
	if not _ok("a %s flight's hold: the map up" % path, m != null and m.flight != null):
		return
	for i in 600:
		if m.flight.can_fly():
			break
		await _tree.process_frame
	var at: int = m.flight.orbit_body()
	var to := -1
	for b in m.view.layout.bodies:
		if b.index != at and SystemLayout.is_place(b.index) and b.kind != &"belt":
			to = b.index
			break
	# (else the sun's close orbit, as `_preview_holds` takes)
	if not _ok("a %s flight's hold: your ship on a ring and a place to fly to (on %d, to %d)" % [path, at, to], to != at and m.flight.can_fly()):
		return
	var was: StringName = SF.path_k
	SF.path_k = path
	m.select_body(-9)
	m.fly_to_body(to)
	for i in 600:
		await _tree.process_frame
		if m.flight.mode == &"fly":
			break
	if not _ok("the %s flight leaves (%s)" % [path, m.flight.mode], m.flight.mode == &"fly"):
		SF.path_k = was
		return
	await _frames(15)
	var pace := float(m.flight.plan.pace) if m.flight.plan != null else 0.0
	_click(_tab_at(ZoomLadder.CHART), _tab_button(ZoomLadder.CHART))
	var held_n := 0
	var moved := 0.0
	var ran := 0.0
	var p0 := Vector3.INF
	var t0 := 0.0
	for i in 300:
		await _tree.process_frame
		if not is_instance_valid(m) or not m.is_inside_tree():
			break
		if not m.clock_held():
			if held_n > 0 or i > 30:
				break
			continue
		if held_n == 0:
			p0 = m.flight.where3()
			t0 = float(m.view.t)
		held_n += 1
		moved = maxf(moved, (m.flight.where3() - p0).length())
		ran = maxf(ran, absf(float(m.view.t) - t0))
	_ok("a %s flight at pace %.0f: the map's clock held through the move (%d frames), the ship stood still in it (%.4f px, the clock %.4f s)" % [path, pace, held_n, moved, ran],
		held_n > 20 and moved < 0.01 and ran < 1e-6 and pace == float(SF.FLIGHT_PACE[path]))
	await _rest()
	await _at(ZoomLadder.MAP)
	await _rest()
	var landed := false
	for i in 900:
		var m2 := Router.current as SystemMapScreen
		if m2 != null and m2.flight != null and m2.flight.reached() == to and m2.flight.can_fly():
			landed = true
			break
		await _tree.process_frame
	_ok("and back on the map the %s flight is at place %d" % [path, to], landed)
	SF.path_k = was
	await _rest()


## A key let go during the hold must go quiet on the next frame, flame out.
func _keys_let_go(key: StringName) -> void:
	await _at(ZoomLadder.MAP)
	var m := Router.current as SystemMapScreen
	if not _ok("a key let go in a hold (%s): the map up" % key, m != null and m.flight != null):
		return
	m.harness_keys = true
	m._wasd[String(key)] = true
	await _frames(20)
	var want0 := Audio.ship_want
	var mode0: StringName = m.flight.mode
	var want_mode: StringName = &"free" if key == &"w" else &"rail"
	_ok("a key let go in a hold (%s): held before the move, the ship %s and sounding (%.2f)" % [key, mode0, want0],
		mode0 == want_mode and want0 > 0.3)
	_click(_tab_at(ZoomLadder.CHART), _tab_button(ZoomLadder.CHART))
	var held_n := 0
	var after := 0
	var loud := 0
	var lit := 0
	var loud_before := 0
	for i in 300:
		await _tree.process_frame
		if not is_instance_valid(m) or not m.is_inside_tree():
			break
		if not m.clock_held():
			if held_n > 0 or i > 30:
				break
			continue
		held_n += 1
		if held_n < 5:
			loud_before += 1 if Audio.ship_want > 0.3 else 0
		elif held_n == 5:
			m._wasd[String(key)] = false
		else:
			after += 1
			loud += 1 if Audio.ship_want > 0.0 else 0
			lit += 1 if m.flight.burn else 0
	if is_instance_valid(m):
		m.harness_keys = false
	_ok("a key let go in a hold (%s): the move held the clock (%d frames) with the key still sounding before it was let go (%d of 4)" % [key, held_n, loud_before],
		held_n > 20 and loud_before == 4)
	_ok("and quiet from the frame after it was let go, its flame out (%d of %d frames sounding, %d lit)" % [loud, after, lit],
		after > 10 and loud == 0 and lit == 0)
	print("  [calm] %s let go in a map -> chart hold: held %d frames, %d of %d after sounding, %d lit" % [key, held_n, loud, after, lit])
	await _rest()


## A drag on the picture, as a hand makes one: down at `from`, a slide to `to`
## over `n` frames, up.
func _drag(from: Vector2, to: Vector2, n: int = 40) -> void:
	var vp := GameShell.input_target(_tree)
	var last := from
	for i in n + 2:
		if i == 1 or i == n + 1:
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			mb.pressed = i == 1
			mb.position = last
			mb.global_position = last
			mb.button_mask = MOUSE_BUTTON_MASK_LEFT if i == 1 else 0
			vp.push_input(mb)
		else:
			var u := clampf(float(i - 1) / float(n), 0.0, 1.0)
			var at := from.lerp(to, u * u * (3.0 - 2.0 * u)).round()
			var mm := InputEventMouseMotion.new()
			mm.position = at
			mm.global_position = at
			mm.relative = at - last
			mm.button_mask = MOUSE_BUTTON_MASK_LEFT if i > 1 else 0
			vp.push_input(mm)
			last = at
		await _tree.process_frame


## Pans drift the field (Jon asked where parallax went); a hop never moves or restores it.
## Why: docs/why/CalmLadderTest.md#field-drift
func _field_drift() -> void:
	var f: NavField = Router.field
	if not _ok("drift: the field is there", f != null and is_instance_valid(f)):
		return
	for r: int in [ZoomLadder.CHART, ZoomLadder.MAP]:
		await _at(r)
		await _frames(20)
		var p0 := f.pan
		var q0: Variant = NavField.screen_pan(Router.current)
		var pic: Rect2 = Router.current.call(&"ladder_picture")
		var c := pic.get_center()
		await _drag(c + Vector2(80, 20), c + Vector2(-60, -10))
		await _frames(20)
		var p1 := f.pan
		var q1: Variant = NavField.screen_pan(Router.current)
		var want: Vector2 = ((q1 as Vector2) - (q0 as Vector2)) if q0 is Vector2 and q1 is Vector2 else Vector2.ZERO
		_ok("drift: a drag on the %s slides the field the way its own sky went (%s -> %s: %s, its sky %s)" % [_nm(r), p0, p1, p1 - p0, want],
			(p1 - p0).length() >= 2.0 and (p1 - p0).dot(want) > 0.0 and ((p1 - p0) - want.round()).length() <= 1.5)
		# (and a hop away: still where it was when it lands)
		var away := ZoomLadder.LOCAL if r == ZoomLadder.CHART else ZoomLadder.CHART
		await _hop("drift: tab %s -> %s after a drag" % [_nm(r), _nm(away)], func() -> void: _click(_tab_at(away), _tab_button(away)), away)
		await _rest()
		await _frames(10)
		_ok("drift: across the hop %s -> %s the field stands where it was (%s, then %s)" % [_nm(r), _nm(away), p1, f.pan], f.pan == p1)
		if away == ZoomLadder.LOCAL:
			var sky := NavField.live_local_sky()
			var fm: ShaderMaterial = sky.get("_far_mat") if sky != null else null
			var lp: Variant = fm.get_shader_parameter("u_skyPan") if fm != null else null
			if fm == null:
				print("  --   drift: LOCAL's sky is not drawn here (headless); its stars against the field's are read windowed (FieldEdgeTest)")
				continue
			_ok("drift: LOCAL arrived lies where the field has slid to (its sky %s, the field %s)" % [lp, f.pan],
				lp is Vector2 and (lp as Vector2).is_equal_approx(f.pan))


## The goal line is gone while the camera moves. No box round the picture (Jon, Oct 18).
## Why: docs/why/CalmLadderTest.md#goal-line-and-box
func _no_box() -> void:
	for r: int in [ZoomLadder.MAP, ZoomLadder.CHART]:
		await _at(r)
		var cur := Router.current
		var pic: Control = null
		var key: Variant = null
		if cur is SystemMapScreen:
			pic = (cur as SystemMapScreen)._frame
			key = (cur as SystemMapScreen)._box.material
		elif cur is StarchartScreen:
			pic = (cur as StarchartScreen)._chart
			key = (cur as StarchartScreen)._chart._sky.material if (cur as StarchartScreen)._chart._sky != null else null
		var wrap := pic.get_parent() as Control if pic != null else null
		var sb: StyleBox = wrap.get_theme_stylebox(&"panel") if wrap != null else null
		var drawn := sb != null and not (sb is StyleBoxEmpty) and (not (sb is StyleBoxFlat) or (sb as StyleBoxFlat).bg_color.a > 0.0
			or (sb as StyleBoxFlat).border_width_left + (sb as StyleBoxFlat).border_width_top + (sb as StyleBoxFlat).border_width_bottom > 0)
		_ok("%s: the picture's frame draws no line and fills nothing (%s)" % [_nm(r), sb], not drawn)
		var fade := 0.0
		var fr := Vector4.ZERO
		if key is ShaderMaterial:
			var fd: Variant = (key as ShaderMaterial).get_shader_parameter(&"fade")
			fade = float(fd) if fd != null else 0.0
			var fv: Variant = (key as ShaderMaterial).get_shader_parameter(&"frame")
			if fv is Vector4:
				fr = fv
		# The chart's sky runs past its picture and fades out (Jon: galaxy vanished near panel).
		var want := pic.get_global_rect()
		if cur is StarchartScreen and (cur as StarchartScreen)._chart.sky_out.has_area():
			var so: Rect2 = (cur as StarchartScreen)._chart.sky_out
			want = Rect2((cur as StarchartScreen)._chart.global_position + so.position, so.size)
		_ok("%s: what the picture holds fades out toward its edge (%.0f px), on its frame as it stands (%s, want %s)" % [_nm(r), fade, fr, want],
			fade >= 16.0 and fr.z > 0.0 and absf(fr.x - want.position.x) < 1.0 and absf(fr.z - want.size.x) < 1.0)
		# Both plates see-through by one alpha, 0.72 to 0.85, more open than `UITheme.PANEL_A`.
		var side := ZoomLadder.side_of(cur)
		var bar := ZoomLadder.bar_of(cur)
		var ssb: StyleBox = side.get_theme_stylebox(&"panel") if side is PanelContainer else null
		var bsb: Variant = bar.get_theme_stylebox(&"panel") if bar is PanelContainer else (bar.get_meta(&"nav_plate") if bar != null and bar.has_meta(&"nav_plate") else null)
		var sa := (ssb as StyleBoxFlat).bg_color.a if ssb is StyleBoxFlat else -1.0
		var ba := (bsb as StyleBoxFlat).bg_color.a if bsb is StyleBoxFlat else -1.0
		_ok("%s: the side panel a see-through plate (alpha %.2f)" % [_nm(r), sa], sa >= 0.72 and sa <= 0.85)
		# The top row keeps the side panel's margin inside its line (Jon: border at button edges).
		var margin := ssb.get_content_margin(SIDE_LEFT) if ssb != null else 12.0
		var least := INF
		var tight := ""
		if bar != null and bar.get_child_count() > 0:
			var pieces: Array = []
			GoalLine._inked(bar.get_child(0) as Control, pieces)
			var pr := bar.get_global_rect()
			var least_v := INF
			for q: Rect2 in pieces:
				var gap := minf(q.position.x - pr.position.x, pr.end.x - q.end.x)
				if gap < least:
					least = gap
					tight = str(q)
				least_v = minf(least_v, minf(q.position.y - pr.position.y, pr.end.y - q.end.y))
			# (and hugging it top and bottom, Jon: "a bit excessive on the
			# height" -- but never touching its line)
			_ok("%s: the toolbar row's plate close above and below it, 4 px or more clear (least %.1f)" % [_nm(r), least_v],
				least_v >= 4.0 - 0.01 and least_v <= 8.0)
		_ok("%s: every piece of the toolbar row %.0f px or more in from its plate's ends, the side panel's margin (least %.1f, %s)" % [_nm(r), margin, least, tight],
			least != INF and least >= margin - 0.01)
		# The goal sits just below the top plate at the picture's top left (Jon, Oct 20).
		var g: GoalLine = Router.hud.goal if Router.hud != null else null
		if g != null:
			g.refresh()
			var gr := Rect2(g.position, g.size)
			var pieces2: Array = []
			if bar != null and bar.get_child_count() > 0:
				GoalLine._inked(bar.get_child(0) as Control, pieces2)
			var hit := ""
			var first_x := INF
			for q: Rect2 in pieces2:
				first_x = minf(first_x, q.position.x)
				if q.intersects(gr):
					hit = str(q)
			var gpic := GoalLine.picture_rect(Router.current)
			var below := bar != null and gr.position.y >= bar.get_global_rect().end.y
			_ok("%s: the goal where LOCAL has it (%s, its place %s), below the plate, at the picture's top left %s + 4 px, clear of the row%s" % [_nm(r), gr.position, GoalLine.fixed_at(), gpic.position, "" if hit == "" else " (over %s)" % hit],
				g.visible and gr.position == GoalLine.fixed_at() and below and gr.position == gpic.position + Vector2(4, 4)
				and gpic.encloses(gr) and hit == "")
			var bx := bar.get_global_rect().position.x if bar != null else 0.0
			_ok("%s: the row's words start at its plate's margin (first at %.0f, the plate's %.0f + %.0f)" % [_nm(r), first_x, bx, margin],
				absf(first_x - (bx + margin)) <= 1.0)
		_ok("%s: the toolbar row a plate, the side panel's own (alpha %.2f)" % [_nm(r), ba], ba >= 0.72 and ba <= 0.85
			and ssb is StyleBoxFlat and bsb is StyleBoxFlat and (ssb as StyleBoxFlat).bg_color == (bsb as StyleBoxFlat).bg_color
			and (ssb as StyleBoxFlat).border_color == (bsb as StyleBoxFlat).border_color
			and (ssb as StyleBoxFlat).border_width_top == (bsb as StyleBoxFlat).border_width_top)


## The goal line is part of the HUD (Jon, Oct 18 and 20): it moves only with the top plate.
## Why: docs/why/CalmLadderTest.md#goal-line-hud
func _goal_line() -> void:
	var g: Variant = Router.hud.get("goal") if Router.hud != null else null
	if g == null:
		print("  --   no goal line on this build")
		return
	Hints.forced = true
	await _at(ZoomLadder.LOCAL)
	await _frames(40)
	var gl := g as Control
	for h: Array in [[ZoomLadder.LOCAL, ZoomLadder.MAP, KEY_TAB], [ZoomLadder.MAP, ZoomLadder.CHART, KEY_TAB],
			[ZoomLadder.CHART, ZoomLadder.LOCAL, KEY_TAB]]:
		var label := "the goal line, %s -> %s" % [_nm(h[0]), _nm(h[1])]
		var r0 := Rect2(gl.position, gl.size)
		var local_hop: bool = h[0] == ZoomLadder.LOCAL or h[1] == ZoomLadder.LOCAL
		_key(h[2])
		var off := 0
		var frames := 0
		var why := ""
		var moved := 0
		var stray := 0
		var stray_why := ""
		var over := 0
		var over_why := ""
		var big := 0.0
		var dirs := {}
		var prev := r0
		for i in 400:
			await _tree.process_frame
			frames += 1
			var r := Rect2(gl.position, gl.size)
			var up: bool = gl.visible and gl.modulate.a > 0.99
			if not up or r.position.x != r0.position.x or r.size != r0.size or r.position != r.position.round():
				off += 1
				if why == "":
					why = "%s at frame %d" % ["%s, from %s" % [r, r0] if up else "not up", frames]
			if r.position.y != prev.position.y:
				moved += 1
				var dy := r.position.y - prev.position.y
				big = maxf(big, absf(dy))
				dirs[signf(dy)] = true
				# only with the plate, at its own point on the curve
				var ps := GoalLine.plate_slide()
				if not local_hop or ps == null or r.position != GoalLine.place_at(ps.k):
					stray += 1
					if stray_why == "":
						stray_why = "frame %d at %s, the plate %s" % [frames, r.position, "k %.3f -> %s" % [ps.k, GoalLine.place_at(ps.k)] if ps != null else "not sliding"]
			# never on the plate or the HUD (the goal and the step's line)
			var plate := Rect2()
			var ps2 := GoalLine.plate_slide()
			if ps2 != null:
				plate = ps2.at()
			elif Router.current != null and Router.current.has_method("ladder_bar"):
				var bar: Control = Router.current.call("ladder_bar")
				# (one the move has hidden is not drawn: `ZoomLadder._hide_chrome`)
				if bar != null and bar.is_visible_in_tree() and bar.modulate.a > 0.0:
					plate = bar.get_global_rect()
			var hud := Router.hud.get_global_rect()
			var sr: Rect2 = (gl as GoalLine).step_rect()
			for x: Rect2 in [r, sr]:
				if x.size == Vector2.ZERO:
					continue
				var hit := ""
				if plate.size != Vector2.ZERO and x.intersects(plate):
					hit = "the plate %s" % plate
				elif x.intersects(hud):
					hit = "the HUD"
				if hit != "":
					over += 1
					if over_why == "":
						over_why = "%s on %s at frame %d" % [x, hit, frames]
			prev = r
			if _settled() and i > 5:
				break
		var want_y: float = GoalLine.place_at(1.0 if h[1] != ZoomLadder.LOCAL else 0.0).y
		_ok("%s: up on every frame, at the same left, the same size, whole pixels (%d of %d not%s)" % [label, off, frames, "" if why == "" else ": " + why], off == 0)
		if local_hop:
			_ok("%s: it moves with the plate only, at the plate's point on its curve (%d frames moved, %d not with it%s)" % [label, moved, stray, "" if stray_why == "" else ": " + stray_why],
				moved > 3 and stray == 0)
			_ok("%s: smooth, one way, %.0f px a frame at most" % [label, big], dirs.size() <= 1 and big <= 4.0)
		else:
			_ok("%s: it does not move (%d frames moved)" % [label, moved], moved == 0)
		_ok("%s: never on the plate or the HUD (%d frames%s)" % [label, over, "" if over_why == "" else ": " + over_why], over == 0)
		_ok("%s: at rest where %s has it (y %.0f, wants %.0f)" % [label, _nm(h[1]), gl.position.y, want_y], gl.position.y == want_y)
		await _rest()
	Hints.forced = false


func _nm(r: int) -> String:
	return ["chart", "map", "LOCAL", "station"][r]
