extends Node

## NO BOX ROUND THE PICTURE (Jon, Oct 18, of the star chart on the one field:
## "The new field is close, but why is there a box around the galaxy panel?").
## Windowed -- it reads the pictures as drawn:
##   godot --path . --resolution 1920x1080 -- sheet=FieldEdgeTest [out=<dir>]
## At rest on the sector map and on the star chart, the picture's former edges
## (left, top and bottom; the side panel stands on the right) are read in strips
## straddling them, 24 px either side, row by row (or column by column) as the
## median of each line: the screen as drawn less the field as drawn alone
## (`NavField.picture`). Inside the edge and outside it the two must agree --
## no line, no step in the ground's tone or colour, nothing the picture adds at
## its edge -- to within the field's own line-to-line variation, and the lines
## either side of the edge never differ by more than the field's own step
## there. `out=`: each strip written beside the screen, as PNGs, for a look.
## In every style (`style=legacy|simplified|painted|radiant`, the game's own
## switch) and in a system inside a cloud (`at=nebula`: the map's cloud runs
## past its picture, cloud:A -- the edge is then read against the gas either
## side of it, not the field). And LOCAL's stars ARE the field's (styles:now):
## on LOCAL at rest, where the field has a star, LOCAL draws it there.

var _fails := 0
var _tree: SceneTree
var _out := ""
## the run's system sits in a cloud (`at=nebula`)
var _cloud := false
var _fmed := 0.0
var _style_lo := false
const BAND := 24
const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
## (levels of 255, on a line's median) -- how far the screen may stand off the
## field at the edge's lines, and how far either side's mean may differ
const STEP := 2.0


func _ok(what: String, c: bool) -> bool:
	if not c:
		print("  FAIL %s" % what)
		_fails += 1
	else:
		print("  ok   %s" % what)
	return c


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _settled() -> bool:
	return not ZoomLadder.busy() and ZoomLadder.chain == &""


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	ZoomLadder.force = 1
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	StarchartScreen._primed_for = Run.galaxy_seed
	if "at=nebula" in OS.get_cmdline_user_args():
		for n: MapGen.MapNode in Run.map:
			if n.in_nebula and n.type == MapGen.NodeType.SYSTEM:
				Run.at = n.index
				_cloud = true
				break
	Run.map[Run.at].visited = true
	print("  --   style %s, %s" % [LocalSky.style_now(), "a system in a cloud" if _cloud else "a clear system"])
	ZoomLadder.hold_off = true
	Router.show_local()
	ZoomLadder.hold_off = false
	await _frames(120)
	await _local_match()
	for which: String in ["SECTOR", "STARCHART"]:
		ZoomLadder.hold_off = true
		if which == "SECTOR":
			Router.show_system()
		else:
			Router.show_starchart()
		ZoomLadder.hold_off = false
		for i in 600:
			await _tree.process_frame
			if _settled() and i > 90:
				break
		await _frames(30)
		await RenderingServer.frame_post_draw
		_check(which)
		if which == "SECTOR" and _cloud:
			_cloud_past()
	# THE TOP PLATE STEADY THROUGH A HOP BETWEEN THE MAP AND THE CHART (Jon: "When
	# going from sector to starchart and vice versa the border on the top panel
	# flickers? or something"): every frame of each, the plate's line and its
	# ground clear of the row's words, against the frame before the click
	await _plate_hop(&"map")
	await _plate_hop(&"chart")
	if _cloud:
		await _cloud_hop()
	print("fieldedgetest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)


## LOCAL'S STARS ARE THE FIELD'S (styles:now): on LOCAL at rest, every place
## the field has a star -- clear of LOCAL's cloud, its worlds, its ship and its
## words, which stand in front of it -- LOCAL draws that star there. Measured as
## the share of the field's stars LOCAL matches within 10 levels, where LOCAL's
## sky is dark round them (its cloud's open sky).
func _local_match() -> void:
	if _cloud:
		print("  --   LOCAL: inside a cloud its far stars stand behind the gas; the match is read in a clear sky")
		return
	await _frames(30)
	await RenderingServer.frame_post_draw
	var field: NavField = Router.field
	if not _ok("LOCAL: the field is fed", field != null and field.picture() != null):
		return
	var shot := _shot()
	var fimg := field.picture().get_image()
	fimg.convert(Image.FORMAT_RGB8)
	fimg.resize(960, 540, Image.INTERPOLATE_NEAREST)
	var c := Router.content.get_global_rect()
	var stars := 0
	var hit := 0
	for y in range(int(c.position.y) + 60, int(c.end.y) - 40, 2):
		for x in range(int(c.position.x) + 10, int(c.end.x) - 10, 2):
			var f := _lum(fimg, x, y)
			if f < 40.0:
				continue
			# (round it LOCAL's sky open -- LOCAL there the field's own ground: its
			# cloud, a world, the ship stand in front elsewhere)
			var dark := true
			for o: Vector2i in [Vector2i(-6, 0), Vector2i(6, 0), Vector2i(0, -6), Vector2i(0, 6)]:
				if absf(_lum(shot, x + o.x, y + o.y) - _lum(fimg, x + o.x, y + o.y)) > 10.0:
					dark = false
			if not dark:
				continue
			stars += 1
			var a := shot.get_pixel(x, y)
			var b := fimg.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) * 255.0 <= 10.0:
				hit += 1
	var share := float(hit) / maxf(stars, 1)
	if stars < 10:
		print("  --   LOCAL (%s): too little open sky to compare (%d of the field's stars in it; a cloud in front)" % [LocalSky.style_now(), stars])
		return
	_ok("LOCAL (%s): its stars are the field's -- %d of %d of the field's stars in LOCAL's open sky drawn there (%.0f%%)" % [LocalSky.style_now(), hit, stars, share * 100.0],
		share >= 0.8)


