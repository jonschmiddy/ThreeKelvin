extends Node

## THE CUSTODIAN AND THE MEGAFAUNA MOVING, filmed in the real fight
## (`FaunaMotion` as `EnemySlot` wires it; nothing is overlaid by this sheet).
##   godot --path . --fixed-fps 30 --windowed --position 3840,0 -- sheet=FaunaSheet
##       out=<dir> [which=custodian,whale,leviathan] [today] [custodian=<png>]
##       [secs=11.5] [seed=N] [restcheck]
## For each enemy, a fight opened on it alone through `Router.start_combat`,
## its fly-in waited out, then `<out>/<enemy>/f_####.png`, the game's own
## 960x540 picture, a frame every 1/30 s:
##   0-4 s     idle;
##   4 s       the Custodian's intent set to Charging... (6.5 s: its next); a
##             creature's turn played through END TURN, so its attack strikes;
##   8 s       the kill: its hull cut to one and a card played at it, through
##             `Combat.play`, until it dies -- the motion settles, the breakup
##             is cut, the wreck is left.
## `today` films the same with `FaunaMotion.enabled` off: the still picture on
## the slot's bob, as the game was. `custodian=<png>` wears that picture on The
## Custodian by putting it in the resource cache under the name the index would
## give it (take 1 lives on fix/pack-layout until it merges); nothing on disk
## changes. Each folder gets meta.json: the frames each beat happened on (the
## motion taking over, the wind-up, the kill, the settle, the cut), and the
## motion's CPU a frame (`FaunaMotion.cost_us`).
## `restcheck` films nothing: on each enemy, idle, it settles the motion, then
## photographs the motion at rest and, the next frame, the art's own picture in
## its place, and prints how many of the canvas's pixels differ (the bob
## allowed its step between the two): 0 is a death cut from exactly what was
## on screen.

const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")

var _args: PackedStringArray
var _keep: Array = []


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	var out := _arg("out", "user://faunasheet")
	DirAccess.make_dir_recursive_absolute(out)
	FaunaMotion.enabled = not ("today" in _args)
	var cust := _arg("custodian")
	if cust != "":
		var img := Image.load_from_file(cust)
		if img != null:
			var tex := ImageTexture.create_from_image(img)
			var path := "res://art/sprites/enemies/custodian_t1_grown.png"
			tex.take_over_path(path)
			_keep.append(tex)
			DB.enemy_sprite_files(&"custodian")
			DB._enemy_art_index["custodian"] = ["custodian_t1_grown.png"]
	for w in _arg("which", "custodian,whale,leviathan").split(","):
		if "restcheck" in _args:
			await _restcheck(tree, String(w))
		else:
			await _film(tree, String(w), out)
	FaunaMotion.enabled = true
	tree.quit()


