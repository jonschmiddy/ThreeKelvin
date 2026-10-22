extends Node

## A RESULT THAT GAVE YOU SOMETHING TO TAKE SHOWS REWARD, headless:
##   godot --headless --path . -- sheet=RewardShownTest
##
## Jon, Oct 22: "some quests don't show REWARD... they basically just say
## continue and the drawer drops to the bottom and there is SECTOR LOOT ....
## that's super NOT intuitive." REWARD was keyed on the outcome's `module` key
## (`OptionTable.pays_item`), and a part is not the only thing an event puts on
## the system's pile: `material`, `material_id` and an effect calling
## `Run.add_material` itself land there too, with no REWARD to say so.
##
## Every authored option, every choice, and every band of a checked choice
## (`SkillCheck.forced`), on a fresh copy of one system, resolved through
## LOCAL's event band (`LocalEventDrawer`) as a player takes it. What landed on
## the system's pile is read off the RUN, not off the drawer or the outcome's
## keys: a result that put anything there has REWARD, enabled; one that put
## nothing there has none; nothing that paid out skips its result
## (`fight_now`). The quest events are named in the sweep (`job_pickup`,
## `job_target` and the placed quest steps), the pickup with a signed fetch
## pointed at the system. And CONTINUE on a result with REWARD unopened still
## leaves the things under SECTOR LOOT, as it always did.
##
## Prints every outcome the old rule missed, so the list of what this fixed is
## the harness's own output.

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
	print("  %d outcomes resolved, %d put something on the pile, %d showed REWARD" % [outcomes, paid, shown])
	print("  the old rule (`module` only) showed no REWARD on %d of them:" % missed_before.size())
	for t in missed_before:
		print("    %s" % t)
	_ok("every outcome that put something on the pile showed REWARD (%d of %d)" % [shown, paid], paid > 0 and shown == paid)
	_ok("a material paid with no `module` key was among them (%d)" % missed_before.size(), missed_before.size() > 0)
	_ok("CONTINUE past REWARD was tried", left_ok)
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
