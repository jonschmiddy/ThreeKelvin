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

var _fails := 0
var _tree: SceneTree
var _out := ""
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
	Run.map[Run.at].visited = true
	ZoomLadder.hold_off = true
	Router.show_local()
	ZoomLadder.hold_off = false
	await _frames(120)
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
	print("fieldedgetest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)


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
	var c := Router.content.get_global_rect()
	# (the picture's frame was 12 px of margin round it, then a line)
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
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var r := (n as Control).get_global_rect()
		var small := r.get_area() < 3000.0
		var leaf := n is Label or n is BaseButton or n is TextureRect or n is Range
		var bit := (n is ColorRect or n is Panel or n is PanelContainer or (n.get_class() == "Control" and n.get_child_count() == 0)) and small
		if leaf or bit:
			out.append(r.grow(3.0))
	return out


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
