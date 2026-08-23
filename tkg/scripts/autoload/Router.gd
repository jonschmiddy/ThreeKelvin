extends Node
## Screen flow. Owns the single content container and swaps screens into it,
## and decides what happens when you arrive at a map node.

var content: Control
var hud: HudBar
var current: Control
var combat: Combat

func register(content_holder: Control, hud_bar: HudBar) -> void:
	content = content_holder
	hud = hud_bar
	Sig.jumped.connect(_on_jumped)
	Sig.run_started.connect(_on_run_started)
	Sig.run_ended.connect(_on_run_ended)

## `chrome` is whether the HUD belongs above this screen. The launcher and the
## record reached from it run before any run exists, and the HUD reads ship
## state — it bails on a null hull, but an empty bar above a title screen is a
## bug that looks like a decision.
func _swap(screen: Control, chrome: bool = true) -> void:
	if current != null:
		current.queue_free()
	current = screen
	content.add_child(screen)
	if hud != null:
		hud.visible = chrome
	Sig.screen_changed.emit()
	_autosave()

## The one place the run is written to disk.
##
## Every safe point is a screen swap and every screen swap comes through here,
## so this is a chokepoint rather than a list of call sites that someone has to
## remember to extend. Combat is excluded by in_combat() — `combat` is assigned
## before start_combat() swaps its screen, so the fight's own swap saves nothing
## and the state on disk stays the one from just before the shooting started.
## Choosing a chassis is excluded for the same reason combat is: the state is
## not one you should be able to come back to. start_new_run() has already
## rolled a world and a random hull by the time the select screen opens, so
## without this, quitting at the select and pressing CONTINUE would resume into
## the sector flying a ship you never picked — the one choice the screen exists
## to ask, answered silently by a dice roll.
##
## The empty map is not a paranoid check either. `_snapshot()` reads
## `Run.node_at()`, which is `map[at]` with nothing in front of it, so a run that
## has a hull but no map takes this chokepoint down with an index error — and
## that is exactly the state a save file with a valid version and a truncated map
## used to leave behind on its way to the launcher.
func _autosave() -> void:
	if Run.hull == null or Run.map.is_empty() or Run.dead or Run.won or in_combat():
		return
	if current is ChassisSelect:
		return
	# And never from the title screen, which is not part of any run and which
	# overwrites Run.galaxy with the one it draws behind itself.
	if current is LauncherScreen or current is HistoryScreen:
		return
	SaveGame.save()

## The party, before a dive. Runs with no run loaded, like the launcher, so it
## takes no HUD — the bar reads ship state and there is no ship yet.
func show_lobby() -> void:
	Audio.music_state(&"menu")
	_swap(LobbyScreen.new(), false)
	(current as LobbyScreen).setup()

## Title screen. Boots here unless a development flag says otherwise.
func show_launcher() -> void:
	# &"menu", not &"sector" — the launcher runs with no run loaded, so the
	# sector arrangement was both the wrong music and the only state in the
	# table nothing ever asked for.
	Audio.music_state(&"menu")
	_swap(LauncherScreen.new(), false)
	(current as LauncherScreen).setup()

## A run beginning — started fresh or restored from the suspend save — cannot
## inherit the last one's fight. Nothing in RunState touches `combat`, so
## ABANDON RUN from the pause menu mid-fight used to leave in_combat() true
## forever: the new run's sector wired itself to the dead run's enemy, the
## autosave bailed on every screen swap so the run was never written, and the
## HUD kept SHIP and STARCHART greyed for the rest of it.
##
## Hung on the signal rather than written into new_run(), because the other
## boundary — load_into_run() — needs exactly the same reset and emits exactly
## the same signal. Two call sites, one chokepoint, same reason _swap() is the
## only place that saves.
func _on_run_started() -> void:
	# Let go of the signal bus first. A shared fight listens for the host on
	# `Sig`, and a connection outlives the reference that made it — an abandoned
	# fight dropped on the floor here would keep reacting to the party's next
	# one for the rest of the session.
	if combat != null:
		combat.release()
	combat = null

