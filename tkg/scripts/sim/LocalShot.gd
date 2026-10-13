extends Node

## LOCAL, photographed: the side-on view (`SectorScreen`, `EncounterView`) in a
## system of a chosen sky, quiet or mid-fight, in the style on the command line.
##
##   godot --path . --windowed --position 3840,0 -- sheet=LocalShot keepwindow
##       [style=simplified|legacy|painted|radiant] [graphics=low] [seed=N]
##       [sky=emission|reflection|planetary|remnant|dark|calm|pulsar|core] [node=I]
##       [combat [fire]] [approach] [wait=F] [out=<png>] [skyout=<png>]
##       [clip=<dir> clipframes=61 clipms=33 cliph=297] [stats=<json>] [bare=<png>] [reduced]
##       [orbit=giant|world|star|edge|belt|derelict] [dustcheck] [nodust] [clipfull] [dustonly]
##
## `out=` is the whole screen, `skyout=` the backdrop alone (its own picture,
## one pixel a block), `clip=` that picture frame after frame for the flicker
## measure (`frames.py`), `stats=` how readable the ships and labels are
## against the backdrop right round them (`_readable`), and how bright the play
## (game y 140 to 330) and the band above it are.
## `orbit=` puts the ship where the sector map would have left it
## (`SystemMapScreen._parked`): in orbit of a ringed giant (or any giant), of a
## world, of the star close in, alongside a belt or a wreck, or free at the
## system's edge; `giant` looks for a system of the sky with a ringed giant.
## `dustcheck` (with `combat fire`): a fight's frames, each taken with the
## foreground dust and again without it, and what the dust covered of the ships'
## pictures and of every label and gauge printed -- the worst frame's share.
## `nodust` turns the dust off; `clipfull` films the whole view, ships and all;
## `dustonly` films the dust alone over the view's plain wash. `fightat=N`
## opens a fight on the clip's Nth frame (with `clipfull`, the screen change
## from LOCAL into it is filmed).
## Needs a window.

const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")

