class_name DevFlags
extends RefCounted
## The harness and shot flags `Main._ready` dispatches on, as ordered tables; the first row to match wins.
## Why: docs/why/DevFlags.md#tables

## Tests that run across frames live here: a RefCounted only a local holds is freed when `_ready` returns.
## Why: docs/why/DevFlags.md#coroutine-tests
var held: Array[RefCounted] = []
var host: Node

func _init(main: Node) -> void:
	host = main

## Before any UI exists: these run instead of the game and most quit when done.
const EARLY: Array[Dictionary] = [
	# Balance sim, through the normal boot so the autoloads exist:  -- sim runs=200
	{flag = "sim", fn = "_sim"},
	# Save/load round-trip test, same shape as the balance sim:  -- savetest
	{flag = "savetest", fn = "_savetest"},
	# Silent-failure check: a melt price creeping above ask would quietly pay all run.
	{flag = "market", script = "res://scripts/sim/MarketTest.gd", how = "quit"},
	# Attribute tuning reads columns, not one ship a screen, or phantom spreads look real.
	# Why: docs/why/DevFlags.md#test-flags
	{flag = "attrs", fn = "_attrs"},
	# Skill checks fail silently both ways, so this prints real costs and proves the odds.
	# Why: docs/why/DevFlags.md#test-flags
	{flag = "checks", fn = "_checks"},
	# Needs a window: SpaceBackdrop is renderer-drawn, so headless viewports come back blank.
	# Why: docs/why/DevFlags.md#test-flags
	{flag = "sky", script = "res://scripts/sim/SkyTest.gd", how = "hold"},
	# Covers the market invariant under standing, which `-- market` cannot reach.
	{flag = "contracttest", script = "res://scripts/sim/ContractTest.gd", how = "quit"},
	# What every repair card is worth at full, half and three hull;
	# RUN THIS AFTER TOUCHING heal OR heal_scale ON ANYTHING
	{flag = "repairs", script = "res://scripts/sim/RepairSheet.gd", how = "quit"},
	# Which picture every card draws, and whether one of them has become a catch-all.
	{flag = "glyphs", script = "res://scripts/sim/GlyphSheet.gd", how = "quit"},
	# Run after touching `Rng` or any generator: broken determinism fails silently.
	{flag = "rngtest", script = "res://scripts/sim/RngTest.gd", how = "quit"},
	# Held in a member: a RefCounted held only by a local is freed when `_ready` returns.
	# Why: docs/why/DevFlags.md#test-flags
	{flag = "nettest", script = "res://scripts/sim/NetTest.gd", how = "hold"},
	# Resolves every authored option through LOCAL's event band, the one place a choice is taken.
	{flag = "localeventtest", script = "res://scripts/sim/LocalEventTest.gd", how = "hold"},
	# The bot returns before the UI and registers Router as its own holder, like a human.
	# Why: docs/why/DevFlags.md#bot-flag
	{flag = "bot", script = "res://scripts/net/BotPilot.gd", how = "hold"},
	# The prompt reads fiction live; force the palette and send no init image or alpha drops.
	# Why: docs/why/DevFlags.md#art-prompt
	{flag = "artprompt", script = "res://scripts/sim/ArtPrompt.gd", how = "hold"},
	# Run after touching HullFit: fittings go on before damage so a bolt-on can be shot off.
	# Why: docs/why/DevFlags.md#test-flags
	{flag = "fit", script = "res://scripts/sim/FitSheet.gd", how = "hold"},
	# Run after touching HullWear's organic ops: the substance split keeps whales unwelded.
	{flag = "bestiary", script = "res://scripts/sim/BestiarySheet.gd", how = "hold"},
	# Wear must introduce no new colours; any count but 0 is a bug.
	{flag = "wear", script = "res://scripts/sim/WearSheet.gd", how = "hold"},
	# Mounts are measured per sprite, so another hull's lines would draw guns in mid-air silently.
	# Why: docs/why/DevFlags.md#test-flags
	{flag = "content", script = "res://scripts/sim/ContentCount.gd", how = "quit"},
	# Each flag asks one question: rarity values, map traversal, option rules, system layout.
	# Why: docs/why/DevFlags.md#test-flags
	{flag = "systemtest", script = "res://scripts/sim/SystemTest.gd", how = "quit"},
	# Checks the sector weather schedule: one at a time, rare showpieces, none if reduced.
	{flag = "weathertest", script = "res://scripts/sim/WeatherTest.gd", how = "quit"},
	{flag = "optiontest", script = "res://scripts/sim/OptionTest.gd", how = "quit"},
	{flag = "maptest", script = "res://scripts/sim/MapTest.gd", how = "quit"},
	{flag = "rarity", script = "res://scripts/sim/RaritySheet.gd", how = "quit"},
	# Every catalogue row becomes an item a real hold accepts.
	{flag = "materialtest", script = "res://scripts/sim/MaterialTest.gd", how = "quit"},
	{flag = "holdtest", fn = "_holdtest"},
	# Probes for start frames and reactor decks, the chart's known-only view, part gauges.
	# Why: docs/why/DevFlags.md#test-flags
	{flag = "attrtest", script = "res://scripts/sim/AttrTest.gd", how = "quit"},
	{flag = "chartfilter", script = "res://scripts/sim/ChartFilter.gd", how = "quit"},
	{flag = "reactor", script = "res://scripts/sim/ReactorSheet.gd", how = "quit"},
	{flag = "mounts", script = "res://scripts/sim/MountCheck.gd", how = "quit"},
	# Every .gd in the project, loaded. `--check-only` does not reach a file nothing instantiates.
	{flag = "parseall", script = "res://scripts/sim/ParseAll.gd", how = "quit"},
	{flag = "artcheck", script = "res://scripts/sim/ArtCheck.gd", how = "quit"},
	{flag = "shipsheet", script = "res://scripts/sim/ConvoyTest.gd", how = "hold"},
]

