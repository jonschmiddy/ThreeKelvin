extends Node

## YOUR OWN SHIP ON THE SECTOR MAP, AND ITS ION DRIVE:
##   godot --headless --fixed-fps 60 --path . -- sheet=MapShipTest
##
## Jeremy, friends' alpha: the sector map's ship should be the player's own,
## not a generic one, and its engine flame blue, an ion drive, so flying in a
## system reads as the drive and not the warp. A new run's sector map, through
## the real screen (`SystemOverlay._draw_ship`, its pixels kept by `record_px`,
## since headless draws nothing that can be read back):
##   - the ship is drawn from your hull's own picture, the one LOCAL draws (the
##     grade's bake, worked out here on its own, not asked of the code under
##     test), at the map's length for its weight: the picture's colours are that
##     art's (a dark hull lifted to read, `MapHull.LIFT_TO`), and pointing
##     straight along the map every hull pixel drawn is the picture's pixel for
##     pixel;
##   - after a hull swap (`Run.transfer_to_hull`, a Solari heavy) the map draws
##     the new hull the same way, longer;
##   - W held through the real step: the flame lit, and every pixel of it and of
##     the engine glow in the ion ramp (blue over red and green), none warm;
##   - fit means nothing overlaps: YOU clear of the hull pointing straight up,
##     and a partner sitting where you are drawn in formation clear of it;
##   - AFTER THE MAP'S KEY: the map's picture is keyed onto the field
##     (`nav_key.gdshader` on `SystemMapScreen._box`), so a colour can be drawn
##     and still not be seen. Each solid pixel of the hull and its dark rim is
##     put through the key's own rule, read off the screen's material, and must
##     stand. The rim was the old arrow's #05070b, inside the key's band, and
##     never showed; the colours recorded before the key could not tell.

var _tree: SceneTree
var _fails := 0
const LEN := [14, 17, 20]


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(k: int) -> void:
	for i in k:
		await _tree.process_frame


## The picture LOCAL draws a hull from, worked out here (ShipView's own rule).
static func _art(h: HullData) -> Texture2D:
	if HullGrade.key_for(h) != "":
		return HullGrade.graded_tex(h, false, HullWear.seed_for(h, "", Rng.master))
	return h.sprite


## The alpha-weighted mean colour of a picture's ink, in linear light; with
## `pm` (the map picture's own), its hull pixels alone, not the outline.
static func _mean(img: Image, pm: PackedFloat32Array = PackedFloat32Array()) -> Color:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var w := 0.0
	var u := img.get_used_rect()
	for y in range(u.position.y, u.end.y):
		for x in range(u.position.x, u.end.x):
			var c := img.get_pixel(x, y)
			if c.a <= 0.0 or (not pm.is_empty() and pm[(y * img.get_width() + x) * 5 + 4] < 0.5):
				continue
			var l := c.srgb_to_linear()
			r += l.r * c.a
			g += l.g * c.a
			b += l.b * c.a
			w += c.a
	return Color(r / w, g / w, b / w) if w > 0.0 else Color(0, 0, 0, 0)


## THE MAP'S KEY as the screen has it: `nav_key.gdshader`'s band (`lo`, `hi`,
## `dark`, `dark_w`) and whether it is on, each from the screen's material or,
## left unset there, the shader's own default. {} when the map is not keyed
## (`-- field=off`): every colour stands.
static func key_of(map: SystemMapScreen) -> Dictionary:
	var m := map._box.material as ShaderMaterial
	if m == null or m.shader == null:
		return {}
	var code := m.shader.code
	var k := {}
	for nm: String in ["lo", "hi", "dark", "dark_w", "on"]:
		var v: Variant = m.get_shader_parameter(nm)
		if v == null:
			var re := RegEx.create_from_string("uniform\\s+\\w+\\s+%s\\s*=\\s*([0-9.]+|true|false)" % nm)
			var hit := re.search(code)
			if hit == null:
				return {}
			var s := hit.get_string(1)
			v = (s == "true") if nm == "on" else float(s)
		k[nm] = v
	return k if bool(k.on) else {}


## How much of an opaque pixel of colour `c` (sRGB, as the map's viewport holds
## it) the key leaves standing over the field, 0 to 1: the shader's own line.
static func kept(k: Dictionary, c: Color) -> float:
	if k.is_empty():
		return 1.0
	var L := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	return maxf(smoothstep(float(k.lo), float(k.hi), L), 1.0 - smoothstep(float(k.dark) - float(k.dark_w), float(k.dark), L))


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_system()
	await _frames(40)
	var map := Router.current as SystemMapScreen
	if not _ok("the sector map is up", map != null and map.view.layout != null and map.flight != null):
		_finish()
		return
	var ov = map.overlay
	ov.set("record_px", true)
	await _frames(2)
	await _check_hull(map, "a new run's Korvan medium")
	# THE SWAP, as a yard makes it: a Solari heavy
	var heavy := DB.hull_for(&"solari", HullData.Weight.HEAVY)
	var was: Variant = ov.get("hull_src")
	if _ok("there is a Solari heavy to swap to", heavy != null):
		Run.transfer_to_hull(heavy)
		await _frames(3)
		_ok("the map is still up after the swap", Router.current == map)
		_ok("the swap changed the picture the map's ship is drawn from", ov.get("hull_src") != was)
		await _check_hull(map, "after a swap to a Solari heavy")
	await _check_flame(map)
	await _check_fit(map)
	_cost()
	_finish()


