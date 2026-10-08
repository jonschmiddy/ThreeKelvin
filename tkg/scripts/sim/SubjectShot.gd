extends Node

## AN ENCOUNTER'S SUBJECT ON LOCAL, photographed (`LocalSubject`):
##   godot --path . --windowed --position 3840,0 -- sheet=SubjectShot keepwindow
##       subject=<id>[,<id>...]|all out=<dir> [style=...] [seed=N] [wait=90] [noband] [wrecks=N]
## For each encounter asked for (`all`: every one that carries a `subject`), a run
## at a system holding just that option, LOCAL opened with the event up as the map
## sends you there, and the game's picture saved as `<dir>/<id>.png` once the
## scene has settled. `noband` drops the event's band (NOT NOW) before the shot,
## so the subject is seen as it is while you are parked at it. Prints each
## subject's pieces and where they landed. `wrecks=N` leaves N dead hulls in the
## system first, as a fight there would, to see the subject keep clear of them.
## `clip=<dir> [clipframes=300]`: then films the scene, your ship hidden, for
## `frames.py` -- one subfolder per encounter, `f_####.png` of LOCAL's view at
## the game's own 960x540, the subject's clock (`ShipView.shot_clock`) stepped
## 1/30 s a frame; run it with `--fixed-fps 30` so the sky steps the same. Each
## folder gets `crop.json`, the subject's drawn box in those frames (grown by
## the drift and the tumble), to measure the subject alone. `subjectonly` hides
## everything else in the view, the sky too; `keepship` keeps your ship in (a
## clamp that grips it); `clipstart=S` starts the clock at S s (default 20).
## `atplace`: the system given the sky
## the option's gates ask for and the ship parked where the option sits (the
## giant, the star's close orbit), as the map's GO leaves it. `take=N`: where
## the encounter keeps more than one take of its thing (`pick`), draw take N
## (from 0) instead of the system's own pick, to photograph each.
## Needs a window.

var _args: PackedStringArray


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
	var dir := _arg("out", "user://subjects")
	DirAccess.make_dir_recursive_absolute(dir)
	var want := _arg("subject", "all")
	var ids: Array[StringName] = []
	for o: Dictionary in OptionTable.all():
		if o.has("subject") and (want == "all" or String(o.id) in want.split(",")):
			ids.append(o.id)
	if ids.is_empty():
		print("subjectshot: no encounter %s carries a subject" % want)
		tree.quit()
		return
	var wait := int(_arg("wait", "90"))
	LocalSubject.force_pick = int(_arg("take", "-1"))
	LocalEventDrawer.quiet = true
	for oid in ids:
		Rng.forced = int(_arg("seed", "4242"))
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var idx := -1
		for n: MapGen.MapNode in Run.map:
			if n.type == MapGen.NodeType.SYSTEM and not n.cleared:
				idx = n.index
				break
		Run.at = idx
		var node: MapGen.MapNode = Run.node_at()
		node.visited = true
		node.options.clear()
		node.options.append(oid)
		var foes: Array = DB.enemies.keys()
		foes.sort()
		for w in int(_arg("wrecks", "0")):
			Run.new_wreck(node, DB.enemies[foes[(w * 7 + 3) % foes.size()]])
		SectorScreen._approached_at = idx
		SystemMapScreen._parked.erase(idx)
		if "atplace" in _args:
			# AT A SYSTEM IT COULD BE ROLLED AT, PARKED WHERE IT SITS: the system
			# given the sky the option's gates ask for (a red or blue star, a giant,
			# a pulsar near, the gas), and the ship in orbit of its place -- the
			# giant, the star's close orbit -- as the map's GO leaves it
			var o := OptionTable.by_id(oid)
			if o.has("needs_star"):
				node.star = int(o.needs_star)
			node.gas_giant = bool(o.get("needs_giant", node.gas_giant))
			node.near_pulsar = bool(o.get("needs_pulsar", node.near_pulsar))
			node.in_nebula = bool(o.get("needs_nebula", node.in_nebula))
			var place := LocalEventDrawer.body_of(node, 0)
			SystemMapScreen._parked[idx] = {"at": place, "p": Vector2(900.0, -210.0), "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}
		LocalEventDrawer.request(idx, 0)
		Router.show_local()
		for i in wait:
			await RenderingServer.frame_post_draw
		var sc := Router.current as SectorScreen
		if sc == null:
			print("subjectshot: %s: LOCAL did not come up" % oid)
			continue
		if "noband" in _args and sc._events != null:
			sc._events.not_now()
			for i in 30:
				await RenderingServer.frame_post_draw
		var sub := LocalSubject.of(sc._view)
		tree.root.get_texture().get_image().save_png("%s/%s.png" % [dir, oid])
		if _arg("clip") != "" and sub != null:
			await _clip(sc, sub, "%s/%s" % [_arg("clip"), oid])
		# YOUR SHIP'S PARTS ON ITS HULL, not floating where the hull used to be
		for c in sc._view.ship_view().get_children():
			if c is MountPoints:
				var off := (c as MountPoints).strays()
				print("subjectshot: %s: your ship's parts %s" % [oid, "on the hull" if off.is_empty() else "OFF THE HULL: " + ", ".join(off)])
		var rs: Array[Rect2] = sub.drawn_rects() if sub != null else []
		print("subjectshot: %s: %d pieces drawn%s" % [oid, rs.size(), "" if sub != null else " (NO SUBJECT)"])
		if sc._view._slots.visible and sc._view._slots_mode == &"wrecks":
			var hulls: Array[String] = []
			for e: EnemySlot in sc._view._made:
				hulls.append(str(e.holder_rect()))
			print("subjectshot: %s: wrecks at %s; subject in %s" % [oid, ", ".join(hulls), str(rs)])
	LocalEventDrawer.quiet = false
	LocalSubject.force_pick = -1
	tree.quit()


## The scene filmed for `frames.py`: your ship hidden (and, `subjectonly`,
## everything but the subject), the subject's clock stepped 1/30 s a frame.
func _clip(sc: SectorScreen, sub: LocalSubject, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var hid: Array[CanvasItem] = []
	for c in sc._view.get_children():
		if not (c is CanvasItem) or not (c as CanvasItem).visible or c == sub:
			continue
		if (c == sc._view.ship_view() and not "keepship" in _args) or "subjectonly" in _args:
			(c as CanvasItem).visible = false
			hid.append(c)
	var vr := sc._view.get_global_rect()
	var arena := Rect2i(int(vr.position.x), int(vr.position.y), int(vr.size.x), int(vr.size.y))
	var box := Rect2()
	var first := true
	for r in sub.drawn_rects():
		box = r if first else box.merge(r)
		first = false
	box = box.grow(12.0)
	box.position -= Vector2(arena.position)
	var f := FileAccess.open(out + "/crop.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({x = int(box.position.x), y = int(box.position.y), w = int(box.size.x), h = int(box.size.y)}))
	f.close()
	var gv := GameShell.input_target(get_tree())
	var t0 := float(_arg("clipstart", "20"))
	var nf := int(_arg("clipframes", "300"))
	for k in nf:
		ShipView.shot_clock = t0 + float(k) / 30.0
		await RenderingServer.frame_post_draw
		gv.get_texture().get_image().get_region(arena).save_png("%s/f_%04d.png" % [out, k])
	ShipView.shot_clock = -1.0
	for c in hid:
		c.visible = true
	print("subjectshot: %s: wrote %d frames to %s (subject in %s)" % [sub.oid, nf, out, box])