## After `Router.register`, before the boot destination is chosen.
const REGISTERED: Array[Dictionary] = [
	# Added after `Router.register`: before it every swap threw while the verdict said PASS.
	# Why: docs/why/DevFlags.md#co-fight-test
	{flag = "cofight", script = "res://scripts/sim/CoFightTest.gd", how = "hold"},
	# Runs after `Router.register`, unlike cofight, since LOCAL and the SECTOR map are checked.
	# Why: docs/why/DevFlags.md#co-fight-test
	{flag = "cojoin", script = "res://scripts/sim/CoJoinTest.gd", how = "hold"},
	# Real galaxy data for the sensor-ladder study:  -- sensordump
	{flag = "sensordump", script = "res://scripts/sim/SensorDump.gd", how = "hold"},
	# What the chart looks like now that sight is live:  -- fogshot
	{flag = "fogshot", script = "res://scripts/sim/FogShot.gd", how = "hold"},
	# Does the ship move when its loadout changes? It must not:  -- shipdrift
	{flag = "shipdrift", script = "res://scripts/sim/ShipDriftTest.gd", how = "hold"},
	# Photographs the chart at a ladder of zooms to see the boundary.
	{flag = "zoomshot", script = "res://scripts/sim/ZoomShot.gd", how = "hold"},
	# Runs after `Router.register`: it needs the UI it measures to exist.
	{flag = "chartbench", script = "res://scripts/sim/ChartBench.gd", how = "hold"},
]