## THE CLOUD PAST THE MAP'S PICTURE IS THE CLOUD GOING ON (Jon: "the mirror is
## visible"): the map's sky ends under the side panel; past it the same cloud is
## drawn on (`SystemView._past`, the cloud's own material, read by `nav_ext`
## with `past_on`), not a mirror or a copy of gas from elsewhere. Where the
## strip starts over the picture's last 32 px it is the same gas, drawn the
## same way: its light follows the picture's there (correlation 1.00 in
## SIMPLIFIED and LEGACY on seed 4242's cloud; the picture's own gas mirrored
## there 0.25, moved 16 px 0.19-0.34; the cloud alone without the sky and dust
## sheets under it 0.24-0.57) at its level (within 2).
func _cloud_past() -> void:
	var v: Variant = (Router.current as SystemMapScreen).view if Router.current is SystemMapScreen else null
	var pv: Variant = v.get("_past") if v != null else null
	var ext: TextureRect = Router.current.get("_gas_ext") if Router.current is SystemMapScreen else null
	if v != null and bool(v.get("painted")):
		# (PAINTED's cloud is its paint pass over the picture: no strip of it --
		# past the end, the sky's own off-screen strip handed over to, `sky_past`)
		print("  --   SECTOR in a cloud (painted): past the picture the sky's off-screen strip, no strip drawn on")
		return
	if not _ok("SECTOR in a cloud: its cloud drawn on past the picture's end (a strip of its own, on)",
			pv is SubViewport and ext != null and ext.visible and bool((ext.material as ShaderMaterial).get_shader_parameter("past_on"))):
		return
	var a := (v.get("_scene") as SubViewport).get_texture().get_image()
	var b := (pv as SubViewport).get_texture().get_image()
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	var x0 := SystemViewS.PAST_X0 / 2
	var xs: Array[float] = []
	var ys: Array[float] = []
	for y in mini(a.get_height(), b.get_height()):
		for i in (960 - SystemViewS.PAST_X0) / 2:
			xs.append(_lum(a, x0 + i, y))
			ys.append(_lum(b, i, y))
	var n := float(xs.size())
	var mx := 0.0
	var my := 0.0
	for k in xs.size():
		mx += xs[k]
		my += ys[k]
	mx /= maxf(n, 1.0)
	my /= maxf(n, 1.0)
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for k in xs.size():
		sxy += (xs[k] - mx) * (ys[k] - my)
		sxx += (xs[k] - mx) * (xs[k] - mx)
		syy += (ys[k] - my) * (ys[k] - my)
	var r := sxy / maxf(sqrt(sxx * syy), 0.0001)
	_ok("SECTOR in a cloud: past the picture the same cloud goes on -- where the two meet its light follows the picture's (correlation %.2f) at its level (%.1f against %.1f)" % [r, my, mx],
		r >= 0.9 and absf(my - mx) <= 2.0)


