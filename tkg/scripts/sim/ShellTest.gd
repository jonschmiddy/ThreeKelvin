extends Node

## THE WINDOW SHELL FROM OUTSIDE: what the player's window shows around and
## through the glass, in every shape of window, and what it costs.
##   tools/dev/render.sh --path tkg -- sheet=ShellTest [out=<dir>] [checks] [stills] [bench]
##
## NEEDS A WINDOW, because the shell IS the window. It resizes that window
## through 1X, 2X, 3X, a letterboxed size and BORDERLESS (which covers the whole
## screen for a few seconds). With none of the three parts named it runs all of
## them; `out=` is where the stills and `shell.json` go.
##
##   checks  A pointer moved through the WINDOW onto your ship on LOCAL lights
##           the cutaway's outline and moving off puts it out (the input path
##           through the hidden container, `GameShell._frame`); the container
##           is culled and still takes input; the game frame keeps drawing
##           under the glass; the black is drawn only over the letterbox bands
##           and every pixel of them is black.
##   stills  The window photographed in each shape and look, with a fixed
##           picture in the game frame (a pattern of edges, gradients, single
##           pixels and bright whites, and a station backdrop), so a before and
##           an after set can be diffed pixel for pixel. Named
##           `<window>_<look>.png`.
##   bench   Each shape at the default look with vsync off: frame ms (median,
##           p95), the ROOT viewport's GPU ms (the shell's own passes, which
##           headless cannot see) and the draw calls a frame.
##
## THE GAME IS STOPPED for the stills and the bench: its viewports frozen, its
## screens hidden and a still picture put over it, so the only thing that
## changes from one run to the next is the shell. The checks run first, on the
## real game.

const LOOKS := [["flat", DisplaySettings.Look.FLAT],
	["gentle", DisplaySettings.Look.CRT_GENTLE],
	["arcade", DisplaySettings.Look.CRT_ARCADE]]
## w1/w2/w3: WINDOWED at that scale, the picture filling the window exactly.
## box: a window with room on all four sides (bands left, right, top, bottom).
## bl: BORDERLESS, the screen and one row (bands top and bottom, one odd).
## w3z: 3X asked for after BORDERLESS, which a Mac leaves zoomed (see `_run`).
const BOX := Vector2i(2100, 1240)
const BENCH_FRAMES := 900

var _args: PackedStringArray
var _tree: SceneTree
var _shell: GameShell
var _fails := 0
var _out := ""
var _manifest := {}
var _pic: TextureRect = null
var _marker: ColorRect = null


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _run() -> void:
	_tree = get_tree()
	_shell = GameShell.instance
	_out = _arg("out")
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	var parts := PackedStringArray()
	for p in ["checks", "stills", "bench"]:
		if p in _args:
			parts.append(p)
	if parts.is_empty():
		parts = PackedStringArray(["checks", "stills", "bench"])
	if not _ok("the game is running inside the shell", _shell != null):
		return _finish()
	await _frames(10)
	print("shelltest: screen %s, scale %.1f, adapter %s" % [
		DisplayServer.screen_get_size(DisplaySettings.safe_screen()),
		DisplayServer.screen_get_max_scale(), RenderingServer.get_video_adapter_name()])
	if "checks" in parts:
		# at 2X, so the container's divide is part of what is tested
		await _window("w2")
		await _hover_check()
	_still_game()
	# The pointer is pretended off the glass, so the rect sits at home whatever
	# the real mouse is doing over the window.
	_shell._pointer = Vector2(1e7, 1e7)
	if "checks" in parts:
		await _frame_checks()
	if "stills" in parts:
		await _stills(["w1", "w2", "w3", "box"])
	if "bench" in parts:
		await _bench(["w3", "w2"])
	# BORDERLESS LAST. Leaving it, a Mac keeps the window zoomed to the screen's
	# visible frame (2880x1694 on a 1440x900 Retina) whatever size is asked
	# for, so nothing windowed after it is the window it says. That zoomed
	# window is photographed too (`w3z`): bands top and bottom at a whole 3X.
	await _window("bl")
	if "checks" in parts:
		await _bands_ok("bl")
	if "stills" in parts:
		await _stills(["bl", "w3z"])
	if "bench" in parts:
		await _bench(["bl"])
	if "checks" in parts:
		await _window("w3z")
		await _bands_ok("w3z")
	_finish()


