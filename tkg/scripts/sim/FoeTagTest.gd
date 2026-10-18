extends Node

## WHAT AN EVENT'S FIGHT BRINGS IS WHAT ITS TEXT SET UP, headless:
##   godot --headless --path . -- sheet=FoeTagTest [seeds=N]
##
## Jon, Oct 17: a fight started from an event's choice may bring a creature,
## "but the text leading up to the fight should make sense. Like it should
## mention the megafauna or whales you know?" The rule is data: an option (or
## one of its choices) carries `foe = &"whale"` / `&"leviathan"` when its text
## is about that creature (`OptionTable.fight_foe`), and `Router.option_foe`
## fields exactly that, or a ship off the ordinary pool when there is no tag.
##
## Three parts:
##   1. THE TABLE. Every tag names a creature, sits on a fauna-gated option that
##      can actually start a fight, and its body names that creature (a calf
##      event says "calf", a leviathan event "leviathan"). Every untagged option
##      that can start a fight has no creature in its body.
##   2. THE SWEEP, over N seeded galaxies (default 24): every fight-capable
##      choice of every option rolled at every system, asked of the same door
##      the game asks. A creature exactly when the option is tagged, and the
##      creature it named; a ship otherwise, fauna space included. Then the
##      same sweep against two broken builds -- the tag dropped on the way to
##      `option_foe`, and the old rule that took fauna from the region -- each
##      of which must be caught, so this check is known to see the fault.
##   3. THE DOORS. Each creature event and two ship events opened on the real
##      LOCAL, its fight choice taken through the event band
##      (`LocalEventDrawer.choose`, `OptionResolve.take`), and the fight that
##      `Router.start_ambush` opens read off `Router.combat`.

var _fails := 0
var _shown := 0
var _tree: SceneTree

## Words that put a creature in a body. Whole words: "calves" (a rock face
## breaking off) is not a calf.
var _creature_words := RegEx.create_from_string("\\b(megafauna|voidwhale|leviathan|whales?|calf)\\b")
## What a tagged body must say for each creature.
const NAMES := {&"whale": "calf", &"leviathan": "leviathan"}


func _ok(what: String, c: bool) -> bool:
	if c:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)
	return c


func _quiet_fail(what: String) -> void:
	_fails += 1
	if _shown < 25:
		print("  FAIL %s" % what)
		_shown += 1


