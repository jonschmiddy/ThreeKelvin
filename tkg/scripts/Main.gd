extends Control
## Entry point. Builds the theme, the persistent HUD, and hands the content
## area to Router. Everything else is created in code by the screens.

func _ready() -> void:
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
	# RUN THIS BEFORE GENERATING ANY MAKER'S PARTS. It reads the fiction live from
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

	Router.register(content, hud)

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

	if "chartshot" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/ChartShot.gd").new()
		_convoy_test.run(get_tree())
		return

	# Every exhaust strip loaded and measured:  godot --headless --path . -- exhaust
	# Headless on purpose: a plume that fails to load is invisible, not loud.
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
		here.makers = [&"solari", &"cygnet"]
		here.manufacturer = &"solari"
		here.danger = 5
		# Something in the hold to sell, something to scrap, and enough of every
		# material to light up the fabricator and the material rows.
		for i in 3:
			Run.stow(LootGen.roll_module(4 + i, &"", true))
		Run.add_material(&"exotic", 2)
		Run.add_material(&"relic", 1)
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
var _sky_test: RefCounted = null
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
		for e in EventTable.build_all():
			for o in e.options:
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
	print("chassis            HUL THR MNV THM SEN STL   hp/cap/diss/dodge/init/fuel  mounts  kit deck hand set")
	for man in DB.STARTABLE:
		for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
			Run.start_new_run(man, int(w))
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
				DB.short_name(DB.manufacturer_name(man)), Run.manufacturer_count(man)])
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