## WHAT IT COSTS, printed and not judged (the machine is shared): shrinking a
## hull the map has not drawn yet, and turning it to a step not yet drawn --
## the most a frame ever pays, since a frame draws one ship at one step.
func _cost() -> void:
	var path := "res://scripts/ui/sysmap/MapHull.gd"
	if not ResourceLoader.exists(path):
		return
	var MH = load(path)
	var h := DB.hull_for(&"korvan", HullData.Weight.LIGHT)
	if h == null:
		return
	# (the grade's bake first, untimed: LOCAL has made it before the map draws)
	var art := _art(h)
	var t0 := Time.get_ticks_usec()
	var pic: Dictionary = MH.picture(h, art)
	var t1 := Time.get_ticks_usec()
	if pic.is_empty():
		return
	for b in 16:
		MH.turned(pic, 7 + b * 13)
	var t2 := Time.get_ticks_usec()
	print("  cost: a Korvan light shrunk in %.1f ms; a new turn %.2f ms (16 timed)" % [(t1 - t0) / 1000.0, (t2 - t1) / 16000.0])


## DRAWN FROM YOUR HULL: the picture it came from, its length, its colours, and
## pointing straight along the map, every hull pixel the picture's own.
func _check_hull(map: SystemMapScreen, when: String) -> void:
	var ov = map.overlay
	var h: HullData = Run.hull
	var want := _art(h)
	var src: Variant = ov.get("hull_src")
	_ok("the map's ship is drawn from your hull's own picture, %s (%s)" % [when, want.resource_path if want != null else "none"],
		want != null and src == want)
	var pic: Variant = ov.get("hull_pic")
	if not _ok("and the map has a picture of it, %s" % when, pic is Dictionary and not (pic as Dictionary).is_empty()):
		return
	var img: Image = pic.img
	var L: int = LEN[int(h.weight)]
	# the ink, the outline either side, and a clear column where that is even
	_ok("at the map's length for its weight, %s (%d px picture for %d px of hull)" % [when, img.get_width(), L],
		img.get_width() == L + 2 + (1 - ((L + 2) & 1)))
	# ITS COLOURS ARE THE ART'S, a dark hull lifted to read on the map
	# (`MapHull.LIFT_TO`): the picture's mean over the lift is the art's
	var a := _mean(want.get_image())
	var gain: float = pic.get("gain", 1.0)
	var m := _mean(img, pic.pm)
	var dc := maxf(absf(a.r - m.r / gain), maxf(absf(a.g - m.g / gain), absf(a.b - m.b / gain)))
	print("  %s: the art's mean %s, the map picture's %s, lifted %.2fx" % [when, a, m, gain])
	_ok("its colours are that art's, shrunk (mean off by %.3f)" % dc, dc < 0.03)
	_ok("lifted only if dark, and to the floor (%.2fx to brightness %.3f)" % [gain, m.get_luminance()],
		gain >= 1.0 and gain <= 2.0 and (gain == 1.0 or m.get_luminance() > 0.18 or gain == 2.0))
	# POINTING STRAIGHT ALONG THE MAP: the picture lands pixel for pixel
	map.set_process(false)
	map.flight.ang = 0.0
	var burn: bool = map.flight.burn
	map.flight.burn = false
	await _frames(2)
	var px: Variant = ov.get("ship_px")
	var at: Vector2 = ov._ship_at
	var mx := (img.get_width() - 1) / 2
	var my := (img.get_height() - 1) / 2
	var n := 0
	var same := 0
	var ink := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				ink += 1
	if px is Array:
		for e: Array in px:
			if e[2] != &"hull" and e[2] != &"outline":
				continue
			n += 1
			var q: Vector2i = Vector2i((e[0] as Vector2) - at) + Vector2i(mx, my)
			if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height():
				continue
			var p := img.get_pixel(q.x, q.y)
			var c: Color = e[1]
			if p.a > 0.0 and absf(p.r - c.r) <= 2.0 / 255.0 and absf(p.g - c.g) <= 2.0 / 255.0 \
					and absf(p.b - c.b) <= 2.0 / 255.0 and c.a > 0.99:
				same += 1
	_ok("pointing along the map, the hull drawn is the picture pixel for pixel, %s (%d of %d drawn, %d in the picture)" % [when, same, n, ink],
		n > 0 and same == n and n >= int(ink * 0.9))
	# AFTER THE MAP'S KEY (pixel for pixel here, so each is all rim or all hull):
	# every solid pixel of each as the field under the map sees it
	var key := key_of(map)
	var tally := {&"outline": [0, 0, ""], &"hull": [0, 0, ""]}
	if px is Array:
		for e: Array in px:
			var c: Color = e[1]
			if c.a < 0.99 or not tally.has(e[2]):
				continue
			var t: Array = tally[e[2]]
			t[0] += 1
			var ka := kept(key, c)
			if ka >= 0.99:
				t[1] += 1
			elif t[2] == "":
				t[2] = ", first %s kept %.2f" % [c.to_html(false), ka]
	var rim: Array = tally[&"outline"]
	var body: Array = tally[&"hull"]
	_ok("the map is keyed onto the field, so the rule below is the screen's (%s)" % str(key), not key.is_empty())
	_ok("the dark rim stands through the map's key, %s (%d of %d solid rim pixels kept%s)" % [when, rim[1], rim[0], rim[2]],
		rim[0] > 0 and rim[1] == rim[0])
	_ok("and so does every solid pixel of the hull, %s (%d of %d kept%s)" % [when, body[1], body[0], body[2]],
		body[0] > 0 and body[1] == body[0])
	map.flight.burn = burn
	map.set_process(true)
	await _frames(1)


