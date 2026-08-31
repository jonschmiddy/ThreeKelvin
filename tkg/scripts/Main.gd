extends Control
## Entry point. Builds the theme, the persistent HUD, and hands the content
## area to Router. Everything else is created in code by the screens.

func _ready() -> void:
	_wear_cursor()
	# The run seed, before anything can roll:  godot --path . -- seed 12345
	# A run is one number. This is the flag that makes a bug report replayable,
	# and it is read before every other branch below because HeadlessSim and the
	# tests all start runs of their own.
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

	# The whole price table, and the proof that it cannot be gamed:
	#   godot --headless --path . -- market
	# Same shape as savetest above it, and for the same reason: the thing it
	# checks fails silently. A market whose melt price creeps above its ask price
	# does not crash, it just quietly pays for the rest of the run.
	if "market" in OS.get_cmdline_user_args():
		load("res://scripts/sim/MarketTest.gd").new().run()
		get_tree().quit()
		return

	# Every starting chassis and what it reads on the six attributes:
	#   godot --headless --path . -- attrs
	# Attribute constants are tuned by staring at this table, and the numbers are
	# only meaningful against each other — a column at a time, not a ship at a
	# time. Reading them off a UI one manufacturer per screen is how you convince
	# yourself a spread exists that does not.
	if "attrs" in OS.get_cmdline_user_args():
		_print_attribute_table()
		get_tree().quit()
		return

	# Every event option, its badge, and 10,000 rolls of its ladder:
	#   godot --headless --path . -- checks
	# A skill check fails silently in both directions — an option nobody can
	# ever pass and an option nobody can ever fail both look like working code
	# and read like working prose. This prints what each one actually costs
	# against a real ship, and proves the odds table matches the rolls.
	if "checks" in OS.get_cmdline_user_args():
		_print_check_table()
		get_tree().quit()
		return

	# Every sector sky on one sheet, and again behind a real ship:
	#   godot --path . -- sky
	# Needs a window, not because it shows one but because SpaceBackdrop is
	# drawn by the renderer — under --headless the viewports it grabs come back
	# blank. Written to user:// and the path is printed.
	#
	# It exists because procedural art is tuned by comparing a dozen rolls at
	# once. Reaching twelve different systems in a run to see twelve skies is
	# not a way to find the one that is too bright.
	if "sky" in OS.get_cmdline_user_args():
		_sky_test = load("res://scripts/sim/SkyTest.gd").new()
		_sky_test.run(get_tree())
		return

	# Seeded generation: the same seed twice, and streams that do not move each
	# other:  godot --headless --path . -- rngtest
	# RUN THIS AFTER TOUCHING Rng OR ANY GENERATOR. Determinism fails silently
	# by nature — a run that is 99% reproducible looks exactly like one that is
	# reproducible, right up to the moment four players are in four galaxies.
	# The archive, machinery and prose both:
	#   godot --headless --path . -- archivetest
	if "archivetest" in OS.get_cmdline_user_args():
		load("res://scripts/sim/ArchiveTest.gd").new().run()
		get_tree().quit()
		return

	# Signing, reaching, killing, docking hot, being paid — and the market
	# invariant under standing, which `-- market` cannot reach:
	#   godot --headless --path . -- contracttest
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

	# Four peers, one process, and the whole join handshake:
	#   godot --headless --path . -- nettest
	# RUN THIS AFTER TOUCHING ANYTHING IN scripts/net/. Held in a member for the
	# same reason the sky test is: it runs across frames rather than inside one,
	# and a RefCounted that only a local variable holds is freed the moment this
	# function returns. It quits the tree itself when it is done.
	if "nettest" in OS.get_cmdline_user_args():
		_net_test = load("res://scripts/sim/NetTest.gd").new()
		_net_test.run(get_tree())
		return

	# Two processes, one enemy:
	#   godot --headless --path . -- cofight host
	#   godot --headless --path . -- cofight join CODE
	#   tools/cofight.sh                    (both, paired by the printed code)
	# RUN THIS AFTER TOUCHING Combat's shared path. nettest cannot reach it:
	# `Run` is a singleton, so one process holds one ship, and every line in
	# Combat that talks to the party needs a second one. Held in a member for
	# the same reason nettest is.
	if "cofight" in OS.get_cmdline_user_args():
		_co_fight = load("res://scripts/sim/CoFightTest.gd").new()
		_co_fight.run(get_tree())
		return

	# A ship in the party that nobody is sitting in front of:
	#   godot --headless --path . -- bot join ABC-123
	#   tools/bot.sh ABC-123
	# It joins by lobby code like a person, rolls its own chassis and holds its
	# own Run. Returns before the UI for the same reason cofight does — there is
	# nobody to show it to — and registers Router a holder of its own, because a
	# bot flies through the same Router the humans do. See scripts/net/BotPilot.
	if "bot" in OS.get_cmdline_user_args():
		_bot = load("res://scripts/net/BotPilot.gd").new()
		_bot.run(get_tree())
		return

	# One PNG per ship, straight out of ShipView's own canvas:
	#   godot --headless --path . -- shipsheet
	# Each hull twice, bare and loaded, because the question is not whether a
	# ship draws — it is whether the ship that draws is the one described. It
	# needs no renderer at all: the view composites into an Image, and the
	# Image is the file. See ConvoyTest.
	# A PixelLab prompt, built from a manufacturer rather than from memory:
	#   godot --headless --path . -- artprompt korvan structures
	# RUN THIS BEFORE GENERATING ANY MANUFACTURER'S PARTS. It reads the fiction live from
	# DB.manufacturers so a prompt cannot drift from the tooltip a player reads,
	# and it carries the two settings that were learned expensively: force the
	# palette, and send no init image or transparency is silently dropped.
	if "artprompt" in OS.get_cmdline_user_args():
		_wear_sheet = load("res://scripts/sim/ArtPrompt.gd").new()
		_wear_sheet.run(get_tree())
		return

	# Every specification class of a hull with real art:
	#   godot --headless --path . -- fit
	#   godot --headless --path . -- fit damage=3
	# RUN THIS AFTER TOUCHING HullFit. The second form composes it with wear,
	# which is the pairing that matters: fittings go on before damage, so a
	# bolt-on can be shot off.
	if "fit" in OS.get_cmdline_user_args():
		_wear_sheet = load("res://scripts/sim/FitSheet.gd").new()
		_wear_sheet.run(get_tree())
		return

	# Every enemy body at every damage band:
	#   godot --headless --path . -- bestiary
	# RUN THIS AFTER TOUCHING HullWear's organic operations. It is where the
	# substance split gets looked at: a whale does not weld, a gunship does not
	# scar, and the two op lists are how that is enforced.
	if "bestiary" in OS.get_cmdline_user_args():
		_wear_sheet = load("res://scripts/sim/BestiarySheet.gd").new()
		_wear_sheet.run(get_tree())
		return

	# Every condition grade of every hull with real art:
	#   godot --headless --path . -- wear
	# RUN THIS AFTER TOUCHING HullWear. It prints new-colour counts per grade,
	# which is the claim the whole approach rests on: wear draws with the
	# sprite's own palette and cannot introduce a colour. Anything but 0 is a bug.
	if "wear" in OS.get_cmdline_user_args():
		_wear_sheet = load("res://scripts/sim/WearSheet.gd").new()
		_wear_sheet.run(get_tree())
		return

	# Every hull's mounts against its own opaque pixels. The lines are measured
	# per sprite, so the failure worth catching is a hull carrying ANOTHER
	# hull's lines — which draws guns in mid-air and throws nothing.
	# The hold's packing rule, against every hull's grid. The failure is invisible
	# in the data — two parts sharing a cell still add up to a sensible "17 of
	# 28" and still save and load — so it is only ever seen on screen.
	# How much of the catalogue exists, against how much is meant to:
	#   godot --headless --path . -- content
	if "content" in OS.get_cmdline_user_args():
		load("res://scripts/sim/ContentCount.gd").new().run()
		get_tree().quit()
		return
	# What a rarity actually buys, in card numbers:
	#   godot --headless --path . -- rarity
	# Is the galaxy traversable, and how short is the short way:
	#   godot --headless --path . -- maptest
	# Does the option roller obey its own rules -- positional, gated, in plan:
	#   godot --headless --path . -- optiontest
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

	# What every frame launches with, and whether the reactor ladder leaves it
	# a deck:
	#   godot --headless --path . -- reactor
	# What the chart's KNOWN ONLY view actually shows:
	#   godot --headless --path . -- chartfilter
	# Does a part move the gauge its grade promised:
	#   godot --headless --path . -- attrtest
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

	# THE FRAME COUNTER, over everything and part of no layout. Added to the
	# window rather than to `root`, so it cannot take a pixel from the HUD row --
	# which is exactly what got the last one deleted. Built whatever the setting
	# says and hidden if it is off, so the toggle works without a relaunch.
	add_child(FpsMeter.new())

	Router.register(content, hud)

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

	# The chart at a ladder of zooms, to SEE the boundary rather than argue
	# about it:
	#   godot --path . -- zoomshot
	if "zoomshot" in OS.get_cmdline_user_args():
		_zoom_shot = load("res://scripts/sim/ZoomShot.gd").new()
		_zoom_shot.run(get_tree())
		return

	# What the chart and the title screen cost:
	#   godot --path . -- chartbench
	# AFTER `Router.register`, unlike the headless harnesses above: this one
	# needs the UI it is measuring to exist.
	if "chartbench" in OS.get_cmdline_user_args():
		_chart_bench = load("res://scripts/sim/ChartBench.gd").new()
		_chart_bench.run(get_tree())
		return


	# Boot destination. The launcher is the default, and every development flag
	# below skips it — an automated run must never stop at a screen waiting to
	# be clicked, and a flag that drops you into a fight plainly means "not the
	# title screen" without having to say so.
	#
	#   -- nolauncher   straight into a new run
	#   -- resume       straight into the suspend save, if there is one
	#   -- lobby        straight into the party screen, with no run rolled
	#
	# `ship` belongs in this list and its absence is not cosmetic: the refit
	# screen reads Run.hull, which is null until a run starts, so booting to the
	# launcher and then swapping the ship screen over it crashes on arrival.
	# `salvage` is the same: it stows into a hold that a run has to exist for,
	# and the sector it opens draws the ship's own reactor.
	var argv := OS.get_cmdline_user_args()
	var skip_launcher := "nolauncher" in argv or "cards" in argv or "fight" in argv \
		or "charttest" in argv or "ship" in argv or "station" in argv \
		or "salvage" in argv or "party" in argv or "archive" in argv \
		or "quest" in argv or "parts" in argv
	# The party screen, before a dive:  godot --path . -- lobby
	# Its own branch rather than a member of skip_launcher, because it must NOT
	# start a run. A lobby's whole job is to agree on the seed the run is going
	# to be made from, and new_run() would have rolled one already.
	if "lobby" in argv:
		Router.show_lobby()
	elif "resume" in argv and SaveGame.has_save():
		Router.continue_run()
	elif skip_launcher:
		Router.new_run()
	else:
		Router.show_launcher()

	# Dev shortcut: drop straight into a fight with a hand of cards.
	#   godot --path . -- fight
	# Card work is 90% of what gets iterated on and reaching a fight normally
	# costs a jump, a sector screen and a loading pass every time you change a
	# pixel. Deliberately not a menu item — it skips the run the balance depends
	# on, so it stays a flag you have to type.
	# Star chart cache test. Needs the real shell and a window, so unlike the
	# sim and savetest it runs after boot rather than instead of it:
	#   godot --path . -- charttest
	# The sector with a party in it:  godot --path . -- convoy
	# Needs a window, and runs after boot rather than instead of it, because it
	# photographs the real screen — the arena, the salvage rail and the hand all
	# competing for the same width, which is the whole question. The party is a
	# fabricated ROSTER and no port is opened.
	# `-- party 6` opens the party page against a fabricated roster.
	#
	# Same argument as `-- convoy`: the page's whole subject is other people, so
	# without this the only way to look at it is to start six Godot processes and
	# fly them to the same place. The roster is faked, not the screen — what is
	# drawn is the real PartyScreen reading the real Net.roster.
	# `-- archive` opens the reading room, and `-- archive all` recovers every
	# entry first. The archive fills up over many runs by design, so without this
	# the only way to look at a deep page is to fly to layer eight.
	# `-- cargo` starts a heavy run with a hold full of materials, and then hands
	# the game back to you.
	#
	# Not a screenshot. `-- shipshot heavy cargo` photographs the same hold and
	# quits, which answers "does it draw" and not "does it feel like anything to
	# pack". Materials are a SPATIAL toy -- the whole ruling behind them is that
	# they do not stack, so every one is a decision about room -- and that is not
	# a thing a still image can be judged on.
	#
	# One of every shape first, then a spread of tiers, then whatever else fits.
	# `-- questrun` places one and opens the chart on it, then hands the game
	# back. NOT `quest`: every mode here matches on a bare word appearing
	# anywhere in the arguments, so `-- chartshot quest` matched this first and
	# quietly opened a playable game instead of taking the photograph.
	#
	# A PLACEMENT CANNOT BE POSED. It is the consequence of an option resolution
	# several jumps back, so the only honest setup is to make the call the
	# outcome makes and let it choose its own target the way it will in a real
	# run. `-- chartshot quest` photographs the marker and quits, which answers
	# "does it draw"; this answers "can you find it, and does the chart still
	# read with it on".
	#
	# `flown` first, because a fresh chart shows every system as currently
	# sensed and the marker is most interesting on a system you CANNOT see --
	# which is the one rule it deliberately breaks.
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

	if "cargo" in OS.get_cmdline_user_args():
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
		# And something on the floor of this system, so SECTOR has a container
		# to open. Half the point of the flag is the reaching, not the packing.
		# A CONTAINER WORTH LOOKING AT: a spread of shapes and tiers on the floor,
		# a part among them so the two icon kinds are judged side by side, and
		# one already claimed so the taken state is visible.
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

	if "archive" in OS.get_cmdline_user_args():
		# `all`, or a count — the PARTIAL archive is the state a real player is in
		# for most of the game, and the redacted rows are most of what the screen
		# has to say, so it needs to be as easy to look at as the full one.
		var want := -1
		if "all" in OS.get_cmdline_user_args():
			want = DB.documents.size()
		for a in OS.get_cmdline_user_args():
			if a.is_valid_int():
				want = int(a)
		if want >= 0:
			Archive.wipe()
			var got := 0
			for d in DB.documents_by_depth(MapGen.LAYERS):
				if got >= want:
					break
				Archive.recover((d as DocumentData).id,
					"recovered by a development flag")
				got += 1
		Router.show_archive()

	# `-- quest` signs the first fetch and the first hunt it can find and opens
	# the chart on them.
	#
	# The rings are the only part of the contract system living on a screen you
	# cannot reach from a station, so without this the only way to look at them is
	# to fly to a station, sign something and fly to the chart — three screens
	# away from the thing being changed. Same argument as `-- party` and
	# `-- salvage`: the contracts are faked, the chart is not.
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

	if "sectorshot" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/SectorShot.gd").new()
		_convoy_test.run(get_tree())
		return

	if "chartshot" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/ChartShot.gd").new()
		_convoy_test.run(get_tree())
		return

	# Every exhaust strip loaded and measured:  godot --headless --path . -- exhaust
	# Headless on purpose: a plume that fails to load is invisible, not loud.
	if "encdump" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/EncDump.gd").new()
		_convoy_test.run(get_tree())
		return

	if "exhaust" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/ExhaustCheck.gd").new()
		_convoy_test.run(get_tree())
		return

	# The refit screen at a chosen weight:  godot --path . -- shipshot heavy
	# Needs a window and runs after boot, same as convoy. The heavy is the
	# default because its 6x5 hold is what any change to that panel has to clear.
	# Every drawn part on one ship, live:  godot --path . -- artdemo
	# AFTER BOOT, beside shipshot and not up with the headless checks: show_ship
	# needs the Router to have been handed a content node, and the branches above
	# run before that exists.
	if "artdemo" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/ArtDemo.gd").new()
		_convoy_test.run(get_tree())
		return

	if "shipshot" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/ShipShot.gd").new()
		_convoy_test.run(get_tree())
		return

	if "convoy" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/ConvoyTest.gd").new()
		_convoy_test.run(get_tree())
		return
	# The salvage rail, driven through the real screen and a real jump — the one
	# thing unit assertions on the rule cannot see:
	#   godot --headless --path . -- stowtest
	# The container, checked on what it DRAWS. Beside stowtest and for the same
	# reason: it builds a real screen and needs a live tree, but no pixels.
	#   godot --headless --path . -- transfertest
	if "transfertest" in OS.get_cmdline_user_args():
		_stow_test = load("res://scripts/sim/TransferTest.gd").new()
		_stow_test.run(get_tree())
		return

	if "stowtest" in OS.get_cmdline_user_args():
		_stow_test = load("res://scripts/sim/StowTest.gd").new()
		_stow_test.run(get_tree())
		return

	# Parts crossing between the hold and the hull, dragged with real events:
	#   godot --path . -- fittest
	# NOT headless — it drives Viewport's own drag machine, and headless has no
	# gui input to drive it with. Held in a member for the same reason ChartTest
	# is: run() awaits, and a RefCounted nobody holds dies mid-coroutine.
	if "fittest" in OS.get_cmdline_user_args():
		_fit_test = load("res://scripts/sim/FitTest.gd").new()
		_fit_test.run(get_tree())
		return

	if "charttest" in OS.get_cmdline_user_args():
		# Held in a member, not called on a throwaway. ChartTest.run() awaits,
		# and a RefCounted nothing holds a reference to is freed the moment the
		# calling statement ends — the suspended coroutine goes with it and the
		# test dies silently after its first print. SaveTest gets away with
		# `load(...).new().run()` only because it never awaits.
		_chart_test = load("res://scripts/sim/ChartTest.gd").new()
		_chart_test.run(get_tree())
	if "cards" in OS.get_cmdline_user_args():
		Router.show_cards()
	# Every module in the game, on one page:  godot --path . -- parts
	#
	# Same argument as `-- cards` one line up, one level out: a part is what you
	# find and pack, and the only way to see one used to be to be handed it.
	#
	# An ELIF, in the chain, and not an `if` of its own beside it. Written as a
	# separate `if` it silently re-parents the `elif` under it — `-- ship` would
	# then be testing whether `parts` was absent rather than whether `cards`
	# was. That has happened here before and cost an afternoon.
	elif "parts" in OS.get_cmdline_user_args():
		Router.show_modules()
	elif "ship" in OS.get_cmdline_user_args():
		# WHICH weight, for comparing the three hull sizes: `-- ship heavy`.
		# Inside this branch rather than in front of the chain — put in front,
		# the `elif` below binds to IT instead of to the flag above, and every
		# other dev flag silently stops working.
		var flags := OS.get_cmdline_user_args()
		if "light" in flags or "heavy" in flags:
			var w: HullData.Weight = HullData.Weight.HEAVY
			if "light" in flags:
				w = HullData.Weight.LIGHT
			Run.fit_chassis(&"korvan", w, 0)
		# The refit screen normally sits two clicks and a chassis choice away,
		# and it is where the attribute block lives — so the screen that most
		# needs looking at was the most tedious to reach.
		#
		# Seeded with a hold, because the screen is a workbench now and an empty
		# hold tests half of it. Eight parts across the rarity range: enough to
		# fill the storage grid past one row, and enough that a swap has
		# something worth swapping to.
		for i in 8:
			Run.stow(LootGen.roll_module(2 + i, &"", true))
		Router.show_ship()
	elif "station" in OS.get_cmdline_user_args():
		# The dock, immediately. Added when the station became four panels rather
		# than two — a shelf, a service desk, a buyer for the hold and a
		# fabricator — and reaching it normally costs a chassis choice, a jump
		# and a sector screen every time one of those four moves a pixel.
		#
		# It also gives the merge gate something that CONSTRUCTS the screen. The
		# boot check only ever built the launcher, so the busiest screen in the
		# game was the one nothing automated had ever drawn.
		var here: MapGen.MapNode = Run.node_at()
		here.type = MapGen.NodeType.STATION
		here.development = MapGen.Development.CITY
		here.security = 4
		here.berths = [&"solari", &"cygnet"]
		here.manufacturer = &"solari"
		here.danger = 5
		# Something in the hold to sell, something to scrap, and enough of every
		# material to light up the fabricator and the material rows.
		for i in 3:
			Run.stow(LootGen.roll_module(4 + i, &"", true))
		# STRAIGHT INTO THE HOLD, because this is the debug seed and its whole
		# job is to put you in a state -- `add_material` would leave them
		# floating in the sector for you to go and fetch.
		for seeded in [&"exotic", &"exotic", &"relic"]:
			Run.stow(MaterialData.of(MaterialTable.by_id(seeded)))
		Run.hp = maxi(1, Run.max_hp() - 12)
		Run.add_dross(3)
		Router.show_station()
	elif "salvage" in OS.get_cmdline_user_args():
		# `-- salvage 8` opens the sector with eight parts in the hold.
		#
		# The salvage rail is the one panel in the game whose layout only
		# misbehaves at sizes a normal run reaches late — a lawless run pays two
		# modules a fight — and it misbehaved by growing the PAGE rather than
		# itself, which pushed the hand strip off the bottom of the screen. The
		# only way to see that was to play until the hold was full, which is the
		# same argument `-- fight 10` makes about the hand.
		#
		# `-- salvage 8 bag=4` also drops a four-part BAG at the node, which is
		# what a shared kill leaves. That one cannot be reached at all without a
		# second machine — `Combat._victory` only opens a bag when the fight was
		# the party's — so without this the newest panel in the game is the one
		# nothing can draw on its own.
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
		# `-- fight 10` deals ten. The hand is the one layout that only
		# misbehaves at sizes a normal run rarely reaches, so seeing it full
		# should not require finding a Redline set bonus first.
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
			# `foehp=20` opens the named contact already hurt — the only way to
			# photograph the states a fight normally has to earn: the wound
			# bands, and the hellbender's escape-burn telegraph.
			for a2 in OS.get_cmdline_user_args():
				if a2.begins_with("foehp="):
					var e0 := Router.combat.enemies[0]
					e0.hp = clampi(int(a2.split("=")[1]), 1, e0.max_hp)
					e0.pick_intent()
					Sig.enemy_changed.emit()
		else:
			var pool := DB.fight_pool(3, false)
			Router.start_combat(DB.enemies[Rng.pick(Rng.foe, pool)])

	# `-- shot` writes what is on screen and quits. For looking at a layout from
	# a place that cannot look at a window — a headless CI leg, an agent, a bug
	# report from somebody who cannot run the project. Deliberately generic: it
	# photographs whatever the flags above put up, so it never needs a case
	# adding for a new screen.
	if _wants_shot():
		_shoot()

