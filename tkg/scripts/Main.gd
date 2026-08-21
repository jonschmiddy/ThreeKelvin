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

	if "shipsheet" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/ConvoyTest.gd").new()
		_convoy_test.run(get_tree())
		return

	DisplaySettings.load_and_apply()
	DevMode.load_settings()
	theme = UITheme.build()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
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
	var argv := OS.get_cmdline_user_args()
	var skip_launcher := "nolauncher" in argv or "cards" in argv or "fight" in argv \
		or "charttest" in argv or "ship" in argv or "station" in argv
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
	if "convoy" in OS.get_cmdline_user_args():
		_convoy_test = load("res://scripts/sim/ConvoyTest.gd").new()
		_convoy_test.run(get_tree())
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
	elif "ship" in OS.get_cmdline_user_args():
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
		Run.dross = 1
		Router.show_station()
	elif "fight" in OS.get_cmdline_user_args():
		# `-- fight 10` deals ten. The hand is the one layout that only
		# misbehaves at sizes a normal run rarely reaches, so seeing it full
		# should not require finding a Redline set bonus first.
		for a in OS.get_cmdline_user_args():
			if a.is_valid_int():
				Run.hand_size_override = clampi(int(a), 1, 12)
		var pool := DB.fight_pool(3, false)
		Router.start_combat(DB.enemies[Rng.pick(Rng.foe, pool)])

## Kept alive for the duration of `-- charttest`; see the call site.
var _chart_test: RefCounted = null
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
			[&"dredge", HullData.Weight.HEAVY]]:
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
			# modules grant 2 cards, utilities 1, and Halcyon one fewer than
			# whatever it would have been.
			var deck := 0
			for mod in Run.installed:
				deck += mod.grant_count()
			# slots_for(), not the raw hull numbers: perks add mounts, and a table
			# that prints 1/2/3 for a ship carrying four utilities is a table that
			# makes you go looking for a bug in the fitting code. Cygnet's
			# spare_bay is exactly that case.
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