## A CLOUD MADE SMALLER HAS NO STRAIGHT SIDE (Jon: "is there any way to have it
## be less of a square when zooming out?"): the map in a cloud to the chart,
## every frame the held cloud is drawn smaller and still half there, the cloud
## as drawn (brighter than the field by 12 levels, the plates and the HUD left
## out) found, and along its bounding box's four sides, 4 px in, how much of
## each line is cloud: a rect would fill them; a cloud thinning out does not.
func _cloud_hop() -> void:
	ZoomLadder.hold_off = true
	Router.show_system()
	ZoomLadder.hold_off = false
	for i in 400:
		await _tree.process_frame
		if _settled() and i > 60:
			break
	await _frames(30)
	await RenderingServer.frame_post_draw
	var cur := Router.current
	var skip: Array = [Router.hud.get_global_rect()]
	for pl: Control in [ZoomLadder.bar_of(cur), ZoomLadder.side_of(cur)]:
		if pl != null:
			skip.append(pl.get_global_rect().grow(2.0))
	var fimg := Router.field.picture().get_image()
	fimg.convert(Image.FORMAT_RGB8)
	fimg.resize(960, 540, Image.INTERPOLATE_NEAREST)
	var c := Router.content.get_global_rect()
	Router.show_starchart()
	var worst := 0.0
	var seen := 0
	var why := ""
	var corner_worst := 0.0
	var corner_why := ""
	for f in 300:
		await RenderingServer.frame_post_draw
		if not ZoomLadder.busy():
			if _settled() and f > 30:
				break
			continue
		var L := ZoomLadder.active
		var sc: Variant = (L._mat as ShaderMaterial).get_shader_parameter(&"scl")
		if not (L._rect as CanvasItem).visible or not (sc is Vector2) or (sc as Vector2).x > 0.97 or L.held_alpha() < 0.5:
			continue
		var shot := _shot()
		var x0 := 9999
		var y0 := 9999
		var x1 := -1
		var y1 := -1
		var cloud := {}
		for y in range(int(c.position.y), int(c.end.y), 2):
			for x in range(int(c.position.x), int(c.end.x), 2):
				if _in_any(skip, Vector2(x, y)):
					continue
				if _lum(shot, x, y) - _lum(fimg, x, y) > 12.0:
					cloud[Vector2i(x, y)] = true
					x0 = mini(x0, x)
					y0 = mini(y0, y)
					x1 = maxi(x1, x)
					y1 = maxi(y1, y)
		if x1 - x0 < 40 or y1 - y0 < 40:
			continue
		seen += 1
		var sides := {"top": [], "bottom": [], "left": [], "right": []}
		for x in range(x0 + 8 - (x0 + 8) % 2, x1 - 6, 2):
			sides.top.append(cloud.has(Vector2i(x, y0 + 4 - (y0 + 4) % 2)))
			sides.bottom.append(cloud.has(Vector2i(x, y1 - 4 - (y1 - 4) % 2)))
		for y in range(y0 + 8 - (y0 + 8) % 2, y1 - 6, 2):
			sides.left.append(cloud.has(Vector2i(x0 + 4 - (x0 + 4) % 2, y)))
			sides.right.append(cloud.has(Vector2i(x1 - 4 - (x1 - 4) % 2, y)))
		for nm: String in sides:
			var arr: Array = sides[nm]
			if arr.is_empty():
				continue
			var cov := float(arr.count(true)) / arr.size()
			if cov > worst:
				worst = cov
				why = "%s side %.0f%% cloud, frame %d (held at %.2f)" % [nm, cov * 100.0, f, (sc as Vector2).x]
		# (and its corners empty: a twelfth of the box each way at each corner)
		var cw := int((x1 - x0) / 12.0)
		var ch := int((y1 - y0) / 12.0)
		for cc: Vector2i in [Vector2i(x0, y0), Vector2i(x1 - cw, y0), Vector2i(x0, y1 - ch), Vector2i(x1 - cw, y1 - ch)]:
			var tot := 0
			var on := 0
			for y in range(cc.y, cc.y + ch + 1, 2):
				for x in range(cc.x, cc.x + cw + 1, 2):
					tot += 1
					if cloud.has(Vector2i(x - x % 2, y - y % 2)):
						on += 1
			var cf := float(on) / maxf(tot, 1)
			if cf > corner_worst:
				corner_worst = cf
				corner_why = "corner at %s %.0f%% cloud, frame %d" % [cc, cf * 100.0, f]
	_ok("map -> chart in a cloud: the held cloud, made smaller, has no straight side -- the most of any side's line that is cloud %.0f%% (%s; %d frames read)" % [worst * 100.0, why, seen],
		seen >= 3 and worst <= 0.40)
	_ok("map -> chart in a cloud: and no corner -- the most of any corner that is cloud %.0f%% (%s)" % [corner_worst * 100.0, corner_why],
		seen >= 3 and corner_worst <= 0.10)


