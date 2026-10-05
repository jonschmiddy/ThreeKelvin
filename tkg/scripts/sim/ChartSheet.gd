extends Node

## The star chart and the title screen's galaxy, photographed at fixed states:
##   godot --path . -- sheet=ChartSheet out=<dir>
##
## FOR PROVING A CHANGE TO THE CHART'S DRAWING CHANGED NOTHING YOU CAN SEE. Run it
## before the change and after, into two folders, and diff the folders. Every
## state is reached the same way both times -- the same seed, the same zooms,
## the same drag a frame at a time -- and the sky's clock is held on a chosen
## moment through `MapChart.clock_override`, so even the galaxy's turn, the gas
## and the swirl round the hole are compared at the same instant.
##
## The states: the chart as it opens; a ladder of zooms on the core from the
## minimum to the maximum; the ship framed; the wheel in and out about a point
## off centre (which pivots the sky); drags short, long, by fractions of a pixel,
## zoomed in and at the minimum (the old sky's slide margin set their lengths);
## the core at several moments, the galaxy turned to each of them, a
## pulsar's flash and a gamma-ray burst in each of the places one can happen; a
## system pointed at, one selected and a cloud pointed at, which are the chart's
## own drawing rather than the sky's; the escape menu's inset; and the title
## screen's galaxy, turned and not.
##
## Each PNG is the chart's own rect cut out of the frame it is drawn in (the
## title shots are the whole 960x540 frame, with everything but the galaxy
## hidden). `out` defaults to user://chartsheet.
## NEEDS A WINDOW: the renderer has to run for there to be pixels.

