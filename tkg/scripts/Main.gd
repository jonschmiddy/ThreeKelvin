extends Control
## Entry point. Builds the theme, the persistent HUD, and hands the content
## area to Router. Everything else is created in code by the screens.

func _ready() -> void:
	# Harnesses get the framed 1920x1080 window; players keep the small borderless one.
	if TestRun.active():
		DisplaySettings.leave_launch_window()
	_wear_cursor()
	# Read first: HeadlessSim and the tests start runs of their own, and the seed replays a bug.
	var argv0 := OS.get_cmdline_user_args()
	for i in argv0.size():
		if argv0[i] == "seed" and i + 1 < argv0.size():
			Rng.forced = int(argv0[i + 1])
			print("Seeded run: %d" % Rng.forced)

	# Balance sim runs through the normal boot so the autoloads exist, then quits
	# before any UI is built:  godot --headless --path . -- sim runs=200
	if "sim" in OS.get_cmdline_user_args():
		HeadlessSim.new().run_sim()
		get_tree().quit()
		return

	# Save/load round-trip test, same shape as the balance sim above it:
	#   godot --headless --path . -- savetest
	if "savetest" in OS.get_cmdline_user_args():
		var t: RefCounted = load("res://scripts/sim/SaveTest.gd").new()
		t.run()
		t.run_history_test()
		t.run_version_test()
		get_tree().quit()
		return

	# Silent-failure check: a melt price creeping above ask would quietly pay all run.
	if "market" in OS.get_cmdline_user_args():
		load("res://scripts/sim/MarketTest.gd").new().run()
		get_tree().quit()
		return

	# Attribute tuning reads columns, not one ship a screen, or phantom spreads look real.
	# Why: docs/why/Main.md#test-flags
	if "attrs" in OS.get_cmdline_user_args():
		_print_attribute_table()
		get_tree().quit()
		return

	# Skill checks fail silently both ways, so this prints real costs and proves the odds.
	# Why: docs/why/Main.md#test-flags
	if "checks" in OS.get_cmdline_user_args():
		_print_check_table()
		get_tree().quit()
		return

	# Needs a window: SpaceBackdrop is renderer-drawn, so headless viewports come back blank.
	# Why: docs/why/Main.md#test-flags
	if "sky" in OS.get_cmdline_user_args():
		_sky_test = load("res://scripts/sim/SkyTest.gd").new()
		_sky_test.run(get_tree())
		return

	# Run after touching `Rng` or any generator: broken determinism fails silently.

	# Covers the market invariant under standing, which `-- market` cannot reach.
	if "contracttest" in OS.get_cmdline_user_args():
		load("res://scripts/sim/ContractTest.gd").new().run()
		get_tree().quit()
		return

	# What every repair card is worth at full, half and three hull —
	# RUN THIS AFTER TOUCHING heal OR heal_scale ON ANYTHING
	if "repairs" in OS.get_cmdline_user_args():
		load("res://scripts/sim/RepairSheet.gd").new().run()
		get_tree().quit()
		return

	# Which picture every card draws, and whether one of them has become a
	# catch-all:  godot --headless --path . -- glyphs
	if "glyphs" in OS.get_cmdline_user_args():
		load("res://scripts/sim/GlyphSheet.gd").new().run()
		get_tree().quit()
		return

	if "rngtest" in OS.get_cmdline_user_args():
		load("res://scripts/sim/RngTest.gd").new().run()
		get_tree().quit()
		return

	# Held in a member: a RefCounted held only by a local is freed when `_ready` returns.
	# Why: docs/why/Main.md#test-flags
	if "nettest" in OS.get_cmdline_user_args():
		_net_test = load("res://scripts/sim/NetTest.gd").new()
		_net_test.run(get_tree())
		return

	# Resolves every authored option through LOCAL's event band, the one place a choice is taken.
	if "localeventtest" in OS.get_cmdline_user_args():
		_co_fight = load("res://scripts/sim/LocalEventTest.gd").new()
		_co_fight.run(get_tree())
		return

	# The bot returns before the UI and registers Router as its own holder, like a human.
	# Why: docs/why/Main.md#bot-flag
	if "bot" in OS.get_cmdline_user_args():
		_bot = load("res://scripts/net/BotPilot.gd").new()
		_bot.run(get_tree())
		return

	# The prompt reads fiction live; force the palette and send no init image or alpha drops.
	# Why: docs/why/Main.md#art-prompt
	if "artprompt" in OS.get_cmdline_user_args():
		_wear_sheet = load("res://scripts/sim/ArtPrompt.gd").new()
		_wear_sheet.run(get_tree())
		return

	# Run after touching HullFit: fittings go on before damage so a bolt-on can be shot off.
	# Why: docs/why/Main.md#test-flags
	if "fit" in OS.get_cmdline_user_args():
		_wear_sheet = load("res://scripts/sim/FitSheet.gd").new()
		_wear_sheet.run(get_tree())
		return

	# Run after touching HullWear's organic ops: the substance split keeps whales unwelded.
	if "bestiary" in OS.get_cmdline_user_args():
		_wear_sheet = load("res://scripts/sim/BestiarySheet.gd").new()
		_wear_sheet.run(get_tree())
		return

	# Wear must introduce no new colours; any count but 0 is a bug.
	if "wear" in OS.get_cmdline_user_args():
		_wear_sheet = load("res://scripts/sim/WearSheet.gd").new()
		_wear_sheet.run(get_tree())
		return

	# Mounts are measured per sprite, so another hull's lines would draw guns in mid-air silently.
	# Why: docs/why/Main.md#test-flags
	if "content" in OS.get_cmdline_user_args():
		load("res://scripts/sim/ContentCount.gd").new().run()
		get_tree().quit()
		return
	# Each flag asks one question: rarity values, map traversal, option rules, system layout.
	# Why: docs/why/Main.md#test-flags
	if "systemtest" in OS.get_cmdline_user_args():
		load("res://scripts/sim/SystemTest.gd").new().run()
		get_tree().quit()
		return
	# Checks the sector weather schedule: one at a time, rare showpieces, none if reduced.
	if "weathertest" in OS.get_cmdline_user_args():
		load("res://scripts/sim/WeatherTest.gd").new().run()
		get_tree().quit()
		return
	if "optiontest" in OS.get_cmdline_user_args():
		load("res://scripts/sim/OptionTest.gd").new().run()
		get_tree().quit()
		return
	if "maptest" in OS.get_cmdline_user_args():
		load("res://scripts/sim/MapTest.gd").new().run()
		get_tree().quit()
		return
	if "rarity" in OS.get_cmdline_user_args():
		load("res://scripts/sim/RaritySheet.gd").new().run()
		get_tree().quit()
		return
	# Every catalogue row becomes an item a real hold accepts:
	#   godot --headless --path . -- materialtest
	if "materialtest" in OS.get_cmdline_user_args():
		load("res://scripts/sim/MaterialTest.gd").new().run()
		get_tree().quit()
		return

	if "holdtest" in OS.get_cmdline_user_args():
		load("res://scripts/sim/HoldTest.gd").new().run()
		get_tree().quit()
		return

	# Probes for start frames and reactor decks, the chart's known-only view, part gauges.
	# Why: docs/why/Main.md#test-flags
	if "attrtest" in OS.get_cmdline_user_args():
		load("res://scripts/sim/AttrTest.gd").new().run()
		get_tree().quit()
		return

	if "chartfilter" in OS.get_cmdline_user_args():
		load("res://scripts/sim/ChartFilter.gd").new().run()
		get_tree().quit()
		return

	if "reactor" in OS.get_cmdline_user_args():
		load("res://scripts/sim/ReactorSheet.gd").new().run()
		get_tree().quit()
		return

	if "mounts" in OS.get_cmdline_user_args():
		load("res://scripts/sim/MountCheck.gd").new().run()
		get_tree().quit()
		return

	# Every .gd in the project, loaded:  godot --headless --path . -- parseall
	# `--check-only` does not reach a file nothing instantiates. See ParseAll.
	if "parseall" in OS.get_cmdline_user_args():
		load("res://scripts/sim/ParseAll.gd").new().run()
		get_tree().quit()
		return

	if "artcheck" in OS.get_cmdline_user_args():
		load("res://scripts/sim/ArtCheck.gd").new().run()
		get_tree().quit()
		return

	if "shipsheet" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/ConvoyTest.gd").new()
		_convoy_test.run(get_tree())
		return

	DisplaySettings.load_and_apply()
	DevMode.load_settings()
	# Read before the theme is built, the only moment it can be read.
	for a_btn in OS.get_cmdline_user_args():
		if (a_btn as String).begins_with("btn="):
			UITheme.button_style = clampi(int((a_btn as String).substr(4)), 0, 5) as UITheme.ButtonStyle
	theme = UITheme.build()

	var margin := Widgets.pad(null, 8, 7)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	margin.add_child(root)

	var hud := HudBar.new()
	root.add_child(hud)

	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	# Added to the window, not `root`, so it cannot take a pixel from the HUD row.
	# Why: docs/why/Main.md#frame-counter
	add_child(FpsMeter.new())
	# THE HULL FAILING (`LowHull`): a faint red at the edges and the odd glitch
	# in the words, on a layer of its own over the game and under the menu.
	add_child(LowHull.new())
	# A LINE FROM THE PARTY that every screen shows until clicked: the galaxies
	# of two machines in one party do not match (`NetSession._galaxy_differs_here`).
	add_child(PartyNotice.new())

	Router.register(content, hud)
	# Kicked on the landing, not the resolution, or the shake ended ten frames before the shot.
	# Why: docs/why/Main.md#hit-kick
	Sig.hit_landed.connect(func(amount: int, to_player: bool, _who: int, _ab: int) -> void:
		if to_player and amount > 0:
			_kick(amount))

	# Added after `Router.register`: before it every swap threw while the verdict said PASS.
	# Why: docs/why/Main.md#co-fight-test
	if "cofight" in OS.get_cmdline_user_args():
		_co_fight = load("res://scripts/sim/CoFightTest.gd").new()
		_co_fight.run(get_tree())
		return

	# Runs after `Router.register`, unlike cofight, since LOCAL and the SECTOR map are checked.
	# Why: docs/why/Main.md#co-fight-test
	if "cojoin" in OS.get_cmdline_user_args():
		_co_fight = load("res://scripts/sim/CoJoinTest.gd").new()
		_co_fight.run(get_tree())
		return

	# Real galaxy data for the sensor-ladder study:
	#   godot --headless --path . -- sensordump
	if "sensordump" in OS.get_cmdline_user_args():
		_sensor_dump = load("res://scripts/sim/SensorDump.gd").new()
		_sensor_dump.run(get_tree())
		return

	# What the chart looks like now that sight is live:
	#   godot --path . -- fogshot
	if "fogshot" in OS.get_cmdline_user_args():
		_fog_shot = load("res://scripts/sim/FogShot.gd").new()
		_fog_shot.run(get_tree())
		return

	# Does the ship move when its loadout changes? It must not:
	#   godot --headless --path . -- shipdrift
	if "shipdrift" in OS.get_cmdline_user_args():
		_ship_drift = load("res://scripts/sim/ShipDriftTest.gd").new()
		_ship_drift.run(get_tree())
		return

	# Photographs the chart at a ladder of zooms to see the boundary.
	if "zoomshot" in OS.get_cmdline_user_args():
		_zoom_shot = load("res://scripts/sim/ZoomShot.gd").new()
		_zoom_shot.run(get_tree())
		return

	# Runs after `Router.register`: it needs the UI it measures to exist.
	if "chartbench" in OS.get_cmdline_user_args():
		_chart_bench = load("res://scripts/sim/ChartBench.gd").new()
		_chart_bench.run(get_tree())
		return


	# Dev flags skip the launcher; `ship` and `salvage` need a run or the screen crashes.
	# Why: docs/why/Main.md#boot-destination
	var argv := OS.get_cmdline_user_args()
	var skip_launcher := "nolauncher" in argv or "cards" in argv or "fight" in argv \
		or "charttest" in argv or "ship" in argv or "station" in argv \
		or "salvage" in argv or "party" in argv \
		or "quest" in argv or "parts" in argv or "gameover" in argv
	# Own branch, not in skip_launcher: a lobby must not start a run before the seed is agreed.
	if "lobby" in argv:
		Router.show_lobby()
	elif "resume" in argv and SaveGame.has_save():
		Router.continue_run()
	elif skip_launcher:
		Router.new_run()
	else:
		Router.show_launcher()

	# Flags match bare words anywhere, so `chartshot quest` once opened `quest` instead.
	# Why: docs/why/Main.md#dev-shortcuts
	if "questrun" in OS.get_cmdline_user_args():
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
		return

	# A shot's argument must not match the mode: `shipshot heavy cargo` opened a game.
	# Why: docs/why/Main.md#dev-shortcuts
	if "cargo" in OS.get_cmdline_user_args() \
			and not "shipshot" in OS.get_cmdline_user_args():
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
		return

	# Quest rings sit on a screen unreachable from a station: contracts faked, chart real.
	# Why: docs/why/Main.md#dev-shortcuts
	if "quest" in OS.get_cmdline_user_args():
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

	if "party" in OS.get_cmdline_user_args():
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

	# The arrival screen, with its option list:  godot --path . -- sectorshot
	if "fitwords" in OS.get_cmdline_user_args():
		load("res://scripts/sim/FitWords.gd").new().run()
		get_tree().quit()
		return

	if "namefit" in OS.get_cmdline_user_args():
		load("res://scripts/sim/NameFit.gd").new().run()
		get_tree().quit()
		return

	if "sighttest" in OS.get_cmdline_user_args():
		load("res://scripts/sim/SightTest.gd").new().run()
		get_tree().quit()
		return

	if "cursorsheet" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/CursorSheet.gd").new()
		_convoy_test.run(get_tree())
		return

	# The jump sequence, frame by frame. NOT `jumpshot`: `Router.animating()` is
	# false for anything ending in "shot" and the tweens are the whole subject.
	if "jumpcine" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/JumpCine.gd").new()
		_convoy_test.run(get_tree())
		return

	if "sectorshot" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/SectorShot.gd").new()
		_convoy_test.run(get_tree())
		return

	if "chartshot" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/ChartShot.gd").new()
		_convoy_test.run(get_tree())
		return

	# Exhaust runs headless: a plume that fails to load is invisible, not loud.
	for a_sh in OS.get_cmdline_user_args():
		if (a_sh as String).begins_with("sheet="):
			add_child(load("res://scripts/sim/%s.gd" % (a_sh as String).substr(6)).new())
			return
	# Every kind of world, as the GPU paints it, on one sheet:  -- planetsheet=<png>
	# Needs a window. Same seeds and light as the approved gallery page.
	for a_ps in OS.get_cmdline_user_args():
		if (a_ps as String).begins_with("planetsheet="):
			add_child(load("res://scripts/sim/PlanetSheet.gd").new())
			return
	# Four real systems as JSON, for laying out the system map:  -- systemdump=<path>
	for a_sd in OS.get_cmdline_user_args():
		if (a_sd as String).begins_with("systemdump="):
			_convoy_test = load("res://scripts/sim/SystemDump.gd").new()
			_convoy_test.run(get_tree())
			return

	if "encdump" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/EncDump.gd").new()
		_convoy_test.run(get_tree())
		return

	if "exhaust" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/ExhaustCheck.gd").new()
		_convoy_test.run(get_tree())
		return

	# Artdemo runs after boot: `show_ship` needs the Router to hold a content node first.
	# Why: docs/why/Main.md#dev-shortcuts
	if "artdemo" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/ArtDemo.gd").new()
		_convoy_test.run(get_tree())
		return

	if "shipshot" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/ShipShot.gd").new()
		_convoy_test.run(get_tree())
		return

	# Beside stationshot: needs a window, asserts nothing, lets an art call be seen, not argued.
	if "cardshot" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/CardShot.gd").new()
		_convoy_test.run(get_tree())
		return

	# Needs a window and a Router content node, which the headless checks run before.
	if "stationshot" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/StationShot.gd").new()
		_convoy_test.run(get_tree())
		return

	# Walks the Router, so it must run after `register` gives it a content node.
	if "skyshot" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/SkyShot.gd").new()
		_convoy_test.run(get_tree())
		return

	if "placesheet" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/PlaceSheet.gd").new()
		_convoy_test.run(get_tree())
		return

	# Windowed for a different reason than the shots: `Audio` switches itself
	# off headless, so the subject of this test only exists with a window.
	if "audiotest" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/AudioTest.gd").new()
		_convoy_test.run(get_tree())
		return

	if "convoy" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/ConvoyTest.gd").new()
		_convoy_test.run(get_tree())
		return
	# The salvage rail is driven through the real screen and a jump, which unit asserts miss.
	# Why: docs/why/Main.md#test-flags
	if "transfertest" in OS.get_cmdline_user_args():
		_stow_test = load("res://scripts/sim/TransferTest.gd").new()
		_stow_test.run(get_tree())
		return

	# The cutaway's moves, through its own handlers (`CutawayView`):
	#   godot --headless --path . -- cutawaytest
	if "cutawaytest" in OS.get_cmdline_user_args():
		_stow_test = load("res://scripts/sim/CutawayTest.gd").new()
		_stow_test.run(get_tree())
		return

	# Every encounter's subject resolves to art and its staging fits LOCAL:
	#   godot --headless --path . -- subjecttest
	if "subjecttest" in OS.get_cmdline_user_args():
		_stow_test = load("res://scripts/sim/SubjectTest.gd").new()
		_stow_test.run(get_tree())
		return

	if "stowtest" in OS.get_cmdline_user_args():
		_stow_test = load("res://scripts/sim/StowTest.gd").new()
		_stow_test.run(get_tree())
		return

	# Leaving a run from the pause menu, and whether the screen left behind draws
	# once more with no ship:  godot --headless --path . -- quittest
	if "quittest" in OS.get_cmdline_user_args():
		_stow_test = load("res://scripts/sim/QuitTest.gd").new()
		_stow_test.run(get_tree())
		return

	# First-run hints: each fires once at its trigger, never again, and SHOW
	# HINTS AGAIN brings them back:  godot --headless --path . -- hinttest
	if "hinttest" in OS.get_cmdline_user_args():
		_stow_test = load("res://scripts/sim/HintTest.gd").new()
		_stow_test.run(get_tree())
		return

	# The sector map's worlds keep up with a pan (no picture trailing its own
	# ring):  godot --headless --path . -- maplagtest
	if "maplagtest" in OS.get_cmdline_user_args():
		_stow_test = load("res://scripts/sim/MapLagTest.gd").new()
		_stow_test.run(get_tree())
		return

	# Key bindings, rebound through Settings and pressed on real screens, in a
	# settings file of its own:  godot --headless --path . -- bindtest
	if "bindtest" in OS.get_cmdline_user_args():
		_stow_test = load("res://scripts/sim/BindTest.gd").new()
		_stow_test.run(get_tree())
		return

	# The escape menu after reduced motion and skip jump change under it, with
	# the animations on:  godot --headless --path . -- menutest
	if "menutest" in OS.get_cmdline_user_args():
		_stow_test = load("res://scripts/sim/MenuTest.gd").new()
		_stow_test.run(get_tree())
		return

	# Developer mode in the editor and as released, from one settings file:
	#   godot --headless --path . -- devtest [asrelease]
	if "devtest" in OS.get_cmdline_user_args():
		_stow_test = load("res://scripts/sim/DevTest.gd").new()
		_stow_test.run(get_tree())
		return

	# Not headless: it drives Viewport's drag machine. Held in a member so the coroutine lives.
	if "fittest" in OS.get_cmdline_user_args():
		_fit_test = load("res://scripts/sim/FitTest.gd").new()
		_fit_test.run(get_tree())
		return

	# Needs a real window and a member holding the coroutine alive, like fittest.
	if "warptest" in OS.get_cmdline_user_args():
		_fit_test = load("res://scripts/sim/WarpTest.gd").new()
		_fit_test.run(get_tree())
		return

	if "charttest" in OS.get_cmdline_user_args():
		# Held in a member: an unreferenced RefCounted is freed mid-await and the test dies.
		# Why: docs/why/Main.md#coroutine-tests
		_chart_test = load("res://scripts/sim/ChartTest.gd").new()
		_chart_test.run(get_tree())
	if "cards" in OS.get_cmdline_user_args():
		Router.show_cards()
	# Keep it an elif in the chain: a separate if re-parents the elif and tests the wrong flag.
	# Why: docs/why/Main.md#dev-shortcuts
	elif "parts" in OS.get_cmdline_user_args():
		Router.show_modules()
	elif "ship" in OS.get_cmdline_user_args():
		# Inside the branch: in front of the chain the elif binds to it and other dev flags die.
		# Why: docs/why/Main.md#dev-shortcuts
		var flags := OS.get_cmdline_user_args()
		if "light" in flags or "heavy" in flags:
			var w: HullData.Weight = HullData.Weight.HEAVY
			if "light" in flags:
				w = HullData.Weight.LIGHT
			Run.fit_chassis(&"korvan", w, 0)
		# Refit is the screen most worth looking at and was the most tedious to reach.
		# The hold is seeded because the screen is a workbench and an empty hold tests half.
		# Why: docs/why/Main.md#ship-shot
		for i in 8:
			Run.stow(LootGen.roll_module(2 + i, &"", true))
		# A module id as an argument is built and installed, duplicated to protect the entry.
		# Why: docs/why/Main.md#ship-shot
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
		# Why: docs/why/Main.md#ship-shot
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
	elif "station" in OS.get_cmdline_user_args():
		# Goes straight to the dock, and gives the merge gate a screen that constructs the station.
		# Why: docs/why/Main.md#station-shot
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
		# Why: docs/why/Main.md#station-shot
		var deep := "full" in OS.get_cmdline_user_args()
		for i in 3:
			Run.stow(LootGen.roll_module(4 + i, &"", true))
		# Straight into the hold: this debug seed puts you in a state, not a pickup to fetch.
		for seeded in [&"exotic", &"exotic", &"relic"]:
			Run.stow(MaterialData.of(MaterialTable.by_id(seeded)))
		if deep:
			# Bound the loop: `stow` can refuse a big part while a smaller fits, so it could spin.
			# Why: docs/why/Main.md#station-shot
			for i in 40:
				if Run.hold_full():
					break
				Run.stow(LootGen.roll_module(3 + (i % 5), &"", true))
			Run.add_credits(900)
		# Four own parts bolted on: a fresh run counts two and the set-bonus chip shows at three.
		# Why: docs/why/Main.md#station-shot
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
	elif "salvage" in OS.get_cmdline_user_args():
		# The rail breaks only at late-run sizes, by growing the page; bags need a second machine.
		# Why: docs/why/Main.md#salvage-shot
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
	elif "fight" in OS.get_cmdline_user_args():
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

	# `-- shot` is generic: it photographs whatever the flags put up, so no case per screen.
	# Why: docs/why/Main.md#shot-flags
	if "menu" in OS.get_cmdline_user_args():
		toggle_menu()
	# Display options for one run, for shots; they are not saved.
	for a0 in OS.get_cmdline_user_args():
		if (a0 as String).begins_with("look="):
			var want := (a0 as String).substr(5).to_upper()
			var names := ["FLAT", "LINES", "CRT", "CRT+", "ARCADE"]
			DisplaySettings.screen_look = maxi(names.find(want), 0) as DisplaySettings.Look
		if (a0 as String).begins_with("phase="):
			TransferView.Arrow.freeze = float((a0 as String).substr(6))
		# `-- off=0.5` freezes the set halfway through switching off, for
		# photographing a moment nobody can pause in play.
		if (a0 as String).begins_with("off="):
			if GameShell.instance != null:
				GameShell.instance.hold_off(float((a0 as String).substr(4)))
		# `-- ptr=960,540` pretends the pointer is there, so a shot tool can
		# photograph the nudge at a chosen place on the glass.
		if (a0 as String).begins_with("ptr="):
			var xy := (a0 as String).substr(4).split(",")
			if xy.size() == 2 and GameShell.instance != null:
				GameShell.instance._pointer = Vector2(float(xy[0]), float(xy[1]))
		if (a0 as String).begins_with("vig="):
			GameShell._vig_override = clampf(float((a0 as String).substr(4)), 0.0, 1.0)
		if (a0 as String).begins_with("edge="):
			GameShell._edge_style = clampi(int((a0 as String).substr(5)), 0, 7)
		if (a0 as String).begins_with("cvd="):
			DisplaySettings.colour_help = clampi(int((a0 as String).substr(4)), 0, 3)
	GameShell.refresh()

	# Checks the keyboard still reaches the game now that it lives in a SubViewport.
	if "keytest" in OS.get_cmdline_user_args():
		_key_test.call_deferred()

	# `-- gameover`: the run-ended panel, for looking at it without dying.
	if "gameover" in OS.get_cmdline_user_args():
		Run.death_reason = "Hull integrity lost. The cold gets in fast."
		Router.show_game_over.call_deferred()

	# A wreck with one COMMON module, opened, to hear the rarity ladder's quietest rung.
	if "salvage" in OS.get_cmdline_user_args():
		_open_test_salvage.call_deferred()

	# `-- settings`, the same for the Settings drawer; `-- confirm` for the
	# escape menu's "abandon this run?" step.
	if "settings" in OS.get_cmdline_user_args():
		_open_settings()
	# Opens Settings at CONTROLS; `bindshot` poses a row in a state worth photographing.
	for a_k in OS.get_cmdline_user_args():
		if a_k == "settings=controls" or (a_k as String).begins_with("bindshot="):
			_open_settings()
			_show_keys.call_deferred()
			break
		# `-- settings=motion`: scrolled to MOTION, for a still of it; `settings=look`
		# to THE LOOK (GRAPHICS, and with `gfxprobe` the machine's pick beside it)
		if a_k == "settings=motion" or a_k == "settings=look":
			_open_settings()
			_show_section.call_deferred(StringName((a_k as String).substr(9)))
			break
	if "confirm" in OS.get_cmdline_user_args() and _menu != null:
		_menu.confirm(true)
	if _wants_shot():
		_shoot()

