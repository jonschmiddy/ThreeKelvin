extends Node

## A LOCKED MANUFACTURER APPEARS NOWHERE (Jon, Oct 20: "Solari things should NOT
## show up in the game until Solari is unlocked (win the game once)").
##   godot --headless --path . -- sheet=LockedPoolTest [seed N]
##
## Three profiles, each over SEEDS seeded galaxies, every source of a part or a
## hull rolled the way the game rolls it:
##   - every wreck a fight could leave, at every system, for every ordinary kind
##     (`Combat.roll_wreck`, Territory space forcing its manufacturer included);
##   - every station's shelf and its yard hull (`StationScreen._stock_up`);
##   - a kill bag at every system (`Run.open_bag`), a derelict's hull and an
##     event's hull (`LootGen.roll_hull` off the salvage stream), the relic
##     analysis and an event's floor part (`LootGen.roll_module`, both ways);
##   - the custodian's body at the core (`Combat.core_body`);
##   - every contract board's fetch item (`Contracts.board`).
## A FRESH profile (no record, developer mode off) finds Korvan and unbranded
## and nothing else, and every one of those still rolls something; a record with
## a Korvan WIN finds Solari too and nothing past it; DEVELOPER MODE finds Solari
## too. No profile finds a manufacturer `DB.ACTIVE_MANUFACTURERS` leaves out.
##
## Then the two ways a run could change its mind: a save from a fresh profile
## loaded after a Korvan win is recorded still finds no Solari (and the next new
## run does), and in a party the host's unlocks are the world's.

var h := Harness.new()

const SEEDS := 6
const HISTORY := "user://lockedpool_history.json"
const SAVE := "user://lockedpool_run.save"

var _history_was: String
var _save_was: String
var _dev_was: bool


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	_history_was = RunHistory.path
	_save_was = SaveGame.path
	_dev_was = DevMode.enabled
	RunHistory.path = HISTORY
	SaveGame.path = SAVE

	_profile("fresh", false, false)
	_profile("a Korvan win", true, false)
	_profile("developer mode", false, true)
	_continue_keeps()
	_party()

	_drop(HISTORY)
	_drop(SAVE)
	RunHistory.path = _history_was
	SaveGame.path = _save_was
	DevMode.enabled = _dev_was
	h.verdict("lockedpooltest")
	get_tree().quit(h.code())


# ------------------------------------------------------------------ profiles

## The record holds one Korvan win, or nothing.
func _record(korvan_won: bool) -> void:
	_drop(HISTORY)
	if not korvan_won:
		return
	var f := FileAccess.open(HISTORY, FileAccess.WRITE)
	f.store_string(JSON.stringify({version = RunHistory.VERSION, runs = [
		{outcome = int(RunHistory.Outcome.WON), chassis_manufacturer = "korvan"}]}))
	f.close()