## A run starts by choosing a chassis, then opens on the sector rather than the
## chart: your ship in open space, not a graph of places you have not been yet.
##
## start_new_run() still runs FIRST and rolls the world plus a random chassis,
## so every screen has a valid hull to draw before anything is chosen. The
## select screen then refits that ship as you browse and hands control on.
##
## A run that was live when this is called was abandoned, not finished, and goes
## into the record as such — restarting a bad opening is a real outcome and
## pretending otherwise would quietly inflate the win rate.
## `seed_value` is the host's, and zero means roll one. A party dive is an
## ordinary run that happens to have been handed its seed — which is why it
## comes through here and lands on the chassis select like any other. Each
## player picks their own ship on the same galaxy, and that IS the party
## composition rule in `docs/coop-design.md` §6.
##
## The previous forced seed is put back rather than cleared, so `-- seed N` on
## the command line survives a run started from the lobby.
func new_run(seed_value: int = 0) -> void:
	if Run.hull != null and not Run.dead and not Run.won:
		RunHistory.record(RunHistory.Outcome.ABANDONED, "Abandoned mid-run.")
	SaveGame.clear()
	var was := Rng.forced
	if seed_value != 0:
		Rng.forced = seed_value
	Run.start_new_run()
	Rng.forced = was
	show_chassis_select()

func show_chassis_select() -> void:
	Audio.music_state(&"ship")
	var s := ChassisSelect.new()
	_swap(s)
	s.setup()
	s.launched.connect(show_sector)

## Resume the suspend save. Falls back to the launcher rather than to a new run:
## a player who pressed CONTINUE did not ask to start over, and silently rolling
## a fresh galaxy would be the worst possible answer to a save that failed to
## read.
func continue_run() -> void:
	if not SaveGame.load_into_run():
		Run.log_line("The save could not be read.", &"them")
		show_launcher()
		return
	resume_here()

## Where a restored run picks up. Always the sector — every arrival lands there
## anyway, and it is the one screen that reads correctly for every node type.
##
## The fight at an uncleared combat node is NOT restarted here. It is offered:
## the sector's action button says ENGAGE and starts it when pressed. Restarting
## it automatically would drop a returning player straight into a turn they did
## not ask for, and the node stays uncleared either way, so nothing is skipped
## for free — flying on forfeits the loot.
func resume_here() -> void:
	show_sector()

## The record. Reachable from the HUD during a run and from the launcher before
## one, which is why the way back is decided by the caller.
func show_history(from_launcher: bool = false) -> void:
	var s := HistoryScreen.new()
	_swap(s, not from_launcher)
	s.setup(show_launcher if from_launcher else show_sector)

## Everybody you are flying with, with the numbers the convoy strip has no room
## for. `back` is where LEAVE returns to, so the HUD can be reached from three
## screens without all three landing on the sector. See PartyScreen.
func show_party() -> void:
	if in_combat():
		return
	var here := current
	var s := PartyScreen.new()
	_swap(s)
	s.setup(show_ship if here is ShipScreen else (
		show_starchart if here is StarchartScreen else show_sector))

## Somebody else's paperwork. `from_launcher` sends LEAVE back to the title
## screen, because the archive is readable out of a run as well as in one — what
## you have read survives the ship. See Archive.
func show_archive(from_launcher: bool = false) -> void:
	var s := ArchiveScreen.new()
	_swap(s, not from_launcher)
	s.setup(show_launcher if from_launcher else show_sector)

func show_starchart() -> void:
	# The chart is the only place jumps are offered, so it is the one chokepoint
	# where being out of fuel has to resolve rather than stall.
	Run.check_stranded()
	if Run.dead:
		show_game_over()
		return
	Audio.music_state(&"chart")
	var s := StarchartScreen.new()
	_swap(s)
	s.setup()

## Where you are. Always available, including after the run ends.
## No combat guard here. after_combat() routes here from inside the fight, so a
## "are we in combat" check would swallow the very transition that ends it — the
## HUD disables the SECTOR tab during a fight, which is where that belongs.
func show_sector() -> void:
	Audio.music_state(&"sector")
	var s := SectorScreen.new()
	_swap(s)
	# Hand the live fight back if there is one. A SectorScreen built with no
	# Combat shows no fight, and the tabs that stay lit during one — CARDS, and
	# now HISTORY — swap this screen out and back. Without this, looking at the
	# card catalog mid-fight and pressing SECTOR returned you to an empty sector
	# with `combat` still running behind it, which is unwinnable and unloseable.
	s.setup(combat if in_combat() else null)