## `-- shot` or `-- shot=path`. Both spellings, because a flag that silently
## does nothing when you name a file is worse than no flag.
func _wants_shot() -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "shot" or a.begins_with("shot="):
			return true
	return false

## Wait several frames: containers size children a frame after adding, so frame zero lies.
## Why: docs/why/Main.md#shot-timing
func _shoot() -> void:
	# Resize the window to the base viewport first, or the PNG silently crops the interface.
	# Why: docs/why/Main.md#shot-timing
	var base := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 540)))
	get_window().size = base
	for i in 8:
		await get_tree().process_frame
	# Shoot the measured pick, not the hint: the title sky needs about a hundred frames.
	if GpuProbe.asked() != "":
		var until := Time.get_ticks_msec() + 30000
		while DisplaySettings.graphics_by == DisplaySettings.GFX_NOBODY and Time.get_ticks_msec() < until:
			await get_tree().process_frame
		for i in 8:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var out := "user://shot.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="):
			out = a.split("=")[1]
	img.save_png(out)
	# Print both texture and layout sizes: a PNG can be narrower than the interface in it.
	# Why: docs/why/Main.md#shot-timing
	print("[shot] %s  texture %dx%d  layout %dx%d" % [
		ProjectSettings.globalize_path(out), img.get_width(), img.get_height(),
		int(size.x), int(size.y)])
	get_tree().quit()