## `-- shot` or `-- shot=path`. Both spellings, because a flag that silently
## does nothing when you name a file is worse than no flag.
func _wants_shot() -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "shot" or a.begins_with("shot="):
			return true
	return false

## Wait for the layout to settle, then save the frame.
##
## Several frames, not one. Containers size their children on the frame AFTER
## they are added, and every screen here is built in code during _ready — a
## grab on frame zero photographs a page whose panels are all still at their
## minimum size, which is precisely the property under test.
func _shoot() -> void:
	# THE WINDOW IS RESIZED TO THE BASE VIEWPORT FIRST, and this is not tidiness.
	#
	# The window is resizable and the controls lay out to it in real pixels, while
	# this grab returns the viewport's own render target at the project's base
	# size. Those two are routinely different — a 999-wide window photographed as
	# a 960-wide PNG — so the picture silently CROPS the interface, and a button
	# perfectly placed in the game appears sliced by the right edge of the file.
	#
	# An afternoon went into chasing a margin bug that did not exist because of
	# it. A screenshot that does not show what the game shows is worse than no
	# screenshot: it is a confident wrong answer.
	var base := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 540)))
	get_window().size = base
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var out := "user://shot.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="):
			out = a.split("=")[1]
	img.save_png(out)
	# THE TEXTURE AND THE LAYOUT ARE NOT ALWAYS THE SAME WIDTH, and reading the
	# picture as if they were costs an afternoon. The window is resizable, the
	# controls lay out to it, and this grab is the viewport's own render target —
	# so a screenshot can be NARROWER than the interface in it, and a button
	# sliced by the right edge of the PNG can be perfectly placed in the game.
	# Both numbers are printed so the next reader can tell those two apart.
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

