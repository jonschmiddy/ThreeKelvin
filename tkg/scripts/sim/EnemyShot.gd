extends Node

## Every enemy type in the fight, photographed: the real fight view (`SectorScreen`,
## `EncounterView`, `EnemySlot`, `EnemyArt`) opened on each enemy in turn, the
## picture taken once it has flown in and settled.
##
##   godot --path . --windowed --position 3840,0 -- sheet=EnemyShot out=<dir>
##       [ids=cutter,lancer:2,...] [packs=cutter+hulk:1,...] [seed=N] [sky=calm]
##       [style=...] [wait=150] [hp=<0..1>] [tele] [tag=<suffix>]
##       [film=<frames>]   (with --fixed-fps 30)
##
## For each id (default: every enemy in `DB.enemies`) and each pack (ids joined
## with `+`, the first leads), writes `<out>/<name>.png` -- the window as it is on
## screen -- and `<out>/<name>_1x.png`, the game's own 960x540 picture, and one
## JSON line per shot to `<out>/shots.jsonl`: where each enemy's holder and drawn
## ship (`used_rect`) are, which picture it wears (`look`), where your ship is,
## and the enemy row (`slots`: left, width, gap, the room it has, the row's
## width), in game pixels. A ship whose box ends past the view's right edge is
## cut off.
##
## WHAT IT DRAWS IS WHAT THE GAME DRAWS. The enemy's picture comes through
## `DB.enemy_sprite` like any fight's; `id:N` makes it wear its kind's Nth
## picture. The bob is stopped once the ship has arrived, so two runs line up
## pixel for pixel. `hp=0.4` opens every enemy at that share of its hull (the
## wound bands); `tele` has every enemy winding up (its own telegraph move, else
## the escape burn) for the wind-up light. `film=N` instead films the fight's
## first N frames from the moment it opens (the fly-in, then a card played at
## the first enemy every 45 frames) into `<out>/<name>_clip/f_####.png`, for an
## MP4. Needs a window.

const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")

