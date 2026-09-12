extends RefCounted

## Contact sheet for the moving parts of a sector:
##
##   godot --path . -- placesheet
##
## `SkyTest` shoots one frame per place, which is the right tool for judging a
## composition and the wrong one for judging an animation. Two things in a
## sector move -- the beacon's rings and a station's navigation strobes -- and a
## single frame cannot tell a ring travelling outward from five circles that
## happen to be drawn at those radii.
##
## So this is the same place across one full cycle, left to right. A row that
## reads as five different pictures is working. A row where the eye cannot find
## what changed is an animation nobody will ever notice, and should be cut
## rather than kept for the changelog.
##
## NOT HEADLESS: it renders through SubViewports and needs a real display, the
## same as every other sheet in this folder.

const W := 420
const H := 260
## Frames across one beacon cycle. `RING_S * 5` is the period, so these are
## evenly spaced through it and the last one is NOT the first repeated.
const SHOTS := 5


func run(tree: SceneTree) -> void:
	await tree.process_frame
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))

	var rows := [
		["beacon", _node(7, MapGen.NodeType.SYSTEM, MapGen.Development.UNCLAIMED)],
		["station", _node(3, MapGen.NodeType.STATION, MapGen.Development.CAPITAL)],
	]
	var sheet := Image.create(W * SHOTS, H * rows.size(), false, Image.FORMAT_RGBA8)

	var period: float = EncounterView.AreaView.RING_S * 5.0
	for r in rows.size():
		var n: MapGen.MapNode = rows[r][1]
		for i in SHOTS:
			var at := period * float(i) / float(SHOTS)
			var img := await _frame(tree, n, at)
			sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(W * i, H * r))
		print("  %-8s %d frames across %.1fs" % [rows[r][0], SHOTS, period])

	var path := "user://place_sheet.png"
	sheet.save_png(path)
	print("wrote %s" % ProjectSettings.globalize_path(path))
	tree.quit()


## One frame of one place, with the clock wound to `at`.
##
## The clock is SET rather than waited for. `_process` would get there on its
## own in a few seconds a frame, and a sheet that takes ten seconds to render is
## a sheet nobody runs twice -- and worse, the frames would land wherever the
## frame rate put them rather than on even divisions of the cycle.
func _frame(tree: SceneTree, n: MapGen.MapNode, at: float) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(vp)

	var view := EncounterView.new()
	view.size = Vector2(W, H)
	vp.add_child(view)
	view.set_place(n)
	view.show_area(n)
	var area: EncounterView.AreaView = view._area
	area.set_process(false)          # nothing may advance it under us
	area._clock = at
	area._phase = fposmod(at / EncounterView.AreaView.RING_S, 5.0)
	area.queue_redraw()

	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


func _node(idx: int, type: int, dev: int) -> MapGen.MapNode:
	var n := MapGen.MapNode.new()
	n.index = idx
	n.type = type
	n.development = dev
	n.danger = 4
	n.layer = 3
	return n
