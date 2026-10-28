extends "res://scripts/sim/MacBench.gd"

## THE FRAME COUNTER CLEARS EVERYTHING ON THE SCREEN (`FpsMeter`, Settings'
## FRAME COUNTER), on the screens a player sits on: the title, the star chart,
## the sector map, LOCAL in orbit of a giant, a fight there, a city's yard, and
## the HUD's SHIP, CARDS and MODULES:
##
##   tools/dev/godot.sh --headless --fixed-fps 60 --path tkg -- sheet=MeterFitTest
##   tools/dev/render.sh --path tkg -- sheet=MeterFitTest [out=<dir>] [screens=a,b]
##
## FIT MEANS NOTHING OVERLAPS, AND A LINE IS SOMETHING. The three-reading meter
## (Oct 27) passed a box test of every Label, Button, RichTextLabel and
## TextureRect, and its figures still ran through the bottom bar's 1 px frame
## line on LOCAL and in a fight for all 158 px of it: a frame is a Panel's edge,
## and that test never looked at one. So this takes the meter's INK -- where its
## figures are drawn, from the font's own glyphs, not the label's box, which
## has empty rows above the capitals -- grown by one pixel all round, and fails
##   * on TEXT whose box meets it (a Label, Button, RichTextLabel or LineEdit);
##   * on an EDGE passing through it of anything that draws: a Panel's or a
##     PanelContainer's frame or fill, a Button's, a ColorRect, a TextureRect, a
##     NinePatchRect, a SubViewportContainer, a control that draws itself. Each
##     rect is first cut to what its clipping parents let show, and an edge on
##     the window's own edge is the window's, not a line;
##   * when the ink touches the window's edge or runs past it.
## On the title the build stamp is also put where an export puts it (under no
## developer switch: `LauncherScreen._add_build_stamp`) and checked.
##
## Headless it reads the rects (the gate's way). With a window it also writes
## each screen with the meter on and off (`out=`), finds the ink in the pixels
## (the meter's colour, where on and off differ) and fails unless it is the
## ink the glyphs give, to the pixel, so the two cannot drift apart. It shrinks
## the window to 1x and keeps it on top while it runs.

const MORE := ["ship", "cards", "modules"]
## The glyph cache pads every glyph's rect by a pixel all round (the rect
## margin a bitmap glyph is packed with), so the ink is the rect less this.
## The windowed run checks the result against the pixels, to the pixel.
const GLYPH_MARGIN := 1.0

var _fails := 0


