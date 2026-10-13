extends Node

## Every enemy type in the fight, photographed: the real fight view (`SectorScreen`,
## `EncounterView`, `EnemySlot`, `EnemyArt`) opened on each enemy in turn, the
## picture taken once it has flown in and settled.
##
##   godot --path . --windowed --position 3840,0 -- sheet=EnemyShot out=<dir>
##       [ids=cutter,lancer,...] [packs=cutter+hulk,...] [seed=N] [sky=calm]
##       [style=...] [wait=150] [hp=<0..1>]
##
## For each id (default: every enemy in `DB.enemies`) and each pack (ids joined
## with `+`, the first leads), writes `<out>/<name>.png` -- the window as it is on
## screen, the game's 960x540 at 2x -- and `<out>/<name>_1x.png`, the game's own
## picture, and one JSON line per shot to `<out>/shots.jsonl`: where each enemy's
## holder and drawn ship (`used_rect`) are and where your ship is, in game pixels.
##
## WHAT IT DRAWS IS WHAT THE GAME DRAWS. The enemy's picture comes through
## `DB.enemy_sprite` like any fight's, so a sprite staged in
## `art/sprites/enemies/<id>.png` (and imported) is photographed in place and
## an id without one shows its procedural drawing. The bob is stopped once the
## ship has arrived, so two runs line up pixel for pixel. `hp=0.4` opens every
## enemy at that share of its hull (the wound bands).
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
	var out := _arg("out", "user://enemyshot")
	DirAccess.make_dir_recursive_absolute(out)
	var shots: Array = []
	var ids := _arg("ids")
	if ids != "":
		for s in ids.split(","):
			shots.append([s])
	else:
		var all: Array = DB.enemies.keys()
		all.sort()
		for s in all:
			shots.append([String(s)])
	var packs := _arg("packs")
	if packs != "":
		for p in packs.split(","):
			shots.append(Array(p.split("+")))
	var log := FileAccess.open(out + "/shots.jsonl", FileAccess.WRITE)
	for shot: Array in shots:
		var rec := await _shoot(tree, shot, out)
		log.store_line(JSON.stringify(rec))
		print("  ", JSON.stringify(rec))
	log.close()
	print("wrote %d shots to %s" % [shots.size(), ProjectSettings.globalize_path(out)])
	tree.quit()


func _shoot(tree: SceneTree, ids: Array, out: String) -> Dictionary:
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var want := _arg("sky", "calm")
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.STATION or n.type == MapGen.NodeType.START:
			continue
		if String(SkyWeatherS.sky_of_node(n)) == want:
			idx = n.index
			break
	if idx < 0:
		for n: MapGen.MapNode in Run.map:
			if n.type != MapGen.NodeType.STATION and n.type != MapGen.NodeType.START:
				idx = n.index
				break
	Run.at = idx
	SectorScreen._approached_at = idx
	var extras: Array = []
	for i in range(1, ids.size()):
		extras.append(DB.enemies[StringName(ids[i])])
	Router.start_combat(DB.enemies[StringName(ids[0])], extras, false, false)
	var hp := float(_arg("hp", "1"))
	if hp < 1.0 and Router.combat != null:
		for e in Router.combat.enemies:
			e.hp = clampi(int(round(float(e.max_hp) * hp)), 1, e.max_hp)
		Sig.enemy_changed.emit()
	for i in int(_arg("wait", "150")):
		await RenderingServer.frame_post_draw
	var view: EncounterView = null
	var sc = Router.current
	if sc != null and sc.get("_view") != null:
		view = sc.get("_view")
	var rec := {"name": "+".join(ids), "ids": ids, "enemies": []}
	if view != null:
		# The bob held at rest, so a before and an after line up.
		var i := 0
		while view.slot(i) != null:
			var s: EnemySlot = view.slot(i)
			s.set_process(false)
			s.art.position = Vector2.ZERO
			i += 1
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var gv := GameShell.input_target(tree)
		var inv: Transform2D = Transform2D.IDENTITY
		i = 0
		while view.slot(i) != null:
			var s: EnemySlot = view.slot(i)
			var u := Rect2(s.art.used_rect())
			var at := s.art.get_global_transform() * Vector2.ZERO
			var hr := s.holder_rect()
			rec.enemies.append({"id": String(s.art._sig.split("|")[0]),
				"holder": [hr.position.x, hr.position.y, hr.size.x, hr.size.y],
				"ship": [at.x + u.position.x, at.y + u.position.y, u.size.x, u.size.y],
				"sprite": DB.enemy_sprite(StringName(s.art._sig.split("|")[0])) != null})
			i += 1
		var sv := view.ship_view()
		var sr: Rect2 = sv.ship_rect() if sv.has_method("ship_rect") else Rect2()
		var sg := sv.get_global_rect()
		rec["you"] = [sg.position.x + sr.position.x, sg.position.y + sr.position.y, sr.size.x, sr.size.y]
		var vr := view.get_global_rect()
		rec["view"] = [vr.position.x, vr.position.y, vr.size.x, vr.size.y]
		gv.get_texture().get_image().save_png("%s/%s_1x.png" % [out, rec.name])
	tree.root.get_texture().get_image().save_png("%s/%s.png" % [out, rec.name])
	return rec