## Refit screen. Reachable from the HUD any time you are not in a fight.
## Development only: every card in the game on one page. See CardGalleryScreen.
func show_cards() -> void:
	var s := CardGalleryScreen.new()
	_swap(s)
	s.setup()

## Development only: every module in the game on one page. See
## ModuleGalleryScreen — the sibling of show_cards, and dev-only for the same
## reason: a catalogue is the answer to a game about finding out what things do.
func show_modules() -> void:
	var s := ModuleGalleryScreen.new()
	_swap(s)
	s.setup()

func show_ship() -> void:
	if in_combat():
		return
	Audio.music_state(&"ship")
	var s := ShipScreen.new()
	_swap(s)
	s.setup()

func show_game_over() -> void:
	Audio.music_state(&"gameover")
	var s := GameOverScreen.new()
	_swap(s)
	s.setup()

func jump_to(index: int) -> void:
	Run.jump_to(index)

func _on_jumped(_index: int) -> void:
	resolve_current_node()

func resolve_current_node() -> void:
	var n: MapGen.MapNode = Run.node_at()
	Run.log_line("Jumped to %s. %s. Danger %d." % [
		MapGen.star_name(n), MapGen.place_line(n).capitalize(), n.danger], &"you")

	# Roll what this system is offering before the save below, not at the moment
	# it is shown. Arriving is the safe point; everything past it is a thing you
	# chose to do here, and a suspend save is a bookmark rather than a way to
	# reject a draw. See _roll_here().
	_roll_here(n)
	# Anything you were paid to come and get is got. Before the autosave, so a
	# force-quit on arrival does not lose the trip you just made.
	Run.reach_contract_target(n.index)
	# The save the SaveGame header promises: on the sector, at the node you flew
	# to, with the contact still there. Until this line the last write predated
	# the JUMP — start_combat() assigns `combat` before it swaps, so the fight's
	# own swap saved nothing and the star chart's was the newest state on disk.
	# Force-quitting a fight therefore refunded the fuel, put you back at the
	# system you left, and let you pick a different route entirely.
	_autosave()

	# Every arrival lands on the sector. You should see the place before you are
	# asked to do anything with it — a station is a lit hab ring turning in the
	# dark, not a menu that appears. Fights are the exception only in that they
	# start immediately, and combat happens on the sector screen anyway.
	# Something followed you in. This is a fight on the way to the door rather
	# than instead of it: the system still holds whatever it held, so the node
	# is NOT consumed by winning here — see start_combat's `clears_node`.
	if not n.ambush.is_empty():
		Run.log_line("Contact. Your heat bloom lit you up on the approach.", &"heat")
		var extras: Array = []
		for i in range(1, n.ambush.size()):
			extras.append(DB.enemies[n.ambush[i]])
		start_combat(DB.enemies[n.ambush[0]], extras, false, false)
		return

	match n.type:
		# THE CORE DOES NOT OPEN ON ARRIVAL, and it used to.
		#
		# Dropping straight into the custodian is right for one ship and wrong
		# for a party, because two people never arrive at a system on the same
		# second. Whoever landed first was in the boss fight before the other had
		# finished their jump — so the run's one set piece was fought alone by
		# design, and the party had no way to be at it together. A latecomer
		# joining mid-fight works and always did; there was simply nothing to
		# join by the time they got there.
		#
		# It also fixes a second core: winning consumed the node, and this branch
		# never checked `cleared`, so the next ship to arrive rolled a fresh
		# custodian and killed the galaxy's boss again. FIGHT has checked that
		# since it was written; GOAL never did.
		#
		# So the core is a place you arrive at now. The sector says what is out
		# there and the button says ENGAGE, which is the wiring a resumed run has
		# always used — `_on_action` and `_quiet_lines` both already had the
		# case, and this makes it the ordinary path instead of the restored one.
		MapGen.NodeType.GOAL:
			if n.cleared:
				Run.log_line("The core is open. The light is behind you.", &"good")
			else:
				Run.log_line("The core fills the viewport. Something is guarding it. Engage when you are ready.", &"big")
			show_sector()
		MapGen.NodeType.FIGHT:
			if n.cleared:
				show_sector()
			else:
				engage_here()
		_:
			show_sector()