## Kept alive for the duration of `-- charttest`; see the call site.
var _chart_test: RefCounted = null
## Held for the same reason the others are: it awaits, and a RefCounted only a
## local holds is freed the moment the calling statement ends.
var _fit_test
var _stow_test: RefCounted = null
## And for `-- sky`, for the same reason: it awaits.
var _sky_test: RefCounted
var _chart_bench: RefCounted = null
var _sensor_dump: RefCounted = null
var _fog_shot: RefCounted = null
var _ship_drift: RefCounted = null
var _zoom_shot: RefCounted = null
var _net_test: RefCounted = null
## And `-- cofight`, which awaits a whole second Godot process.
var _co_fight: RefCounted = null
## The party's ninth seat. Held for the same reason the tests above are: it
## runs across frames, and a RefCounted only a local holds is freed on return.
var _bot: RefCounted = null
var _wear_sheet: RefCounted = null
var _convoy_test: RefCounted = null

## Prints each badge and rolls its ladder 10,000 times to compare against ODDS.
## Why: docs/why/Main.md#check-table
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
	# Why: docs/why/Main.md#attribute-table
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

var _menu: PauseMenu = null

## Menu has its own layer so its blur sees the whole game, including `top_level` controls.
## A CanvasLayer is not a Control, so hand it `theme` by hand or it uses the default font.
## Why: docs/why/Main.md#overlay-layer
var _overlay: CanvasLayer = null