## After the boot destination is up. `falls` rows go on to the next row instead of ending `_ready`.
const BOOTED: Array[Dictionary] = [
	# Flags match bare words anywhere, so `chartshot quest` once opened `quest` instead.
	# Why: docs/why/DevFlags.md#dev-shortcuts
	{flag = "questrun", fn = "_questrun"},
	# A shot's argument must not match the mode: `shipshot heavy cargo` opened a game.
	# Why: docs/why/DevFlags.md#dev-shortcuts
	{flag = "cargo", unless = "shipshot", fn = "_cargo"},
	# Quest rings sit on a screen unreachable from a station: contracts faked, chart real.
	# Why: docs/why/DevFlags.md#dev-shortcuts
	{flag = "quest", fn = "_quest"},
	{flag = "party", fn = "_party"},
	# The arrival screen, with its option list:  -- sectorshot
	{flag = "fitwords", script = "res://scripts/sim/FitWords.gd", how = "quit"},
	{flag = "namefit", script = "res://scripts/sim/NameFit.gd", how = "quit"},
	{flag = "sighttest", script = "res://scripts/sim/SightTest.gd", how = "quit"},
	{flag = "cursorsheet", script = "res://scripts/sim/CursorSheet.gd", how = "hold"},
	# The jump sequence, frame by frame. NOT `jumpshot`: `Router.animating()` is
	# false for anything ending in "shot" and the tweens are the whole subject.
	{flag = "jumpcine", script = "res://scripts/sim/JumpCine.gd", how = "hold"},
	{flag = "sectorshot", script = "res://scripts/sim/SectorShot.gd", how = "hold"},
	{flag = "chartshot", script = "res://scripts/sim/ChartShot.gd", how = "hold"},
	# Exhaust runs headless: a plume that fails to load is invisible, not loud.
	{starts = "sheet=", script = "res://scripts/sim/%s.gd", how = "add"},
	# Every kind of world, as the GPU paints it, on one sheet:  -- planetsheet=<png>
	# Needs a window. Same seeds and light as the approved gallery page.
	{starts = "planetsheet=", script = "res://scripts/sim/PlanetSheet.gd", how = "add"},
	# Four real systems as JSON, for laying out the system map:  -- systemdump=<path>
	{starts = "systemdump=", script = "res://scripts/sim/SystemDump.gd", how = "hold"},
	{flag = "encdump", script = "res://scripts/sim/EncDump.gd", how = "hold"},
	{flag = "exhaust", script = "res://scripts/sim/ExhaustCheck.gd", how = "hold"},
	# Artdemo runs after boot: `show_ship` needs the Router to hold a content node first.
	# Why: docs/why/DevFlags.md#dev-shortcuts
	{flag = "artdemo", script = "res://scripts/sim/ArtDemo.gd", how = "hold"},
	{flag = "shipshot", script = "res://scripts/sim/ShipShot.gd", how = "hold"},
	# Beside stationshot: needs a window, asserts nothing, lets an art call be seen, not argued.
	{flag = "cardshot", script = "res://scripts/sim/CardShot.gd", how = "hold"},
	# Needs a window and a Router content node, which the headless checks run before.
	{flag = "stationshot", script = "res://scripts/sim/StationShot.gd", how = "hold"},
	# Walks the Router, so it must run after `register` gives it a content node.
	{flag = "skyshot", script = "res://scripts/sim/SkyShot.gd", how = "hold"},
	{flag = "placesheet", script = "res://scripts/sim/PlaceSheet.gd", how = "hold"},
	# Windowed for a different reason than the shots: `Audio` switches itself
	# off headless, so the subject of this test only exists with a window.
	{flag = "audiotest", script = "res://scripts/sim/AudioTest.gd", how = "hold"},
	{flag = "convoy", script = "res://scripts/sim/ConvoyTest.gd", how = "hold"},
	# The salvage rail is driven through the real screen and a jump, which unit asserts miss.
	# Why: docs/why/DevFlags.md#test-flags
	{flag = "transfertest", script = "res://scripts/sim/TransferTest.gd", how = "hold"},
	# The cutaway's moves, through its own handlers (`CutawayView`).
	{flag = "cutawaytest", script = "res://scripts/sim/CutawayTest.gd", how = "hold"},
	# Every encounter's subject resolves to art and its staging fits LOCAL.
	{flag = "subjecttest", script = "res://scripts/sim/SubjectTest.gd", how = "hold"},
	{flag = "stowtest", script = "res://scripts/sim/StowTest.gd", how = "hold"},
	# Leaving a run from the pause menu, and whether the screen left behind draws once more with no ship.
	{flag = "quittest", script = "res://scripts/sim/QuitTest.gd", how = "hold"},
	# First-run hints: each fires once at its trigger, never again, and SHOW HINTS AGAIN brings them back.
	{flag = "hinttest", script = "res://scripts/sim/HintTest.gd", how = "hold"},
	# The sector map's worlds keep up with a pan (no picture trailing its own ring).
	{flag = "maplagtest", script = "res://scripts/sim/MapLagTest.gd", how = "hold"},
	# Key bindings, rebound through Settings and pressed on real screens, in a settings file of its own.
	{flag = "bindtest", script = "res://scripts/sim/BindTest.gd", how = "hold"},
	# The escape menu after reduced motion and skip jump change under it, with the animations on.
	{flag = "menutest", script = "res://scripts/sim/MenuTest.gd", how = "hold"},
	# Developer mode in the editor and as released, from one settings file:  -- devtest [asrelease]
	{flag = "devtest", script = "res://scripts/sim/DevTest.gd", how = "hold"},
	# Not headless: it drives Viewport's drag machine. Held so the coroutine lives.
	{flag = "fittest", script = "res://scripts/sim/FitTest.gd", how = "hold"},
	# Needs a real window and a holder for the coroutine, like fittest.
	{flag = "warptest", script = "res://scripts/sim/WarpTest.gd", how = "hold"},
	# Held: an unreferenced RefCounted is freed mid-await and the test dies.
	# Why: docs/why/DevFlags.md#coroutine-tests
	{flag = "charttest", script = "res://scripts/sim/ChartTest.gd", how = "hold", falls = true},
]

