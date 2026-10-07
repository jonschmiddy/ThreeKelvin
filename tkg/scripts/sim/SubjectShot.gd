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
	tree.quit()