func _shot() -> Image:
	var img := Router.content.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


## The plate's line (its four edges, 1 px) and its ground (its 12 px margin
## inside the line, clear of the row) as drawn: [line pixels, ground pixels].
func _plate_px(img: Image, r: Rect2) -> Array:
	var line: Array = []
	var ground: Array = []
	var x0 := int(r.position.x)
	var x1 := int(r.end.x) - 1
	var y0 := int(r.position.y)
	var y1 := int(r.end.y) - 1
	for x in range(x0, x1 + 1, 3):
		line.append(img.get_pixel(x, y0))
		line.append(img.get_pixel(x, y1))
		# (the margin between the line and the row: 5 px, its middle)
		for y in [y0 + 2, y1 - 2]:
			ground.append(img.get_pixel(x, y))
	for y in range(y0, y1 + 1, 3):
		line.append(img.get_pixel(x0, y))
		line.append(img.get_pixel(x1, y))
	return [line, ground]


func _most_off(a: Array, b: Array) -> float:
	var m := 0.0
	for i in mini(a.size(), b.size()):
		var p: Color = a[i]
		var q: Color = b[i]
		m = maxf(m, maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))) * 255.0)
	return m


func _plate_hop(to: StringName) -> void:
	# (from the other one, at rest)
	ZoomLadder.hold_off = true
	if to == &"map":
		Router.show_starchart()
	else:
		Router.show_system()
	ZoomLadder.hold_off = false
	for i in 400:
		await _tree.process_frame
		if _settled() and i > 60:
			break
	await _frames(20)
	await RenderingServer.frame_post_draw
	var bar := ZoomLadder.bar_of(Router.current)
	if bar == null:
		return
	var r := bar.get_global_rect()
	var base := _plate_px(_shot(), r)
	var f0: Image = Router.field.picture().get_image() if Router.field != null and Router.field.picture() != null else null
	if to == &"map":
		Router.show_system()
	else:
		Router.show_starchart()
	var worst_line := 0.0
	var worst_ground := 0.0
	var at := -1
	var frames := 0
	for i in 300:
		await RenderingServer.frame_post_draw
		frames += 1
		var now := _plate_px(_shot(), r)
		var ol := _most_off(base[0], now[0])
		var og := _most_off(base[1], now[1])
		if ol > worst_line:
			worst_line = ol
			at = frames
		worst_ground = maxf(worst_ground, og)
		if _settled() and frames > 30:
			break
	if f0 != null and OS.get_cmdline_user_args().has("debug"):
		var f1: Image = Router.field.picture().get_image()
		var most := 0.0
		for y in range(0, f0.get_height(), 2):
			for x in range(0, f0.get_width(), 2):
				var a := f0.get_pixel(x, y)
				var b := f1.get_pixel(x, y)
				most = maxf(most, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) * 255.0)
		print("    debug: the field picture moved %.0f levels at most over the hop" % most)
	_ok("%s -> %s: the top plate steady every frame -- its line at most %.0f levels off what it was (frame %d), its ground %.0f (%d frames%s)" % ["chart" if to == &"map" else "map", to, worst_line, at, worst_ground, frames, "; in a cloud the gas behind the glass moves, the line alone held" if _cloud else ""],
		worst_line <= 2.0 and (worst_ground <= 3.0 or _cloud))


