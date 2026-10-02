extends Node

## THE CORE, as the GPU paints it, over a test sky at several moments:
##   godot --path . -- sheet=CoreSheet coreout=<dir> [coretimes=1,4.3,9.7] [coreraw] [corebench=120]
##
## Drawn in its own 960 x 540 viewport, the game's, with the hole where the
## system map puts it (622, 262). The test sky is a grid every 24 px, hashed
## stars and a few dim purple tiles -- the same function as the scratchpad's
## `core/ref.js`, which draws the mockup's `coreDraw` over it, so the two can
## be set side by side pixel for pixel. Writes `core_<t>.png` per moment
## (341 x 331, the lens's whole patch) and `sheet.png`, the moments in a row.
## `coreraw` writes the renderer's own picture instead (330 x 210, no glow, no
## lens: the mockup's `BH.draw`). `corebench=N` then times N frames with the
## hole and N without, and prints the cost. Needs a window: a shader draws
## nothing headless.
##
## ZOOM: `corezoom=1,1.5,2,3,4,2.6` takes the hole through those zooms in turn
## at the first of `coretimes`, in a 1440 x 1380 viewport over the test sky
## (not magnified: the map's sky keeps its stars single pixels zoomed). For each
## k: `standin_<k>.png`, the frame drawn just after the zoom changed (the
## nearest kept trace stretched), when k was not kept yet, and `zoom_<k>.png`,
## once its own trace is in; each the lens's patch, 340k + 1 x 330k + 1. Then
## `zoomsheet.png`, the settled 1, 2, 3, 4 side by side at their own sizes,
## `standins.png`, each stand-in beside its settled frame, and the times.
## `corek=K` with `corebench=N` times the hole at zoom K where the map puts it,
## (480, 270) in the 960 x 540 picture (`corestack` as before), and takes no
## pictures. `coretracetime=1,2,3,4` times the trace itself at each zoom: its
## GPU time and its read back.

const CoreView := preload("res://scripts/ui/sysmap/CoreView.gd")
const CX := 622
const CY := 262

var _dir := "user://core"
var _times: Array[float] = [1.0, 4.3, 9.7, 18.5, 26.0]
var _raw := false
var _bench := 0
var _stack := 1
var _zooms: Array[float] = []
var _bench_k := 0.0
var _trace_ks: Array[float] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("coreout="):
			_dir = s.substr(8)
		elif s.begins_with("coretimes="):
			_times.clear()
			for x in s.substr(10).split(","):
				_times.append(float(x))
		elif s == "coreraw":
			_raw = true
		elif s.begins_with("corebench="):
			_bench = int(s.substr(10))
		elif s.begins_with("corestack="):
			_stack = int(s.substr(10))
		elif s.begins_with("corezoom="):
			for x in s.substr(9).split(","):
				_zooms.append(float(x))
		elif s.begins_with("corek="):
			_bench_k = float(s.substr(6))
		elif s.begins_with("coretracetime="):
			for x in s.substr(14).split(","):
				_trace_ks.append(float(x))
	DirAccess.make_dir_recursive_absolute(_dir)
	if not _trace_ks.is_empty():
		await _trace_time()
		get_tree().quit()
		return
	if not _zooms.is_empty():
		await _zoom_run()
		get_tree().quit()
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(960, 540)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vp)
	var shown := TextureRect.new()
	shown.texture = vp.get_texture()
	shown.scale = Vector2(2, 2)
	add_child(shown)
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(_test_sky())
	vp.add_child(bg)
	var core := CoreView.new()
	core.position = Vector2(CX, CY)
	vp.add_child(core)
	if _raw:
		core.set_raw(true)
		core.take_lens().free()
	core.setup()
	if not core.ready_to_draw:
		await core.traced
	if _bench_k > 0.0 and _bench > 0:
		core.position = Vector2(480, 270)
		await _settle(core, _bench_k, 3.0)
		var cores: Array = [core]
		for i in _stack - 1:
			var more := CoreView.new()
			more.position = Vector2(480, 270)
			vp.add_child(more)
			more.setup()
			if not more.ready_to_draw:
				await more.traced
			await _settle(more, _bench_k, 3.0)
			cores.append(more)
		print("  corebench at zoom %s, at (480, 270)" % String.num(_bench_k))
		await _time(vp, cores)
		get_tree().quit()
		return
	var crop := Rect2i(CX - 165, CY - 105, 330, 210) if _raw else Rect2i(CX - 170, CY - 165, 341, 331)
	var shots: Array[Image] = []
	for t in _times:
		core.step(t)
		for _i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image().get_region(crop)
		img.convert(Image.FORMAT_RGB8)
		img.save_png("%s/%s_%s.png" % [_dir, "raw" if _raw else "core", _tname(t)])
		shots.append(img)
	var sheet := Image.create(crop.size.x * shots.size(), crop.size.y, false, Image.FORMAT_RGB8)
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(Vector2i.ZERO, crop.size), Vector2i(crop.size.x * i, 0))
	sheet.save_png("%s/%s.png" % [_dir, "rawsheet" if _raw else "sheet"])
	print("  coresheet: %d moments to %s" % [shots.size(), _dir])
	if _bench > 0:
		# `corestack=N` piles N holes on the one spot, lens and all, so the GPU's
		# share stands clear of the timer's noise: (with - without) / N each
		var cores: Array = [core]
		for i in _stack - 1:
			var more := CoreView.new()
			more.position = Vector2(CX, CY)
			vp.add_child(more)
			more.setup()
			if not more.ready_to_draw:
				await more.traced
			cores.append(more)
		await _time(vp, cores)
	get_tree().quit()


