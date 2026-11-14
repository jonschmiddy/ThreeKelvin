extends Node

## Photographs a creature event and its fight, so the fauna path can be inspected on screen.
## Why: docs/why/FoeTagShot.md#creature-shots


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(path)
	print("foetagshot: wrote %s" % path)


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	var dir := Harness.arg("out", "user://foetag")
	DirAccess.make_dir_recursive_absolute(dir)
	LocalEventDrawer.quiet = false
	for raw in Harness.arg("ids", "in_the_wake,the_harpoon_line").split(","):
		var oid := StringName(raw)
		var o := OptionTable.by_id(oid)
		if o.is_empty():
			print("foetagshot: no option %s" % oid)
			continue
		Router.combat = null
		Router.current_fight = {}
		Rng.forced = Harness.seed_arg(4242)
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var idx := -1
		for m: MapGen.MapNode in Run.map:
			if m.type == MapGen.NodeType.SYSTEM and not m.cleared and m.danger >= 3:
				idx = m.index
				break
		Run.at = idx
		var n: MapGen.MapNode = Run.node_at()
		n.visited = true
		n.fauna = true
		n.region = MapGen.Region.FAUNA
		n.danger = clampi(n.danger, int(o.get("min_danger", 1)), int(o.get("max_danger", 10)))
		n.options.clear()
		n.options.append(oid)
		n.taken.clear()
		SectorScreen._approached_at = idx
		ParkedShips.spots.erase(idx)
		LocalEventDrawer.request(idx, 0)
		Router.show_local()
		await _frames(90)
		var sc := Router.current as SectorScreen
		if sc == null or sc._events == null:
			print("foetagshot: %s did not open on LOCAL" % oid)
			continue
		var d: LocalEventDrawer = sc._events
		if d.text != null and not d.text.done:
			d.text.skip()
		await _frames(30)
		await _snap("%s/%s_1_event.png" % [dir, oid])
		var j := int(Harness.arg("choice", "-1"))
		var choices: Array = o.choices
		if j < 0:
			for k in choices.size():
				if bool((choices[k] as Dictionary).get("fight", false)) and not (choices[k] as Dictionary).has("check"):
					j = k
					break
		var r: Dictionary = await d.choose(j)
		if not r.get("fight_now", false):
			await _frames(30)
			if d.text != null and not d.text.done:
				d.text.skip()
			await _frames(20)
			await _snap("%s/%s_2_result.png" % [dir, oid])
			var go := d.find_child("TheyAreFiring", true, false) as Button
			if go != null:
				go.pressed.emit()
		for i in 600:
			await RenderingServer.frame_post_draw
			if Router.combat != null:
				break
		await _frames(240)
		var brought := &""
		if Router.combat != null and not Router.combat.enemies.is_empty():
			brought = Router.combat.enemies[0].template.id
		print("foetagshot: %s '%s' brought %s (tag %s)" % [oid, choices[j].label, brought, OptionTable.fight_foe(o, choices[j])])
		await _snap("%s/%s_3_fight.png" % [dir, oid])
	tree.quit()
