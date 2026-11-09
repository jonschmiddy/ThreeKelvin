extends Node

## Jon, Oct 22: results that gave loot showed only CONTINUE, as REWARD was keyed on `module` alone.
## What landed on the pile is read off the run, not the drawer or the outcome's keys.
## Why: docs/why/RewardShownTest.md#reward-shown

var _tree: SceneTree
var _fails := 0
var _holder: Control


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _fail(why: String) -> void:
	print("  FAIL %s" % why)
	_fails += 1


func _ready() -> void:
	_run.call_deferred()


func _frames(k: int) -> void:
	for i in k:
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	LocalEventDrawer.quiet = true
	LocalEventDrawer.layout = &"column"
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_holder = Control.new()
	_holder.size = Vector2(960, 540)
	_tree.root.add_child(_holder)
	var n := _system()
	if not _ok("a system to resolve in", n != null):
		_end()
		return
	var outcomes := 0
	var paid := 0
	var shown := 0
	var missed_before: Array = []
	var quests := {}
	var left_ok := false
	var named_seen := false
	var science := 0
	for o in OptionTable.all():
		var id := StringName(o.id)
		var is_quest := (o.get("tags", []) as Array).has(&"quest")
		var choices: Array = o.get("choices", [])
		for j in choices.size():
			var c: Dictionary = choices[j]
			var bands: Array = [-1]
			if c.has("check"):
				bands = [SkillCheck.Band.MET, SkillCheck.Band.CLEAN,
					SkillCheck.Band.PARTIAL, SkillCheck.Band.BOTCHED]
			for b in bands:
				_fresh(n, id)
				if c.has("cost_credits"):
					Run.add_credits(int(c.cost_credits) + 50)
				if id == &"job_pickup":
					_sign_fetch(n)
				# a science reading burns fuel, and is refused below the way out
				if bool(c.get("burns", false)):
					Run.fuel = Run.FUEL_TANK
				SkillCheck.forced = int(b)
				var d := LocalEventDrawer.new()
				d.screen = _holder
				d.node = n
				_holder.add_child(d)
				d.open(0)
				await _frames(3)
				var was := OptionResolve.pile_now(n)
				var r: Dictionary = await d.choose(j)
				SkillCheck.forced = -1
				await _frames(1)
				var tag := "%s choice %d%s" % [id, j, "" if b < 0 else " " + SkillCheck.band_name(b)]
				if not r.get("ok", false):
					_fail("%s did not resolve: %s" % [tag, r.get("why", "?")])
					d.queue_free()
					continue
				outcomes += 1
				if is_quest:
					quests[id] = int(quests.get(id, 0)) + 1
				var gained := OptionResolve.pile_gained(n, was)
				var res: Dictionary = r.get("res", {})
				if gained > 0:
					paid += 1
					if not OptionTable.pays_item(res):
						missed_before.append(tag)
				if d.died or Run.dead:
					d.queue_free()
					Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
					n = _system()
					continue
				var reward := d.find_child("Reward", true, false) as Button
				# A READING PAYS DATA, NOT THINGS: its result has no REWARD and is
				# never a fight with nothing to read
				if OptionTable.is_science(o):
					science += 1
					if r.get("fight_now", false) or d.page != &"result" or reward != null or gained > 0:
						_fail("%s (science): fight_now %s, page %s, REWARD %s, %d on the pile" % [tag,
							str(r.get("fight_now", false)), d.page, str(reward != null), gained])
				if r.get("fight_now", false):
					# straight to the fight, no result: only when nothing was paid
					if gained > 0:
						_fail("%s put %d on the pile and went straight to the fight with no result" % [tag, gained])
				elif d.page != &"result":
					_fail("%s shows no result" % tag)
				elif gained > 0:
					if reward == null:
						_fail("%s put %d on the pile and the result has no REWARD" % [tag, gained])
					elif reward.disabled:
						_fail("%s put %d on the pile and REWARD is greyed" % [tag, gained])
					else:
						shown += 1
						# ONE NAME FOR THE PILE, and the louder button (stripped-down UI 6, Nov 9)
						var cont := d.find_child("Continue", true, false) as Button
						if cont == null:
							cont = d.find_child("TheyAreFiring", true, false) as Button
						var sb := reward.get_theme_stylebox(&"normal") as StyleBoxFlat
						if not named_seen:
							named_seen = true
							var csb: StyleBoxFlat = (cont.get_theme_stylebox(&"normal") as StyleBoxFlat) if cont != null else null
							_ok("the pile's button says SECTOR LOOT, in ember over the plain button beside it (%s, %s)" % [reward.text, cont.text if cont != null else "none"],
								reward.text == "SECTOR LOOT" and sb != null and sb.border_color.is_equal_approx(UITheme.EMBER)
								and cont != null and (csb == null or not csb.border_color.is_equal_approx(UITheme.EMBER)))
					# CONTINUE with REWARD unopened: the things stay in SECTOR LOOT
					if reward != null and not left_ok:
						d.continue_on()
						await _frames(2)
						var loot := Run.sector_loot(n)
						left_ok = _ok("CONTINUE past an unopened REWARD (%s) leaves it under SECTOR LOOT (%d there)" % [
							tag, Run.jetsam_left(n, loot) if loot != null else 0],
							loot != null and Run.jetsam_left(n, loot) >= gained)
				elif reward != null:
					_fail("%s put nothing on the pile and the result has REWARD" % tag)
				d.queue_free()
	_ok("a result with loot was checked for its button's name and ink", named_seen)
	print("  %d outcomes resolved, %d put something on the pile, %d showed REWARD" % [outcomes, paid, shown])
	print("  the old rule (`module` only) showed no REWARD on %d of them:" % missed_before.size())
	for t in missed_before:
		print("    %s" % t)
	_ok("every outcome that put something on the pile showed REWARD (%d of %d)" % [shown, paid], paid > 0 and shown == paid)
	_ok("a material paid with no `module` key was among them (%d)" % missed_before.size(), missed_before.size() > 0)
	_ok("CONTINUE past REWARD was tried", left_ok)
	_ok("every science outcome (%d) shows its result with no REWARD and no fight" % science, science == 8 * 6)
	for q in [&"job_pickup", &"job_target", &"paid_in_full"]:
		_ok("the quest event %s was resolved (%d)" % [q, int(quests.get(q, 0))], int(quests.get(q, 0)) > 0)
	_end()