func _tname(t: float) -> String:
	# 1 not 1.0, as the reference pictures are named
	return str(int(t)) if t == floorf(t) else String.num(t)


## N frames with the hole(s), N with them hidden, vsync off: the CPU time of
## `step` (the first hole's only; the stack's others draw on as they stood,
## which costs the GPU the same) and the wall time of a whole frame, each
## averaged. The viewport's own GPU timer was tried first and is noise here:
## twenty holes read faster than none.
func _time(vp: SubViewport, cores: Array) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var res := {}
	for on in [true, false, true, false]:
		for core: Node2D in cores:
			core.visible = on
			(core.get("lens") as Node2D).visible = on
		for _i in 30:
			await get_tree().process_frame
		var cpu := 0.0
		var w0 := Time.get_ticks_usec()
		for i in _bench:
			var t0 := Time.get_ticks_usec()
			if on:
				cores[0].call("step", 3.0 + i * 0.016)
			cpu += Time.get_ticks_usec() - t0
			await RenderingServer.frame_post_draw
		var wall := float(Time.get_ticks_usec() - w0) / _bench / 1000.0
		res[on] = [cpu / _bench / 1000.0, wall]
	print("  corebench, %d hole(s), over %d frames: step() %.3f ms CPU; a frame %.3f ms with, %.3f without, so %.3f ms a hole" % [cores.size(), _bench, res[true][0], res[true][1], res[false][1], (res[true][1] - res[false][1] - res[true][0]) / cores.size()])
	# and the GPU's share alone: a frame drawn there and then and the picture
	# read back, which waits for the GPU to finish it, with and without
	var sync := {true: 0.0, false: 0.0}
	for _r in 4:
		for on in [true, false]:
			for core: Node2D in cores:
				core.visible = on
				(core.get("lens") as Node2D).visible = on
			for _i in 10:
				await get_tree().process_frame
				var t0 := Time.get_ticks_usec()
				RenderingServer.force_draw(false)
				vp.get_texture().get_image()
				sync[on] += float(Time.get_ticks_usec() - t0) / 1000.0 / 40.0
	print("  corebench, drawn and read back at once: %.3f ms with, %.3f without, so %.3f ms of GPU a hole" % [sync[true], sync[false], (sync[true] - sync[false]) / cores.size()])


## The test sky, the same function as `core/ref.js`'s.
static func _test_sky() -> Image:
	var img := Image.create(960, 540, false, Image.FORMAT_RGB8)
	var base := Color8(7, 10, 18)
	var grid := Color8(28, 44, 70)
	var s1 := Color8(78, 100, 130)
	var s2 := Color8(201, 216, 234)
	var neb := Color8(40, 18, 52)
	for y in 540:
		for x in 960:
			var c := base
			if x % 24 == 0 or y % 24 == 0:
				c = grid
			else:
				var h: float = CoreView.hash2(x * 3 + 1, y * 5 + 2)
				if h < 0.012:
					c = s2
				elif h < 0.04:
					c = s1
				elif ((x >> 4) + (y >> 4)) % 7 == 0:
					c = neb
			img.set_pixel(x, y, c)
	return img