var _args: PackedStringArray


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	Rng.forced = int(_arg("seed", "4242"))
	if "reduced" in _args:
		DisplaySettings.reduced_motion = true
	if "nodust" in _args:
		LocalDust.off = true
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var want := _arg("sky", "calm")
	var orbit := _arg("orbit")
	var idx := int(_arg("node", "-1"))
	if idx < 0:
		for pass_i in 2:
			for n: MapGen.MapNode in Run.map:
				if n.type == MapGen.NodeType.STATION or n.type == MapGen.NodeType.START:
					continue
				if String(SkyWeatherS.sky_of_node(n)) != want:
					continue
				if orbit != "" and orbit != "star" and orbit != "edge" and _body_for(SystemLayout.of(n), orbit, pass_i == 0) < 0:
					continue
				idx = n.index
				break
			if idx >= 0:
				break
	if idx < 0:
		print("no system with a %s sky on seed %d" % [want, Rng.forced])
		tree.quit()
		return
	Run.at = idx
	var node: MapGen.MapNode = Run.node_at()
	if orbit != "":
		var Lo := SystemLayout.of(node)
		var at := -9
		var mode := &"rail"
		match orbit:
			"star":
				at = -1
			"edge":
				mode = &"free"
			_:
				at = _body_for(Lo, orbit, true)
				if at < 0:
					at = _body_for(Lo, orbit, false)
		SystemMapScreen._parked[idx] = {"at": at, "p": Vector2(Lo.edge * 1.02, -210.0), "v": Vector2.ZERO, "head": 0.0, "mode": mode}
		print("  orbit %s: body %d" % [orbit, at])
	print("  node %d %s: sky %s, star %d, nebula %s, giant %s" % [idx, MapGen.star_name(node),
		SkyWeatherS.sky_of_node(node), SystemLayout.of(node).star, node.in_nebula, node.gas_giant])
	if not "approach" in _args:
		SectorScreen._approached_at = idx
	if "combat" in _args:
		Run.hand_size_override = 5
		Router.start_combat(DB.enemies[&"cutter"], [], false)
	else:
		Router.show_local()
	var wait := int(_arg("wait", "90"))
	for i in wait:
		await RenderingServer.frame_post_draw
	# A FIGHT IN PROGRESS: the first cards that can be played, played at the
	# enemy, and the picture taken with their shots in the air
	if "combat" in _args and "fire" in _args:
		var cb = Router.current.get("combat")
		if cb != null:
			var played := 0
			for k in 3:
				for i in (cb.hand as Array).size():
					if cb.can_play(cb.hand[i]):
						cb.play(i, 0)
						played += 1
						break
				for f in 7:
					await RenderingServer.frame_post_draw
			print("  played %d cards" % played)
	var view: EncounterView = null
	var sc = Router.current
	if sc != null and sc.get("_view") != null:
		view = sc.get("_view")
	var sky: Control = view.backdrop if view != null else null
	if view != null:
		var r := view.get_global_rect()
		print("  view %s  ship %s" % [r, view.ship_view().get_global_rect()])
	if "dustcheck" in _args and view != null and view.get("dust") != null:
		await _dustcheck(tree, view)
	var outp := _arg("out")
	if outp != "":
		tree.root.get_texture().get_image().save_png(outp)
		print("wrote ", outp)
	if sky != null:
		var skyp := _arg("skyout")
		if skyp != "" and sky.has_method("picture"):
			var img: Image = sky.call("picture")
			if img != null:
				img.save_png(skyp)
				print("wrote ", skyp)
	if sky != null and sky.has_method("gpu_ms") and not "approach" in _args:
		sky.call("gpu_ms")
		var gsum := 0.0
		for gi in 60:
			await RenderingServer.frame_post_draw
			gsum += float(sky.call("gpu_ms"))
		var gvp := GameShell.input_target(tree)
		RenderingServer.viewport_set_measure_render_time(gvp.get_viewport_rid(), true)
		await RenderingServer.frame_post_draw
		var ggame := 0.0
		for gi in 60:
			await RenderingServer.frame_post_draw
			ggame += RenderingServer.viewport_get_measured_render_time_gpu(gvp.get_viewport_rid())
		print("  sky gpu %.3f ms, game view gpu %.3f ms, fps %d" % [gsum / 60.0, ggame / 60.0, Engine.get_frames_per_second()])
	# THE SKY BARE: the ships, their labels and the shots hidden, the game's own
	# 960x540 picture (before the screen filter) read back
	var statp := _arg("stats")
	var clip := _arg("clip")
	var barep := _arg("bare")
	if view != null and (statp != "" or clip != "" or barep != ""):
		# (for the readability measure: the whole picture first, and where every
		# ship and label is in it)
		var full_img: Image = null
		var r_ships: Array[Rect2] = []
		var r_labels: Array[Rect2] = []
		if statp != "":
			full_img = GameShell.input_target(tree).get_texture().get_image()
			_rects(view, r_ships, r_labels)
		var hid: Array[CanvasItem] = []
		for c in view.get_children():
			var keep_c: bool = c == view.get("dust") or (not "dustonly" in _args and (c == view.backdrop or c == view.weather))
			if not "clipfull" in _args and c is CanvasItem and not keep_c and (c as CanvasItem).visible:
				(c as CanvasItem).visible = false
				hid.append(c)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var vr := view.get_global_rect()
		var arena := Rect2i(int(vr.position.x), int(vr.position.y), int(vr.size.x), mini(int(_arg("cliph", "297")), int(vr.size.y)))
		var gv := GameShell.input_target(tree)
		if barep != "":
			gv.get_texture().get_image().save_png(barep)
			print("wrote ", barep)
		if statp != "":
			var bare_img := gv.get_texture().get_image()
			var st := _stats(bare_img, Rect2i(arena.position.x, 140, arena.size.x, 190))
			var top := _stats(bare_img, Rect2i(arena.position.x, 0, arena.size.x, 70))
			st["top_mean"] = top.mean
			st.merge(_readable(full_img, bare_img, r_ships, r_labels, Rect2(arena)))
			var f := FileAccess.open(statp, FileAccess.WRITE)
			f.store_string(JSON.stringify(st))
			print("  stats ", JSON.stringify(st))
		if clip != "":
			DirAccess.make_dir_recursive_absolute(clip)
			var nf := int(_arg("clipframes", "61"))
			var ms := int(_arg("clipms", "0"))
			for k in nf:
				if ms > 0:
					var t0 := Time.get_ticks_msec()
					while Time.get_ticks_msec() - t0 < ms:
						await RenderingServer.frame_post_draw
				else:
					await RenderingServer.frame_post_draw
				# (`fightat=N`: a fight opens on the Nth frame, so the clip films the
				# screen change from LOCAL into it -- a new view, a new sky)
				if k == int(_arg("fightat", "-1")):
					Router.start_combat(DB.enemies[&"cutter"], [], false)
				gv.get_texture().get_image().get_region(arena).save_png("%s/f_%04d.png" % [clip, k])
			print("wrote ", nf, " frames to ", clip)
		for c in hid:
			c.visible = true
	tree.quit()