func _ok(what: String, good: bool) -> void:
	if not good:
		_fails += 1
		print("  FAIL %s" % what)


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	tree.root.gui_disable_input = true
	if GameShell.instance != null:
		GameShell.instance.view.gui_disable_input = true
	var outd := _arg("out")
	if outd != "":
		DirAccess.make_dir_recursive_absolute(outd)
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_pick_places()
	DisplaySettings.set_fps_meter(true)
	if not _headless():
		# A WINDOW THAT CANNOT BE HIDDEN: a Mac stops drawing a window that is
		# covered or minimised, and every wait for a drawn frame then waits
		# for ever (the first run, Oct 27, stopped on the chart at 3x, a
		# window the size of the screen). The game view is 960x540 at any size.
		DisplaySettings.set_scale(1)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		await _settle(0.5)
	var all: Array = ALL_SCREENS.duplicate()
	all.erase("map2")
	all.append_array(MORE)
	var screens := _arg("screens", ",".join(all)).split(",", false)
	var seen := 0
	for sc in screens:
		if not await _go(sc):
			_ok("%s could not be shown" % sc, false)
			continue
		await _settle(1.3)
		var m: FpsMeter = null
		for n in tree.root.find_children("*", "FpsMeter", true, false):
			if (n as FpsMeter).is_visible_in_tree():
				m = n as FpsMeter
		if m == null or m.text == "":
			_ok("%s: no frame counter on screen" % sc, false)
			continue
		seen += 1
		await _check(sc, m, outd)
	_ok("every screen checked (%d of %d)" % [seen, screens.size()], seen == screens.size())
	_leave()
	_restore_galaxy()
	print("meterfittest: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	tree.quit(1 if _fails > 0 else 0)


func _go(sc: String) -> bool:
	match sc:
		"ship", "cards", "modules":
			_leave()
			_restore_galaxy()
			match sc:
				"ship":
					Router.show_ship()
				"cards":
					Router.show_cards()
				"modules":
					Router.show_modules()
			await _settle(1.0)
			return Router.current != null
	return await super._go(sc)


## One screen: the meter's ink against everything in its viewport.
func _check(sc: String, m: FpsMeter, outd: String) -> void:
	var vp := m.get_viewport_rect().size
	var ink := _ink(m)
	var pad := ink.grow(1.0)
	var win := Rect2(Vector2.ZERO, vp)
	print("  %s (%s): meter '%s', box %s, ink rows %d-%d, cols %d-%d" % [sc, "none" if Router.current == null else String(Router.current.name),
		m.text, m.get_global_rect(), int(ink.position.y), int(ink.end.y) - 1, int(ink.position.x), int(ink.end.x) - 1])
	_ok("%s: the ink inside the window, a pixel clear of its edge (ink %s, window %s)" % [sc, ink, vp],
		win.grow(-1.0).encloses(ink))
	var hits := _hits(m, pad, win)
	for h in hits:
		_ok("%s: %s" % [sc, h], false)
	if sc == "title":
		var stamp := Router.current.find_child("BuildStamp", true, false) as Label
		_ok("title: a build stamp", stamp != null)
		if stamp != null:
			var was := stamp.offset_bottom
			# WHERE AN EXPORT PUTS IT: no developer switch, so the stamp takes
			# the switch's place (offset_bottom -10)
			stamp.offset_bottom = -10
			await _frame()
			var r := _shown(stamp)
			print("    build stamp where an export puts it: %s" % r)
			_ok("title: the export's build stamp clear of the meter (%s)" % r, not r.intersects(pad))
			stamp.offset_bottom = was
			await _frame()
	if not _headless():
		await _pixels(sc, m, outd)


## Every visible thing in the meter's viewport that meets `pad`, by what it is.
func _hits(m: FpsMeter, pad: Rect2, win: Rect2) -> Array[String]:
	var out: Array[String] = []
	for n in get_tree().root.find_children("*", "Control", true, false):
		var c := n as Control
		if c == m or c.get_viewport() != m.get_viewport() or not c.is_visible_in_tree():
			continue
		if _alpha(c) < 0.05:
			continue
		var r := _shown(c)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var what := "%s %s at %s" % [c.get_class(), c.name, r]
		var t := _text(c)
		if t != "" and r.intersects(pad):
			out.append("text %s '%s' meets the ink" % [what, t.left(24)])
			continue
		var d := _draws(c)
		if d == "":
			continue
		# THE MAP'S SKY DRAWN AGAIN PAST ITS PICTURE (`SystemMapScreen`'s
		# GasPastPicture, `nav_ext.gdshader`): a backdrop sized past the window
		# and faded at its edges, with no line anywhere (`FieldEdgeTest` leaves
		# it out too). The meter sits over it as it sits over the title's sky;
		# in the margin band it drew nothing at all (Oct 27, the map's stills).
		if c.name == &"GasPastPicture":
			continue
		var edges := {
			"top": Rect2(r.position.x, r.position.y, r.size.x, 1.0),
			"bottom": Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0),
			"left": Rect2(r.position.x, r.position.y, 1.0, r.size.y),
			"right": Rect2(r.end.x - 1.0, r.position.y, 1.0, r.size.y),
		}
		for side: String in edges:
			var e: Rect2 = edges[side]
			# (an edge on the window's own edge is where the window stops)
			if (e.size.y == 1.0 and (e.position.y <= 0.0 or e.position.y >= win.end.y - 1.0)) \
					or (e.size.x == 1.0 and (e.position.x <= 0.0 or e.position.x >= win.end.x - 1.0)):
				continue
			if e.intersects(pad):
				out.append("the %s edge of %s (%s) passes through the ink" % [side, what, d])
	return out


## What the control shows of itself, in viewport pixels: its rect cut to every
## clipping parent's, up to a top-level one (which no parent clips).
func _shown(c: Control) -> Rect2:
	var r := c.get_global_rect()
	r = Rect2(r.position.floor(), (r.end.ceil() - r.position.floor()))
	var n: Node = c
	while n != null and not (n is Control and (n as Control).is_set_as_top_level()):
		n = n.get_parent()
		var p := n as Control
		if p != null and (p.clip_contents or p is ScrollContainer):
			var pr := p.get_global_rect()
			r = r.intersection(Rect2(pr.position.floor(), pr.end.ceil() - pr.position.floor()))
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				return Rect2()
		if not (n is CanvasItem):
			break
	return r


func _alpha(c: CanvasItem) -> float:
	var a := c.self_modulate.a
	var n: Node = c
	while n is CanvasItem:
		a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	return a


func _text(c: Control) -> String:
	if c is Label:
		return (c as Label).text.strip_edges()
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text().strip_edges()
	if c is LineEdit:
		var le := c as LineEdit
		return le.text if le.text != "" else le.placeholder_text
	if c is Button:
		var b := c as Button
		if b.text.strip_edges() != "":
			return b.text.strip_edges()
		if b.icon != null:
			return "(icon)"
	return ""