## Zooms the hole to k and waits for its own trace to be drawn, stepping it at
## time t meanwhile.
func _settle(core: Node2D, k: float, t: float) -> void:
	core.call("set_zoom", k)
	core.call("step", t)
	while absf(float(core.get("drawn_zoom")) - k) > 0.002:
		await get_tree().process_frame
		core.call("set_zoom", k)
		core.call("step", t)
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _zoom_run() -> void:
	const VW := 1440
	const VH := 1380
	var c := Vector2i(VW / 2, VH / 2)
	var t := _times[0]
	var vp := SubViewport.new()
	vp.size = Vector2i(VW, VH)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vp)
	var shown := TextureRect.new()
	shown.texture = vp.get_texture()
	shown.scale = Vector2(0.5, 0.5)
	add_child(shown)
	# the test sky round the hole's spot on it, wide enough for zoom 1
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(_test_sky_at(CX - VW / 2, CY - VH / 2, VW, VH))
	vp.add_child(bg)
	var core := CoreView.new()
	core.position = Vector2(c)
	vp.add_child(core)
	core.setup()
	if not core.ready_to_draw:
		await core.traced
	print("  corezoom: traced zoom 1 in %.1f ms (read back %.1f ms)" % [core.trace_ms, core.readback_ms])
	var settled := {}
	var pairs: Array[Image] = []
	for k in _zooms:
		var crop := Rect2i(c.x - roundi(170.0 * k), c.y - roundi(165.0 * k), roundi(340.0 * k) + 1, roundi(330.0 * k) + 1)
		var t0 := Time.get_ticks_usec()
		core.set_zoom(k)
		var set_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		core.step(t)
		var had: float = core.drawn_zoom
		var stand: Image = null
		if absf(had - k) > 0.002:
			for _i in 2:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			stand = vp.get_texture().get_image().get_region(crop)
			stand.convert(Image.FORMAT_RGB8)
			stand.save_png("%s/standin_%s.png" % [_dir, _tname(k)])
			await _settle(core, k, t)
			print("  corezoom %s: stand-in from %s's trace; traced after the settle in %.1f ms, two frames waited included (read back %.1f ms); picture %dx%d" % [_tname(k), _tname(had), core.trace_ms, core.readback_ms, 2 * ceili(165.0 * k - 0.001), 2 * ceili(105.0 * k - 0.001)])
		else:
			await _settle(core, k, t)
			print("  corezoom %s: kept, drawn at once (set_zoom %.2f ms, switch %.2f ms)" % [_tname(k), set_ms, core.use_ms])
		var img := vp.get_texture().get_image().get_region(crop)
		img.convert(Image.FORMAT_RGB8)
		img.save_png("%s/zoom_%s.png" % [_dir, _tname(k)])
		settled[k] = img
		if stand != null:
			var pair := Image.create(img.get_width() * 2 + 8, img.get_height(), false, Image.FORMAT_RGB8)
			pair.blit_rect(stand, Rect2i(Vector2i.ZERO, stand.get_size()), Vector2i.ZERO)
			pair.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(img.get_width() + 8, 0))
			pairs.append(pair)
	print("  corezoom: kept traces at %s, %.1f MB on the CPU (as much again on the GPU)" % [str(CoreView.cache_zooms()), CoreView.cache_bytes() / 1048576.0])
	var row: Array[Image] = []
	for k in [1.0, 2.0, 3.0, 4.0]:
		if settled.has(k):
			row.append(settled[k])
	_strip(row, "zoomsheet")
	_strip(pairs, "standins", true)


## The trace's cost at each zoom: a frame drawn there and then and the bake
## read back, which waits for the GPU to finish it, with the trace drawn and
## without (the difference is the trace's GPU time), and the read back alone.
func _trace_time() -> void:
	for k in _trace_ks:
		var vp: SubViewport = CoreView.trace_viewport(k)
		add_child(vp)
		for _i in 3:
			await RenderingServer.frame_post_draw
		var sync := [0.0, 0.0]
		for _r in 3:
			for on in [1, 0]:
				for _i in 5:
					await get_tree().process_frame
					vp.render_target_update_mode = SubViewport.UPDATE_ONCE if on == 1 else SubViewport.UPDATE_DISABLED
					var t0 := Time.get_ticks_usec()
					RenderingServer.force_draw(false)
					vp.get_texture().get_image()
					sync[on] += float(Time.get_ticks_usec() - t0) / 1000.0 / 15.0
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		for _i in 3:
			await RenderingServer.frame_post_draw
		var rb := 0.0
		var bytes := 0
		for _i in 5:
			var t0 := Time.get_ticks_usec()
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			rb += float(Time.get_ticks_usec() - t0) / 1000.0 / 5.0
			bytes = img.get_data().size()
		vp.queue_free()
		print("  coretrace zoom %s: %dx%d bake, %.1f MB; the trace %.2f ms of GPU (%.2f drawn and read back, %.2f without it); read back alone %.2f ms" % [_tname(k), vp.size.x, vp.size.y, bytes / 1048576.0, sync[1] - sync[0], sync[1], sync[0], rb])


## Images in a row (or a column), 8 px apart, on black.
func _strip(imgs: Array[Image], name: String, down := false) -> void:
	if imgs.is_empty():
		return
	var w := 0
	var h := 0
	for im in imgs:
		w = w + im.get_width() + 8 if not down else maxi(w, im.get_width())
		h = maxi(h, im.get_height()) if not down else h + im.get_height() + 8
	var out := Image.create(w, h, false, Image.FORMAT_RGB8)
	var at := 0
	for im in imgs:
		out.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(at, 0) if not down else Vector2i(0, at))
		at += (im.get_width() if not down else im.get_height()) + 8
	out.save_png("%s/%s.png" % [_dir, name])


## The test sky, any part of it: x0, y0 is the picture's top-left pixel.
static func _test_sky_at(x0: int, y0: int, w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var base := Color8(7, 10, 18)
	var grid := Color8(28, 44, 70)
	var s1 := Color8(78, 100, 130)
	var s2 := Color8(201, 216, 234)
	var neb := Color8(40, 18, 52)
	for j in h:
		var y := y0 + j
		for i in w:
			var x := x0 + i
			var c := base
			if posmod(x, 24) == 0 or posmod(y, 24) == 0:
				c = grid
			else:
				var hv: float = CoreView.hash2(x * 3 + 1, y * 5 + 2)
				if hv < 0.012:
					c = s2
				elif hv < 0.04:
					c = s1
				elif posmod((x >> 4) + (y >> 4), 7) == 0:
					c = neb
			img.set_pixel(i, j, c)
	return img