func _finish() -> void:
	if _out != "":
		var f := FileAccess.open(_out.path_join("shell.json"), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(_manifest, "  "))
	print("shelltest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(0 if _fails == 0 else 1)


# --------------------------------------------------------------- the window

## Put the window in shape `w` and wait until the root has its new size.
func _window(w: String) -> void:
	match w:
		"w1": DisplaySettings.set_scale(1)
		"w2": DisplaySettings.set_scale(2)
		"w3", "w3z": DisplaySettings.set_scale(3)
		"box":
			DisplaySettings.set_scale(2)
			await _frames(4)
			DisplayServer.window_set_size(BOX)
		"bl": DisplaySettings.set_mode(DisplaySettings.Mode.BORDERLESS)
	var last := Vector2i(-1, -1)
	var still := 0
	for i in 120:
		await _frames(1)
		var now := Vector2i(_tree.root.get_visible_rect().size)
		still = still + 1 if now == last else 0
		last = now
		if still >= 8:
			break
	await _frames(4)


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img := _tree.root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _look(look: int) -> void:
	DisplaySettings.screen_look = look as DisplaySettings.Look
	GameShell.refresh()
	await _frames(3)


# ------------------------------------------------------------ the still game

## Freeze the game and put a fixed picture in its frame.
func _still_game() -> void:
	var main := _shell.view.get_child(0)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	if main is CanvasItem:
		(main as CanvasItem).visible = false
	for n in _all(main):
		if n is SubViewport:
			(n as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
		elif n is CanvasLayer:
			(n as CanvasLayer).visible = false
	var layer := CanvasLayer.new()
	layer.layer = 128
	_pic = TextureRect.new()
	_pic.texture = ImageTexture.create_from_image(_picture())
	_pic.position = Vector2.ZERO
	_pic.size = Vector2(GameShell.BASE)
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_pic)
	_marker = ColorRect.new()
	_marker.position = Vector2(8, 8)
	_marker.size = Vector2(16, 16)
	_marker.visible = false
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_marker)
	_shell.view.add_child(layer)


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all(c))
	return out


## Edges, gradients, single pixels, saturated blocks, whites above the shader's
## knee, and a real backdrop: everything the glass treats differently.
func _picture() -> Image:
	var w := GameShell.BASE.x
	var h := GameShell.BASE.y
	var px := PackedByteArray()
	px.resize(w * h * 4)
	var i := 0
	for y in h:
		for x in w:
			var r := int(float(x) * 255.0 / float(w - 1))
			var g := int(float(y) * 255.0 / float(h - 1))
			var b := (x * 13 + y * 7) % 256
			if x % 16 == 0:
				r = 255; g = 255; b = 255
			elif y % 24 == 0:
				r = 0; g = 0; b = 0
			elif x < 64 and y < 64:
				var odd := (x + y) % 2 == 1
				r = 255 if odd else 0; g = 0; b = 0 if odd else 255
			px[i] = r; px[i + 1] = g; px[i + 2] = b; px[i + 3] = 255
			i += 4
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, px)
	var art := load("res://art/sprites/station/backdrop_city_bar11a.png") as Texture2D
	if art != null:
		var a := art.get_image()
		a.convert(Image.FORMAT_RGBA8)
		img.blend_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i(80, 70))
	for k in 6:
		var c: Color = [Color.MAGENTA, Color.CYAN, Color.YELLOW, Color.WHITE,
			Color(0.5, 0.5, 0.5), Color.BLACK][k]
		img.fill_rect(Rect2i(120 + k * 40, 490, 30, 30), c)
	return img