## Decide what is waiting at a system, once, and leave it on the node so the
## save carries it. Cleared nodes are left alone — whatever was here is resolved
## and re-rolling it would put it back.
##
## Both of these used to be rolled at the moment the screen opened, which meant
## quitting and resuming rolled them again: a bad enemy draw or a hail with two
## bad options cost nothing to refuse. That is save-scumming through the front
## door, and it defeats "every death is self-authored" without touching a
## number. Idempotent by design — it is also the lazy path for saves written
## before the node carried these.
func _roll_here(n: MapGen.MapNode) -> void:
	if n.cleared:
		return
	match n.type:
		MapGen.NodeType.FIGHT:
			if n.foes.is_empty():
				n.foes = _roll_foes(n)
		MapGen.NodeType.EVENT:
			if n.event_key.is_empty():
				n.event_key = EventTable.pick_key(Rng.derive(&"event", n.index))
		_:
			pass
	_roll_ambush(n)

## Whether anything followed your heat trail in.
##
## Rolled here with the rest of what a system holds, and for the same reason:
## arriving is the safe point, so a hostile your own throttle attracted cannot
## be refused by quitting and coming back cold. Combat nodes are excluded
## because they already hold a fight — being ambushed on the way to a fight is
## the fight.
func _roll_ambush(n: MapGen.MapNode) -> void:
	if n.ambush_rolled or n.type == MapGen.NodeType.FIGHT \
			or n.type == MapGen.NodeType.GOAL:
		return
	n.ambush_rolled = true
	# The ambush roll itself is a stream draw, not a positional one, and that is
	# deliberate: whether something notices you depends on YOUR signature, so
	# four ships arriving at one system do not all get jumped or all slip past.
	# What is waiting IF you are jumped is positional, like everything else that
	# lives at a node.
	if Rng.foe.randf() < Run.ambush_chance(n):
		n.ambush = _roll_foes(n)

## The contact and its pack. Packs appear deeper in, and more often in lawless
## space where nobody is flying alone. They split health rather than doubling it
## — see Combat.start.
## Positional. What is flying at a system is a property of the system, and
## `n.foes` is already saved per node — so this was ALREADY meant to be decided
## once and stay decided. It just had no way to say so across two machines.
func _roll_foes(n: MapGen.MapNode) -> Array[StringName]:
	var r := Rng.derive(&"foes", n.index)
	var out: Array[StringName] = []
	var pool := DB.fight_pool(n.danger, n.region == MapGen.Region.FAUNA)
	out.append(Rng.pick(r, pool))
	var lead: EnemyTemplate = DB.enemies[out[0]]
	if n.danger >= 2 and not lead.boss and not lead.fauna:
		var odds := 0.45 if n.region == MapGen.Region.LAWLESS else 0.22
		if r.randf() < odds:
			out.append(Rng.pick(r, DB.fight_pool(n.danger, false)))
	return out

## Dock. Reached from the sector, not on arrival.
func show_station() -> void:
	Audio.music_state(&"station")
	play_dock()
	var s := StationScreen.new()
	_swap(s)
	s.setup()

## Open the hail. The node is NOT consumed here — event_resolved() does that
## when the outcome actually lands. Marking it on open meant the swap below
## autosaved a cleared node while the picked event existed only inside
## EventScreen, so a force-quit at the hail resumed onto a system whose signal
## had stopped and which gave nothing.
##
## The pick lives on the node, decided on arrival by _roll_here(). Two reasons,
## and only the first is about quitting. HudBar.refresh() only greys tabs while
## in_combat(), which an event is not, so all five stay lit and the screen can be
## swapped out from under a live hail; rolling a fresh event on the way back
## would make leaving and returning a re-roll until the options pay. Holding it
## in Router covered that but not a force-quit, because Router is not saved and
## the node is.
func show_event() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n.cleared:
		return
	_roll_here(n)
	Audio.music_state(&"event")
	var e := EventScreen.new()
	_swap(e)
	e.setup(EventTable.by_key(n.event_key))

## The hail has been answered: the outcome is already on RunState, so the node
## is consumed at that instant and not a moment later. Waiting for CONTINUE
## would let you take the outcome, leave through a HUD tab, and answer the same
## hail again — and the autosave that runs on the way out would bank both.
func event_resolved() -> void:
	Run.consume_node(Run.node_at())