## The dev shortcuts: the first match wins, then `_ready` goes on to the shot flags.
## Why: docs/why/DevFlags.md#dev-shortcuts
const SHORTCUTS: Array[Dictionary] = [
	{flag = "cards", fn = "_cards"},
	{flag = "parts", fn = "_parts"},
	{flag = "ship", fn = "_ship"},
	{flag = "station", fn = "_station"},
	{flag = "salvage", fn = "_salvage"},
	{flag = "fight", fn = "_fight"},
]


## Runs every matching row in order; true once one has ended `_ready`.
func dispatch(rows: Array[Dictionary]) -> bool:
	var argv := OS.get_cmdline_user_args()
	for row in rows:
		var arg := _match(row, argv)
		if arg != "" and _run(row, arg):
			return true
	return false


## Runs only the first matching row.
func dispatch_first(rows: Array[Dictionary]) -> void:
	var argv := OS.get_cmdline_user_args()
	for row in rows:
		var arg := _match(row, argv)
		if arg != "":
			_run(row, arg)
			return


## The argument that matched the row, or "" when none did.
func _match(row: Dictionary, argv: PackedStringArray) -> String:
	if row.has("unless") and row.unless in argv:
		return ""
	if row.has("flag"):
		return String(row.flag) if row.flag in argv else ""
	for a in argv:
		if a.begins_with(row.starts):
			return a
	return ""


## True when `_ready` must return afterwards.
func _run(row: Dictionary, arg: String) -> bool:
	var how: String = row.get("how", "fn")
	if how == "fn":
		return call(row.fn)
	var path: String = row.script
	if "%s" in path:
		path = path % arg.substr(String(row.starts).length())
	if how == "add":
		host.add_child(load(path).new())
		return true
	var t: RefCounted = load(path).new()
	if how == "hold":
		held.append(t)
		t.run(host.get_tree())
		return not row.get("falls", false)
	t.run()
	host.get_tree().quit()
	return true


func _sim() -> bool:
	var sim := HeadlessSim.new()
	sim.run_sim()
	host.get_tree().quit(sim.exit_code)
	return true


## Held and awaited: its pick-mode check runs in the tree, on frames.
func _holdtest() -> bool:
	var t: RefCounted = load("res://scripts/sim/HoldTest.gd").new()
	held.append(t)
	_run_then_quit(t)
	return true