# ------------------------------------------------------------------- checks

## THE CUTAWAY'S HOVER, THROUGH THE WINDOW. Your ship on LOCAL at rest; a
## pointer pushed at the WINDOW pixel where the hull's middle is drawn has to
## reach the ship's slot through the shell's container -- which is not drawn --
## and light the outline, and one moved off the hull has to put it out.
func _hover_check() -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	var sc: SectorScreen = null
	var art: ShipView = null
	# A new run's ship flies in: wait for the arrival to start and end, then a
	# second more (a run with no arrival at all is let through after five).
	var saw_arrive := false
	var parked_ms := -1
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 40000:
		await _tree.process_frame
		sc = Router.current as SectorScreen
		art = sc._view.ship_view() if sc != null and sc._view != null else null
		if art == null or sc._ship_outline == null:
			continue
		var now := Time.get_ticks_msec()
		if art._arrive_at >= 0:
			saw_arrive = true
		elif saw_arrive and parked_ms < 0:
			parked_ms = now
		var settled := parked_ms >= 0 and now - parked_ms > 1000
		if sc.cutaway_ready() and (settled or (not saw_arrive and now - t0 > 5000)):
			break
	if not _ok("LOCAL is up with your ship at rest (arrival seen %s)" % saw_arrive, art != null
			and sc != null and sc._ship_outline != null and sc.cutaway_ready()):
		return
	sc._still_pointer = Vector2.INF
	DisplaySettings.screen_look = DisplaySettings.Look.CRT_GENTLE
	GameShell.refresh()
	await _frames(2)
	var slot := art.get_parent() as Control
	var to_game := art.get_global_transform_with_canvas()
	var mid := to_game * art.hull_rect().get_center()
	# A point on the ship's slot and off the hull: just outside a corner of
	# the hull's rect, on whichever side the slot reaches.
	var off := Vector2(-1, -1)
	var hr := art.hull_rect()
	for c in [hr.position + Vector2(-3, -3), hr.end + Vector2(3, 3),
			Vector2(hr.end.x + 3, hr.position.y - 3), Vector2(hr.position.x - 3, hr.end.y + 3),
			hr.get_center() + Vector2(0, -hr.size.y * 0.5 - 4)]:
		if not CutawayView.on_hull(art, c) \
				and slot.get_global_rect().has_point(art.get_global_transform() * (c as Vector2)):
			off = to_game * (c as Vector2)
			break
	_ok("the hull's middle is on the hull", CutawayView.on_hull(art, art.hull_rect().get_center()))
	if off.x >= 0.0:
		await _point_at(off)
		_ok("a pointer moved onto the ship's slot off its hull leaves it unlit",
			not sc._ship_outline.visible)
	await _point_at(mid)
	_ok("a pointer moved through the window onto your ship lights its outline (game %s)" % mid,
		sc._ship_outline.visible)
	if off.x >= 0.0:
		await _point_at(off)
		_ok("and moved off the hull puts it out", not sc._ship_outline.visible)
	else:
		print("  (no point on the slot off the hull; the off half is skipped)")


## A motion at the window pixel that SHOWS game point `g`, pushed at the root
## the way the operating system's would be: through the shell, its container,
## the bend and the nudge.
func _point_at(g: Vector2) -> void:
	var win := _window_for(g)
	_shell._pointer = win
	_shell._nudge()
	var e := InputEventMouseMotion.new()
	e.position = win
	e.global_position = win
	_tree.root.push_input(e, true)
	await _frames(2)


## Which window pixel shows the game point `want`: Newton against the bend, as
## `-- warptest` finds it.
func _window_for(want: Vector2) -> Vector2:
	var size := _shell.frame_rect().size
	var p := _shell._home + want / Vector2(GameShell.BASE) * size
	for _i in 8:
		var err := _shell._bend_at(p, _shell._home) - want
		if err.length() < 0.01:
			break
		p -= err / Vector2(GameShell.BASE) * size
	return p