var _args: PackedStringArray


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	if _arg("packlayout") != "":
		EncounterView.pack_layout = StringName(_arg("packlayout"))
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	var out := _arg("out", "user://enemyshot")
	DirAccess.make_dir_recursive_absolute(out)
	var shots: Array = []
	var ids := _arg("ids")
	var packs := _arg("packs")
	if ids != "":
		for s in ids.split(","):
			shots.append([s])
	elif packs == "":
		var all: Array = DB.enemies.keys()
		all.sort()
		for s in all:
			shots.append([String(s)])
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
	Run.hand_size_override = 5
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
	var kinds: Array = []
	var looks: Array = []
	for raw in ids:
		var parts := String(raw).split(":")
		kinds.append(StringName(parts[0]))
		looks.append(int(parts[1]) if parts.size() > 1 else -1)
	var extras: Array = []
	for i in range(1, kinds.size()):
		extras.append(DB.enemies[kinds[i]])
	var name := "+".join(ids).replace(":", "-") + _arg("tag")
	# `local` (a pack of one shot's ids): no fight -- each is left at the
	# system as a wreck, and LOCAL is opened on them, as after a fight
	if "local" in _args:
		for i in kinds.size():
			Run.new_wreck(Run.node_at(), DB.enemies[kinds[i]], maxi(0, int(looks[i])))
		Router.show_local()
		for i in int(_arg("wait", "150")):
			await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
		GameShell.input_target(tree).get_texture().get_image().save_png("%s/%s_1x.png" % [out, name])
		return {"name": name, "ids": ids, "local": true}
	Router.start_combat(DB.enemies[kinds[0]], extras, false, false)
	var hp := float(_arg("hp", "1"))
	if Router.combat != null:
		for k in Router.combat.enemies.size():
			var e: Combat.EnemyState = Router.combat.enemies[k]
			if k < looks.size() and int(looks[k]) >= 0:
				e.look = int(looks[k])
			if hp < 1.0:
				e.hp = clampi(int(round(float(e.max_hp) * hp)), 1, e.max_hp)
			# `dead=0,2`: those ships are already wrecks when the picture is taken
			if str(k) in _arg("dead").split(","):
				e.hp = 0
			if "tele" in _args:
				var t: IntentData = null
				for it in e.template.loop:
					if it.telegraph:
						t = it
				e.intent = t if t != null else Combat.escape_intent()
		Sig.enemy_changed.emit()
	var gv := GameShell.input_target(tree)
	var film := int(_arg("film", "0"))
	if film > 0:
		var dir := "%s/%s_clip" % [out, name]
		DirAccess.make_dir_recursive_absolute(dir)
		var cb = Router.combat
		var kill_at := int(_arg("killat", "-1"))
		var rein := _arg("reinforceat").split(":")
		for f in film:
			# `killat=F`: the first ship still flying is killed outright on frame F
			# (its breakup plays); `reinforceat=F:id[:look]`: that ship answers the
			# call on frame F and flies in
			if f == kill_at and cb != null:
				for e2 in cb.enemies:
					if e2.hp > 0:
						cb.damage_enemy(9999, 1, "film", e2)
						break
			if rein.size() >= 2 and f == int(rein[0]) and cb != null:
				cb.reinforce(DB.enemies[StringName(rein[1])], Run.node_at().danger)
				if rein.size() >= 3:
					cb.enemies[cb.enemies.size() - 1].look = int(rein[2])
				Sig.enemy_changed.emit()
			if f > 0 and f % 45 == 0 and kill_at < 0 and cb != null and not cb.finished:
				for i in (cb.hand as Array).size():
					if cb.can_play(cb.hand[i]):
						cb.play(i, 0)
						break
			await RenderingServer.frame_post_draw
			gv.get_texture().get_image().save_png("%s/f_%04d.png" % [dir, f])
		return {"name": name, "ids": ids, "film": film}
	for i in int(_arg("wait", "150")):
		await RenderingServer.frame_post_draw
	var view: EncounterView = null
	var sc = Router.current
	if sc != null and sc.get("_view") != null:
		view = sc.get("_view")
	var rec := {"name": name, "ids": ids, "enemies": []}
	if view != null:
		# The bob held at rest, so a before and an after line up.
		var i := 0
		while view.slot(i) != null:
			var s: EnemySlot = view.slot(i)
			s.set_process(false)
			s.art.position = s._art_base
			i += 1
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		i = 0
		while view.slot(i) != null:
			var s: EnemySlot = view.slot(i)
			var u := Rect2(s.art.used_rect())
			var at := s.art.get_global_transform() * Vector2.ZERO
			var hr := s.holder_rect()
			var id := StringName(s.art._sig.split("|")[0])
			rec.enemies.append({"id": String(id),
				"look": Router.combat.enemies[i].look if Router.combat != null and i < Router.combat.enemies.size() else -1,
				"holder": [hr.position.x, hr.position.y, hr.size.x, hr.size.y],
				"ship": [at.x + u.position.x, at.y + u.position.y, u.size.x, u.size.y],
				"sprite": DB.enemy_looks(id) > 0})
			i += 1
		var sv := view.ship_view()
		var sr: Rect2 = sv.ship_rect() if sv.has_method("ship_rect") else Rect2()
		var sg := sv.get_global_rect()
		rec["you"] = [sg.position.x + sr.position.x, sg.position.y + sr.position.y, sr.size.x, sr.size.y]
		var vr := view.get_global_rect()
		var sl: Control = view.get("_slots")
		var gr := sl.get_global_rect()
		var ar: Rect2 = view._pack_area()
		rec["slots"] = [gr.position.x, gr.size.x, String(EncounterView.pack_layout), gr.position.x + ar.position.x, ar.size.x]
		var boxes: Array = []
		var k := 0
		while view.slot(k) != null:
			for b in view.slot(k).boxes():
				var r: Rect2 = b[1]
				boxes.append([k, String(b[0]), r.position.x, r.position.y, r.size.x, r.size.y])
			k += 1
		for r: Rect2 in view.player_boxes():
			boxes.append([-1, "you", r.position.x, r.position.y, r.size.x, r.size.y])
		rec["boxes"] = boxes
		rec["view"] = [vr.position.x, vr.position.y, vr.size.x, vr.size.y]
		gv.get_texture().get_image().save_png("%s/%s_1x.png" % [out, name])
	tree.root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	return rec
