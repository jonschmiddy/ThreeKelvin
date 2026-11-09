extends Harness

## Worlds must sit on their place during a pan; the ease once trailed by about 2.4 frames (Jon).
## Why: docs/why/MapLagTest.md#map-lag

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
	await Harness.frames(_tree, 40)
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
	await Harness.frames(_tree, 300)
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


func _finish() -> void:
	verdict("maplagtest")
	_tree.quit(1 if _fails > 0 else 0)
