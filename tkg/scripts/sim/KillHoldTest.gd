extends Node

## A KILL MOVES NOTHING, headless with the animations on:
##   godot --headless --path . -- sheet=KillHoldTest
## Jon, on the pack-of-three film: "The enemy dips down and then pops up after
## the death animation?" The dying ship's readout lost its intent, the pack was
## laid out again round the shorter block, and the breakup, anchored where the
## art was mid-shake, handed back to a wreck drawn somewhere else.
## For a seeded pack of three (drawn at half) and a pair (full size), the first
## ship is killed outright and its breakup played to the end and one second on:
##   - every slot, and every ship's resting place in it, stays exactly where it
##     stood before the kill, every frame;
##   - the breakup is drawn from the dying ship's resting place (riding its bob);
##   - its last frame is the wreck the slot then draws, pixel for pixel.

var _fails := 0


func _ok(what: String, c: bool) -> bool:
	if not c:
		print("  FAIL %s" % what)
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	Router.animate_in_harness = true
	await _case(tree, [[&"lancer", 0], [&"marauder", 0], [&"hulk", 0]], "pack of three (half)")
	await _case(tree, [[&"lancer", 0], [&"marauder", 0]], "pair (full size)")
	Router.animate_in_harness = false
	print("killholdtest: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	tree.quit()


func _rest(sl: EnemySlot) -> Vector2:
	return sl.holder_rect().position + sl._art_base


func _case(tree: SceneTree, pack: Array, tag: String) -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for m: MapGen.MapNode in Run.map:
		if m.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(m):
			Run.at = m.index
			break
	SectorScreen._approached_at = Run.at
	var extras: Array = []
	for i in range(1, pack.size()):
		extras.append(DB.enemies[pack[i][0]])
	Router.start_combat(DB.enemies[pack[0][0]], extras, false, false)
	var cb = Router.combat
	if not _ok("%s: a fight" % tag, cb != null):
		return
	for i in pack.size():
		cb.enemies[i].look = int(pack[i][1])
	Sig.enemy_changed.emit()
	await tree.create_timer(1.2).timeout
	var view: EncounterView = Router.current.get("_view")
	var n := pack.size()
	var slots0: Array = []
	var rests0: Array = []
	for k in n:
		slots0.append(view.slot(k).get_global_rect().position)
		rests0.append(_rest(view.slot(k)))
	var dying: EnemySlot = view.slot(0)
	var held := {rest = null, done = false}
	cb.damage_enemy(9999, 1, "test", cb.enemies[0])
	var b: ShipBreakup = null
	var frames := 0
	var after := -1.0
	var moved := 0.0
	var off := 0.0
	var seen := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		await tree.process_frame
		frames += 1
		for k in n:
			moved = maxf(moved, (view.slot(k).get_global_rect().position - slots0[k]).length())
			moved = maxf(moved, (_rest(view.slot(k)) - rests0[k]).length())
		if b == null:
			for c in view.get_children():
				if c is ShipBreakup and not (c as Node).is_queued_for_deletion():
					b = c
					seen = true
					b.finished.connect(func() -> void:
						held.rest = b.rest_image()
						held.done = true)
		if b != null and is_instance_valid(b) and not held.done:
			# drawn from the dying ship's resting place, riding its bob
			var art := dying.art
			var canvas := _rest(dying) + (art.size - Vector2(EnemyArt.W, EnemyArt.H)) * 0.5
			var want := (view.get_global_transform().affine_inverse() * canvas).round() \
				+ Vector2(0, roundf(art.position.y - dying._art_base.y))
			off = maxf(off, (b.position - want).length())
		if held.done and after < 0.0:
			after = float(Time.get_ticks_msec())
		if after > 0.0 and float(Time.get_ticks_msec()) - after > 1000.0:
			break
	_ok("%s: the kill played a breakup" % tag, seen)
	_ok("%s: the breakup finished" % tag, held.done)
	_ok("%s: no slot and no ship's resting place moved from the kill to a second after (%.1f px)" % [tag, moved], moved < 0.5)
	# (within a pixel: the breakup takes the bob a frame after the art does)
	_ok("%s: the breakup stood where the ship rests (%.1f px off at worst)" % [tag, off], off <= 1.0)
	if held.done:
		await tree.process_frame
		var wreck: Image = dying.art._img
		var rest: Image = held.rest
		var same: bool = rest != null and rest.get_size() == wreck.get_size() and rest.get_data() == wreck.get_data()
		var diff := 0
		if rest != null and not same and rest.get_size() == wreck.get_size():
			for y in rest.get_height():
				for x in rest.get_width():
					if rest.get_pixel(x, y) != wreck.get_pixel(x, y):
						diff += 1
		_ok("%s: its last frame is the wreck the slot draws (%d pixels differ)" % [tag, diff], same)
	print("killholdtest: %s, %d frames watched" % [tag, frames])