var out := "user://chartsheet"
var _chart: Control = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("out="):
			out = (a as String).substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	var MC = StarchartScreen.MapChart
	MC.clock_override = 123.456
	Rng.forced = 4242
	Run.start_new_run(&"korvan", 1)
	Router.show_starchart()
	await _frames(60)
	var scp := Router.current as StarchartScreen
	scp.dismiss_primer()
	_chart = scp._chart
	# Nothing the real pointer does may reach it: a hover would draw a tooltip
	# and the reticle into the picture.
	_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await _shot("c00_default")

	# ZOOM, minimum to maximum, on the core.
	for z: float in [0.42, 0.55, 0.78, 1.0, 1.4, 2.0, 2.9, 4.2, 6.0]:
		_chart._go_to(z, Vector2.ZERO, false)
		await _shot("c1_zoom_%05.2f" % z)
	# The ship framed.
	_chart.center_on_ship(1.2)
	await _shot("c20_ship_1.2")
	_chart.center_on_ship(3.0)
	await _shot("c21_ship_3.0")

	# THE WHEEL, which pivots the sky about the cursor and leaves the pan on
	# fractions of a pixel.
	_chart._go_to(1.0, Vector2.ZERO, false)
	await _frames(2)
	for i in 6:
		_chart._zoom_at(_chart.size * Vector2(0.3, 0.35), 1.12)
		await _frames(1)
	await _shot("c30_wheel_in")
	for i in 10:
		_chart._zoom_at(_chart.size * Vector2(0.7, 0.6), 1.0 / 1.12)
		await _frames(1)
	await _shot("c31_wheel_out")

	# DRAGS, a frame at a time as the hand does it.
	_chart._go_to(1.0, Vector2.ZERO, false)
	await _frames(2)
	await _drag(Vector2(3.0, 1.2), 40)
	await _shot("c40_drag_inside_margin")
	await _drag(Vector2(3.0, 1.2), 60)
	await _shot("c41_drag_past_margin")
	await _drag(Vector2(-2.5, 0.7), 37)
	await _shot("c42_drag_fractional")
	_chart._go_to(2.6, Vector2(100.0, -50.0), false)
	await _frames(2)
	await _drag(Vector2(-3.0, -1.2), 90)
	await _shot("c43_drag_zoom2.6")
	_chart._go_to(0.42, Vector2.ZERO, false)
	await _frames(2)
	await _drag(Vector2(3.0, -1.2), 120)
	await _shot("c44_drag_min_zoom")

	# THE LIVE LAYER AT OTHER MOMENTS.
	_chart._go_to(3.0, Vector2.ZERO, false)
	MC.clock_override = 123.456
	await _shot("c50_core_t123")
	MC.clock_override = 50.0
	await _shot("c51_core_t50")
	MC.clock_override = 3600.25
	await _shot("c52_core_t3600")
	_chart._go_to(0.42, Vector2.ZERO, false)
	MC.clock_override = 110.05
	await _shot("c53_pulsar_flash")
	var bursts := _burst_times()
	if bursts.has("galaxy"):
		MC.clock_override = bursts["galaxy"]
		await _shot("c54_burst_in_galaxy")
	if bursts.has("deep"):
		MC.clock_override = bursts["deep"]
		await _shot("c55_burst_in_deep_field")
	print("CHARTSHEET bursts at %s" % [bursts])
	# The core again, then 59 seconds on: the turn, the climb toward the hole
	# and the swirl all moved on.
	_chart._go_to(3.0, Vector2.ZERO, false)
	MC.clock_override = 123.456
	await _shot("c56_core_t123_again")
	MC.clock_override = 182.9
	await _shot("c57_core_t182.9")

	# THE CHART'S OWN DRAWING: a system pointed at, one selected, a cloud
	# pointed at. Picked the same way every time: the first charted system in
	# range, and the first cloud.
	MC.clock_override = 123.456
	_chart.center_on_ship(1.4)
	var pick := -1
	for raw in Run.in_range():
		if Run.charted(raw):
			pick = (raw as MapGen.MapNode).index
			break
	if pick >= 0:
		_chart.hovered = pick
		_chart._hover_t = 1.0
		_chart.queue_redraw()
		await _shot("c60_hover_system")
		_chart.hovered = -1
		_chart._hover_t = 0.0
		_chart.set_state(pick)
		await _shot("c61_selected")
		_chart.set_state(-1)
	var clouds := NebulaField.clouds()
	if not clouds.is_empty():
		var cl: NebulaField.Cloud = clouds[0]
		# Through the chart's projection, so the cloud is in the middle however
		# the galaxy has turned.
		_chart._go_to(1.0, -_chart._proj_unit(cl.pos), false)
		_chart._neb_hot = cl.name
		_chart._neb_hot_emit = cl.emission
		_chart._neb_hot_kind = cl.label()
		_chart._neb_hot_at = _chart.size * 0.5
		_chart.queue_redraw()
		await _shot("c62_hover_cloud")
		_chart._neb_hot = ""
		_chart.queue_redraw()

	# THE ESCAPE MENU'S INSET: the same chart in a small box, free to pan, with
	# no scale bar.
	var main := get_parent()
	main.toggle_menu()
	await _frames(40)
	var inset := _find_chart(main._menu)
	if inset != null:
		var keep := _chart
		_chart = inset
		await _shot("p0_pause_inset")
		_chart = keep
	main.toggle_menu(false)
	await _frames(5)

	# THE TITLE SCREEN, which draws the same galaxy class bigger than the screen
	# and turned.
	MC.clock_override = 123.456
	LauncherScreen._sky_kind = -1
	seed(4242)
	Router.show_launcher()
	await _frames(40)
	var ls := Router.current as LauncherScreen
	ls.set_process(false)
	for c in ls.get_children():
		if c != ls._sky and c is CanvasItem:
			(c as CanvasItem).visible = false
	_chart = null
	for r: float in [0.0, 0.7, 2.4]:
		ls._sky.set_sky_rotation(r)
		await _shot("t_title_rot%.1f" % r)

	print("CHARTSHEET wrote %s" % ProjectSettings.globalize_path(out))
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _drag(d: Vector2, frames: int) -> void:
	for i in frames:
		var before: Vector2 = _chart.pan
		_chart.pan += d
		_chart._clamp_pan()
		_chart.sky_pan += _chart.pan - before
		_chart._repaint_galaxy()
		await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await _frames(4)
	if _chart == null:
		GameShell.instance.view.get_texture().get_image().save_png(out.path_join(name + ".png"))
		return
	# From whichever viewport the chart is drawn in, at its place on that
	# viewport's canvas: the escape menu sits on a layer of its own.
	var img := _chart.get_viewport().get_texture().get_image()
	var at := _chart.get_global_transform_with_canvas().origin
	img = img.get_region(Rect2i(Vector2i(at.round()), Vector2i(_chart.size.round())))
	img.save_png(out.path_join(name + ".png"))


func _find_chart(n: Node) -> Control:
	if n == null:
		return null
	if n is StarchartScreen.MapChart:
		return n as Control
	for c in n.get_children():
		var f := _find_chart(c)
		if f != null:
			return f
	return null


## The first moment a burst is lit in each of the two places one can happen,
## found with the chart's own hashes, so the shot does not wait on luck.
func _burst_times() -> Dictionary:
	var found := {}
	for idx in 400:
		for slot in 3:
			var period: float = 13.0 + float(slot) * 8.0
			if _chart._frac(_chart._hash2(idx, slot, 6021)) > 0.4:
				continue
			var start: float = float(idx) * period \
				+ _chart._frac(_chart._hash2(idx, slot, 77)) * (period - 1.2)
			var kind := "galaxy" if _chart._frac(_chart._hash2(idx, slot, 131)) < 0.55 \
				else "deep"
			if not found.has(kind):
				found[kind] = start + 0.12
		if found.size() == 2:
			break
	return found