## The screen as drawn, and the field alone, both on the game's 960x540.
func _check(which: String) -> void:
	var cur := Router.current
	var field: NavField = Router.field
	if not _ok("%s: the field is up under it" % which, field != null and field.visible and field.picture() != null):
		return
	var shot := Router.content.get_viewport().get_texture().get_image()
	shot.convert(Image.FORMAT_RGB8)
	if shot.get_width() != 960:
		shot.resize(960, 540, Image.INTERPOLATE_NEAREST)
	var fimg := field.picture().get_image()
	fimg.convert(Image.FORMAT_RGB8)
	fimg.resize(960, 540, Image.INTERPOLATE_NEAREST)
	var pic: Rect2 = cur.call(&"ladder_picture")
	# (the screen's words and buttons are UI over the field, not the picture's
	# edge: the lines skip them)
	var ui := _ui_rects(cur)
	# (and the two plates, the toolbar row's and the side panel's: chrome too)
	for pl: Control in [ZoomLadder.bar_of(cur), ZoomLadder.side_of(cur)]:
		if pl != null:
			ui.append(pl.get_global_rect().grow(4.0))
	var c := Router.content.get_global_rect()
	# (the picture's frame was 12 px of margin round it, then a line)
	# THE PLATES SEE-THROUGH (Jon, Oct 18: "make both panels slightly see
	# through like the other panels"): over the toolbar row's plate and the side
	# panel's, clear of their words, the screen follows the field under it by
	# about 1 - `NavField.PLATE_A` (fitted: the slope of the screen's luminance
	# on the field's)
	var words := _ui_rects(cur)
	for pl: Control in [ZoomLadder.bar_of(cur), ZoomLadder.side_of(cur)]:
		if pl == null:
			continue
		if _cloud and which == "SECTOR":
			# (in a cloud the map's gas runs on under the plates: what shows
			# through them is the gas, not the field)
			print("  --   %s: under its plates, the cloud" % which)
			break
		var r := pl.get_global_rect().grow(-4.0)
		# (the plate's own pictures -- a star's portrait, a glow -- left out: only
		# pixels near the plate's own dark, split by the field's under them, the
		# field's stars against its void)
		# (the field's own ground under it: its dark where it is dark, LEGACY's
		# wash where that lifts it)
		var fl_all: Array = []
		for y in range(int(r.position.y), int(r.end.y), 4):
			for x in range(int(r.position.x), int(r.end.x), 4):
				fl_all.append(_lum(fimg, x, y))
		fl_all.sort()
		_fmed = float(fl_all[fl_all.size() / 2]) if not fl_all.is_empty() else 0.0
		_style_lo = _fmed >= 12.0
		var lo_s := 0.0
		var lo_f := 0.0
		var hi_s := 0.0
		var hi_f := 0.0
		var nlo := 0
		var nhi := 0
		for y in range(int(r.position.y), int(r.end.y), 1):
			for x in range(int(r.position.x), int(r.end.x), 1):
				if _in_any(words, Vector2(x, y)) or _in_inner(pl, Vector2(x, y)):
					continue
				var fl := _lum(fimg, x, y)
				var sl := _lum(shot, x, y)
				if sl > 60.0:
					continue
				if fl < 14.0 or (_style_lo and fl < _fmed + 4.0):
					lo_s += sl
					lo_f += fl
					nlo += 1
				elif fl > 40.0:
					hi_s += sl
					hi_f += fl
					nhi += 1
		var n := nhi
		var slope := 0.0
		if nlo > 0 and nhi > 0:
			slope = (hi_s / nhi - lo_s / nlo) / maxf(hi_f / nhi - lo_f / nlo, 1.0)
		var want := 1.0 - NavField.PLATE_A
		var nm2 := "toolbar" if pl == ZoomLadder.bar_of(cur) else "side"
		if n >= 8:
			_ok("%s: the field shows through the %s plate (the screen follows its stars by %.2f, %.2f wanted, %d star px)" % [which, nm2, slope, want, n],
				absf(slope - want) <= 0.12)
		else:
			# (too few of the field's stars under it to fit: its ground, then -- the
			# plate's colour over the field's void at PLATE_A, not the panel's own)
			var pc := UITheme.PANEL
			var pl_l := (0.299 * pc.r + 0.587 * pc.g + 0.114 * pc.b) * 255.0
			var got := lo_s / maxf(nlo, 1)
			var mix := NavField.PLATE_A * pl_l + (1.0 - NavField.PLATE_A) * lo_f / maxf(nlo, 1)
			_ok("%s: the %s plate is the panel's colour over the field at %.2f (its ground %.1f, %.1f wanted, %.1f were it solid; %d px)" % [which, nm2, NavField.PLATE_A, got, mix, pl_l, nlo],
				nlo > 40 and absf(got - mix) <= 1.0 and absf(got - pl_l) > 1.0)
	var edges := {
		"left": [Vector2(pic.position.x, 0), true],
		"top": [Vector2(0, pic.position.y), false],
		"bottom": [Vector2(0, pic.end.y), false],
	}
	for nm: String in edges:
		var at: Vector2 = edges[nm][0]
		var vertical: bool = edges[nm][1]
		var lines: Array = []
		var field_lines: Array = []
		for k in range(-BAND, BAND):
			var meds: Array = []
			var fmeds: Array = []
			if vertical:
				var x := int(at.x) + k
				if x < int(c.position.x) or x >= int(c.end.x):
					continue
				for y in range(int(pic.position.y + 40), int(pic.end.y - 40), 2):
					if _in_any(ui, Vector2(x, y)):
						continue
					meds.append(_diff(shot, fimg, x, y))
					fmeds.append(_lum(fimg, x, y))
			else:
				var y := int(at.y) + k
				if y < int(c.position.y) or y >= int(c.end.y):
					continue
				for x in range(int(pic.position.x + 40), int(pic.end.x - 40), 2):
					if _in_any(ui, Vector2(x, y)):
						continue
					meds.append(_diff(shot, fimg, x, y))
					fmeds.append(_lum(fimg, x, y))
			if meds.is_empty():
				continue
			meds.sort()
			fmeds.sort()
			lines.append([k, meds[meds.size() / 2], fmeds[fmeds.size() / 2]])
		if lines.is_empty():
			continue
		# the screen less the field, line by line: the two sides' means within STEP
		# of each other, and no jump between lines bigger than the field's own
		# there (how far any line stands off the field is reported: the picture's
		# own things, faded toward its edge)
		var worst := 0.0
		var ins := 0.0
		var outs := 0.0
		var ni := 0
		var no := 0
		var jump := 0.0
		var fjump := 0.0
		var prev: Variant = null
		for l: Array in lines:
			worst = maxf(worst, absf(float(l[1])))
			var inside: bool = int(l[0]) >= 0 if nm != "bottom" else int(l[0]) < 0
			if inside:
				ins += float(l[1])
				ni += 1
			else:
				outs += float(l[1])
				no += 1
			if prev != null:
				jump = maxf(jump, absf(float(l[1]) - float(prev[1])))
				fjump = maxf(fjump, absf(float(l[2]) - float(prev[2])))
			prev = l
		var step := absf(ins / maxf(ni, 1) - outs / maxf(no, 1))
		if _cloud and which == "SECTOR":
			# (the cloud runs on past the picture: its gas either side, not the
			# field -- the line at the edge no further from the one before it than
			# the cloud's own lines are from theirs)
			var at_edge := 0.0
			var others: Array = []
			for i in range(1, lines.size()):
				var d := absf(float(lines[i][1]) - float(lines[i - 1][1]))
				if int(lines[i][0]) == 0 or int(lines[i - 1][0]) == 0 or (nm == "bottom" and int(lines[i][0]) == -1):
					at_edge = maxf(at_edge, d)
				else:
					others.append(d)
			others.sort()
			var typical: float = others[int(others.size() * 0.9)] if not others.is_empty() else 0.0
			_ok("%s, the picture's %s edge in the cloud: no step across it (the line at the edge %.1f from the one before it, the cloud's own up to %.1f)" % [which, nm, at_edge, typical],
				at_edge <= typical + 2.0)
			continue
		_ok("%s, the picture's %s edge: no step across it (the screen less the field: sides %.1f levels apart, the biggest jump line to line %.1f against the field's own %.1f; the most any line stood off the field %.1f)" % [which, nm, step, jump, fjump, worst],
			step <= STEP and jump <= maxf(STEP, fjump + 1.0))
		if _out != "":
			var r := Rect2(at.x - BAND, pic.position.y, BAND * 2, pic.size.y) if vertical else Rect2(pic.position.x, at.y - BAND, pic.size.x, BAND * 2)
			r = r.intersection(Rect2(0, 0, 960, 540))
			var crop := shot.get_region(Rect2i(r))
			crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
			crop.save_png("%s/edge_%s_%s.png" % [_out, which.to_lower(), nm])