## Every checked option in the table, measured against three real ships.
##
## Prints the badge the player would see and then rolls the ladder ten thousand
## times, so the four bands can be compared against what ODDS promises. A drift
## between them means pick_outcome or the split is wrong, and neither would
## crash.
func _print_check_table() -> void:
	for probe in [[&"redline", HullData.Weight.LIGHT], [&"korvan", HullData.Weight.MEDIUM],
			[&"probate", HullData.Weight.HEAVY]]:
		Run.start_new_run(probe[0], int(probe[1]))
		print("\n=== %s ===" % Run.hull.name)
		print("%-22s %-34s %6s %6s %6s %6s" % [
			"event", "badge", "met", "clean", "part", "botch"])
		# THE OPTIONS, because that is where checks live now. This probe read
		# `EventTable` until that table was emptied by the batch-04 port; the
		# ladder it verifies did not move, only the content carrying it, and
		# there is now four times as much of it to verify against.
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

## Starts a run per manufacturer and prints the resulting attribute row, plus
## the raw gauges each one is derived from so a surprising attribute can be
## traced to the stat that caused it without opening Database.gd.
func _print_attribute_table() -> void:
	# RCT WAS MISSING and the row has always printed it: the loop below walks
	# `Run.attributes()`, which is seven gauges, against six labels. Every
	# column after HUL read as the one to its left, so a heavy's thrust of 8
	# looked like a maneuverability of 8 on a frame that cannot turn at all.
	print("chassis            HUL RCT THR MNV THM SEN STL   hp/cap/diss/dodge/init/fuel  mounts  kit deck hand set")
	for manufacturer in DB.STARTABLE:
		for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
			Run.start_new_run(manufacturer, int(w))
			var row := ""
			for a in Run.attributes():
				row += "%3d " % int(a.value)
			# Deck size is the number that decides whether a starting hand is a
			# DRAW or just your whole deck, and it is not obvious from the kit:
			# modules grant 2 cards, utilities 1, and Verity one fewer than
			# whatever it would have been.
			var deck := 0
			for mod in Run.installed:
				deck += mod.grant_count()
			# slots_for(), not the raw hull numbers. No perk adds a mount any more --
			# spare_bay was the only one that did and it is gone -- but the set
			# bonuses and the hull perks still reach these numbers, and a table that
			# disagrees with the ship sends you looking for a bug in the fitting code.
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
var _settings: SettingsMenu = null

## The game shipped with no way to exit — no quit action, no input map entries.
## Escape now opens the menu; F11 toggles fullscreen so a screen-sized window
## can never trap the player behind missing title-bar chrome again.
## TAB IS THE SHIP, and it has to be caught in `_input` rather than in
## `_unhandled_key_input`.
##
## Godot binds Tab to `ui_focus_next` and the GUI consumes it walking focus
## between controls, so it never reaches the unhandled pass -- which is where I
## put it first, and why it did nothing. Taking it here and marking it handled
## costs the focus walk, which this game does not use: nothing is keyboard
## navigable and every control is clicked.
##
## `show_ship` refuses during a fight on its own, so there is no guard here.
## THE POINTER, AND THE POINTER CLOSING.
##
## Four corners and a dot -- see `art/tools/cursors.py` for why there is no
## crosshair -- travelling from six pixels out to three when the thing under
## them can be pressed.
##
## FRAMES, BECAUSE A CUSTOM CURSOR IS ONE STATIC TEXTURE PER SHAPE. Godot has
## no animated form of it, so the animation is four images and the swapping is
## here. The alternative -- hiding the system cursor and painting our own
## Control at the mouse position -- can tween anything, and is a cursor one
## frame behind the mouse forever. A pointer that lags is a worse pointer than
## one that does not ease, so the frames win.
##
## IT COSTS FOUR OS CALLS PER HOVER, not four a second: `_process` only touches
## the cursor when the rounded frame index actually changes, which is three
## times on the way in and three on the way out.
const CURSOR_FRAMES := 4
## The pixel you are pointing with: the middle, for a shape that closes around
## it rather than an arrow that points from a corner.
const CURSOR_HOT := Vector2(16, 16)
## Frames per second of travel. Nine hundredths of a second end to end, which is
## fast enough to feel like a response and slow enough to see happen.
const CURSOR_SPEED := 34.0

var _cursor_tex: Array[ImageTexture] = []
## Where the animation currently is, 0 open to 3 closed. Fractional between.
var _cursor_at: float = 0.0
## Which frame the operating system is actually holding, to avoid handing it the
## same image sixty times a second.
var _cursor_shown: int = -1


func _wear_cursor() -> void:
	_cursor_tex.clear()
	for i in CURSOR_FRAMES:
		var img := Image.new()
		if img.load(ProjectSettings.globalize_path(
				"res://art/cursors/reticle_%d_2x.png" % i)) != OK:
			return
		_cursor_tex.append(ImageTexture.create_from_image(img))
	_show_cursor(0)


func _show_cursor(f: int) -> void:
	if f == _cursor_shown or f < 0 or f >= _cursor_tex.size():
		return
	_cursor_shown = f
	# BOTH SHAPES, THE SAME IMAGE. Godot swaps ARROW for POINTING_HAND by itself
	# the instant the pointer crosses a control, which would jump the reticle to
	# its end state and leave the animation running behind it. Holding both to
	# the current frame means the swap is invisible and this is the only thing
	# deciding what the cursor looks like.
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		Input.set_custom_mouse_cursor(_cursor_tex[f],
			shape as Input.CursorShape, CURSOR_HOT)


## Is the thing under the pointer something you can press?
##
## Asked of the hovered control rather than of the cursor, because the cursor is
## what we are deciding. `mouse_default_cursor_shape` is the declaration every
## button makes through `Widgets._btn`, so this reads the same fact Godot would
## have read to do the swap we are taking over.
func _cursor_wants_shut() -> bool:
	# A HELD BUTTON IS A GRIP. Dragging the starchart, dragging a crate across
	# the hold, holding a card -- the pointer has hold of something for the
	# whole of it, and one rule covers all three without any of them knowing
	# this exists. It is also what keeps a click scrunched for as long as the
	# click lasts, rather than for one frame.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true
	var h := get_viewport().gui_get_hovered_control()
	return h != null and h.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND


func _process(delta: float) -> void:
	if _cursor_tex.is_empty():
		return
	var want := float(CURSOR_FRAMES - 1) if _cursor_wants_shut() else 0.0
	_cursor_at = move_toward(_cursor_at, want, delta * CURSOR_SPEED)
	_show_cursor(int(round(_cursor_at)))


func _input(event: InputEvent) -> void:
	# SNAP SHUT, EASE OPEN. A press jumps the reticle to closed rather than
	# travelling there: the animation is a response to hovering, and a click is
	# an impact. Easing INTO a click makes the pointer feel behind your hand;
	# easing out of one reads as the thing recovering.
	#
	# NOT HANDLED, deliberately. This watches the click on the way past; the
	# control under it still gets it.
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_cursor_at = float(CURSOR_FRAMES - 1)
		_show_cursor(CURSOR_FRAMES - 1)
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode != KEY_TAB:
		return
	get_viewport().set_input_as_handled()
	# SHIP, SECTOR, STARCHART, round. The three screens a run is actually played
	# on, in the order you move between them: what you are carrying, where you
	# are, where you are going.
	#
	# Each `show_` refuses on its own terms -- `show_ship` during a fight, the
	# chart with nothing to jump to -- so a refused step simply leaves you where
	# you were rather than needing a guard here.
	if Router.current is ShipScreen:
		Router.show_sector()
	elif Router.current is SectorScreen:
		Router.show_starchart()
	else:
		Router.show_ship()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE:
		if _settings != null:
			_close_settings()
		elif Router.current is LauncherScreen:
			pass   ## nothing to pause: the launcher IS the menu
		else:
			toggle_menu()
	elif k.keycode == KEY_F11:
		DisplaySettings.toggle_fullscreen()