func _overlay_layer() -> CanvasLayer:
	if _overlay == null:
		_overlay = CanvasLayer.new()
		_overlay.layer = 10
		add_child(_overlay)
	return _overlay
var _settings: SettingsMenu = null

## Tab is caught in `_input`: the GUI eats it for focus walking, which this game never uses.
## The cursor is four swapped frames: a painted Control cursor would lag the mouse.
## Why: docs/why/Main.md#input-and-cursor
const CURSOR_FRAMES := 4
## The pixel you are pointing with: the middle, for a shape that closes around
## it rather than an arrow that points from a corner.
const CURSOR_HOT := Vector2(16, 16)
## Frames per second of travel. Nine hundredths of a second end to end, which is
## fast enough to feel like a response and slow enough to see happen.
const CURSOR_SPEED := 34.0
## Every shape the reticle stands in for: the two of hovering, and the four a
## drag can ask for.
const CURSOR_SHAPES := [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND,
	Input.CURSOR_FORBIDDEN, Input.CURSOR_CAN_DROP, Input.CURSOR_DRAG, Input.CURSOR_MOVE]

var _cursor_tex: Array[ImageTexture] = []
## Where the animation currently is, 0 open to 3 closed. Fractional between.
var _cursor_at: float = 0.0
## Which frame the operating system is actually holding, to avoid handing it the
## same image sixty times a second.
var _cursor_shown: int = -1