func _run_then_quit(t: RefCounted) -> void:
	await t.run()
	host.get_tree().quit()


func _savetest() -> bool:
	var t: RefCounted = load("res://scripts/sim/SaveTest.gd").new()
	t.run()
	t.run_history_test()
	t.run_version_test()
	host.get_tree().quit()
	return true


func _attrs() -> bool:
	_print_attribute_table()
	host.get_tree().quit()
	return true


func _checks() -> bool:
	_print_check_table()
	host.get_tree().quit()
	return true


func _questrun() -> bool:
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var seen := {Run.at: true}
	var queue: Array[int] = [Run.at]
	var done := 0
	while not queue.is_empty() and done < 24:
		var i: int = queue.pop_front()
		(Run.map[i] as MapGen.MapNode).visited = true
		done += 1
		for j in (Run.map[i] as MapGen.MapNode).links:
			if not seen.has(j):
				seen[j] = true
				queue.append(j)
	Run.chart_from(Run.node_at())
	var at := OptionTable.place(Run.node_at(), &"paid_in_full")
	if at < 0:
		print("nowhere to place it")
	else:
		var t: MapGen.MapNode = Run.map[at]
		print("%s -- %s on %s, layer %d, you are on %d"
			% [Run.hull.name, OptionTable.quest_name(t),
				MapGen.star_name(t), t.layer,
				(Run.node_at() as MapGen.MapNode).layer])
	Router.show_starchart()
	return true


func _cargo() -> bool:
	Run.start_new_run(&"korvan", int(HullData.Weight.HEAVY))
	var shapes := ["2x2", "4x1", "3x1", "2x1", "1x1"]
	var tiers: Array[StringName] = [&"legendary", &"exotic", &"contraband",
		&"artifact", &"epic", &"rare", &"common"]
	var ti := 0
	for shape in shapes:
		for row in MaterialTable.all():
			if String(row.get("cells", "")) != shape:
				continue
			var m := MaterialData.of(row)
			m.tier = tiers[ti % tiers.size()]
			ti += 1
			if not Run.place_in_hold(m):
				break
	# Then fill the rest, so the hold is genuinely tight and the packing is
	# something you have to think about rather than look at.
	for row in MaterialTable.all():
		if Run.hold_full():
			break
		var m2 := MaterialData.of(row)
		m2.tier = tiers[ti % tiers.size()]
		ti += 1
		Run.place_in_hold(m2)
	var used := 0
	for c in Run.cargo:
		used += c.cells()
	print("%s -- hold %dx%d, %d items, %d of %d cells" % [Run.hull.name,
		Run.hull.hold_grid.x, Run.hull.hold_grid.y, Run.cargo.size(),
		used, Run.hull.hold_grid.x * Run.hull.hold_grid.y])
	# Puts a container on the floor so SECTOR has one to open; reaching is half the point.
	var n0: MapGen.MapNode = Run.node_at()
	var tiers0: Array[StringName] = [&"legendary", &"contraband", &"rare",
		&"exotic", &"common", &"artifact", &"epic"]
	var want0 := ["2x2", "4x1", "1x1", "3x1", "2x1", "1x1", "2x1"]
	var k0 := 0
	for shape0 in want0:
		for row0 in MaterialTable.all():
			if String(row0.get("cells", "")) != shape0:
				continue
			var mm := MaterialData.of(row0)
			mm.tier = tiers0[k0 % tiers0.size()]
			k0 += 1
			n0.bag.append(mm)
			break
	n0.bag.append(LootGen.roll_module(3, &"", false, Rng.derive(&"look", 7)))
	n0.bagged = true
	Router.show_ship()
	return true


