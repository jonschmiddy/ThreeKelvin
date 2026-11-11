extends Node

## Stills of LAUNCH A RUN at tiers 0 (no win), 3, 7, 8 and 10 (won up to there) and tier 8
## pointed at; then every tier's picture (`gal_<n>.png`), checked inside the lamp ring.
## `-- sheet=LaunchBoxShot out=<dir> [tiers=3,10] [tierart=<dir>] [film=1] [frames=1]`; needs a
## window. `film=1`: the box at every tier, each frame of its picture (`film_<t>_<k>.png`).

var _out := ""


func _ready() -> void:
	_out = Harness.arg("out", "user://launchbox")
	TierGalaxy.art_dir = Harness.arg("tierart")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run.call_deferred()


func _run() -> void:
	await Harness.frames(get_tree(), 2)
	DevMode.enabled = false
	RunHistory.path = TestRun.scratch("launchboxshot_history", "json")
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Rng.forced = 0
	SaveGame.save()
	Run.hull = null
	var want := Harness.arg("tiers", "0,3,7,8,10").split(",")
	for pair: Array in [[0, -1], [3, 9], [7, 9], [8, 8], [10, 10]]:
		var tier: int = pair[0]
		var best: int = pair[1]
		if not want.has(str(tier)) and tier != 10:
			continue
		var runs: Array = []
		if best >= 0:
			runs.append({"outcome": int(RunHistory.Outcome.WON), "chassis_manufacturer": "korvan", "ascension": best})
		var f := FileAccess.open(RunHistory.path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"version": RunHistory.VERSION, "runs": runs}))
		f.close()
		LaunchBox.last_tier = tier
		Router.show_launcher()
		await _secs(0.5)
		var nr := Harness.button_with_text(Router.current, "NEW RUN")
		nr.pressed.emit()
		await _secs(1.3)
		var img := get_tree().root.get_texture().get_image()
		if want.has(str(tier)):
			img.save_png("%s/tier_%d.png" % [_out, tier])
			print("  wrote %s/tier_%d.png (%dx%d)" % [_out, tier, img.get_width(), img.get_height()])
		if tier == 8:
			await _hovered()
	if Harness.arg("film") == "1":
		await _film()
	await _ring_sweep()
	SaveGame.clear()
	RunHistory.clear()
	print("launchboxshot: done")
	get_tree().quit()


## The pointer on the galaxy until the tag is up, then a still.
func _hovered() -> void:
	var box := Harness.first(Router.current, func(n: Node) -> bool: return n is LaunchBox) as LaunchBox
	var at := box.galaxy.get_global_rect().get_center() + Vector2(10, -6)
	get_tree().root.warp_mouse(at)
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	Input.parse_input_event(mm)
	await _secs(0.9)
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/tier_8_hover.png" % _out)
	print("  wrote %s/tier_8_hover.png, tag up: %s" % [_out, TagLayer.instance != null and TagLayer.instance.shown() != null])
	get_tree().root.warp_mouse(Vector2(4, 4))
	var away := InputEventMouseMotion.new()
	away.position = Vector2(4, 4)
	away.global_position = away.position
	Input.parse_input_event(away)
	await _secs(0.4)


## Every tier's picture inside the lamp ring, drawn alone on a clear SubViewport (the screen's
## glass bends the window's own pixels): over six frames no ink more than LAMP_R - 3 from its
## middle but the ring, the lamps and the far stars.
func _ring_sweep() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(TierGalaxy.G, TierGalaxy.G)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var g := TierGalaxy.new()
	vp.add_child(g)
	var bad := 0
	var every := Harness.arg("frames") == "1"
	for t in Ladder.count():
		g.set_tier(t)
		await _secs(0.5)
		var worst := 0
		var n := g._art_n if g._art_n > 0 else 6
		for f in n:
			if g._art_n > 0:
				TierGalaxy.hold_frame = f
				await Harness.frames(get_tree(), 3)
			var img := vp.get_texture().get_image()
			if f == 0 or every:
				img.save_png("%s/gal_%d%s.png" % [_out, t, "_%d" % f if every else ""])
			worst = maxi(worst, _outside(g, img))
			if g._art_n == 0:
				await _secs(0.25)
		TierGalaxy.hold_frame = -1
		bad += 1 if worst > 0 else 0
		print("  ring: tier %d %s (%d px outside, %d frames)" % [t, "inside" if worst == 0 else "OUTSIDE", worst, n])
	print("ring: %s, %d of %d tiers inside" % ["PASS" if bad == 0 else "FAIL", Ladder.count() - bad, Ladder.count()])
	vp.queue_free()


## The box at every tier, a still of it for each frame of its picture, held in turn.
func _film() -> void:
	var box := Harness.first(Router.current, func(n: Node) -> bool: return n is LaunchBox) as LaunchBox
	var r := Rect2i(box.get_global_rect().grow(6.0))
	for t in Ladder.count():
		box.pick(t)
		await _secs(0.3)
		for k in maxi(1, box.galaxy._art_n):
			TierGalaxy.hold_frame = k
			await Harness.frames(get_tree(), 3)
			get_tree().root.get_texture().get_image().get_region(r).save_png("%s/film_%d_%d.png" % [_out, t, k])
		TierGalaxy.hold_frame = -1
	print("  filmed the box at every tier")


func _outside(g: TierGalaxy, img: Image) -> int:
	var n := 0
	var mid := Vector2(TierGalaxy.G, TierGalaxy.G) / 2.0
	for y in TierGalaxy.G:
		for x in TierGalaxy.G:
			var d := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(mid)
			if d <= TierGalaxy.LAMP_R - 3.0 or g.far.has(Vector2i(x, y)) or g._ring.has(Vector2(x, y)):
				continue
			if range(1, 11).any(func(k: int) -> bool: return g.lamp_rect(k).grow(2.0).has_point(Vector2(x, y))):
				continue
			if img.get_pixel(x, y).a > 0.05:
				n += 1
	return n


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout
