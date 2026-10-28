extends Node

## THE HULL NUMBER BESIDE THE PIPS (ruling 12 C, Jon, Oct 27):
##   godot --headless --path . --fixed-fps 60 -- sheet=HullNumberTest
##
## Geno, in the friends' alpha, read the chassis select's HULL as 4, 6 and 8
## pips against Korvan's 29, 40 and 57 hull and took them for a mismatch. The
## pips are hull over 7, rounded, and the tooltip claimed an exact "A pip is 7
## hull". So:
##
## - the real chassis select, at the game's 960x540, prints every frame's real
##   hull ("29 hull") after HULL's number, for every manufacturer and weight,
##   and that is the hull the run launches with (`Run.max_hp()`, full). Every
##   startable frame, for certain: a scratch flight record with a win for every
##   manufacturer opens them all (`_unlock_all`), so the count does not hang on
##   DevMode being on, and it must be all of them;
## - HULL is the only row that carries one;
## - it fits: no overlap with anything drawn on the screen, inside its column,
##   the column no wider than `ChassisSelect.SIDE_W`, inside the screen;
## - the HULL tooltip says about 7, never an exact 7, and its sum is the ship's
##   own, "Your 29 hull rounds to 4 pips." (also on a damaged ship and at 1 pip);
## - a block set up without `amounts` (the refit screen, the cutaway, the yard)
##   prints no readout.

var _tree: SceneTree
var _fails := 0
## The flight record's path before `_unlock_all` pointed it at a scratch file.
var _history_was := ""


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	_tooltip_text()

	# (before the screen is built, so it is built as a player with all seven sees it)
	_unlock_all()
	Router.new_run(4242)
	await _frames(4)
	var cs := Router.current as ChassisSelect
	if not _ok("a new run opens the chassis select", cs != null):
		return _finish()
	var screen := cs.get_viewport().get_visible_rect()
	print("  [screen] %s" % screen)
	_ok("the game's picture is 960x540", screen.size == Vector2(960, 540))

	var flown := 0
	for i in DB.STARTABLE.size():
		var manufacturer: StringName = DB.STARTABLE[i]
		if not _ok("%s is open to fly" % manufacturer, Unlocks.unlocked(manufacturer)):
			continue
		for w in ChassisSelect.WEIGHTS:
			cs._select(i)
			cs._pick_weight(w)
			await _frames(3)
			_check(cs, manufacturer, w, screen)
			flown += 1
	var every := DB.STARTABLE.size() * ChassisSelect.WEIGHTS.size()
	_ok("every startable manufacturer at every weight was checked (%d of %d frames)" % [flown, every],
		flown == every)

	await _plain_blocks()
	_finish()


## THE TOOLTIP: about 7, and the sum on the ship you have.
func _tooltip_text() -> void:
	var per := int(round(Run.HULL_REF / Run.ATTR_MAX))
	_ok("a pip is HULL_REF / ATTR_MAX = %d hull" % per, per == 7)
	Rng.forced = 4242
	for w in ChassisSelect.WEIGHTS:
		Run.start_new_run(&"korvan", int(w))
		for hp: int in [Run.max_hp(), floori(Run.max_hp() * 0.5), 5, 0]:
			Run.hp = hp
			var row := _hull_row(Run.attributes())
			var effect := String(row.effect)
			var pips := Run.attr_hull()
			var sum := "Your %d hull rounds to %d %s." % [hp, pips, "pip" if pips == 1 else "pips"]
			print("    %s %d/%d: %s" % [HullData.weight_name(w), hp, Run.max_hp(), effect])
			_ok("  %s at %d hull: the tooltip says about %d, not an exact %d" % [
				HullData.weight_name(w), hp, per, per],
				effect.begins_with("A pip is about %d hull. " % per)
				and not effect.contains("A pip is %d hull." % per))
			_ok("  and does the sum on this ship: \"%s\"" % sum, effect.contains(sum))
			_ok("  and the row carries the hull it reads: %s" % row.get("amount", "none"),
				String(row.get("amount", "")) == "%d hull" % hp)
	Rng.forced = 0


