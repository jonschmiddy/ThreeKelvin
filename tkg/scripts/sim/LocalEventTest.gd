extends Harness

## Every authored option, opened and resolved through LOCAL's event band
## (`LocalEventDrawer`), the one place a choice is taken now:
##   godot --headless --path . -- localeventtest
##
## For every option in `OptionTable` and every one of its choices, on a fresh
## copy of one system: the band opens on it (its text, one card per choice),
## the choice resolves through `OptionResolve` -- the one rule -- and the band
## shows how it went: the result page with the band word and CONTINUE, or LEFT
## ALONE with CHOOSE AGAIN for a walk-away, or THEY ARE FIRING for a fight with
## something to read, or straight to the fight (`fight_now`), or the game over.
## A choice the band will not let you afford (credits, a material you are not
## carrying) is given what it wants first, so every branch is reached. In all
## three layouts. The screens a fight or a death would open are not opened
## (`LocalEventDrawer.quiet`).

var _tree: SceneTree


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	LocalEventDrawer.quiet = true
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var holder := Control.new()
	holder.size = Vector2(960, 540)
	tree.root.add_child(holder)
	var n := _system()
	if not _ok("a system to resolve in", n != null):
		_end(tree)
		return
	var opened := 0
	var resolved := 0
	var kinds := {}
	for layout: StringName in [&"row", &"column", &"card"]:
		LocalEventDrawer.layout = layout
		for o in OptionTable.all():
			var choices: Array = o.get("choices", [])
			for j in choices.size():
				_fresh(n, StringName(o.id))
				var c: Dictionary = choices[j]
				if c.has("cost_credits"):
					Run.add_credits(int(c.cost_credits) + 50)
				if c.has("needs_material") and Run.material(StringName(c.needs_material)) < 1:
					Run.add_material(StringName(c.needs_material), 1)
				var d := LocalEventDrawer.new()
				d.screen = holder
				d.node = n
				holder.add_child(d)
				d.open(0)
				await tree.process_frame
				await tree.process_frame
				await tree.process_frame
				var cards := 0
				for k in choices.size():
					if d.find_child("Choice%d" % k, true, false) != null:
						cards += 1
				if d.page != &"event" or cards != choices.size():
					_fail("%s (%s) did not open: page %s, %d of %d choices" % [o.id, layout, d.page, cards, choices.size()])
					d.queue_free()
					continue
				opened += 1
				var r: Dictionary = await d.choose(j)
				await tree.process_frame
				var what := ""
				if not r.get("ok", false):
					_fail("%s choice %d (%s) did not resolve: %s" % [o.id, j, layout, r.get("why", "?")])
				elif d.died:
					what = "dead"
				elif r.get("fight_now", false):
					what = "fight now" if d.fought else "?"
				elif d.page != &"result":
					_fail("%s choice %d (%s) shows no result" % [o.id, j, layout])
				elif r.get("stay", false):
					what = "left alone" if d.find_child("ChooseAgain", true, false) != null else "?"
				elif d.find_child("TheyAreFiring", true, false) != null:
					what = "they are firing"
				elif d.find_child("Continue", true, false) != null:
					what = "continue"
				if what == "?":
					_fail("%s choice %d (%s): the result has the wrong way on" % [o.id, j, layout])
				elif what != "":
					resolved += 1
					kinds[what] = int(kinds.get(what, 0)) + 1
				d.queue_free()
				if Run.dead:
					Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
					n = _system()
	print("  %d openings, %d resolutions: %s" % [opened, resolved, kinds])
	_ok("every option opened and every choice resolved in all three layouts", _fails == 0)
	_end(tree)


func _end(tree: SceneTree) -> void:
	LocalEventDrawer.quiet = false
	LocalEventDrawer.layout = &"row"
	print("")
	verdict("localeventtest")
	tree.quit(1 if _fails > 0 else 0)


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
	if Run.credits < 200:
		Run.add_credits(200)
