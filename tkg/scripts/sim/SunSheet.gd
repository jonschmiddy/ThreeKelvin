extends Node

## The system map's ordinary, red and blue suns on one sheet, as the GPU paints
## them (`SunView` + `sun.gdshader`), each in the mockup's 420x300 box on black:
##   godot --path . -- sheet=SunSheet sun_out=<png> [sun_cases=<txt>] [sun_t=S]
##       [sun_from=S] [sun_bg=#rrggbb]
##   godot --path . -- sheet=SunSheet sun_bench=1 [sun_copies=N] [sun_zoom=K]
##   godot --path . -- sheet=SunSheet sun_out=<png> sun_zooms=1,2,3,4 [sun_cases=<txt>]
##
## The default cases are the mockup page's own suns -- system 0 (index 18, a red
## giant), 3 (index 311, ordinary) and 6 (index 1023, blue) -- then a few other
## systems of each kind chosen so that every look in each kind's pool appears.
## A cases file has one sun a line, `KIND:system_index:radius:t`, for setting
## beside the mockup's own render of the same suns (scratchpad `sun/mkref.py`).
##
## `sun_bench=1` puts N copies (default 20) of one sun at a time where the map
## puts it, in a 960x540 view with vsync off, and prints what one sun adds to
## the frame and to the view's GPU time over 120 frames, and what `step` costs
## on the CPU. Copies, because one sun is lost in the noise of a frame.
##
## `sun_zooms=` draws each case once a row at every zoom listed (`set_zoom`),
## each in its whole zoomed box (420k x 300k), left to right. `sun_zoom=K`
## benches the suns zoomed.
## Needs a window: a shader draws nothing headless.

const SUN := preload("res://scripts/ui/sysmap/SunView.gd")
const BW := 420
const BH := 300
const COLS := 4
const DEFAULT := [
	"RED:18:48", "ORDINARY:311:16", "BLUE:1023:24",
	"RED:4:48", "RED:1:48", "RED:7:48", "RED:10:48",
	"ORDINARY:1:16", "ORDINARY:10:16", "ORDINARY:17:16", "ORDINARY:35:16",
	"BLUE:1:24", "BLUE:4:24", "BLUE:6:24", "BLUE:8:24", "BLUE:0:24",
]

var _out := ""
var _cases_path := ""
var _t := 7.3
var _bench := false
## with `sun_from=S`, each sun is stepped at 60 fps of clock from S up to its t
## first, so what a sun carries between frames (a spray's drops) is tested too
var _from := -1.0
var _step_ms := 0.0
var _bench_copies := 20
## the zooms of a zoom sheet (`sun_zooms=1,2,3,4`), and the bench's zoom
var _zooms: Array[float] = []
var _bench_zoom := 1.0
## the sheet's background (`sun_bg=#rrggbb`): black matches the mockup's own
## render of a sun; a sky colour shows the face laid on solid and the rest added
var _bg := Color.BLACK


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("sun_out="):
			_out = a.substr(8)
		elif a.begins_with("sun_cases="):
			_cases_path = a.substr(10)
		elif a.begins_with("sun_t="):
			_t = float(a.substr(6))
		elif a.begins_with("sun_from="):
			_from = float(a.substr(9))
		elif a == "sun_bench=1":
			_bench = true
		elif a.begins_with("sun_bg="):
			_bg = Color(a.substr(7))
		elif a.begins_with("sun_copies="):
			_bench_copies = int(a.substr(11))
		elif a.begins_with("sun_zooms="):
			for z in a.substr(10).split(","):
				_zooms.append(float(z))
		elif a.begins_with("sun_zoom="):
			_bench_zoom = float(a.substr(9))
	if _bench:
		await _run_bench()
	elif not _zooms.is_empty():
		await _run_zooms()
	else:
		await _run_sheet()
	get_tree().quit()


func _cases() -> Array[String]:
	var out: Array[String] = []
	if _cases_path != "":
		for line in FileAccess.get_file_as_string(_cases_path).split("\n"):
			if line.strip_edges() != "":
				out.append(line.strip_edges())
	else:
		for c: String in DEFAULT:
			out.append("%s:%s" % [c, _t])
	return out