func _quest() -> bool:
	for kind in [ContractData.Kind.FETCH, ContractData.Kind.HUNT,
			ContractData.Kind.HEAT]:
		var got := false
		for n in Run.map:
			for c in Contracts.board(n as MapGen.MapNode):
				var job: ContractData = c
				if job.kind == kind and not Run.holds_contract(job):
					Run.take_contract(job)
					got = true
					break
			if got:
				break
	Router.show_starchart()
	# ...and select the fetch target, which is the state worth looking at:
	# a system you know about only because you signed for it.
	for c in Run.contracts:
		var job: ContractData = c
		if job.at >= 0 and Run.known_only_by_contract(job.at):
			(Router.current as StarchartScreen)._on_node_picked(job.at)
			break
	return false


func _party() -> bool:
	var crew := 5
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			crew = clampi(int(a), 1, 7)
	# Loaded rather than named: ConvoyTest carries no class_name, which is why
	# every other use of it in this file goes through load() too.
	var ct: GDScript = load("res://scripts/sim/ConvoyTest.gd")
	ct.fake_party(crew)
	Net.state = NetSession.State.IN_PARTY
	Router.show_party()
	return false


func _cards() -> bool:
	Router.show_cards()
	return false


func _parts() -> bool:
	Router.show_modules()
	return false


func _ship() -> bool:
	var flags := OS.get_cmdline_user_args()
	if "light" in flags or "heavy" in flags:
		var w: HullData.Weight = HullData.Weight.HEAVY
		if "light" in flags:
			w = HullData.Weight.LIGHT
		Run.fit_chassis(&"korvan", w, 0)
	# Refit is the screen most worth looking at and was the most tedious to reach.
	# The hold is seeded because the screen is a workbench and an empty hold tests half.
	# Why: docs/why/DevFlags.md#ship-shot
	for i in 8:
		Run.stow(LootGen.roll_module(2 + i, &"", true))
	# A module id as an argument is built and installed, duplicated to protect the entry.
	# Why: docs/why/DevFlags.md#ship-shot
	for a in flags:
		var mid := StringName(a)
		if not DB.modules.has(mid):
			continue
		var pick := (DB.modules[mid] as ModuleData).duplicate(true) as ModuleData
		Run.install_module(pick)
		print("[ship] installed %s (%s)" % [pick.name, mid])
	# `sets`, `mixed` and `name` give the masthead and perk corner state a default run lacks.
	var want := 0
	for a2 in flags:
		if (a2 as String).begins_with("sets="):
			want = int((a2 as String).substr(5))
		elif (a2 as String).begins_with("name="):
			Run.ship_name = (a2 as String).substr(5)
	var fitted := 0
	for mid2 in DB.modules:
		if fitted >= want:
			break
		var md: ModuleData = DB.modules[mid2]
		if md.manufacturer != Run.hull.manufacturer:
			continue
		Run.install_module(md.duplicate(true) as ModuleData)
		fitted += 1
	# Two others, not three: three left the hull manufacturer at four, one short of top.
	# Why: docs/why/DevFlags.md#ship-shot
	if "mixed" in flags:
		var others := 0
		for oid in DB.manufacturers:
			if oid == Run.hull.manufacturer or others >= 2:
				continue
			for mid3 in DB.modules:
				if (DB.modules[mid3] as ModuleData).manufacturer != oid:
					continue
				Run.install_module((DB.modules[mid3] as ModuleData).duplicate(true) as ModuleData)
				others += 1
				break
	var tally := PackedStringArray()
	for oid2 in DB.manufacturers:
		var n2 := Run.manufacturer_count(oid2)
		if n2 > 0:
			tally.append("%s %d" % [DB.short_name(DB.manufacturer_name(oid2)), n2])
	if tally.size() > 0:
		print("[ship] allegiances: %s%s" % [", ".join(tally),
			"  ·  named '%s'" % Run.ship_name if Run.ship_name != "" else ""])
	Router.show_ship()
	return false