## The container is culled and alive; the game frame keeps drawing under the
## glass; the black is the bands and only the bands.
func _frame_checks() -> void:
	var fr := _shell._frame
	_ok("the input container is not drawn (modulate alpha %.2f; Godot culls under 0.007)" % fr.modulate.a,
		fr.modulate.a < 0.007)
	_ok("and is still in the tree to take input (visible, mouse %d)" % fr.mouse_filter,
		fr.is_visible_in_tree() and fr.mouse_filter != Control.MOUSE_FILTER_IGNORE)
	_ok("and the game's frame still updates every frame",
		_shell.view.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	await _look(DisplaySettings.Look.FLAT)
	# THE PICTURE IS LIVE: a square in the game's corner turned red and then
	# blue is red and then blue through the glass.
	_marker.visible = true
	var seen: Array[Color] = []
	for c in [Color.RED, Color.BLUE]:
		_marker.color = c
		await _frames(2)
		var img := await _grab()
		var k := float(_shell._frame.stretch_shrink)
		var at := Vector2i(_shell._home + Vector2(16, 16) * k)
		seen.append(img.get_pixelv(at))
	_marker.visible = false
	_ok("the game frame keeps drawing through the glass (red then blue: %s, %s)" % [seen[0], seen[1]],
		seen[0].r > 0.8 and seen[0].b < 0.2 and seen[1].b > 0.8 and seen[1].r < 0.2)
	for w in ["w2", "box"]:
		await _window(w)
		await _bands_ok(w)
	await _look(DisplaySettings.Look.CRT_GENTLE)


## Every pixel outside the glass is black, and (on the shell that draws its
## black as bands) the bands are exactly the window less the glass.
func _bands_ok(w: String) -> void:
	var img := await _grab()
	var win := Rect2i(Vector2i.ZERO, img.get_size())
	var glass := Rect2i(Vector2i(_shell._home), Vector2i(_shell.frame_rect().size)).intersection(win)
	var outside := 0
	for r in _minus(win, glass):
		var cut := img.get_region(r)
		var black := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
		black.fill(Color.BLACK)
		if cut.get_data() != black.get_data():
			outside += 1
	_ok("%s %s: everything off the glass %s is black" % [w, win.size, glass], outside == 0)
	var bands = _shell.get("_bands")
	if not _ok("%s: the shell draws its black as bands" % w, bands is Array):
		return
	var area := 0
	var lit: Array[Rect2i] = []
	for b in bands:
		var cr := b as ColorRect
		if cr.visible:
			lit.append(Rect2i(Rect2(cr.position, cr.size)))
			area += int(cr.size.x * cr.size.y)
	var want := _minus(win, glass)
	var want_area := 0
	for r in want:
		want_area += r.size.x * r.size.y
	var overlap := false
	for i in lit.size():
		if lit[i].intersects(glass):
			overlap = true
		for j in range(i + 1, lit.size()):
			if lit[i].intersects(lit[j]):
				overlap = true
	_ok("%s: the bands are the window less the glass (%d px, want %d; %d bands, no overlap)"
			% [w, area, want_area, lit.size()], area == want_area and not overlap)


## `outer` less `inner`, as up to four rects: the rows above and below, then
## the columns either side.
func _minus(outer: Rect2i, inner: Rect2i) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var top := inner.position.y
	var bot := inner.end.y
	if top > outer.position.y:
		out.append(Rect2i(outer.position.x, outer.position.y, outer.size.x, top - outer.position.y))
	if bot < outer.end.y:
		out.append(Rect2i(outer.position.x, bot, outer.size.x, outer.end.y - bot))
	if inner.position.x > outer.position.x:
		out.append(Rect2i(outer.position.x, top, inner.position.x - outer.position.x, bot - top))
	if inner.end.x < outer.end.x:
		out.append(Rect2i(inner.end.x, top, outer.end.x - inner.end.x, bot - top))
	return out


# ------------------------------------------------------------------- stills

func _stills(windows: Array) -> void:
	if _out == "":
		print("  (stills need out=<dir>)")
		return
	for w in windows:
		await _window(w)
		for l in LOOKS:
			await _look(l[1])
			await _save("%s_%s" % [w, l[0]])
		if w in ["w1", "bl"]:
			await _extras(w)
	DisplaySettings.screen_look = DisplaySettings.Look.CRT_GENTLE
	GameShell.refresh()


## The paths every look does not reach: the set switching off, colour help with
## high contrast, and the bezel.
func _extras(w: String) -> void:
	await _look(DisplaySettings.Look.CRT_GENTLE)
	for v in [0.05, 0.3, 0.6, 0.95]:
		_shell.hold_off(v)
		await _frames(3)
		await _save("%s_off%02d" % [w, int(v * 100.0)])
	_shell._mat.set_shader_parameter(&"power_off", 0.0)
	_shell.set_process(true)
	DisplaySettings.colour_help = 2
	DisplaySettings.high_contrast = true
	await _look(DisplaySettings.Look.CRT)
	await _save("%s_cvd2hc" % w)
	DisplaySettings.colour_help = 0
	DisplaySettings.high_contrast = false
	GameShell._edge_style = 3
	await _look(DisplaySettings.Look.CRT_ARCADE)
	await _save("%s_bezel" % w)
	GameShell._edge_style = 6
	GameShell.refresh()


func _save(name: String) -> void:
	var img := await _grab()
	var path := _out.path_join(name + ".png")
	img.save_png(path)
	_manifest[name] = {window = [img.get_width(), img.get_height()],
		home = [_shell._home.x, _shell._home.y], k = _shell._frame.stretch_shrink}
	print("  still %s  %dx%d  glass at %s x%d" % [name, img.get_width(), img.get_height(),
		_shell._home, _shell._frame.stretch_shrink])


# -------------------------------------------------------------------- bench

func _bench(windows: Array) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var root := _tree.root.get_viewport_rid()
	var game := _shell.view.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(root, true)
	RenderingServer.viewport_set_measure_render_time(game, true)
	await _look(DisplaySettings.Look.CRT_GENTLE)
	var rows := {}
	for w in windows:
		await _window(w)
		await _frames(60)
		var ms: Array[float] = []
		var gpu := 0.0
		var gpu_game := 0.0
		var calls := 0.0
		var t := Time.get_ticks_usec()
		for i in BENCH_FRAMES:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			ms.append((now - t) / 1000.0)
			t = now
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(root)
			gpu_game += RenderingServer.viewport_get_measured_render_time_gpu(game)
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		ms.sort()
		var mean := 0.0
		for m in ms:
			mean += m
		mean /= float(ms.size())
		var size := Vector2i(_tree.root.get_visible_rect().size)
		var row := {window = [size.x, size.y], mean_ms = mean, p25_ms = ms[int(ms.size() * 0.25)], p50_ms = ms[int(ms.size() * 0.5)],
			p95_ms = ms[int(ms.size() * 0.95)], root_gpu_ms = gpu / BENCH_FRAMES,
			game_gpu_ms = gpu_game / BENCH_FRAMES, draw_calls = calls / BENCH_FRAMES}
		rows[w] = row
		print("  bench %-3s %4dx%-4d  frame mean %.2f ms  p25 %.2f  p50 %.2f  p95 %.2f  root GPU %.3f ms  game GPU %.3f ms  draw calls %.1f"
			% [w, size.x, size.y, mean, row.p25_ms, row.p50_ms, row.p95_ms, row.root_gpu_ms, row.game_gpu_ms, row.draw_calls])
	var all: Dictionary = _manifest.get("bench", {})
	all.merge(rows)
	_manifest["bench"] = all