func _arg(k: String, d: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Rng.forced = 777
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var fights := _fight_choices()
	print("=== the table ===")
	_table(fights)
	print("=== the sweep ===")
	_sweep(fights, int(_arg("seeds", "24")))
	print("=== the doors ===")
	await _doors()
	print("foetagtest: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	_tree.quit()


## Which choices of each option can start a fight: every outcome of every
## choice run once on a scratch ship kept alive, and the ones whose result
## says `fight` kept. By running them, not by reading them, so a fight hidden
## in a botched branch counts.
func _fight_choices() -> Dictionary:
	var out := {}
	for o in OptionTable.all():
		var js: Array[int] = []
		var choices: Array = o.get("choices", [])
		for j in choices.size():
			var c: Dictionary = choices[j]
			var calls: Array = []
			if c.has("effect"):
				calls.append(c.effect)
			for k in ["met", "clean", "partial", "botched"]:
				if c.has(k):
					calls.append(c[k])
			for f in calls:
				Run.dead = false
				Run.hp = Run.max_hp()
				Run.credits = maxi(Run.credits, 500)
				var res: Variant = (f as Callable).call()
				if typeof(res) == TYPE_DICTIONARY and bool((res as Dictionary).get("fight", false)):
					js.append(j)
					break
		if not js.is_empty():
			out[StringName(o.id)] = js
	Run.dead = false
	return out


func _tag(o: Dictionary) -> StringName:
	return OptionTable.fight_foe(o)


func _table(fights: Dictionary) -> void:
	var tagged := 0
	var ship := 0
	for o in OptionTable.all():
		var id := StringName(o.id)
		var body := String(o.get("body", "")).to_lower()
		var tags: Array[StringName] = []
		if o.has("foe"):
			tags.append(StringName(o.foe))
		for c in o.get("choices", []):
			if (c as Dictionary).has("foe"):
				tags.append(StringName(c.foe))
		if tags.is_empty():
			if fights.has(id):
				ship += 1
				var m := _creature_words.search(body)
				if m != null:
					_quiet_fail("%s starts a fight with a ship, but its text is about a creature (\"%s\"): tag it or rewrite it" % [id, m.get_string()])
			continue
		tagged += 1
		for t in tags:
			var e: EnemyTemplate = DB.enemies.get(t)
			if e == null or not e.fauna:
				_quiet_fail("%s is tagged foe = %s, which is not a creature" % [id, t])
				continue
			if not body.contains(String(NAMES.get(t, String(t)))):
				_quiet_fail("%s brings a %s, and its text never says \"%s\"" % [id, e.name, NAMES.get(t, t)])
		if not bool(o.get("needs_fauna", false)):
			_quiet_fail("%s is tagged for a creature and is not fauna-gated" % id)
		if not fights.has(id):
			_quiet_fail("%s is tagged for a creature and nothing in it starts a fight" % id)
	_ok("every tag is a creature, on a fauna-gated event that fights, whose text names it (%d tagged)" % tagged, _fails == 0)
	var before := _fails
	_ok("no ship fight follows text about a creature (%d ship events)" % ship, _fails == before)


## Every fight-capable choice of every option a system rolled, over `seeds`
## galaxies. `how` is the build under test: "game" asks the door the game
## asks; "dropped" loses the tag on the way; "region" is the old rule that
## fielded fauna wherever the region was fauna.
func _bring(n: MapGen.MapNode, o: Dictionary, c: Dictionary, how: String) -> EnemyTemplate:
	match how:
		"dropped":
			return Router.option_foe(n)
		"region":
			return DB.enemies[Rng.pick(Rng.foe, DB.fight_pool(n.danger, n.fauna))]
	return Router.option_foe(n, OptionTable.fight_foe(o, c))


func _wrong(n: MapGen.MapNode, o: Dictionary, c: Dictionary, t: EnemyTemplate) -> String:
	var want := OptionTable.fight_foe(o, c)
	if want == &"" and t.fauna:
		return "%s at system %d (danger %d%s) brought a %s after text about ships" % [
			o.id, n.index, n.danger, ", fauna" if n.fauna else "", t.name]
	if want != &"" and t.id != want:
		return "%s at system %d (danger %d) brought a %s after text about a %s" % [
			o.id, n.index, n.danger, t.name, DB.enemies[want].name]
	return ""


func _sweep(fights: Dictionary, seeds: int) -> void:
	var tally := {"game": 0, "dropped": 0, "region": 0}
	var asked := 0
	var creatures := 0
	var fauna_systems := 0
	var fauna_with := 0
	var fauna_events := 0
	var by_id := {}
	var by_danger := {}
	for sd in seeds:
		Rng.forced = 5000 + sd * 37
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if n.type != MapGen.NodeType.SYSTEM or not OptionTable.ensure(n):
				continue
			var creature_here := false
			for oid in n.options:
				var o := OptionTable.by_id(oid)
				if o.is_empty() or not fights.has(StringName(oid)):
					continue
				var choices: Array = o.choices
				if o.has("foe"):
					by_id[oid] = int(by_id.get(oid, 0)) + 1
				for j: int in fights[StringName(oid)]:
					var c: Dictionary = choices[j]
					for how in ["game", "dropped", "region"]:
						var t := _bring(n, o, c, how)
						var why := _wrong(n, o, c, t)
						if why != "":
							tally[how] = int(tally[how]) + 1
							if how == "game":
								_quiet_fail(why)
						elif how == "game":
							asked += 1
							if t.fauna:
								creatures += 1
								creature_here = true
			if n.fauna:
				by_danger[n.danger] = int(by_danger.get(n.danger, 0)) + 1
				fauna_systems += 1
				fauna_events += n.options.size()
				if creature_here:
					fauna_with += 1
	print("  %d fight choices asked over %d galaxies · %d brought a creature" % [asked, seeds, creatures])
	print("  systems holding each creature event: %s" % str(by_id))
	var ds := by_danger.keys()
	ds.sort()
	var hist := PackedStringArray()
	for d in ds:
		hist.append("%d:%d" % [d, by_danger[d]])
	print("  fauna systems by danger: %s" % " ".join(hist))
	print("  fauna systems %d holding %d events · %d of them hold a creature fight event (%.0f%%)" % [
		fauna_systems, fauna_events, fauna_with, 100.0 * fauna_with / maxi(1, fauna_systems)])
	_ok("every event fight brought what its text set up (%d wrong)" % int(tally.game), int(tally.game) == 0)
	_ok("creature events do come up in creature space (%d systems)" % fauna_with, fauna_with > 0)
	_ok("the check catches a build that drops the tag (%d wrong there)" % int(tally.dropped), int(tally.dropped) > 0)
	_ok("the check catches a build that takes creatures from the region (%d wrong there)" % int(tally.region), int(tally.region) > 0)


## The real doors: LOCAL, the event band, `OptionResolve.take`, the drawer's
## `_fight`, `Router.start_ambush`. One fight choice of each creature event,
## and two ship events taken in fauna space.
func _doors() -> void:
	var ids: Array[StringName] = []
	for o in OptionTable.all():
		if o.has("foe"):
			ids.append(StringName(o.id))
	ids.append(&"hostile_contact")
	ids.append(&"first_on_the_wreck")
	LocalEventDrawer.quiet = false
	for oid in ids:
		var o := OptionTable.by_id(oid)
		var j := -1
		var choices: Array = o.choices
		for k in choices.size():
			if bool((choices[k] as Dictionary).get("fight", false)) and not (choices[k] as Dictionary).has("check"):
				j = k
				break
		if not _ok("%s has a fight choice to take" % oid, j >= 0):
			continue
		var got := await _take_on_local(oid, j)
		var want := OptionTable.fight_foe(o, choices[j])
		if want == &"":
			_ok("%s: '%s' on LOCAL in fauna space brought a ship (%s)" % [oid, choices[j].label, got],
				got != &"" and not (DB.enemies[got] as EnemyTemplate).fauna)
		else:
			_ok("%s: '%s' on LOCAL brought the %s it named (%s)" % [oid, choices[j].label, DB.enemies[want].name, got],
				got == want)
	LocalEventDrawer.quiet = false


func _take_on_local(oid: StringName, j: int) -> StringName:
	Router.combat = null
	Router.current_fight = {}
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := -1
	for m: MapGen.MapNode in Run.map:
		if m.type == MapGen.NodeType.SYSTEM and not m.cleared and m.danger >= 3:
			idx = m.index
			break
	Run.at = idx
	var n: MapGen.MapNode = Run.node_at()
	n.visited = true
	# fauna space, and a danger the option admits
	n.fauna = true
	n.region = MapGen.Region.FAUNA
	var o := OptionTable.by_id(oid)
	n.danger = clampi(n.danger, int(o.get("min_danger", 1)), int(o.get("max_danger", 10)))
	n.options.clear()
	n.options.append(oid)
	n.taken.clear()
	SectorScreen._approached_at = idx
	SystemMapScreen._parked.erase(idx)
	LocalEventDrawer.request(idx, 0)
	Router.show_local()
	for i in 30:
		await _tree.process_frame
	var sc := Router.current as SectorScreen
	if sc == null or sc._events == null or sc._events.page != &"event":
		_quiet_fail("%s did not open on LOCAL" % oid)
		return &""
	var d: LocalEventDrawer = sc._events
	Run.hp = Run.max_hp()
	var r: Dictionary = await d.choose(j)
	await _tree.process_frame
	if not r.get("fight_now", false):
		var go := d.find_child("TheyAreFiring", true, false) as Button
		if go == null:
			_quiet_fail("%s: no THEY ARE FIRING after the choice" % oid)
			return &""
		go.pressed.emit()
	for i in 60:
		await _tree.process_frame
		if Router.combat != null:
			break
	if Router.combat == null or Router.combat.enemies.is_empty():
		_quiet_fail("%s: no fight opened" % oid)
		return &""
	return Router.combat.enemies[0].template.id
