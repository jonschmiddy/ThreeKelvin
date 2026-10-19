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
	# THE TOP PLATE STEADY THROUGH A HOP BETWEEN THE MAP AND THE CHART (Jon: "When
	# going from sector to starchart and vice versa the border on the top panel
	# flickers? or something"): every frame of each, the plate's line and its
	# ground clear of the row's words, against the frame before the click
	await _plate_hop(&"map")
	await _plate_hop(&"chart")
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