## Fly the beam.
##
## The one node type that is a deliberate trade rather than a fight or a shop:
## a neutron star's wind is the densest fuel source in the galaxy and its
## radiation is the most reliable way to lose a hull. You come away with a full
## tank and exotic matter worth studying, and you pay for it in the only
## currency the ship cannot buy back cheaply.
func harvest_pulsar() -> void:
	var n: MapGen.MapNode = Run.node_at()
	Run.harvest_pulsar()
	if Run.dead:
		show_game_over()
		return
	# A beam that has been sweeping this long has swept other people. Read before
	# the screen swaps, so the line lands in the log the sector is about to draw.
	Archive.recover_at(n, "pulled out of a pulsar's sweep")
	show_sector()

## Strip the wreck, then stay where you are: the salvage rail on the sector
## screen already shows what came aboard, so a separate loot screen was one
## transition too many.
func salvage_here() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n.cleared:
		return
	await _resolve_derelict(n)

## A wreck is the one thing in the game today that two ships can genuinely race
## for, so this is the one place that ASKS the party rather than assuming.
##
## Everything else that finishes a system — the fight you won, the hail you were
## inside — cannot be taken out from under you, and `Run.take_whole()` tells the
## party without waiting. Here the answer decides whether any loot is rolled at
## all, and rolling it first and apologising afterwards does not take the module
## back out of the loser's hold.
func _resolve_derelict(n: MapGen.MapNode) -> void:
	if not await Run.take_option(n, MapGen.OPTION_WHOLE):
		var who := Net.taker_name(n.index, MapGen.OPTION_WHOLE)
		Run.log_line("The bays are already stripped.%s" % (
			" %s got here first." % who.to_upper() if who != "" else ""), &"them")
		show_sector()
		return
	# Positional: what is in the wreck is in the wreck, whoever opens it and in
	# whatever order. See Rng.derive().
	var r := Rng.derive(&"salvage", n.index)
	var count := 2 if n.region == MapGen.Region.LAWLESS else 1
	for i in count:
		var force := n.manufacturer if n.region == MapGen.Region.TERRITORY else &""
		Run.stow(LootGen.roll_module(n.danger, force,
			n.region == MapGen.Region.CORE or n.region == MapGen.Region.FAUNA, r))
	# Precursor fragments come off deep wrecks and nowhere else in normal space.
	# They are the one material with no manufactured source, which is what makes
	# RELIC ANALYSIS a reason to have flown coreward rather than a recipe you
	# grind toward at the rim.
	if MapGen.tier(n.danger) >= 4 and r.randf() < 0.30:
		Run.add_material(&"relic", 1)
		Run.log_line("Something in the wreck predates the wreck. Precursor fragment recovered.", &"good")
	if r.randf() < 0.35:
		Run.find_hull(LootGen.roll_hull(n.danger, r))
		Run.log_line("A flyable hull is still attached: %s" % Run.found_hull.display_name(), &"good")
	Run.log_line("Derelict stripped. %d module%s recovered." % [
		count, "" if count == 1 else "s"], &"good")
	Archive.recover_at(n, "stripped out of a derelict")
	show_sector()