func _profile(label: String, korvan_won: bool, dev: bool) -> void:
	print("=== %s ===" % label.to_upper())
	_record(korvan_won)
	DevMode.enabled = dev
	var want_solari := korvan_won or (dev and DevMode.enabled)
	if dev and not DevMode.enabled:
		h._fail("developer mode is not available in this binary, so it cannot be tested")
		return
	var seen: Dictionary = {}      # manufacturer -> count, every part and hull
	var by_source: Dictionary = {}  # source -> {manufacturer -> count}
	var empty: Array[String] = []
	var read_ok := true
	for i in SEEDS:
		h.seed_run(7100 + i)
		Run.start_new_run(&"korvan", i % 3)
		var expect: Array[StringName] = [&"korvan"]
		if want_solari:
			expect.append(&"solari")
		if not dev:
			read_ok = read_ok and Run.unlocked_manufacturers == expect
		else:
			read_ok = read_ok and Run.unlocked_manufacturers.size() == Unlocks.CHAIN.size()
		_roll_everything(seen, by_source, empty)
	h._ok("the run read %s off the record at its start" % label, read_ok)

	var names := PackedStringArray()
	for m in seen:
		names.append("%s %d" % [String(m) if m != &"" else "unbranded", int(seen[m])])
	print("  found: %s" % ", ".join(names))
	h._ok("Korvan parts appear", int(seen.get(&"korvan", 0)) > 0)
	h._ok("unbranded parts appear", int(seen.get(&"", 0)) > 0)
	if want_solari:
		h._ok("Solari appears", int(seen.get(&"solari", 0)) > 0)
		for src in by_source:
			if src in ["contract fetch item"]:
				continue
			var row: Dictionary = by_source[src]
			if not h._ok("  and in %s" % src, int(row.get(&"solari", 0)) > 0):
				print("    %s: %s" % [src, str(row)])
	else:
		var leaks: Array[String] = []
		for src in by_source:
			var row: Dictionary = by_source[src]
			if int(row.get(&"solari", 0)) > 0:
				leaks.append("%s %d" % [src, int(row[&"solari"])])
		h._ok("no Solari part, hull or name anywhere%s" % (
			"" if leaks.is_empty() else ": " + ", ".join(leaks)), leaks.is_empty())
	# Past the chain's second rung, or off the active list: never, on any profile.
	var past: Array[String] = []
	for m in seen:
		if m == &"" or m == &"korvan" or m == &"solari":
			continue
		past.append("%s %d" % [String(m), int(seen[m])])
	h._ok("nothing from a manufacturer that is locked or switched off%s" % (
		"" if past.is_empty() else ": " + ", ".join(past)), past.is_empty())
	h._ok("every roll rolled something%s" % (
		"" if empty.is_empty() else ": " + ", ".join(empty)), empty.is_empty())
	# The hull pool itself, which a derelict and a yard both draw from.
	var frames: Dictionary = {}
	for f in LootGen.hull_pool():
		frames[f.manufacturer] = true
	var want_frames := [&"", &"korvan"]
	if want_solari:
		want_frames.append(&"solari")
	h._ok("the yard and derelict frames are %s" % str(want_frames),
		frames.size() == want_frames.size() and want_frames.all(func(m) -> bool: return frames.has(m)))


## Every source, rolled as the game rolls it, into `seen` and `by_source`.
func _roll_everything(seen: Dictionary, by_source: Dictionary, empty: Array[String]) -> void:
	var kinds: Array[EnemyTemplate] = []
	for id in DB.enemies:
		var t: EnemyTemplate = DB.enemies[id]
		if not (t.boss or t.miniboss or t.fauna):
			kinds.append(t)
	var stocker := StationScreen.new()
	var at_was := Run.at
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		match n.type:
			MapGen.NodeType.SYSTEM:
				for k in kinds.size():
					var items := Combat.roll_wreck(n, kinds[k], k, 1)
					_count(items, "wrecks", seen, by_source)
				n.bagged = false
				n.bag.clear()
				Run.open_bag(n, 2, 1)
				if n.bag.is_empty():
					empty.append("a kill bag at %d" % n.index)
				_count(n.bag, "kill bags", seen, by_source)
				var r := Rng.derive(&"salvage", n.index)
				for j in 3:
					_count([LootGen.roll_hull(n.danger, r)], "derelict hulls", seen, by_source)
				_count([LootGen.roll_module(n.danger)], "event floor parts", seen, by_source)
				_count([LootGen.roll_module(n.danger, &"", true)], "relic analysis", seen, by_source)
				# Territory space forcing each manufacturer in turn, which is the
				# path that has to fall back rather than empty its pool.
				for m in Unlocks.CHAIN:
					var forced := LootGen.roll_module(n.danger, m, false, Rng.derive(&"lockedforce", n.index))
					if forced == null:
						empty.append("forced %s at %d" % [m, n.index])
					_count([forced], "forced territory rolls", seen, by_source)
			MapGen.NodeType.STATION:
				Run.at = n.index
				n.stocked = false
				n.shop.clear()
				n.shop_hull = null
				stocker._stock_up()
				if n.shop.is_empty():
					empty.append("the shelf at %d" % n.index)
				_count(n.shop, "station shelves", seen, by_source)
				if n.shop_hull != null:
					_count([n.shop_hull], "yard hulls", seen, by_source)
				for c in Contracts.board(n):
					var cd := c as ContractData
					if cd.item == "":
						continue
					var who := _named(cd.item)
					_tally(who, "contract fetch item", seen, by_source)
			MapGen.NodeType.CORE:
				var custodian: EnemyTemplate = DB.enemies[&"custodian"]
				var body := Combat.core_body(n, custodian)
				var parts := 0
				for it in body.items:
					if it is ModuleData:
						parts += 1
				if parts < Combat.CORE_PARTS:
					empty.append("the custodian's body (%d parts)" % parts)
				_count(body.items, "the custodian's body", seen, by_source)
	Run.at = at_was
	stocker.free()