## What the foreground dust may cover of the ships and their labels, over a
## fight's frames: every visible mote's whole box (`LocalDust.boxes`, more than
## it draws) against every ship picture and every label and gauge in the view;
## and how fast its motes faded -- the largest change of a mote's visibility in
## a frame, and how many frames changed one abruptly.
func _dustcheck(tree: SceneTree, view: EncounterView) -> void:
	var dust: LocalDust = view.get("dust")
	var worst_ship := 0.0
	var worst_label := 0.0
	var blocks := 0
	var cb = Router.current.get("combat")
	for k in 90:
		if k % 15 == 0 and cb != null:
			for i in (cb.hand as Array).size():
				if cb.can_play(cb.hand[i]):
					cb.play(i, 0)
					break
		await RenderingServer.frame_post_draw
		var ships: Array[Rect2] = []
		var labels: Array[Rect2] = []
		_rects(view, ships, labels)
		var at := dust.get_global_rect().position
		var ds: Array[Rect2] = []
		for bx: Rect2 in dust.boxes:
			ds.append(Rect2(at + bx.position, bx.size))
		blocks = maxi(blocks, ds.size())
		worst_ship = maxf(worst_ship, _cover(ds, ships))
		worst_label = maxf(worst_label, _cover(ds, labels))
	print("  dustcheck: up to %d motes showing; their boxes overlap at worst %.4f of the ships' pictures, %.4f of the labels and gauges (no pixel is drawn inside them); largest visibility change in a frame %.3f, abrupt frames %d" % [blocks, worst_ship, worst_label, dust.worst_step, dust.abrupt])


func _rects(n: Node, ships: Array[Rect2], labels: Array[Rect2]) -> void:
	for c in n.get_children():
		if not (c is CanvasItem) or not (c as CanvasItem).visible or c is LocalDust or c is LocalSky:
			continue
		if c is ShipView:
			var sr := (c as ShipView).ship_rect()
			ships.append(Rect2(sr.position + (c as Control).global_position, sr.size))
		elif c is EnemyArt:
			var er := Rect2((c as EnemyArt).used_rect())
			ships.append(Rect2(er.position + (c as Control).global_position, er.size))
		elif c is Label and (c as Label).text.strip_edges() != "":
			labels.append(_text_rect(c as Label))
		elif c is ProgressBar:
			labels.append((c as Control).get_global_rect())
		_rects(c, ships, labels)


## The share of the rects' area the blocks cover.
func _cover(blocks: Array[Rect2], rects: Array[Rect2]) -> float:
	var area := 0.0
	var hit := 0.0
	for r in rects:
		area += r.get_area()
		for b in blocks:
			hit += r.intersection(b).get_area()
	return hit / maxf(area, 1.0)


## A body of the kind a situation asks for: a giant (a ringed one when `strict`),
## any world, a belt or a wreck; -1 for none.
func _body_for(Lo: SystemLayout, what: String, strict: bool) -> int:
	for i in Lo.bodies.size():
		var b := Lo.bodies[i]
		match what:
			"giant":
				if b.kind == &"giant" and b.world != &"" and (not strict or bool(Worlds.spec(b.world, b.seed, 100.0).get("ring", false))):
					return i
			"world":
				if b.kind == &"planet" and b.world != &"":
					return i
			"belt":
				if b.kind == &"belt":
					return i
			"derelict":
				if b.kind == &"derelict":
					return i
	return -1


## What the sky puts behind the play, in sRGB luma: mean, 95th and 99.5th
## centiles, spread, brightest.
func _stats(img: Image, r: Rect2i) -> Dictionary:
	var ls: Array[float] = []
	var sum := 0.0
	var sq := 0.0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			var l := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			ls.append(l)
			sum += l
			sq += l * l
	ls.sort()
	var n := float(ls.size())
	var mean := sum / n
	return {"mean": snappedf(mean, 0.0001), "p95": snappedf(ls[int(n * 0.95)], 0.0001),
		"p995": snappedf(ls[int(n * 0.995)], 0.0001), "std": snappedf(sqrt(maxf(sq / n - mean * mean, 0.0)), 0.0001),
		"max": snappedf(ls[ls.size() - 1], 0.0001)}