## A signed fetch pointed at `n`, so the pickup's choice readies a real job.
func _sign_fetch(n: MapGen.MapNode) -> void:
	var job := ContractData.new()
	job.kind = ContractData.Kind.FETCH
	job.state = ContractData.State.TAKEN
	job.at = n.index
	job.manufacturer = &"korvan"
	job.item = "SEALED POD"
	Run.contracts.append(job)


func _end() -> void:
	SkillCheck.forced = -1
	LocalEventDrawer.quiet = false
	print("")
	print("rewardshowntest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)


## The first ordinary system of the run, with the ship at it.
func _system() -> MapGen.MapNode:
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.SYSTEM:
			OptionTable.ensure(m)
			Run.at = m.index
			return m
	return null


## The system holding this one option, untouched, and the ship whole.
func _fresh(n: MapGen.MapNode, id: StringName) -> void:
	n.options.clear()
	n.options.append(id)
	n.taken.clear()
	n.results.clear()
	n.left.clear()
	n.said.clear()
	n.jetsam.clear()
	n.cleared = false
	n.ambush_pending = false
	Run.at = n.index
	Run.hp = Run.max_hp()
	Run.heat = 0
	Run.cargo.clear()
	Run.contracts.clear()
	if Run.credits < 200:
		Run.add_credits(200)