## What a control draws, or "" for nothing: containers and empty boxes draw
## nothing of their own.
func _draws(c: Control) -> String:
	if c is Panel or c is PanelContainer:
		return "frame" if _box_draws(c.get_theme_stylebox("panel")) else ""
	if c is Button:
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			if _box_draws(c.get_theme_stylebox(st)):
				return "button frame"
	if c is ColorRect:
		return "fill" if (c as ColorRect).color.a > 0.02 else ""
	if c is TextureRect:
		return "picture" if (c as TextureRect).texture != null else ""
	if c is NinePatchRect:
		return "frame" if (c as NinePatchRect).texture != null else ""
	if c is SubViewportContainer:
		return "picture"
	var s := c.get_script() as Script
	while s != null:
		for meth: Dictionary in s.get_script_method_list():
			if meth.name == "_draw":
				return "drawn by %s" % (s.resource_path.get_file() if s.resource_path != "" else "a built-in script")
		s = s.get_base_script()
	return ""


func _box_draws(sb: StyleBox) -> bool:
	if sb == null or sb is StyleBoxEmpty:
		return false
	if sb is StyleBoxFlat:
		var f := sb as StyleBoxFlat
		var border := f.border_color.a > 0.02 and (f.border_width_left + f.border_width_top + f.border_width_right + f.border_width_bottom) > 0
		return border or (f.draw_center and f.bg_color.a > 0.02) or f.shadow_size > 0
	return true


## WHERE THE METER'S FIGURES ARE DRAWN (viewport px), from the font's glyphs:
## the label right-aligns one line in a box its own minimum size, the baseline
## the font's ascent below the top.
func _ink(m: FpsMeter) -> Rect2:
	var f := UITheme.pixel_font()
	var fs := UITheme.FS_SMALL
	var ts := TextServerManager.get_primary_interface()
	var line := TextLine.new()
	line.add_string(m.text, f, fs)
	var box := m.get_global_rect()
	var x := box.end.x - line.get_line_width()
	var base := box.position.y + f.get_ascent(fs)
	var ink := Rect2()
	for g: Dictionary in ts.shaped_text_get_glyphs(line.get_rid()):
		var key := Vector2i(int(g.font_size), 0)
		var gs: Vector2 = ts.font_get_glyph_size(g.font_rid, key, int(g.index))
		if gs.x > 0.0 and gs.y > 0.0:
			var at: Vector2 = Vector2(x, base) + (g.offset as Vector2) + ts.font_get_glyph_offset(g.font_rid, key, int(g.index))
			var gr := Rect2(at, gs).grow(-GLYPH_MARGIN)
			ink = gr if ink.size == Vector2.ZERO else ink.merge(gr)
		x += float(g.advance)
	return Rect2(ink.position.round(), ink.size.round())


## With a window: the screen with the meter on and off, written when `out=` is
## given, and the ink found in the pixels -- the meter's colour, where the two
## differ -- which has to be the glyphs' ink exactly.
func _pixels(sc: String, m: FpsMeter, outd: String) -> void:
	var tex := GameShell.input_target(get_tree()).get_texture()
	await RenderingServer.frame_post_draw
	# (the reading as this frame drew it: the glyphs' ink worked out in the
	# same frame as the picture is taken)
	var ink := _ink(m)
	var box := m.get_global_rect()
	var col: Color = m.get_theme_color("font_color")
	var on := tex.get_image()
	m.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var off := tex.get_image()
	m.visible = true
	if outd != "":
		on.save_png(outd.path_join("%s.png" % sc))
		off.save_png(outd.path_join("%s_off.png" % sc))
	var seen := Rect2()
	var count := 0
	var look := box.grow(4.0).intersection(Rect2(Vector2.ZERO, Vector2(on.get_size())))
	for y in range(int(look.position.y), int(look.end.y)):
		for x in range(int(look.position.x), int(look.end.x)):
			var p := on.get_pixel(x, y)
			if p.is_equal_approx(off.get_pixel(x, y)):
				continue
			if absf(p.r - col.r) + absf(p.g - col.g) + absf(p.b - col.b) > 0.04:
				continue
			var px := Rect2(x, y, 1, 1)
			seen = px if count == 0 else seen.merge(px)
			count += 1
	print("    ink in the pixels: %d px, rows %d-%d, cols %d-%d" % [count, int(seen.position.y), int(seen.end.y) - 1,
		int(seen.position.x), int(seen.end.x) - 1])
	_ok("%s: the meter's ink found in the pixels" % sc, count > 0)
	_ok("%s: the pixels' ink %s is the glyphs' %s" % [sc, seen, ink], count == 0 or seen == ink)
