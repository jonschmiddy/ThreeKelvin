extends Node

## LOCAL IN EVERY STYLE AND STATE, in one window (`LocalShot` and `CutawayShot`
## take one state a run; this walks the whole matrix in one process, for the
## polish audit and its before/after):
##   godot --path . --windowed --position 3840,0 --fixed-fps 30 -- sheet=LocalAudit
##       out=<dir> [styles=simplified,legacy,painted,radiant] [cases=<name>,...]
##       [clipframes=45] [cut] [nocut] [noblur]
## Each case: a new run (its seed), the ship parked as the sector map leaves it,
## LOCAL shown, then <dir>/<style>/<case>.png (the game's own 960x540 frame),
## <case>_clip/f_####.png (the sky and the dust, ships and words hidden, every
## frame for `frames.py`), and with `cut` (the default for the cases marked so)
## the cutaway pushed in on your ship: <case>_cut/f_####.png every frame of the
## push-in and 30 held after it (its ship, parts and panel hidden), the scene as
## the player sees it behind the cutaway (`noblur`: the blur held off, to see
## what the zoom itself draws). The clocks step 1/30 s a frame; run with
## `--fixed-fps 30` so the frames play at true speed. Needs a window.

const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")
## name: [sky, seed, orbit, cutaway]
const CASES := {
	"emission": ["emission", 1, "", true],
	"reflection": ["reflection", 4242, "", false],
	"planetary": ["planetary", 4242, "", false],
	"remnant": ["remnant", 4242, "", false],
	"dark": ["dark", 4242, "", false],
	"calm": ["calm", 4242, "", true],
	"pulsar": ["pulsar", 4242, "", false],
	"core": ["core", 4242, "", true],
	"giant": ["reflection", 4242, "giant", true],
	"world": ["reflection", 4242, "world", true],
	"star": ["reflection", 4242, "star", false],
	"edge": ["reflection", 4242, "edge", false],
	"belt": ["calm", 4242, "belt", true],
	"derelict": ["reflection", 4242, "derelict", true],
}

var _args: PackedStringArray
var _tree: SceneTree


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
		if ShipView.shot_clock >= 0.0:
			ShipView.shot_clock += 1.0 / 30.0


func _img() -> Image:
	return GameShell.input_target(_tree).get_texture().get_image()


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	CutawayView.fixed_step = 1.0 / 30.0
	ShipView.shot_clock = 0.0
	if "noblur" in _args:
		CutawayView.harness_no_blur = true
	var out := _arg("out", "user://local_audit")
	var styles := _arg("styles", "simplified,legacy,painted,radiant").split(",")
	var cases: PackedStringArray = _arg("cases", ",".join(CASES.keys())).split(",")
	var nclip := int(_arg("clipframes", "45"))
	for st in styles:
		DisplaySettings.render_style = StringName(st)
		var dir := "%s/%s" % [out, st]
		DirAccess.make_dir_recursive_absolute(dir)
		for cname in cases:
			if not CASES.has(cname):
				continue
			var c: Array = CASES[cname]
			if not await _show(String(c[0]), int(c[1]), String(c[2])):
				print("localaudit: %s %s: no system" % [st, cname])
				continue
			await _frames(70)
			_img().save_png("%s/%s.png" % [dir, cname])
			var sc := Router.current as SectorScreen
			if sc == null:
				continue
			var view: EncounterView = sc._view
			var sky: LocalSky = view.backdrop
			# the sky's GPU time, the dust's own count
			sky.gpu_ms()
			var g := 0.0
			for i in 20:
				await RenderingServer.frame_post_draw
				g += sky.gpu_ms()
			print("localaudit: %s %s node %d: sky gpu %.3f ms" % [st, cname, sky.node.index, g / 20.0])
			# (`pdump`: PAINTED's own pictures -- what went into its far picture, and
			# its band memory -- and the sky's)
			if "pdump" in _args:
				sky.picture().save_png("%s/%s_sky.png" % [dir, cname])
				if not sky._pt.is_empty():
					(sky._pt.svp as SubViewport).get_texture().get_image().save_png("%s/%s_svp.png" % [dir, cname])
					(sky._pt.tvp as SubViewport).get_texture().get_image().save_png("%s/%s_tvp.png" % [dir, cname])
				print("localaudit:   neb %s visible %s ready %s" % [sky._neb_mat != null, sky._neb != null and sky._neb.visible, sky._ready_sky])
				if sky._neb_mat != null:
					var nm := sky._neb_mat
					for u in ["painted", "p_puffs", "p_ne", "p_sheets_on", "strength", "exposure", "kind", "t0", "off", "p_sky", "p_gm"]:
						print("localaudit:     %s = %s" % [u, nm.get_shader_parameter(u)])
					print("localaudit:     neb parent %s, in tree %s, pos %s size %s" % [sky._neb.get_parent(), sky._neb.is_inside_tree(), sky._neb.position, sky._neb.size])
					for u in ["t0", "t1", "t2", "p_sheets"]:
						var tx: Variant = nm.get_shader_parameter(u)
						if tx is Texture2D:
							var im := (tx as Texture2D).get_image()
							im.save_png("%s/%s_%s.png" % [dir, cname, u])
							print("localaudit:     %s %s %s" % [u, im.get_size(), im.get_format()])
			# THE BARE SKY AND THE DUST, filmed
			var hid := _hide(view)
			await _frames(2)
			var cd := "%s/%s_clip" % [dir, cname]
			DirAccess.make_dir_recursive_absolute(cd)
			var vr := Rect2i(view.get_global_rect())
			for k in nclip:
				await _frames(1)
				_img().get_region(vr).save_png("%s/f_%04d.png" % [cd, k])
			for h in hid:
				h.visible = true
			# THE CUTAWAY'S PUSH-IN
			var want_cut: bool = c[3] if not "cut" in _args else true
			if "nocut" in _args:
				want_cut = false
			if want_cut and sc.cutaway_ready():
				var ud := "%s/%s_cut" % [dir, cname]
				DirAccess.make_dir_recursive_absolute(ud)
				var cut := sc.open_cutaway()
				var art := view.ship_view()
				if cut != null:
					for k in 44:
						await _frames(1)
						if k == 16:
							# (held: only the scene behind the cutaway)
							cut._stage.visible = false
							cut._hold_panel.visible = false
						_img().get_region(vr).save_png("%s/f_%04d.png" % [ud, k])
					cut._stage.visible = true
					cut._hold_panel.visible = true
					cut.close()
					await _frames(30)
		if "fight" in _args:
			await _fight(dir, st)
	print("localaudit: done")
	_tree.quit()