func _run_sheet() -> void:
	var cases := _cases()
	var rows := (cases.size() + COLS - 1) / COLS
	var vp := SubViewport.new()
	vp.size = Vector2i(COLS * BW, rows * BH)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = _bg
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	for i in cases.size():
		var f := cases[i].split(":")
		var sv: Node2D = SUN.new()
		sv.position = Vector2((i % COLS) * BW + 210, (i / COLS) * BH + 150)
		vp.add_child(sv)
		sv.call("setup", f[0], int(f[1]), float(f[2]))
		var t := float(f[3])
		if _from >= 0.0:
			# (the last six seconds of it are enough: a flare lasts under six)
			var s := maxf(_from, t - 6.0)
			while s < t:
				sv.call("step", s)
				s += 1.0 / 60.0
			sv.set("_last", -1e9)
		sv.call("step", t)
		print("  sun %d: %s looks %s" % [i, cases[i], ", ".join(PackedStringArray(sv.P.looks))])
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(_out)
	print("  sunsheet: %d suns to %s" % [cases.size(), _out])


func _run_zooms() -> void:
	var cases := _cases()
	var wide := 0
	var kmax := 1.0
	for k in _zooms:
		wide += int(ceilf(210.0 * k - 0.001)) * 2
		kmax = maxf(kmax, k)
	var row_h := int(ceilf(150.0 * kmax - 0.001)) * 2
	var vp := SubViewport.new()
	vp.size = Vector2i(wide, cases.size() * row_h)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = _bg
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	for i in cases.size():
		var f := cases[i].split(":")
		var x := 0
		for k in _zooms:
			var hx := int(ceilf(210.0 * k - 0.001))
			var sv: Node2D = SUN.new()
			sv.position = Vector2(x + hx, i * row_h + row_h / 2)
			vp.add_child(sv)
			sv.call("setup", f[0], int(f[1]), float(f[2]))
			sv.call("set_zoom", k)
			var t := float(f[3])
			if _from >= 0.0:
				var s := maxf(_from, t - 6.0)
				while s < t:
					sv.call("step", s)
					s += 1.0 / 60.0
				sv.set("_last", -1e9)
			sv.call("step", t)
			x += hx * 2
		print("  sun %d: %s" % [i, cases[i]])
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(_out)
	print("  sunsheet: %d suns at zooms %s to %s" % [cases.size(), str(_zooms), _out])


func _run_bench() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp := SubViewport.new()
	vp.size = Vector2i(960, 540)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	add_child(vp)
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	var bg := ColorRect.new()
	bg.color = Color("#070a12")
	bg.size = Vector2(960, 540)
	vp.add_child(bg)
	# the frame on its own is dominated by whatever else the window is doing, so
	# the sun is drawn COPIES times over and its cost is the difference / COPIES
	var COPIES := int(_bench_copies)
	var base := await _time_frames(vp, [])
	print("  bench: zoom %.2f" % _bench_zoom)
	print("  bench: empty 960x540 view: frame %.3f ms, view GPU %.3f ms, CPU %.3f ms" % [base.x, base.y, base.z])
	for c: String in ["RED:18:48", "ORDINARY:311:16", "BLUE:1023:24", "RED:4:48", "ORDINARY:17:16", "ORDINARY:1:16", "BLUE:1:24", "BLUE:6:24", "BLUE:4:24"]:
		var f := c.split(":")
		var svs: Array[Node2D] = []
		for _k in COPIES:
			var sv: Node2D = SUN.new()
			sv.position = Vector2(264 + (960 - 264) / 2 + 10, 262)
			vp.add_child(sv)
			sv.call("setup", f[0], int(f[1]), float(f[2]))
			sv.call("set_zoom", _bench_zoom)
			svs.append(sv)
		var r := await _time_frames(vp, svs)
		print("  bench: %s (%s): one sun costs %.3f ms of frame, %.3f ms of view GPU; step %.3f ms CPU" % [c, ", ".join(PackedStringArray(svs[0].P.looks)), (r.x - base.x) / COPIES, (r.y - base.y) / COPIES, _step_ms])
		for sv in svs:
			sv.queue_free()
		await get_tree().process_frame


## Mean frame time, the view's GPU time and CPU time over 120 frames, stepping
## the suns at 60 fps of clock time from t = 1 so their flares and 30 Hz
## redraws happen as on the map.
func _time_frames(vp: SubViewport, svs: Array[Node2D]) -> Vector3:
	for _i in 10:
		await get_tree().process_frame
	var t := 1.0
	var step_us := 0
	var steps := 0
	var gpu := 0.0
	var cpu := 0.0
	var t0 := Time.get_ticks_usec()
	for _i in 120:
		for sv in svs:
			var s0 := Time.get_ticks_usec()
			sv.call("step", t)
			step_us += Time.get_ticks_usec() - s0
			steps += 1
		t += 1.0 / 60.0
		await get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid())
	var ms := float(Time.get_ticks_usec() - t0) / 120.0 / 1000.0
	_step_ms = float(step_us) / maxf(1.0, steps) / 1000.0
	return Vector3(ms, gpu / 120.0, cpu / 120.0)