func _wear_cursor() -> void:
	_cursor_tex.clear()
	for i in CURSOR_FRAMES:
		# Load via the imported texture: an export has no loose PNG, so friends got the arrow.
		# Why: docs/why/Main.md#cursor
		var tex := load("res://art/cursors/reticle_%d_2x.png" % i) as Texture2D
		if tex == null:
			return
		_cursor_tex.append(ImageTexture.create_from_image(tex.get_image()))
	_show_cursor(0)


func _show_cursor(f: int) -> void:
	if f == _cursor_shown or f < 0 or f >= _cursor_tex.size():
		return
	_cursor_shown = f
	# Both shapes and every drag shape wear the same frame, so Godot's swaps stay invisible.
	# Why: docs/why/Main.md#cursor
	for shape in CURSOR_SHAPES:
		Input.set_custom_mouse_cursor(_cursor_tex[f],
			shape as Input.CursorShape, CURSOR_HOT)


## Reads `mouse_default_cursor_shape`, the fact `Widgets._btn` declares and Godot would read.
## Why: docs/why/Main.md#cursor
func _cursor_wants_shut() -> bool:
	# A held button is a grip: one rule covers drags and holds, and keeps a click shut.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true
	var h := get_viewport().gui_get_hovered_control()
	return h != null and h.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND


func _process(delta: float) -> void:
	_shake_step(delta)
	if _cursor_tex.is_empty():
		return
	var want := float(CURSOR_FRAMES - 1) if _cursor_wants_shut() else 0.0
	_cursor_at = move_toward(_cursor_at, want, delta * CURSOR_SPEED)
	_show_cursor(int(round(_cursor_at)))


## The viewport moves, in whole pixels only, so a half-pixel never resamples every sprite.
## Why: docs/why/Main.md#screen-shake
const SHAKE_S := 0.22
const SHAKE_HZ := 34.0
const SHAKE_MAX := 4.0
var _shake: float = 0.0            ## seconds left
var _shake_px: float = 0.0         ## amplitude this kick started at

func _key_test() -> void:
	for _i in 20:
		await get_tree().process_frame
	var was := Router.current
	_press(KEY_ESCAPE)
	await get_tree().process_frame
	print("[keytest] ESC opened the menu: %s" % [_menu != null])
	_press(KEY_ESCAPE)
	await get_tree().process_frame
	print("[keytest] ESC closed it again: %s" % [_menu == null])
	_press(KEY_TAB)
	await get_tree().process_frame
	await get_tree().process_frame
	print("[keytest] TAB changed the page: %s (%s -> %s)" % [
		Router.current != was, was, Router.current])
	get_tree().quit()

