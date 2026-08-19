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
func _autosave() -> void:
	if Run.hull == null or Run.dead or Run.won or in_combat():
		return
	SaveGame.save()

## Title screen. Boots here unless a development flag says otherwise.
func show_launcher() -> void:
	# &"menu", not &"sector" — the launcher runs with no run loaded, so the
	# sector arrangement was both the wrong music and the only state in the
	# table nothing ever asked for.
	Audio.music_state(&"menu")
	_swap(LauncherScreen.new(), false)
	(current as LauncherScreen).setup()

## Opens on the sector rather than the chart: the run starts with your ship in
## open space, not with a graph of places you have not been yet.
##
## A run that was live when this is called was abandoned, not finished, and goes
## into the record as such — restarting a bad opening is a real outcome and
## pretending otherwise would quietly inflate the win rate.
func new_run() -> void:
	if Run.hull != null and not Run.dead and not Run.won:
		RunHistory.record(RunHistory.Outcome.ABANDONED, "Abandoned mid-run.")
	SaveGame.clear()
	Run.start_new_run()
	show_sector()

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

	# Every arrival lands on the sector. You should see the place before you are
	# asked to do anything with it — a station is a lit hab ring turning in the
	# dark, not a menu that appears. Fights are the exception only in that they
	# start immediately, and combat happens on the sector screen anyway.
	match n.type:
		MapGen.NodeType.GOAL:
			Run.log_line("The core fills the viewport. Something is guarding it.", &"big")
			start_combat(DB.enemies[&"custodian"])
		MapGen.NodeType.FIGHT:
			if n.cleared:
				show_sector()
			else:
				var pool := DB.fight_pool(n.danger, n.region == MapGen.Region.FAUNA)
				start_combat(DB.enemies[pool.pick_random()])
		_:
			show_sector()

## Dock. Reached from the sector, not on arrival.
func show_station() -> void:
	Audio.music_state(&"station")
	play_dock()
	var s := StationScreen.new()
	_swap(s)
	s.setup()

## Open the hail. The node is marked resolved here rather than on arrival, so
## looking at an event without engaging it does not consume it.
func show_event() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n.cleared:
		return
	n.cleared = true
	Audio.music_state(&"event")
	var e := EventScreen.new()
	_swap(e)
	e.setup(EventTable.pick())

## Fly the beam.
##
## The one node type that is a deliberate trade rather than a fight or a shop:
## a neutron star's wind is the densest fuel source in the galaxy and its
## radiation is the most reliable way to lose a hull. You come away with a full
## tank and exotic matter worth studying, and you pay for it in the only
## currency the ship cannot buy back cheaply.
func harvest_pulsar() -> void:
	Run.harvest_pulsar()
	if Run.dead:
		show_game_over()
		return
	show_sector()

## Strip the wreck, then stay where you are: the salvage rail on the sector
## screen already shows what came aboard, so a separate loot screen was one
## transition too many.
func salvage_here() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n.cleared:
		return
	_resolve_derelict(n)

func _resolve_derelict(n: MapGen.MapNode) -> void:
	n.cleared = true
	var count := 2 if n.region == MapGen.Region.LAWLESS else 1
	for i in count:
		var force := n.manufacturer if n.region == MapGen.Region.TERRITORY else &""
		Run.cargo.append(LootGen.roll_module(n.danger, force,
			n.region == MapGen.Region.CORE or n.region == MapGen.Region.FAUNA))
	if randf() < 0.35:
		Run.found_hull = LootGen.roll_hull(n.danger)
		Run.log_line("A flyable hull is still attached: %s" % Run.found_hull.display_name(), &"good")
	Run.log_line("Derelict stripped. %d module%s recovered." % [
		count, "" if count == 1 else "s"], &"good")
	show_sector()

func start_combat(template: EnemyTemplate) -> void:
	# Bosses are hand-tuned set pieces, so they get the dread cue rather than
	# the theme at full intensity. DREAD_NOTES §5, "boss reveal".
	Audio.music_state(&"boss" if template.boss else &"combat")
	Run.node_at().fled = false
	combat = Combat.new()
	var s := SectorScreen.new()
	_swap(s)
	# Connect before starting. Turn one resolves inside start() — charges, opening
	# log lines, even an instant win — and a screen wired up afterwards misses all
	# of it.
	s.setup(combat)
	# Packs appear deeper in, and more often in lawless space where nobody is
	# flying alone. They split health rather than doubling it — see Combat.start.
	var node: MapGen.MapNode = Run.node_at()
	var extras: Array = []
	# Development: `-- fight foes=3` forces a pack. Multi-enemy layout only
	# exists at danger 2+ behind a 22% roll, so seeing two on screen was a
	# matter of waiting rather than looking.
	var forced := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("foes="):
			forced = clampi(int(a.split("=")[1]), 1, 4)
	if forced > 1:
		var pool0 := DB.fight_pool(maxi(node.danger, 1), false)
		for i in forced - 1:
			extras.append(DB.enemies[pool0.pick_random()])
		combat.start(template, node.danger, extras)
		return
	if node.danger >= 2 and not template.boss and not template.fauna:
		var odds := 0.45 if node.region == MapGen.Region.LAWLESS else 0.22
		if randf() < odds:
			var pool := DB.fight_pool(node.danger, false)
			extras.append(DB.enemies[pool.pick_random()])
	combat.start(template, node.danger, extras)

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
	var pool := DB.fight_pool(n.danger, n.region == MapGen.Region.FAUNA)
	start_combat(DB.enemies[pool.pick_random()])

## Events can drop you straight into a fight (distress-beacon bait).
func start_ambush() -> void:
	var pool := DB.fight_pool(Run.node_at().danger, false)
	start_combat(DB.enemies[pool.pick_random()])

func in_combat() -> bool:
	return combat != null and not combat.finished

func after_combat(_c: Combat) -> void:
	combat = null
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