## `extras` is what the node already rolled. It is a parameter rather than
## something rolled in here so that the fight a node offers is decided once, at
## arrival, and survives a save — see _roll_here().
## `share` is whether the party can be in this one.
##
## True for the fight a SYSTEM holds — that is a fact about a place, so every
## machine derived the same enemies from the same node index and a second ship
## arriving is arriving at the same frigate.
##
## FALSE for an ambush, and the reason is in `_roll_ambush`: whether something
## noticed you is rolled off `Rng.foe`, a stream, precisely so that four ships
## at one system do not all get jumped. Two players' ambushes at the same node
## are two different events that happen to share an address, and joining one to
## the other would be joining a fight that is not there.
func start_combat(template: EnemyTemplate, extras: Array = [],
		clears_node: bool = true, share: bool = true) -> void:
	# Bosses are hand-tuned set pieces, so they get the dread cue rather than
	# the theme at full intensity. DREAD_NOTES §5, "boss reveal".
	Audio.music_state(&"boss" if template.boss else &"combat")
	Run.node_at().fled = false
	combat = Combat.new()
	combat.clears_node = clears_node
	var s := SectorScreen.new()
	_swap(s)
	# Connect before starting. Turn one resolves inside start() — charges, opening
	# log lines, even an instant win — and a screen wired up afterwards misses all
	# of it.
	s.setup(combat)
	var node: MapGen.MapNode = Run.node_at()
	# Development: `-- fight foes=3` forces a pack. Multi-enemy layout only
	# exists at danger 2+ behind a 22% roll, so seeing two on screen was a
	# matter of waiting rather than looking. It overrides the node's own roll,
	# which is the point of the flag.
	var forced := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("foes="):
			forced = clampi(int(a.split("=")[1]), 1, 4)
	if forced > 1:
		var pool0 := DB.fight_pool(maxi(node.danger, 1), false)
		extras = []
		for i in forced - 1:
			extras.append(DB.enemies[Rng.pick(Rng.foe, pool0)])
	# Built, then offered to the party, then opened. `plan()` produces the hull
	# numbers the host is told, so danger scaling and the pack split stay in
	# `Combat._spawn` rather than being worked out a second time in the session
	# layer — see Combat.plan().
	combat.plan(template, node.danger, extras)
	var f: SharedFight = null
	if share:
		# One round trip on a client, none on the host, and null in the solo
		# game. Null means "fight it alone", which is what every one of those
		# three wants when there is nobody else here.
		f = await Net.open_fight(node.index, combat.foe_ids(),
			combat.foe_hp(), combat.foe_brace())
		if f != null and f.crew.size() > 1:
			var names := Net.fight_crew_names(node.index)
			Run.log_line("Fighting alongside %s." % ", ".join(names).to_upper(), &"good")
	combat.begin(f)

## Start the fight waiting at this system.
##
## Only reachable after a resume: arriving at a combat node normally begins the
## fight inside resolve_current_node(), so the sector never draws with an
## unfought contact in it. A restored run does exactly that, and the action
## button that says ENGAGE has to mean it.
func engage_here() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n.cleared or in_combat():
		return
	if n.type == MapGen.NodeType.GOAL:
		start_combat(DB.enemies[&"custodian"])
		return
	# Whatever this system rolled when you arrived, including on a run restored
	# from disk. _roll_here() is idempotent, so this also covers a save written
	# before the node carried its foes.
	_roll_here(n)
	var extras: Array = []
	for i in range(1, n.foes.size()):
		extras.append(DB.enemies[n.foes[i]])
	start_combat(DB.enemies[n.foes[0]], extras)

## Events can drop you straight into a fight (distress-beacon bait).
##
## Not shared, and not because of the enemy: the fight is drawn from `Rng.foe`
## rather than from the node, so two players who took the same bait are not
## looking at the same ship. The event that produced it was a private
## conversation and so is what came out of it.
func start_ambush() -> void:
	var pool := DB.fight_pool(Run.node_at().danger, false)
	start_combat(DB.enemies[Rng.pick(Rng.foe, pool)], [], true, false)

func in_combat() -> bool:
	return combat != null and not combat.finished

func after_combat(_c: Combat) -> void:
	combat = null
	# An ambush is spent whatever happened to it — killed, pacified or shaken
	# off. Left on the node it would fire again the next time you flew in here,
	# and the heat that attracted it is not the heat you are carrying now.
	Run.node_at().ambush = []
	if Run.dead or Run.won:
		show_game_over()
		return
	show_loot_or_map()

func after_event() -> void:
	if Run.dead:
		show_game_over()
		return
	show_loot_or_map()

## Salvage is resolved where it was found, not on a screen of its own. The
## sector shows what is in the hold and lets you fit or scrap it there.
func show_loot_or_map() -> void:
	show_sector()

## Recorded and the save dropped the moment the run ends, not when the summary
## screen appears — a player who alt-F4s on the death screen has still died, and
## a suspend save that outlived the run would resurrect them.
func _on_run_ended(won: bool, reason: String) -> void:
	SaveGame.clear()
	RunHistory.record(
		RunHistory.Outcome.WON if won else RunHistory.Outcome.DIED, reason)
	## screens call show_game_over() so the player sees the summary first

## Docking clamps. Sig has no "you docked" signal and adding one for a single
## sound would be noise in the bus, so the screen that opens plays it.
func play_dock() -> void:
	Audio.play(&"station_dock", 0.03)