## Opens the escape menu, or closes it if it is already up.
func toggle_menu() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
		return
	_menu = PauseMenu.new()
	add_child(_menu)
	_menu.setup()
	_menu.resume_requested.connect(toggle_menu)
	# Abandoning is an ENDING, so it goes into the record — the same one
	# Router.new_run() writes when you start over on top of a live run. Recorded
	# here rather than left for later because the run is over the moment this is
	# pressed, and a player who abandons and then closes the game would otherwise
	# have it vanish from the flight record entirely.
	_menu.quit_requested.connect(func() -> void:
		toggle_menu()
		RunHistory.record(RunHistory.Outcome.ABANDONED, "Abandoned mid-run.")
		SaveGame.clear()
		# No ship any more, which is the state the game boots in and the state
		# the title screen expects. It also stops new_run() recording this same
		# abandonment a second time, since its guard is a live hull.
		Run.hull = null
		Router.show_launcher())
	_menu.new_run_requested.connect(func() -> void:
		toggle_menu()
		Router.new_run())
	_menu.settings_requested.connect(_open_settings)
	# The autosave has already written a screen swap, but state moves after one
	# — a station's purchases and repairs all land on a screen that was saved
	# when it opened — so the explicit write is what makes SAVE & QUIT mean it.
	#
	# Not mid-combat, though. Combat is outside the save by design and the format
	# stores none of it, so writing there banked the hull and heat the fight had
	# already spent against an enemy that comes back at full HP on a node still
	# marked unfought: strictly worse than force-quitting, from the button that
	# promises to be the safe way out. Mid-fight this now does what force-quitting
	# does — the last save, from before the shooting started, stands.
	_menu.save_and_quit_requested.connect(func() -> void:
		# Combat is outside the save, so mid-fight the bookmark from arrival at
		# this system is what stands — writing here would write a state the
		# loader cannot reconstruct.
		if not Router.in_combat():
			SaveGame.save()
		toggle_menu()
		# The run is on disk now, so the copy in memory is finished with. Letting
		# it stay live would be actively dangerous: the title screen rolls its
		# own Run.galaxy for the backdrop, and any later autosave would then
		# write this run's MAP against that galaxy — the systems are positioned
		# from the galaxy, so every one of them would move.
		Run.hull = null
		Router.combat = null
		Router.show_launcher())

func _open_settings() -> void:
	if _settings != null:
		return
	_settings = SettingsMenu.new()
	add_child(_settings)
	_settings.setup()
	_settings.closed.connect(_close_settings)

func _close_settings() -> void:
	if _settings == null:
		return
	_settings.queue_free()
	_settings = null