func _press(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)

## Hit for `amount`: a nick is one pixel, a big hit is four.
func _kick(amount: int) -> void:
	if not DisplaySettings.screen_shake or not Router.animating():
		return
	_shake_px = clampf(1.0 + float(amount) / 6.0, 1.0, SHAKE_MAX)
	_shake = SHAKE_S

func _shake_step(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - delta)
	var amp := _shake_px * (_shake / SHAKE_S)
	var t := (SHAKE_S - _shake) * SHAKE_HZ * TAU
	var at := Vector2(roundf(sin(t) * amp), roundf(cos(t * 0.7) * amp * 0.6))
	if _shake <= 0.0:
		at = Vector2.ZERO
	var tr := get_viewport().canvas_transform
	tr.origin = at
	get_viewport().canvas_transform = tr


func _input(event: InputEvent) -> void:
	# Snap shut, ease open: a press is an impact. The click is watched but not handled.
	# Why: docs/why/Main.md#cursor
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_cursor_at = float(CURSOR_FRAMES - 1)
		_show_cursor(CURSOR_FRAMES - 1)
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	# A bare Tab is still eaten for focus; a letter binding yields to a focused text field.
	if not k.is_action_pressed(&"next_screen"):
		if k.keycode == KEY_TAB and Keys.clashes(&"next_screen", KEY_TAB).is_empty():
			get_viewport().set_input_as_handled()
		return
	if k.keycode != KEY_TAB and get_viewport().gui_get_focus_owner() is LineEdit:
		return
	get_viewport().set_input_as_handled()
	# Only inside a run: Tab on hull pick had no ship, and the menu freezes the page behind.
	if Run.hull == null or Router.is_front_door(Router.current) or _menu != null:
		return
	# Not off the move: Tab over the yard swapped the station out and lost the pad (Jon, Oct 23).
	# Why: docs/why/Main.md#tab-round
	if Router.move_open():
		return
	# Not off the end of a run: Tab would reopen LOCAL in a run that is already over.
	if Router.final_loot or Router.current is GameOverScreen:
		return
	# The round is LOCAL, SECTOR, STARCHART; docked, the berth takes LOCAL's place (Jon, Oct 27).
	# A move under way steps from its target, so a quick double Tab is two steps.
	# Why: docs/why/Main.md#tab-round
	var at := ZoomLadder.lit_rank() if ZoomLadder.busy() else -1
	if at == ZoomLadder.LOCAL or at == ZoomLadder.STATION:
		Router.show_system()
	elif at == ZoomLadder.MAP:
		Router.show_starchart()
	elif at == ZoomLadder.CHART:
		if Router.docked:
			Router.show_station()
		else:
			Router.show_local()
	elif Router.current is SectorScreen or Router.current is StationScreen:
		Router.show_system()
	elif Router.current is SystemMapScreen:
		Router.show_starchart()
	elif Router.docked:
		Router.show_station()
	else:
		Router.show_local()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE:
		if _menu != null and _menu.in_settings():
			_menu.hide_settings()
		elif Router.final_loot and _menu == null:
			# Escape is DONE here, as on any popup: the menu would offer ABANDON on a won run.
			Router.finish_core_loot()
		elif Router.current is LauncherScreen:
			# Nothing to pause: the launcher IS the menu. Its Settings drawer is
			# the one thing Esc can close there.
			(Router.current as LauncherScreen).close_settings()
		elif Router.current is ChassisSelect and _menu == null:
			# Before the run: no escape menu, whose ABANDON would record a run
			# that never launched. The deck's popup, then the title.
			(Router.current as ChassisSelect).escape()
		else:
			toggle_menu()
	elif k.is_action_pressed(&"fullscreen"):
		# A binding (`Keys`), F11 out of the box. Escape above is not: it is
		# the way back from everything and is never moved.
		DisplaySettings.toggle_fullscreen()