## A FIGHT, its shots in the air: a still, the foreground dust's rules measured
## over 90 frames (`LocalShot dustcheck`: what its boxes cover of the ships and
## of every label and gauge, the largest change in a mote's visibility in a
## frame, the frames that changed one abruptly), then the dust alone over the
## view's plain wash for `frames.py` (`dustonly`).
func _fight(dir: String, st: String) -> void:
	if not await _show("reflection", 4242, ""):
		return
	# first the dust alone at rest, no fight (nothing shaking the view)
	await _frames(70)
	var v0: EncounterView = (Router.current as SectorScreen)._view
	await _dust_alone(v0, "%s/dustrest_clip" % dir)
	Run.hand_size_override = 5
	Router.start_combat(DB.enemies[&"cutter"], [], false)
	await _frames(90)
	var view: EncounterView = Router.current.get("_view")
	var dust: LocalDust = view.dust
	dust.worst_step = 0.0
	dust.abrupt = 0
	var cb = Router.current.get("combat")
	var worst_ship := 0.0
	var worst_label := 0.0
	var most := 0
	for k in 90:
		if k % 15 == 0 and cb != null:
			for i in (cb.hand as Array).size():
				if cb.can_play(cb.hand[i]):
					cb.play(i, 0)
					break
		await _frames(1)
		if k == 20:
			_img().save_png("%s/fight.png" % dir)
		var ships: Array[Rect2] = []
		var labels: Array[Rect2] = []
		_rects(view, ships, labels)
		var at := dust.get_global_rect().position
		var ds: Array[Rect2] = []
		for bx: Rect2 in dust.boxes:
			ds.append(Rect2(at + bx.position, bx.size))
		most = maxi(most, ds.size())
		worst_ship = maxf(worst_ship, _cover(ds, ships))
		worst_label = maxf(worst_label, _cover(ds, labels))
	print("localaudit: %s dustcheck: up to %d motes showing; their boxes overlap at worst %.4f of the ships' pictures, %.4f of the labels and gauges; largest visibility change in a frame %.3f, abrupt frames %d" % [st, most, worst_ship, worst_label, dust.worst_step, dust.abrupt])
	# the dust alone, over the view's own wash
	await _dust_alone(view, "%s/dustonly_clip" % dir)
	Run.hand_size_override = 0


func _dust_alone(view: EncounterView, dd: String) -> void:
	var hid: Array[CanvasItem] = []
	for c in view.get_children():
		if c is CanvasItem and c != view.dust and (c as CanvasItem).visible:
			(c as CanvasItem).visible = false
			hid.append(c)
	DirAccess.make_dir_recursive_absolute(dd)
	var vr := Rect2i(view.get_global_rect())
	for k in 90:
		await _frames(1)
		_img().get_region(vr).save_png("%s/f_%04d.png" % [dd, k])
	for h in hid:
		h.visible = true


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
			labels.append((c as Control).get_global_rect())
		elif c is ProgressBar:
			labels.append((c as Control).get_global_rect())
		_rects(c, ships, labels)


func _cover(blocks: Array[Rect2], rects: Array[Rect2]) -> float:
	var area := 0.0
	var hit := 0.0
	for r in rects:
		area += r.get_area()
		for b in blocks:
			hit += r.intersection(b).get_area()
	return hit / maxf(area, 1.0)


## A run at a system of that sky, parked as the map leaves you, LOCAL shown.
func _show(want: String, seed: int, orbit: String) -> bool:
	Rng.forced = seed
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := -1
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
		return false
	Run.at = idx
	var node: MapGen.MapNode = Run.node_at()
	SystemMapScreen._parked.erase(idx)
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
	SectorScreen._approached_at = idx
	Router.show_local()
	return true


func _hide(view: EncounterView) -> Array[CanvasItem]:
	var hid: Array[CanvasItem] = []
	for c in view.get_children():
		var keep_c: bool = c == view.get("dust") or c == view.backdrop or c == view.weather
		if c is CanvasItem and not keep_c and (c as CanvasItem).visible:
			(c as CanvasItem).visible = false
			hid.append(c)
	return hid


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
