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
				# a science reading burns fuel, and is refused below the way out
				if bool(c.get("burns", false)):
					Run.fuel = Run.FUEL_TANK
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
				# A READING IS NEVER A FIGHT: its result reads, then CONTINUE
				if OptionTable.is_science(o) and what != "continue" and what != "dead":
					_fail("%s choice %d (%s): a science result goes to '%s', not CONTINUE" % [o.id, j, layout, what])
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
	await _fuel_gate(holder, n)
	await _fuel_cards(holder, n)
	_reveal_sound(holder)
	_end(tree)


## THE FUEL GATE ON THE BAND (science, a hard gate): with the tank one fuel short
## of the way out plus the reading's fuel, a click on either reading does
## nothing (no fuel, no DATA, no result), `OptionResolve.take` says "fuel", and
## the credits line still resolves.
func _fuel_gate(holder: Control, n: MapGen.MapNode) -> void:
	LocalEventDrawer.layout = &"column"
	_fresh(n, &"the_spare_probe")
	var short := Run.fuel_floor() + OptionTable.science_fuel() - 1
	Run.fuel = short
	Run.data = 0
	var d := LocalEventDrawer.new()
	d.screen = holder
	d.node = n
	holder.add_child(d)
	d.open(0)
	for f in 3:
		await _tree.process_frame
	if d.text != null and not d.text.done:
		d.text.skip()
	var r0: Dictionary = await d.choose(0)
	var r1: Dictionary = await d.choose(1)
	var held := r0.is_empty() and r1.is_empty() and Run.fuel == short and Run.data == 0 and d.page == &"event"
	var t: Dictionary = await OptionResolve.take(n, 0, 0)
	_ok("one fuel short of the way out plus a reading's fuel, both readings refuse on the band (take says '%s')"
		% String(t.get("why", "")), held and not bool(t.get("ok", true)) and String(t.get("why", "")) == "fuel"
		and Run.fuel == short and Run.data == 0)
	var cr := Run.credits
	var r2: Dictionary = await d.choose(2)
	_ok("and the credits line still resolves, burning nothing", bool(r2.get("ok", false))
		and Run.credits > cr and Run.fuel == short and Run.data == 0)
	d.queue_free()
	Run.fuel = Run.FUEL_TANK


## WHAT A READING BURNS IS ON ITS CARD (`EncounterDrawer.choice_card`), in all
## three layouts, for every science event: with a full tank each `burns` card's
## note ends "· N fuel" after its odds ("N fuel" alone on the careful line), N
## the reading's own `OptionTable.science_fuel()`, and the card answers a
## click; the credits line says nothing of fuel. With exactly the way out plus
## the reading in the tank the card is still live and still reads "N fuel" (the
## gate's edge). One fuel short of that, each `burns` card reads "needs N fuel +
## K to leave · you have M" (N the same price as on the full card, K the way out
## `Run.fuel_floor()` keeps, M the tank), in FLARE, and is not pressable: no
## live plate, no pointing hand (only pressable things look pressable); the
## credits line still is. And with the note showing it fits: every note inside
## its card, every card inside the band and clear of the others, the band
## asking for no more than its cap.
func _fuel_cards(holder: Control, n: MapGen.MapNode) -> void:
	var looked_at := 0
	var saw_keep := 0
	var bad: Array = []
	for layout: StringName in [&"row", &"column", &"card"]:
		LocalEventDrawer.layout = layout
		for o in OptionTable.all():
			if not OptionTable.is_science(o):
				continue
			for tank: StringName in [&"full", &"exact", &"short"]:
				var short := tank == &"short"
				_fresh(n, StringName(o.id))
				var burn := OptionTable.science_fuel()
				var keep := Run.fuel_floor()
				var need := burn + keep
				Run.fuel = {&"full": Run.FUEL_TANK, &"exact": need, &"short": need - 1}[tank]
				var d := LocalEventDrawer.new()
				d.screen = holder
				d.node = n
				holder.add_child(d)
				d.open(0)
				for f in 4:
					await _tree.process_frame
				var at := "%s (%s, %s)" % [o.id, layout, tank]
				var choices: Array = o.get("choices", [])
				var band := d.panel.get_global_rect()
				var cap := LocalEventDrawer.CARD_MAX_H if layout == &"card" else LocalEventDrawer.H
				if d.panel.get_combined_minimum_size().y > cap + 0.5:
					bad.append("%s: the band asks for %.0f px of its %.0f" % [at, d.panel.get_combined_minimum_size().y, cap])
				var rects: Array = []
				for j in choices.size():
					var c: Dictionary = choices[j]
					var card := d.find_child("Choice%d" % j, true, false) as EncounterDrawer.OptionCard
					if card == null:
						bad.append("%s: no card %d" % [at, j])
						continue
					looked_at += 1
					var note := card.find_child("Note", true, false) as Label
					var said := note.text if note != null else ""
					var cr := card.get_global_rect()
					if bool(c.get("burns", false)):
						var badge := SkillCheck.badge(c.check) + " · " if c.has("check") else ""
						var want := "%s%d fuel" % [badge, burn]
						if short:
							var left := Run.fuel_floor()
							want = "needs %d fuel%s · you have %d" % [burn, " + %d to leave" % left if left > 0 else "", Run.fuel]
							saw_keep = maxi(saw_keep, left)
						if said != want:
							bad.append("%s choice %d: the note reads '%s', not '%s'" % [at, j, said, want])
						if card.live == short or (card.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND) == short:
							bad.append("%s choice %d: the card is %s with %d fuel" % [at, j, "pressable" if short else "refused", Run.fuel])
						if short and note != null and note.get_theme_color("font_color") != UITheme.FLARE:
							bad.append("%s choice %d: the refusal is not in FLARE" % [at, j])
					else:
						if said.contains("fuel"):
							bad.append("%s choice %d: the credits line says '%s'" % [at, j, said])
						if not card.live:
							bad.append("%s choice %d: the credits line is not pressable" % [at, j])
					if note != null:
						var nr := note.get_global_rect()
						if not cr.encloses(nr):
							bad.append("%s choice %d: the note %s is off its card %s" % [at, j, nr, cr])
						if note.get_minimum_size().y > nr.size.y + 0.5:
							bad.append("%s choice %d: the note wants %.0f px tall and has %.0f" % [at, j, note.get_minimum_size().y, nr.size.y])
					if not band.encloses(cr):
						bad.append("%s choice %d: the card %s is off the band %s" % [at, j, cr, band])
					for r2: Rect2 in rects:
						if r2.intersects(cr):
							bad.append("%s choice %d: the card %s meets another %s" % [at, j, cr, r2])
					rects.append(cr)
				d.queue_free()
				await _tree.process_frame
	for line in bad.slice(0, 8):
		print("    " + String(line))
	_ok("every science card says the fuel it burns and fits, and a refused one reads 'needs N fuel + K to leave' and is not pressable (%d cards, %d faults, K up to %d)" % [looked_at, bad.size(), saw_keep],
		looked_at > 0 and saw_keep > 0 and bad.is_empty())
	LocalEventDrawer.layout = &"column"
	Run.fuel = Run.FUEL_TANK


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