## HOW READABLE the ships and labels are against what is right behind them:
## for each, its own pixels (where the whole picture differs from the bare
## backdrop) against the backdrop in a band RING px wide round its OUTLINE (not
## its box: the sky the eye sets its edge against) -- the difference of their
## mean OKLab lightness (`dL`), and how busy the backdrop in that band is
## (`busy`: the spread of its fine detail, each pixel's lightness against the
## 5x5 round it -- a smooth fall of light is not busy, a field of specks is).
## The worst of each, and each ship's own. REPORTED, NOT A GATE: it counts
## lightness alone, so a blue-grey hull on pink gas of the same lightness
## scores near 0 and reads plainly; Jon judges by eye.
const RING := 6
func _readable(full: Image, bare: Image, ships: Array[Rect2], labels: Array[Rect2], arena: Rect2) -> Dictionary:
	var out := {"ship_dL": 9.0, "label_dL": 9.0, "ship_busy": 0.0, "label_busy": 0.0, "n_ships": 0, "n_labels": 0}
	for pass_i in 2:
		var rs: Array[Rect2] = ships if pass_i == 0 else labels
		var key := "ship" if pass_i == 0 else "label"
		for r in rs:
			if not arena.encloses(r) or r.size.x < 2.0 or r.size.y < 2.0:
				continue
			var ri := Rect2i(r)
			var reg := ri.grow(RING + 2).intersection(Rect2i(arena))
			var gw := reg.size.x
			var gh := reg.size.y
			var lb := PackedFloat32Array()
			var obj := PackedByteArray()
			lb.resize(gw * gh)
			obj.resize(gw * gh)
			var on := 0.0
			var on_n := 0
			for y in gh:
				for x in gw:
					var pp := reg.position + Vector2i(x, y)
					var cb := bare.get_pixel(pp.x, pp.y)
					lb[y * gw + x] = _okl(cb)
					obj[y * gw + x] = 0
					if ri.has_point(pp):
						var cf := full.get_pixel(pp.x, pp.y)
						if absf(cf.r - cb.r) + absf(cf.g - cb.g) + absf(cf.b - cb.b) > 0.06:
							obj[y * gw + x] = 1
							on += _okl(cf)
							on_n += 1
			if on_n < 4:
				continue
			# (the band: within RING of an object pixel, by rows then columns)
			var hx := PackedByteArray()
			hx.resize(gw * gh)
			for y in gh:
				for x in gw:
					var hit := 0
					for d in range(-RING, RING + 1):
						var xx := x + d
						if xx >= 0 and xx < gw and obj[y * gw + xx] == 1:
							hit = 1
							break
					hx[y * gw + x] = hit
			var m := 0.0
			var n := 0
			var sd := 0.0
			var nd := 0
			for y in gh:
				for x in gw:
					if obj[y * gw + x] == 1:
						continue
					var near := false
					for d in range(-RING, RING + 1):
						var yy := y + d
						if yy >= 0 and yy < gh and hx[yy * gw + x] == 1:
							near = true
							break
					if not near:
						continue
					var v: float = lb[y * gw + x]
					m += v
					n += 1
					if x >= 2 and y >= 2 and x < gw - 2 and y < gh - 2:
						var lm := 0.0
						for oy in range(-2, 3):
							for ox in range(-2, 3):
								lm += lb[(y + oy) * gw + x + ox]
						var dv := v - lm / 25.0
						sd += dv * dv
						nd += 1
			if n == 0:
				continue
			m /= float(n)
			sd = sqrt(sd / float(maxi(nd, 1)))
			var dl := absf(on / float(on_n) - m)
			out[key + "_dL"] = snappedf(minf(out[key + "_dL"], dl), 0.0001)
			out[key + "_busy"] = snappedf(maxf(out[key + "_busy"], sd), 0.0001)
			out["n_" + key + "s"] = int(out["n_" + key + "s"]) + 1
			if pass_i == 0:
				# (each ship's own, left to right: which one is the worst)
				out["ships"] = (out.get("ships", []) as Array) + [[int(r.position.x), snappedf(dl, 0.0001), snappedf(sd, 0.0001)]]
	return out


## OKLab lightness of an sRGB colour.
func _okl(c: Color) -> float:
	var r := c.srgb_to_linear()
	var l := pow(0.4122214708 * r.r + 0.5363325363 * r.g + 0.0514459929 * r.b, 1.0 / 3.0)
	var mm := pow(0.2119034982 * r.r + 0.6806995451 * r.g + 0.1073969566 * r.b, 1.0 / 3.0)
	var ss := pow(0.0883024619 * r.r + 0.2817188376 * r.g + 0.6299787005 * r.b, 1.0 / 3.0)
	return 0.2104542553 * l + 0.7936177850 * mm - 0.0040720174 * ss


## Where a label's text is drawn (global px): its control is often far wider
## than its words, and the band round the control would be mostly empty sky.
static func _text_rect(l: Label) -> Rect2:
	var r := l.get_global_rect()
	var f := l.get_theme_font("font")
	if f == null:
		return r
	var fs := l.get_theme_font_size("font_size")
	var sz := f.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	sz = Vector2(minf(sz.x, r.size.x), minf(sz.y, r.size.y))
	var x := r.position.x
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x += (r.size.x - sz.x) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			x += r.size.x - sz.x
	var y := r.position.y
	match l.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			y += (r.size.y - sz.y) * 0.5
		VERTICAL_ALIGNMENT_BOTTOM:
			y += r.size.y - sz.y
	return Rect2(Vector2(x, y), sz)
