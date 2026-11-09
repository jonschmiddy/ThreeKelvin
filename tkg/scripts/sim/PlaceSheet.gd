extends RefCounted

## One place across a full cycle, as one frame cannot tell a travelling ring from circles.
## Not headless: needs a real display.
## Why: docs/why/PlaceSheet.md#place-contact-sheet

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

	var period: float = AreaView.RING_S * 5.0
	for r in rows.size():
		var n: MapGen.MapNode = rows[r][1]
		# (a station's ring is drawn only at the station: dock:A)
		Router.park_at_station(n)
		for i in SHOTS:
			var at := period * float(i) / float(SHOTS)
			var img := await _frame(tree, n, at)
			sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(W * i, H * r))
		print("  %-8s %d frames across %.1fs" % [rows[r][0], SHOTS, period])

	var path := "user://place_sheet.png"
	sheet.save_png(path)
	print("wrote %s" % ProjectSettings.globalize_path(path))
	tree.quit()


## The clock is set, not waited for, so frames land on even divisions of the cycle.
## Why: docs/why/PlaceSheet.md#place-frame
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
	var area: AreaView = view._area
	area.set_process(false)          # nothing may advance it under us
	area._clock = at
	area._phase = fposmod(at / AreaView.RING_S, 5.0)
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
