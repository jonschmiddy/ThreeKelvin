extends Harness

## The sector map's worlds keep up with the camera, headless:
##   godot --headless --path . -- maplagtest
##
## Jon: "When moving the view left to right in the sector view, the planets seem
## to lag behind." Each world's picture is eased onto its place on the grid as a
## zoom settles (`SystemView._live`); the ease once chased the place on a pan
## too, so the picture trailed its own orbit ring, label and beacons by about
## 2.4 frames of the pan (13 px at 6 px a frame, 30 at 12, on a 30 fps window;
## more on a faster one). Through the real map: zoomed in and settled, then
## panned 6 px a frame both ways, and every world's picture must sit on its place
## (`SystemView.world_lag`) on every frame of the pan. The used state, not the
## fresh one: the zoom has just moved and settled before the pan starts, and the
## pan turns round halfway.

var _tree: SceneTree

const PAN_PX := 6.0
const PAN_FRAMES := 40
## a world's picture may sit this far off its place, px (its centre's odd-size
## nudge is a pixel; the old trail was 13 px and more)
const MAX_LAG := 1.0


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_system()
	await _frames(40)
	var map := Router.current as SystemMapScreen
	if not _ok("the sector map is up", map != null and map.view.layout != null):
		_finish()
		return
	var view = map.view
	map.frozen = true
	map._location_on = false
	if not _ok("the system has worlds to watch (%d)" % view._views.size(), view._views.size() > 0):
		_finish()
		return
	# zoomed in by the wheel's own ease, and left to settle
	map._zoom_to = minf(view.ZOOM_MAX, map.zoom_min * 2.5)
	await _frames(300)
	_ok("the zoom has settled (zoom %.2f)" % view.zoom, not view.zooming())
	var worst := 0.0
	var worst_at := ""
	for k in PAN_FRAMES:
		var dir := -1.0 if k < PAN_FRAMES / 2 else 1.0
		view.pan += Vector2(PAN_PX * dir, 0.0)
		await _tree.process_frame
		for i: int in view._views:
			var lag: float = view.world_lag(i).length()
			if lag > worst:
				worst = lag
				worst_at = "world %d, pan frame %d" % [i, k]
	_ok("every world's picture on its place through a %.0f px a frame pan, both ways (worst %.2f px%s)" % [
		PAN_PX, worst, "" if worst_at == "" else " at " + worst_at], worst <= MAX_LAG)
	_finish()


func _frames(k: int) -> void:
	for i in k:
		await _tree.process_frame


func _finish() -> void:
	verdict("maplagtest")
	_tree.quit(1 if _fails > 0 else 0)