## One frame on the real chassis select.
func _check(cs: ChassisSelect, manufacturer: StringName, w: HullData.Weight, screen: Rect2) -> void:
	var tag := "%s %s" % [manufacturer, HullData.weight_name(w)]
	var frame := DB.hull_for(manufacturer, w)
	var block := _find(cs, func(n: Node) -> bool:
		return n is AttrBlock and (n as AttrBlock).is_visible_in_tree()) as AttrBlock
	if not _ok("%s: the attribute block is up" % tag, block != null):
		return
	var amounts := _amounts_of(block)
	var amt := amounts.get(0, null) as Label
	print("    %-18s frame %d hull, launches with %d/%d, gauge %d, readout \"%s\"" % [
		tag, frame.max_hull, Run.hp, Run.max_hp(), Run.attr_hull(),
		amt.text if amt != null else "none"])
	if not _ok("%s: HULL's row shows a hull number" % tag, amt != null and amt.is_visible_in_tree()):
		return
	_ok("%s: it is the real max hull, \"%d hull\" (frame %d, full: %d/%d)" % [
		tag, Run.max_hp(), frame.max_hull, Run.hp, Run.max_hp()],
		amt.text == "%d hull" % Run.max_hp() and Run.hp == Run.max_hp())
	_ok("%s: HULL is the only row with one" % tag,
		amounts.size() == 1 and amounts.has(0))
	# after the pips and HULL's number, in the same row
	var value := block._values[0]
	var cells := block._rows[0]
	var row := amt.get_parent() as Control
	_ok("%s: in HULL's row, after its pips and its number" % tag,
		row == value.get_parent() and row == cells.get_parent()
		and amt.get_index() == value.get_index() + 1
		and cells.get_global_rect().end.x <= value.get_global_rect().position.x
		and value.get_global_rect().end.x <= amt.get_global_rect().position.x)
	_ok("%s: in the row's own size" % tag,
		amt.get_theme_font_size("font_size") == value.get_theme_font_size("font_size"))

	# FIT: nothing overlaps, the column has not grown, all on screen
	var right := block.get_parent() as Control
	var ar := amt.get_global_rect()
	_ok("%s: inside its column (%s in %s)" % [tag, ar, right.get_global_rect()],
		right.get_global_rect().grow(0.5).encloses(ar))
	var widest := 0.0
	for v in block._values:
		if v != value:
			widest = maxf(widest, (v.get_parent() as Control).size.x)
	_ok("%s: the column is still %d wide (%.0f; HULL's row %.0f, the others %.0f)" % [
		tag, ChassisSelect.SIDE_W, right.size.x, row.size.x, widest],
		right.size.x <= ChassisSelect.SIDE_W + 0.5)
	_ok("%s: on screen" % tag, screen.grow(0.5).encloses(ar))
	var hits: Array[String] = []
	for c in _drawn(cs):
		if c == amt or c.is_ancestor_of(amt):
			continue
		var r := c.get_global_rect().intersection(ar)
		if r.size.x > 0.0 and r.size.y > 0.0:
			hits.append("%s %s" % [c.get_class() if c.get_script() == null else c.get_script().get_global_name(),
				(c as Label).text if c is Label else String(c.name)])
	_ok("%s: overlaps nothing drawn%s" % [tag, "" if hits.is_empty() else ": " + ", ".join(hits)],
		hits.is_empty())
	# the readout's own row neighbours, box by box
	var kids: Array[Control] = []
	for k in row.get_children():
		if k is Control and (k as Control).visible:
			kids.append(k)
	var clash := false
	for a in kids.size():
		for b in range(a + 1, kids.size()):
			var r2 := kids[a].get_global_rect().intersection(kids[b].get_global_rect())
			if r2.size.x > 0.0 and r2.size.y > 0.0:
				clash = true
	_ok("%s: HULL's label, pips, number and hull clear of each other" % tag, not clash)
	_ok("%s: and the row's tooltip is the honest one" % tag,
		row.tooltip_text.replace("\n", " ").contains("A pip is about 7 hull. Your %d hull rounds to" % Run.max_hp()))


## Every Control under `root` that puts ink on the screen.
func _drawn(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	if root is Control and (root as Control).is_visible_in_tree() and (
			root is Label or root is BaseButton or root is TextureRect
			or root is AttrBlock.Cells or root is ShipView or root is ChassisSelect.Banner):
		out.append(root)
	for c in root.get_children():
		out.append_array(_drawn(c))
	return out


## A block set up the refit screen's way prints no readout.
##
## Through `callv` and `_amounts_of` rather than by name, so that on the code
## before the readout this reports a failure instead of failing to compile.
func _plain_blocks() -> void:
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var takes := 0
	for md: Dictionary in (load("res://scripts/ui/AttrBlock.gd") as Script).get_script_method_list():
		if md.name == "setup":
			takes = (md.args as Array).size()
	if not _ok("AttrBlock.setup takes `amounts` (%d arguments)" % takes, takes >= 3):
		return
	var plain := AttrBlock.new()
	var full := AttrBlock.new()
	add_child(plain)
	add_child(full)
	plain.setup(Run.attributes())
	full.callv(&"setup", [Run.attributes(), UITheme.CHILL, true])
	await _frames(2)
	_ok("a block set up without amounts prints no readout (the refit screen, cutaway, yard)",
		_amounts_of(plain).is_empty())
	_ok("and one set up with them prints HULL's alone",
		_amounts_of(full).size() == 1 and _amounts_of(full).has(0))
	plain.queue_free()
	full.queue_free()


## The block's readouts by row, or none on a block that has no such thing.
func _amounts_of(b: AttrBlock) -> Dictionary:
	var v: Variant = b.get(&"_amounts")
	return v if v is Dictionary else {}


func _hull_row(rows: Array[Dictionary]) -> Dictionary:
	for r in rows:
		if r.key == &"hull":
			return r
	return {}


func _find(root: Node, matches: Callable) -> Node:
	if root == null:
		return null
	if matches.call(root):
		return root
	for c in root.get_children():
		var f := _find(c, matches)
		if f != null:
			return f
	return null


## EVERY STARTABLE MANUFACTURER OPEN, whatever DevMode says. A locked one cannot
## be picked (`ChassisSelect._select`), and the sheet skipped them, so it only
## covered all seven because DevMode is on from the editor. A scratch flight
## record with a win for each opens the chain the way a player opens it.
func _unlock_all() -> void:
	_history_was = RunHistory.path
	RunHistory.path = TestRun.scratch("hullnumber_history", "json")
	var runs: Array = []
	for m in Unlocks.CHAIN:
		runs.append({"outcome": int(RunHistory.Outcome.WON), "chassis_manufacturer": String(m)})
	var f := FileAccess.open(RunHistory.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": RunHistory.VERSION, "runs": runs}))
	f.close()


func _finish() -> void:
	if _history_was != "":
		RunHistory.clear()
		RunHistory.path = _history_was
	print("hullnumbertest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