## Which manufacturer makes the part a contract names, or &"" for an unmarked crate.
func _named(item: String) -> StringName:
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.name == item:
			return m.manufacturer
	return &""


func _count(items: Array, src: String, seen: Dictionary, by_source: Dictionary) -> void:
	for it in items:
		if it is ModuleData:
			_tally((it as ModuleData).manufacturer, src, seen, by_source)
		elif it is HullData:
			_tally((it as HullData).manufacturer, src, seen, by_source)


func _tally(m: StringName, src: String, seen: Dictionary, by_source: Dictionary) -> void:
	seen[m] = int(seen.get(m, 0)) + 1
	if not by_source.has(src):
		by_source[src] = {}
	by_source[src][m] = int(by_source[src].get(m, 0)) + 1


# ------------------------------------------------------------- mid-run change

## A run started fresh, saved, and loaded after a Korvan win: the world it is
## already in keeps rolling from the pool it started with. The next run is new.
func _continue_keeps() -> void:
	print("=== CONTINUE ===")
	DevMode.enabled = false
	_record(false)
	h.seed_run(7200)
	Run.start_new_run(&"korvan", 1)
	SaveGame.save()
	_record(true)
	h._ok("the save loads", SaveGame.load_into_run())
	h._ok("and keeps the pool it started with, Korvan alone",
		Run.unlocked_manufacturers == ([&"korvan"] as Array[StringName]))
	var solari := 0
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type != MapGen.NodeType.SYSTEM:
			continue
		for i in 4:
			var m := LootGen.roll_module(n.danger, &"solari", false, Rng.derive(&"lockedkeep", n.index * 4 + i))
			if m.manufacturer == &"solari":
				solari += 1
		if LootGen.roll_hull(n.danger, Rng.derive(&"lockedkeep", n.index)).manufacturer == &"solari":
			solari += 1
	h._ok("so it still finds no Solari (%d)" % solari, solari == 0)
	Run.start_new_run(&"korvan", 1)
	h._ok("the next new run has Solari", Run.unlocked_manufacturers.has(&"solari"))
	_record(false)


# ---------------------------------------------------------------------- party

## In a party the host's unlocks are the world's, on every machine.
func _party() -> void:
	print("=== PARTY ===")
	DevMode.enabled = false
	_record(false)
	var probe := NetSession.new()
	probe._apply_dive(4242, ["korvan", "solari", "nobody"])
	h._ok("a dive's unlocks are read off the wire, unknown ids dropped",
		probe.dive_unlocked == ([&"korvan", &"solari"] as Array[StringName]))
	probe.free()
	var was_state := Net.state
	var was_seed := Net.dive_seed
	var was_open := Net.dive_unlocked.duplicate()
	Net.state = NetSession.State.DIVING
	Net.dive_seed = 4242
	Net.dive_unlocked = [&"korvan", &"solari"] as Array[StringName]
	var got := Unlocks.for_new_run()
	Net.state = was_state
	Net.dive_seed = was_seed
	Net.dive_unlocked = was_open
	h._ok("a fresh profile in a host's dive rolls from the host's unlocks (%s)" % str(got),
		got == ([&"korvan", &"solari"] as Array[StringName]))
	h._ok("and alone, from its own (Korvan)", Unlocks.for_new_run() == ([&"korvan"] as Array[StringName]))


func _drop(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