## Silent until a sound is picked, rather than warning on every Esc.
func _open_test_salvage() -> void:
	var sector := Router.current as SectorScreen
	var n: MapGen.MapNode = Run.node_at()
	if sector == null or n == null:
		return
	var wreck := Run.new_wreck(n, DB.enemies[&"cutter"])
	var want: Array = [ModuleData.Rarity.COMMON, ModuleData.Rarity.RARE,
		ModuleData.Rarity.EPIC, ModuleData.Rarity.LEGENDARY]
	for r in want:
		for i in 400:
			# Commons drop shallower than tier 3 only (`LootGen.NO_COMMON_TIER`).
			var m := LootGen.roll_module(1 if r == ModuleData.Rarity.COMMON else 5)
			if m != null and m.rarity == r:
				wreck.items.append(m)
				break
	# EXOTIC and ARTIFACT come off the material table, which is where those
	# tiers actually live.
	for tier: StringName in [&"exotic", &"artifact"]:
		for row in MaterialTable.all():
			if StringName((row as Dictionary).get("tier", &"")) == tier:
				wreck.items.append(MaterialData.of(row))
				break
	wreck.items.append(CreditChit.of(120))
	print("[salvage] %s: %s" % [wreck.label,
		", ".join(wreck.items.map(func(m: HoldItem) -> String: return m.name))])
	sector._open_jetsam(wreck, "SALVAGE")

func _menu_sound(id: StringName) -> void:
	if ResourceLoader.exists(Audio.SFX_PATH % id):
		Audio.play(id, 0.03, 120)

## `animate` false when leaving the run, so the drawer does not slide over the title screen.
func toggle_menu(animate: bool = true) -> void:
	if _menu != null:
		if animate:
			_menu.close()
			_menu_sound(&"menu_close")
		else:
			_menu.queue_free()
		_menu = null
		return
	_menu_sound(&"menu_open")
	_menu = PauseMenu.new()
	_menu.theme = theme
	_overlay_layer().add_child(_menu)
	_menu.setup()
	_menu.resume_requested.connect(func() -> void: toggle_menu())
	# Abandon is recorded now: the run is over at the press, and quitting would lose it.
	# Why: docs/why/Main.md#abandon-and-quit
	_menu.quit_requested.connect(func() -> void:
		toggle_menu(false)
		# Skip if the run already ended, as `Router.new_run` does, or ABANDONED follows DIED.
		if not Run.dead and not Run.won:
			RunHistory.record(RunHistory.Outcome.ABANDONED, "Abandoned mid-run.")
		SaveGame.clear()
		# No hull is the boot state the title expects, and stops `new_run()` recording this twice.
		Run.hull = null
		# Out of a shared fight too, now: left for the next run to drop, it kept
		# a ghost in the party's crew until then (review, Nov 5).
		Router.drop_combat()
		Router.show_launcher())
	# Save and quit skips mid-combat: combat is outside the save and would bank spent hull.
	# Why: docs/why/Main.md#abandon-and-quit
	_menu.save_and_quit_requested.connect(func() -> void:
		# Combat is outside the save, so the arrival bookmark stands; a write would be unloadable.
		if not Router.in_combat():
			SaveGame.save()
		else:
			SaveGame.mark_fight(Router.current_fight)
		toggle_menu(false)
		# Drop the in-memory run once saved: the title's own galaxy would move this run's systems.
		# Why: docs/why/Main.md#abandon-and-quit
		Run.hull = null
		# Drop the party's fight and signals too, or partners stay on WAIT and CONTINUE resumes it.
		# Why: docs/why/Main.md#abandon-and-quit
		Router.drop_combat()
		Router.show_launcher())

## For shots: Settings in the escape drawer, scrolled once the rows have laid out.
func _show_keys() -> void:
	for i in 3:
		await get_tree().process_frame
	var panel: SettingsPanel = _find_settings_panel(self)
	if panel == null:
		return
	var page := panel.keys_page
	# A shot changes keys only in a file of its own, never the player's.
	var scratch := "user://bindshot.cfg"
	Keys.path = scratch
	for a in OS.get_cmdline_user_args():
		match a:
			"bindshot=listen":
				page.listen(&"ship_thrust", 1)
			"bindshot=clash":
				page.listen(&"ship_thrust", 0)
				page.offer(KEY_S)
			"bindshot=reset":
				# One key moved, so a RESET shows on its row, then the question.
				page.listen(&"ship_thrust", 1)
				page.offer(KEY_SPACE)
				page.ask_reset_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	await get_tree().process_frame
	panel.show_keys("bindshot=reset" in OS.get_cmdline_user_args())

## For `-- settings=motion`: the open Settings, scrolled to one section's head
## once the drawer has laid out.
func _show_section(id: StringName) -> void:
	for i in 3:
		await get_tree().process_frame
	var panel: SettingsPanel = _find_settings_panel(self)
	if panel != null:
		panel.show_section(id)

func _find_settings_panel(n: Node) -> SettingsPanel:
	if n is SettingsPanel:
		return n
	for c in n.get_children():
		var found := _find_settings_panel(c)
		if found != null:
			return found
	return null

func _open_settings() -> void:
	if _menu != null:
		_menu.show_settings()
		return
	if _settings != null:
		return
	_settings = SettingsMenu.new()
	_settings.theme = theme
	_overlay_layer().add_child(_settings)
	_settings.setup()
	_settings.closed.connect(_close_settings)

func _close_settings() -> void:
	if _settings == null:
		return
	_settings.close()
	_settings = null
