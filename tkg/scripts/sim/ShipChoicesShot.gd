extends Node

## Stills of the choices on your own ship (`ShipChoices`), at the size you play at:
## `-- sheet=ShipChoicesShot out=<dir> [hulls] [ids=a,b] [short=<json>] [custodian]` (needs a window,
## `--resolution 1920x1080`). `short=` swaps in proposed text for the run only, from a file outside the repo.
## Why: docs/why/ShipChoices.md#on-your-ship

## A ship, a wreck and a rock.
const EVENTS: Array[StringName] = [&"one_number_between_two", &"dead_hull", &"long_claim"]

var _out := ""
var _tree: SceneTree


func _ready() -> void:
	_run.call_deferred()


func _secs(t: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(t * 1000.0):
		await RenderingServer.frame_post_draw


func _shot(nm: String) -> void:
	# at the size you play at: the game's 960x540 frame, each pixel two
	var im := GameShell.input_target(_tree).get_texture().get_image()
	im.resize(im.get_width() * 2, im.get_height() * 2, Image.INTERPOLATE_NEAREST)
	im.save_png("%s/%s.png" % [_out, nm])
	print("  shipchoicesshot: %s" % nm)


func _drawer() -> LocalEventDrawer:
	var sc := Router.current as SectorScreen
	return sc.get("_events") if sc != null else null


## The pointer on `c`, through the window and the game's frame, as a hand moves it.
func _point(c: Control) -> void:
	var at := UiRect.of(c).get_center()
	var fr := GameShell.instance.get("_frame") as SubViewportContainer if GameShell.instance != null else null
	var mv := InputEventMouseMotion.new()
	mv.position = fr.get_global_transform() * (at * float(fr.stretch_shrink)) if fr != null else at
	mv.global_position = mv.position
	_tree.root.push_input(mv)


func _run() -> void:
	_tree = get_tree()
	_out = Harness.arg("out", "user://shipchoices")
	DirAccess.make_dir_recursive_absolute(_out)
	LocalEventDrawer.layout = &"ship"
	# (the doors and the station's side as a player has them: a harness otherwise takes the old flow)
	ZoomLadder.force = 1
	Router.animate_in_harness = true
	SkillCheck.forced = int(SkillCheck.Band.MET)
	await _tree.process_frame
	Rng.forced = Harness.seed_arg(1)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n := _node(int(Harness.arg("node", "11")))
	var ids: Array[StringName] = EVENTS.duplicate()
	if Harness.arg("ids") != "":
		ids.assign(Array(Harness.arg("ids").split(",")).map(func(x: String) -> StringName: return StringName(x)))
	n.options.assign(ids)
	if Harness.arg("short") != "":
		_shorten(Harness.arg("short"))
	n.options.append(&"dropped_load")
	Router.show_local()
	await _secs(3.0)
	if "hulls" in OS.get_cmdline_user_args():
		await _hulls(n)
	elif "custodian" in OS.get_cmdline_user_args():
		await _custodian()
	else:
		for k in ids.size():
			await _steps(k, String(ids[k]))
		await _secs(0.6)
		_shot("4_system_tag")
		await _station()
	SkillCheck.forced = -1
	_tree.quit()


func _node(idx: int) -> MapGen.MapNode:
	var n: MapGen.MapNode = Run.map[idx]
	Run.at = idx
	n.visited = true
	OptionTable.ensure(n)
	SectorScreen._approached_at = idx
	return n


## Steps 1, 2 (the mouse on the first choice's part) and 3 of event k.
func _steps(k: int, id: String) -> void:
	var d := _drawer()
	d.open(k)
	await _secs(1.2)
	_shot("%s_1_tag_arriving" % id)
	d.text.skip()
	await _secs(0.3)
	_shot("%s_1_tag" % id)
	await _secs(1.6)
	var ov := d.get("_ship") as ShipChoices
	var hit := ov.find_child("Choice0Part", false, false) as Control
	if hit != null:
		_point(hit)
		# (a hidden desktop's window never has the pointer, so the hover is told, not felt)
		hit.mouse_entered.emit()
	await _secs(0.4)
	_shot("%s_2_choices_hover" % id)
	d.choose(0)
	await _secs(0.4)
	if d.text != null:
		d.text.skip()
	await _secs(0.5)
	_shot("%s_3_result" % id)
	d.continue_on()
	await _secs(0.8)


## A station's quiet tag, parked at it.
func _station() -> void:
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.STATION:
			_node(m.index)
			Router.park_at_station(m)
			Router.show_local()
			await _secs(4.0)
			_shot("5_station_tag")
			return


## Step 2 of the most crowded of the four on every hull.
func _hulls(n: MapGen.MapNode) -> void:
	var i := n.options.size() - 1
	for fr: HullData in DB.hull_frames:
		Run.hull = DB.at_tier(fr, 0)
		Sig.ship_changed.emit()
		await _secs(0.5)
		var d := _drawer()
		d.open(i)
		await _secs(0.2)
		d.text.skip()
		await _secs(1.6)
		_shot("hull_%s_%s" % [fr.manufacturer if fr.manufacturer != &"" else &"salvage", fr.display_name().to_lower().replace(" ", "_")])
		d.not_now()
		await _secs(0.4)


## The Custodian dead, its body waiting on LOCAL to be stripped.
func _custodian() -> void:
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type != MapGen.NodeType.CORE:
			continue
		_node(m.index)
		m.cleared = true
		var h := MapGen.Jetsam.new()
		h.art = &"custodian"
		h.label = "THE CUSTODIAN"
		h.site = MapGen.SITE_ANY
		h.slot = m.jetsam.size()
		h.items.append(LootGen.roll_module(9))
		m.jetsam.append(h)
		Router.await_core_body()
		await _secs(4.0)
		_shot("6_custodian_body")
		return


## Proposed text for these encounters, this run only: {id: {source, body, labels{j}, outs{j}{band}}}.
func _shorten(path: String) -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		print("  shipchoicesshot: no short text at %s" % path)
		return
	for id: String in d:
		var o := OptionTable.by_id(StringName(id))
		var e: Dictionary = d[id]
		if o.is_empty():
			continue
		if e.has("source"):
			o.source = e.source
		if e.has("body"):
			o.body = e.body
		var cs: Array = o.get("choices", [])
		for j in cs.size():
			var c: Dictionary = cs[j]
			var k := str(j)
			if (e.get("labels", {}) as Dictionary).has(k):
				c.label = e.labels[k]
			var outs: Dictionary = (e.get("outs", {}) as Dictionary).get(k, {})
			for band: String in outs:
				if c.has(band) and c[band] is Callable:
					var was: Callable = c[band]
					var said: String = outs[band]
					c[band] = func() -> Dictionary:
						var r: Dictionary = was.call()
						r.text = said
						return r
		print("  shipchoicesshot: short text for %s" % id)
