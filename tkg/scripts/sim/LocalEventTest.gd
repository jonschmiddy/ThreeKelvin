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
##
## And WHAT YOU END UP WITH, in every look (`OutcomeRow`): each result drawn
## again as today, A, B and C and held to what the run actually moved
## (`OutcomeCheck`: the ledger, the system's pile, the hold and the frame,
## diffed), with the box test. Every choice in the column layout,
## every fifth option in the other two.

var _tree: SceneTree
var _opt_i := -1
## Renders checked, and what kinds of change they covered ("hp-", "part+").
var looked := 0
var _kinds_seen := {}


func _tally(want: Dictionary) -> void:
	var any := false
	for k in want.stats:
		var d := int((want.stats[k] as Array)[0])
		if d != 0:
			any = true
			var key := "%s%s" % [k, "+" if d > 0 else "-"]
			_kinds_seen[key] = int(_kinds_seen.get(key, 0)) + 1
	for pair in [["gained", "+"], ["lost", "-"]]:
		for nm in want[pair[0]]:
			any = true
			var key2: String = "%s%s" % [want.kind.get(nm, "item"), pair[1]]
			_kinds_seen[key2] = int(_kinds_seen.get(key2, 0)) + 1
	for k2 in ["frame", "place"]:
		if want[k2]:
			any = true
			var key3: String = String(k2) + "+"
			_kinds_seen[key3] = int(_kinds_seen.get(key3, 0)) + 1
	if not any:
		_kinds_seen["nothing"] = int(_kinds_seen.get("nothing", 0)) + 1


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
		_opt_i = -1
		for o in OptionTable.all():
			_opt_i += 1
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
				var before := OutcomeCheck.snapshot(n)
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
				# WHAT YOU END UP WITH, in every look (`OutcomeRow`): the numbers the
				# run actually moved, and the box test. Every choice in Jon's
				# layout (the column); every fifth option in the other two.
				if what != "" and d.page == &"result" and (layout == &"column" or _opt_i % 5 == 0):
					var want := OutcomeCheck.expect(n, before, r.get("res", {}))
					_tally(want)
					for lk: StringName in OutcomeRow.LOOKS:
						OutcomeRow.look = lk
						d.out.erase("flown")
						d._result()
						for f in 3:
							await tree.process_frame
						var bad := OutcomeCheck.check(d, lk, want)
						looked += 1
						for line in bad.slice(0, 3):
							_fail("%s choice %d (%s): %s" % [o.id, j, layout, line])
						if not OutcomeRow.held.is_empty():
							_fail("%s choice %d (%s, %s): HUD numbers left held %s" % [o.id, j, layout, lk, OutcomeRow.held])
					OutcomeRow.look = &"today"
				d.queue_free()
				if Run.dead:
					Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
					n = _system()
	print("  %d openings, %d resolutions: %s" % [opened, resolved, kinds])
	print("  %d outcomes drawn in every look and box-tested, %d renders; what they moved: %s" % [looked / OutcomeRow.LOOKS.size(), looked, _kinds_seen])
	_ok("every option opened and every choice resolved in all three layouts, and every look said what moved and fit", _fails == 0)
	for k in ["hp-", "credits+", "credits-", "fuel+", "fuel-", "heat+", "part+", "material+", "frame+", "nothing"]:
		_ok("an outcome that moved %s was among them (%d)" % [k, int(_kinds_seen.get(k, 0))], int(_kinds_seen.get(k, 0)) > 0)
	_reveal_sound(holder)
	_end(tree)


## THE LETTERS' SOUND, counted (`SignalText.blips`; `Audio` is off headless, so
## what is checked is what the text asks for). A whole reveal asks for one blip
## per three letters, spaces not counted. A reveal skipped part way asks for no
## more after the skip. Reduced motion has no reveal and so no blips.
func _reveal_sound(holder: Control) -> void:
	var body := "A cargo lighter is moored to the loading mast outside the station. Its load has moved. Forty tonnes of something has come off its tethers."
	var letters := body.replace(" ", "").length()
	var want := int(ceil(letters / float(SignalText.BLIP_EVERY)))
	var was_anim: bool = Router.animate_in_harness
	var was_rm := DisplaySettings.reduced_motion
	Router.animate_in_harness = true
	DisplaySettings.reduced_motion = false
	var t := SignalText.new()
	t.custom_minimum_size.x = 600
	holder.add_child(t)
	t.text = body
	t.set_process(false)
	t.play()
	var steps := 0
	while not t.done and steps < 6000:
		t._process(1.0 / 60.0)
		steps += 1
	_ok("a whole reveal asks for a blip every %d letters (%d for %d letters, got %d)" % [
		SignalText.BLIP_EVERY, want, letters, t.blips], t.done and t.blips == want)
	t.play()
	while t.shown < 40.0 and steps < 12000:
		t._process(1.0 / 60.0)
		steps += 1
	var before := t.blips
	t.skip()
	for k in 30:
		t._process(1.0 / 60.0)
	_ok("a skipped reveal asks for nothing after the skip (%d before, %d after)" % [before, t.blips],
		before > 0 and t.blips == before)
	DisplaySettings.reduced_motion = true
	t.play()
	for k in 30:
		t._process(1.0 / 60.0)
	_ok("reduced motion shows the text whole with no blips (got %d)" % t.blips, t.done and t.blips == 0)
	DisplaySettings.reduced_motion = was_rm
	Router.animate_in_harness = was_anim
	t.queue_free()


func _end(tree: SceneTree) -> void:
	LocalEventDrawer.quiet = false
	LocalEventDrawer.layout = &"column"
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
