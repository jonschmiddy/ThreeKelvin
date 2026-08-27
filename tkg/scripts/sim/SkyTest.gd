extends RefCounted

## Contact sheet for SpaceBackdrop: one sector sky per synthetic node, written
## to PNG. Procedural art is tuned by looking at a dozen rolls side by side,
## never at one.
##
## The second sheet puts the same skies behind a real EncounterView, with the
## ship and the place art on top, because the only question that matters about a
## backdrop is whether the subject still reads over it.

const W := 620
const H := 320
const _KINDS := ["deep", "planet", "giant", "rocks", "star", "fleet", "core"]

func run(tree: SceneTree) -> void:
	# One frame before anything is added: Main is still inside _ready when this
	# is called, and a node cannot take children while it is setting up its own.
	await tree.process_frame
	_census()
	await _sheet(tree, false, "user://sky_sheet.png")
	# The same skies again with a real hull and the place art over them. A
	# backdrop is only as good as what still reads in front of it.
	Run.start_new_run(&"solari", int(HullData.Weight.MEDIUM))
	await _sheet(tree, true, "user://sky_sheet_full.png")
	tree.quit()

func _sheet(tree: SceneTree, full: bool, path: String) -> void:
	var cases := _cases()
	var cols := 3
	var rows := int(ceil(float(cases.size()) / float(cols)))
	var sheet := Image.create(W * cols, H * rows, false, Image.FORMAT_RGBA8)
	for i in cases.size():
		var n: MapGen.MapNode = cases[i][1]
		var vp := SubViewport.new()
		vp.size = Vector2i(W, H)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		tree.root.add_child(vp)
		var t0 := Time.get_ticks_usec()
		if full:
			var view := EncounterView.new()
			view.size = Vector2(W, H)
			vp.add_child(view)
			view.set_place(n)
			view.show_area(n)
		else:
			var wash := ColorRect.new()
			wash.color = Color("#070a10")
			wash.size = Vector2(W, H)
			vp.add_child(wash)
			var bg := SpaceBackdrop.new()
			bg.size = Vector2(W, H)
			vp.add_child(bg)
			bg.setup(n)
			# Drawn size and bake cost, because both are tuning numbers: a body
			# that reads as a corner accent on this sheet and costs 90 ms is a
			# body that wants a smaller radius, and neither fact is visible in
			# the picture.
			var wide := 0.0
			if bg._body != null:
				wide = float(bg._body.get_width() * bg._body_px)
			print("%-22s %-7s  at %.2f,%.2f  %dpx wide  bake %.0f ms" % [
				cases[i][0], _KINDS[bg._kind], bg._body_at.x, bg._body_at.y, wide,
				(Time.get_ticks_usec() - t0) / 1000.0])
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		sheet.blit_rect(vp.get_texture().get_image(), Rect2i(0, 0, W, H),
			Vector2i((i % cols) * W, int(i / cols) * H))
		vp.queue_free()
	sheet.save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))

## What a real galaxy actually gets, by node type. The sheet says a sky looks
## right; this says the spread is there at all — a table that is 80% empty sky
## reads as "the feature did not ship" however good the other 20% is.
func _census() -> void:
	var map := MapGen.generate(Rect2(Vector2.ZERO, Vector2(1600, 900)))
	var tally := {}
	var bg := SpaceBackdrop.new()
	for n in map:
		bg._index = -1
		bg.setup(n)
		var key: String = "%s / %s" % [MapGen.type_label(n.type), _KINDS[bg._kind]]
		tally[key] = int(tally.get(key, 0)) + 1
	bg.free()
	var keys := tally.keys()
	keys.sort()
	print("--- %d systems" % map.size())
	for k in keys:
		print("  %-22s %d" % [k, tally[k]])

func _node(idx: int, type: int, dev: int, berths: Array[StringName],
		fauna: bool = false) -> MapGen.MapNode:
	var n := MapGen.MapNode.new()
	n.index = idx
	n.type = type
	n.development = dev
	n.berths = berths
	n.manufacturer = berths[0] if not berths.is_empty() else &""
	n.security = 3 if not berths.is_empty() else 1
	n.fauna = fauna
	n.danger = 4
	return n

func _cases() -> Array:
	var out: Array = []
	out.append(["station / capital", _node(3, MapGen.NodeType.STATION,
		MapGen.Development.CAPITAL, [&"solari", &"cygnet"])])
	out.append(["station / outpost", _node(11, MapGen.NodeType.STATION,
		MapGen.Development.OUTPOST, [&"probate"])])
	out.append(["station / settlement", _node(24, MapGen.NodeType.STATION,
		MapGen.Development.SETTLEMENT, [&"korvan"])])
	out.append(["event beacon", _node(7, MapGen.NodeType.SYSTEM,
		MapGen.Development.UNCLAIMED, [])])
	out.append(["derelict", _node(9, MapGen.NodeType.SYSTEM,
		MapGen.Development.UNCLAIMED, [])])
	out.append(["derelict b", _node(13, MapGen.NodeType.SYSTEM,
		MapGen.Development.UNCLAIMED, [])])
	out.append(["fight / unclaimed", _node(2, MapGen.NodeType.SYSTEM,
		MapGen.Development.UNCLAIMED, [])])
	out.append(["fight / migration", _node(5, MapGen.NodeType.SYSTEM,
		MapGen.Development.UNCLAIMED, [], true)])
	out.append(["fight / contested", _node(6, MapGen.NodeType.SYSTEM,
		MapGen.Development.SETTLEMENT, [&"solari", &"redline"])])
	out.append(["fight / contested b", _node(28, MapGen.NodeType.SYSTEM,
		MapGen.Development.SETTLEMENT, [&"cygnet", &"redline"])])
	out.append(["fight / city", _node(21, MapGen.NodeType.SYSTEM,
		MapGen.Development.CITY, [&"verity"])])
	out.append(["the core", _node(40, MapGen.NodeType.CORE,
		MapGen.Development.UNCLAIMED, [])])
	return out