func _station() -> bool:
	# Goes straight to the dock, and gives the merge gate a screen that constructs the station.
	# Why: docs/why/DevFlags.md#station-shot
	var here: MapGen.MapNode = Run.node_at()
	here.type = MapGen.NodeType.STATION
	here.development = MapGen.Development.CITY
	here.security = 4
	# Contested by default, `manufacturer=a,b,c` overrides; up to three, as MapGen wants.
	var berths: Array[StringName] = [&"solari", &"cygnet"]
	for a4 in OS.get_cmdline_user_args():
		if not (a4 as String).begins_with("manufacturer="):
			continue
		var arg := (a4 as String).substr(13)
		if arg == "none":
			berths = []
			continue
		var want: Array[StringName] = []
		for piece in arg.split(",", false):
			var mid := StringName(piece.strip_edges())
			if DB.manufacturers.has(mid):
				want.append(mid)
			else:
				print("[station] no manufacturer '%s' -- skipped" % mid)
		if not want.is_empty():
			berths = want
	here.berths = berths
	here.manufacturer = berths[0] if not berths.is_empty() else &""
	here.danger = 5
	# `full` packs the hold until `hold_full()` says no cell is free, to exercise busy decks.
	# Why: docs/why/DevFlags.md#station-shot
	var deep := "full" in OS.get_cmdline_user_args()
	for i in 3:
		Run.stow(LootGen.roll_module(4 + i, &"", true))
	# Straight into the hold: this debug seed puts you in a state, not a pickup to fetch.
	for seeded in [&"exotic", &"exotic", &"relic"]:
		Run.stow(MaterialData.of(MaterialTable.by_id(seeded)))
	if deep:
		# Bound the loop: `stow` can refuse a big part while a smaller fits, so it could spin.
		# Why: docs/why/DevFlags.md#station-shot
		for i in 40:
			if Run.hold_full():
				break
			Run.stow(LootGen.roll_module(3 + (i % 5), &"", true))
		Run.add_credits(900)
	# Four own parts bolted on: a fresh run counts two and the set-bonus chip shows at three.
	# Why: docs/why/DevFlags.md#station-shot
	var want := 4
	for a3 in OS.get_cmdline_user_args():
		if (a3 as String).begins_with("sets="):
			want = int((a3 as String).substr(5))
	var fitted := 0
	for mid2 in DB.modules:
		if fitted >= want:
			break
		var md: ModuleData = DB.modules[mid2]
		if md.manufacturer != here.manufacturer:
			continue
		Run.install_module(md.duplicate(true) as ModuleData)
		fitted += 1
	print("[station] %s berth · %d fitted · set count %d" % [
		DB.manufacturer_name(here.manufacturer), fitted,
		Run.manufacturer_count(here.manufacturer)])

	Run.hp = maxi(1, Run.max_hp() - 12)
	Run.add_dross(3)
	if deep:
		# Forced here, not by raising odds: the Yard's 75% roll is balance, this a debug seed.
		var here2: MapGen.MapNode = Run.node_at()
		here2.stocked = true
		for i in 5:
			here2.shop.append(LootGen.roll_module(5 + i, &"", true))
		here2.shop_hull = LootGen.roll_hull(7)
		print("[station] full: hold %d items, shelf %d, hull on the blocks"
			% [Run.cargo.size(), here2.shop.size()])
	# (docked is at the station: the ship alongside it, as if flown there)
	Router.park_at_station()
	Router.show_station()
	return false


func _salvage() -> bool:
	# The rail breaks only at late-run sizes, by growing the page; bags need a second machine.
	# Why: docs/why/DevFlags.md#salvage-shot
	var many := 8
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			many = clampi(int(a), 1, 24)
	for i in many:
		Run.stow(LootGen.roll_module(2 + (i % 5), &"", true))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("bag="):
			var here2: MapGen.MapNode = Run.node_at()
			here2.danger = 5
			Run.open_bag(here2, 1, clampi(int(a.split("=")[1]), 1, 8))
	Router.show_sector()
	return false