## THE ION DRIVE: W held through the real step, the flame lit, all of it blue.
func _check_flame(map: SystemMapScreen) -> void:
	var ov = map.overlay
	map.harness_keys = true
	var lit := 0
	var flame := 0
	var warm := 0
	var cold := 0
	var worst := ""
	for i in 40:
		map._wasd.w = true
		await _tree.process_frame
		if map.flight.burn:
			lit += 1
		var px: Variant = ov.get("ship_px")
		if not px is Array:
			continue
		for e: Array in px:
			if e[2] != &"flame" and e[2] != &"glow":
				continue
			if e[2] == &"flame":
				flame += 1
			var c: Color = e[1]
			if c.b > c.r + 0.2 and c.b >= c.g:
				cold += 1
			else:
				warm += 1
				if worst == "":
					worst = "%s %s" % [e[2], c.to_html(false)]
	map._wasd.w = false
	map.harness_keys = false
	_ok("W held: the engine burns (%d of 40 frames)" % lit, lit >= 30)
	_ok("and its flame is drawn (%d flame pixels over the frames)" % flame, flame > 40)
	_ok("every pixel of the flame and the engine glow is the ion drive's blue (%d blue, %d not%s)" % [cold, warm, "" if worst == "" else ", first " + worst],
		cold > 0 and warm == 0)


## FIT MEANS NOTHING OVERLAPS: YOU over the hull pointing straight up, and a
## partner sitting on your spot drawn in formation, both clear of your hull.
func _check_fit(map: SystemMapScreen) -> void:
	var ov = map.overlay
	var f = map.flight
	# a partner, VEGA, sitting exactly where you are (two ships jumped in together)
	var pid := 77
	Net.roster[pid] = {"id": pid, "name": "Vega", "order": 9, "at": Run.at}
	Net.spots[pid] = {"at": Run.at, "body": -9, "x": f.f.p.x, "z": f.f.p.y, "ang": PI}
	await _frames(3)
	map.set_process(false)
	f.ang = -PI / 2.0
	f.burn = false
	Net.spots[pid] = {"at": Run.at, "body": -9, "x": f.f.p.x, "z": f.f.p.y, "ang": PI}
	await _frames(3)
	var hull := Rect2()
	var any := false
	var px: Variant = ov.get("ship_px")
	if px is Array:
		for e: Array in px:
			if e[2] == &"hull" or e[2] == &"outline":
				var r := Rect2(e[0] as Vector2, Vector2.ONE)
				hull = r if not any else hull.merge(r)
				any = true
	_ok("your hull drawn pointing up (%s)" % hull, any and hull.size.y > hull.size.x)
	var you_hit := false
	for r: Rect2 in ov.label_rects:
		if r.intersects(hull):
			you_hit = true
	_ok("no word on the map over your hull (%d placed: %s)" % [ov.label_rects.size(), ov.label_rects], any and not you_hit)
	var marks: Array = map.partner_marks()
	if _ok("the partner on your spot is drawn", marks.size() == 1):
		# the partner's arrow at PI: its outline from 7 px behind it to 4 ahead,
		# 4 either side
		var m: Vector2 = marks[0]
		var pb := Rect2(m + Vector2(-7, -4), Vector2(12, 9))
		_ok("in formation clear of your hull (partner %s, its arrow %s, your hull %s)" % [m, pb, hull], not pb.intersects(hull))
	Net.roster.erase(pid)
	Net.spots.erase(pid)
	map.set_process(true)
	await _frames(1)


func _finish() -> void:
	print("mapshiptest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(0 if _fails == 0 else 1)