func _film(tree: SceneTree, id: String, out: String) -> void:
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.hand_size_override = 5
	for n: MapGen.MapNode in Run.map:
		if n.type != MapGen.NodeType.STATION and n.type != MapGen.NodeType.START \
				and String(SkyWeatherS.sky_of_node(n)) == "calm":
			Run.at = n.index
			break
	SectorScreen._approached_at = Run.at
	Router.start_combat(DB.enemies[StringName(id)], [], false, false)
	for f in 45:
		await RenderingServer.frame_post_draw
	var sc := Router.current as SectorScreen
	if sc == null or sc._view == null or sc._view.slot(0) == null:
		push_error("faunasheet: no fight view")
		return
	var slot: EnemySlot = sc._view.slot(0)
	var cb: Combat = Router.combat
	var e: Combat.EnemyState = cb.enemies[0]
	var tele: IntentData = null
	var other: IntentData = null
	for it in e.template.loop:
		if it.telegraph:
			tele = it
		elif other == null and it.damage > 0:
			other = it
	var dir := out.path_join(id)
	DirAccess.make_dir_recursive_absolute(dir)
	var gv := GameShell.input_target(tree)
	var total := int(round(float(_arg("secs", "11.5")) * 30.0))
	var meta := {id = id, today = not FaunaMotion.enabled, took_over = -1, wind = -1, wind_end = -1,
		kill = -1, settle = -1, rest = -1, cut = -1}
	var costs: Array[int] = []
	var setup_ms := 0.0
	var fps := 0.0
	for f in total:
		if not is_instance_valid(slot):
			# the view rebuilt its slots (or the fight ended): take the new one
			var sc2 := Router.current as SectorScreen
			if sc2 == null or sc2._view == null or sc2._view.slot(0) == null:
				print("faunasheet: %s: the fight is gone at frame %d (%s)" % [id, f, cb.result])
				break
			slot = sc2._view.slot(0)
			print("faunasheet: %s: new slot at frame %d" % [id, f])
		var fm := slot.fauna_motion()
		if fm != null and fm.ready_to_draw and meta.took_over < 0:
			meta.took_over = f
		if fm != null:
			setup_ms = fm.setup_ms
			fps = fm.fps()
			costs.append(fm.cost_us)
			if fm._settling and meta.settle < 0:
				meta.settle = f
			if fm.rested and meta.rest < 0:
				meta.rest = f
		if f == 120:
			meta.wind = f
			if id == "custodian":
				e.intent = tele
				Sig.enemy_changed.emit()
			else:
				Run.hp = Run.max_hp()
				sc._on_end_turn()
		if f == 195 and id == "custodian":
			meta.wind_end = f
			e.intent = other
			Sig.enemy_changed.emit()
		if f >= 240 and e.hp > 0 and not sc._playing and not sc._hold and f % 20 == 0:
			if meta.kill < 0:
				meta.kill = f
			Run.hp = Run.max_hp()
			e.hp = 1
			e.block = 0
			for i in cb.hand.size():
				if cb.can_play(cb.hand[i]):
					cb.play(i, 0)
					break
		if meta.cut < 0 and meta.kill >= 0 and slot.art.self_modulate.a <= 0.0:
			meta.cut = f
		await RenderingServer.frame_post_draw
		gv.get_texture().get_image().save_png("%s/f_%04d.png" % [dir, f])
	var avg := 0.0
	var mx := 0
	for c in costs:
		avg += c
		mx = maxi(mx, c)
	if not costs.is_empty():
		avg /= costs.size()
	var used := slot.art.used_rect()
	var canvas := slot.art.get_global_rect().position + (slot.art.size - Vector2(EnemyArt.W, EnemyArt.H)) * 0.5
	meta.frames = total
	meta.canvas = [roundf(canvas.x), roundf(canvas.y), EnemyArt.W, EnemyArt.H]
	meta.ship = [roundf(canvas.x) + used.position.x, roundf(canvas.y) + used.position.y, used.size.x, used.size.y]
	meta.cpu_us_avg = snappedf(avg, 0.1)
	meta.cpu_us_max = mx
	meta.setup_ms = snappedf(setup_ms, 0.1)
	meta.fps = fps
	var fa := FileAccess.open(dir.path_join("meta.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(meta, "  "))
	fa.close()
	print("faunasheet: %s %s took over %d, wind %d, kill %d, settle %d, rest %d, cut %d, cpu avg %.0f us max %d" % [
		id, "TODAY" if meta.today else "", meta.took_over, meta.wind, meta.kill, meta.settle, meta.rest,
		meta.cut, avg, mx])


func _restcheck(tree: SceneTree, id: String) -> void:
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.start_combat(DB.enemies[StringName(id)], [], false, false)
	for f in 90:
		await RenderingServer.frame_post_draw
	var sc := Router.current as SectorScreen
	var slot: EnemySlot = sc._view.slot(0)
	var fm := slot.fauna_motion()
	if fm == null:
		print("restcheck %s: no motion" % id)
		return
	slot.fauna_settle()
	for f in 8:
		await RenderingServer.frame_post_draw
	var gv := GameShell.input_target(tree)
	var canvas := Rect2i(Vector2i((slot.art.get_global_rect().position
		+ (slot.art.size - Vector2(EnemyArt.W, EnemyArt.H)) * 0.5).round()), Vector2i(EnemyArt.W, EnemyArt.H))
	# a bob step between the two would move everything else; take a pair
	# with none
	var a: Image
	var b: Image
	var dy := 1
	for tries in 20:
		a = gv.get_texture().get_image()
		var ya := slot.art.position.y
		fm.visible = false
		slot.art.texture = slot._fauna_tex
		await RenderingServer.frame_post_draw
		b = gv.get_texture().get_image()
		dy = int(slot.art.position.y - ya)
		fm.visible = true
		slot.art.texture = null
		if dy == 0:
			break
		for f in 5:
			await RenderingServer.frame_post_draw
	var diff := 0
	for y in range(canvas.position.y + 3, canvas.end.y - 3):
		for x in range(canvas.position.x, canvas.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y + dy)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 6.0 / 255.0:
				diff += 1
	print("restcheck %s: rested %s, %d px of the canvas differ from the art's own picture (bob step %d)" % [
		id, str(fm.rested), diff, dy])