func _fight() -> bool:
	# `fight 10` deals ten: the hand only misbehaves at sizes a normal run rarely reaches.
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			Run.hand_size_override = clampi(int(a), 1, 12)
	# `-- fight foe=hellbender` names the contact. The pool never holds the
	# set pieces, so without this the only way to LOOK at one is to earn it.
	var named: EnemyTemplate = null
	for a in OS.get_cmdline_user_args():
		if a.begins_with("foe=") and not a.contains("foes="):
			named = DB.enemies.get(StringName(a.split("=")[1]))
	if named != null:
		Router.start_combat(named, [], false)
		# `foehp` opens a contact already hurt, to photograph wound bands and burn telegraph.
		for a2 in OS.get_cmdline_user_args():
			if a2.begins_with("foehp="):
				var e0 := Router.combat.enemies[0]
				e0.hp = clampi(int(a2.split("=")[1]), 1, e0.max_hp)
				e0.pick_intent()
				Sig.enemy_changed.emit()
	else:
		var pool := DB.fight_pool(3, false)
		Router.start_combat(DB.enemies[Rng.pick(Rng.foe, pool)])
	return false


## Prints each badge and rolls its ladder 10,000 times to compare against ODDS.
## Why: docs/why/DevFlags.md#check-table
func _print_check_table() -> void:
	for probe in [[&"redline", HullData.Weight.LIGHT], [&"korvan", HullData.Weight.MEDIUM],
			[&"probate", HullData.Weight.HEAVY]]:
		Run.start_new_run(probe[0], int(probe[1]))
		print("\n=== %s ===" % Run.hull.name)
		print("%-22s %-34s %6s %6s %6s %6s" % [
			"event", "badge", "met", "clean", "part", "botch"])
		# Reads `OptionTable`, since the batch-04 port emptied `EventTable`.
		for e in OptionTable.all():
			for o in (e as Dictionary).choices:
				var opt: Dictionary = o
				if not opt.has("check"):
					continue
				var counts := {0: 0, 1: 0, 2: 0, 3: 0}
				for i in 10000:
					counts[int(SkillCheck.roll(opt.check))] += 1
				print("%-22s %-34s %5.1f%% %5.1f%% %5.1f%% %5.1f%%" % [
					str(e.title), SkillCheck.badge(opt.check),
					counts[0] / 100.0, counts[1] / 100.0,
					counts[2] / 100.0, counts[3] / 100.0])

## One run per manufacturer; prints raw gauges so a surprising attribute can be traced.
func _print_attribute_table() -> void:
	# Seven gauges against six labels shifted every column, so thrust 8 read as maneuverability.
	# Why: docs/why/DevFlags.md#attribute-table
	print("chassis            HUL RCT THR MNV THM SEN STL   hp/cap/diss/dodge/init/fuel  mounts  kit deck hand set")
	for manufacturer in DB.STARTABLE:
		for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
			Run.start_new_run(manufacturer, int(w))
			var row := ""
			for a in Run.attributes():
				row += "%3d " % int(a.value)
			# Deck size decides whether a start hand is a draw or the whole deck.
			var deck := 0
			for mod in Run.installed:
				deck += mod.grant_count()
			# Uses `slots_for()`, not raw hull numbers, or the table disagrees with the ship.
			print("%-18s %s  %3d/%3d/%3d/%.2f/%+d/%.1f   %d/%d/%d    %d %4d %4d  %s %d" % [
				Run.hull.name, row, Run.hp, Run.heat_cap(), Run.dissipation(),
				Run.dodge(), Run.initiative(), Run.fuel_factor(),
				Run.slots_for(ModuleData.Slot.WEAPON),
				Run.slots_for(ModuleData.Slot.SYSTEM),
				Run.slots_for(ModuleData.Slot.UTILITY),
				Run.installed.size(), deck, Run.hand_size(),
				DB.short_name(DB.manufacturer_name(manufacturer)),
				Run.manufacturer_count(manufacturer)])
		print("")
	print("\nunbranded salvage frames, at full hull:")
	for h in DB.hull_frames:
		if h.manufacturer != &"":
			continue
		Run.hull = h.duplicate(true) as HullData
		Run.installed.clear()
		Run.hp = Run.max_hp()
		var row2 := ""
		for a in Run.attributes():
			row2 += "%3d " % int(a.value)
		print("%-18s %s" % [h.name, row2])