## The screen's UI drawn over the field: its words, buttons, pips and bars (a
## few px round each), not its containers.
func _ui_rects(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		# (not into a picture's own viewport: its things are the picture)
		if n is SubViewport:
			continue
		for k: Node in n.get_children():
			stack.append(k)
		if not (n is Control) or not (n as Control).is_visible_in_tree() or n.name == &"GasPastPicture":
			continue
		var r := (n as Control).get_global_rect()
		var small := r.get_area() < 3000.0
		var leaf := n is Label or n is BaseButton or n is TextureRect or n is Range
		var bit := (n is ColorRect or n is Panel or n is PanelContainer or (n.get_class() == "Control" and n.get_child_count() == 0)) and small
		if leaf or bit:
			out.append(r.grow(3.0))
	return out


## A point on a plate's own inner cards (an opaque row, a portrait's box), not
## the plate itself.
func _in_inner(plate: Control, p: Vector2) -> bool:
	var st: Array = plate.get_children()
	while not st.is_empty():
		var c: Node = st.pop_back()
		for k: Node in c.get_children():
			st.append(k)
		if (c is PanelContainer or c is Panel) and (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().has_point(p):
			var sb: StyleBox = (c as Control).get_theme_stylebox(&"panel")
			if sb is StyleBoxFlat and (sb as StyleBoxFlat).bg_color.a > 0.0:
				return true
	return false


func _in_any(rs: Array, p: Vector2) -> bool:
	for r: Rect2 in rs:
		if r.has_point(p):
			return true
	return false


func _lum(img: Image, x: int, y: int) -> float:
	var p := img.get_pixel(x, y)
	return (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) * 255.0


## The screen less the field at a pixel, in levels (the largest channel's).
func _diff(a: Image, b: Image, x: int, y: int) -> float:
	var p := a.get_pixel(x, y)
	var q := b.get_pixel(x, y)
	var d := Vector3(p.r - q.r, p.g - q.g, p.b - q.b) * 255.0
	return d.x if absf(d.x) >= maxf(absf(d.y), absf(d.z)) else (d.y if absf(d.y) >= absf(d.z) else d.z)
