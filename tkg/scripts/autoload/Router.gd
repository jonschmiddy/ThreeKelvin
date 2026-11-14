extends Node
## Screen flow. Owns the single content container and swaps screens into it,
## and decides what happens when you arrive at a map node.

var content: Control
var hud: HudBar
var current: Control
var combat: Combat
## The sky lives here, not in a screen, so swapping screens leaves the world alone.
var sky: SpaceLayer
## THE SPACE LOCAL, THE MAP AND THE CHART ARE BUILT ON (`NavField`): one field
## of stars under all three, kept through every move between them.
var field: NavField
## Not on Run and not a Sig signal: it is which side of the airlock you are on.
## Why: docs/why/Router.md#docked-state
var docked: bool = false:
	set(v):
		if not v:
			powered.clear()
			undock_nudge = false
		if v != docked:
			# (partners see you dock and undock: `NetSession`'s presence)
			Net._mark_presence()
		docked = v

## Powered-on decks are remembered per docking, so a chart round trip does not replay them.
## Why: docs/why/Router.md#docked-state
var powered := {}

func register(content_holder: Control, hud_bar: HudBar) -> void:
	content = content_holder
	hud = hud_bar
	# First child, so every screen draws in front. `_swap` never frees the sky.
	sky = SpaceLayer.new()
	content.add_child(sky)
	field = NavField.new()
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(field)
	Sig.jumped.connect(_on_jumped)
	Sig.run_started.connect(_on_run_started)
	Sig.run_ended.connect(_on_run_ended)
	Sig.combat_started.connect(func(enemy: String) -> void:
		crumb("[fight] start: %s" % enemy))
	Sig.combat_ended.connect(func(result: StringName, _s: String) -> void:
		crumb("[fight] end: %s, hull %d/%d" % [result, Run.hp, Run.max_hp()]))


## Screen changes are logged to godot.log so a bug report can say where the player was.
## Off under the balance sim, which plays hundreds of runs.
## Why: docs/why/Router.md#breadcrumbs
var _crumbs := not "sim" in OS.get_cmdline_user_args()

func crumb(line: String) -> void:
	if _crumbs:
		print(line)


## Closing the window saves like SAVE & EXIT, as the autosave only runs on a screen change.
## Waits for a worker flight plan before quit, or the quit crashes (signal 11).
## Why: docs/why/Router.md#closing-the-window
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_on_close()
		_drain_flights()
	elif what == NOTIFICATION_PREDELETE:
		_drain_flights()


## (by path, and only once the map's flight has been loaded: no ship, no plan)
const _FLIGHT_GD := "res://scripts/ui/sysmap/ShipFlight.gd"
func _drain_flights() -> void:
	if ResourceLoader.has_cached(_FLIGHT_GD):
		load(_FLIGHT_GD).drain()

func save_on_close() -> void:
	if in_combat():
		if Run.hull != null and not Run.dead and not Run.won:
			SaveGame.mark_fight(current_fight)
			crumb("[run] window closed mid-fight; the fight starts again on resume")
		return
	_autosave()
	if SaveGame.has_save():
		crumb("[run] window closed, run saved")

## Whose pair the screen just left showed, and on which frame. -1 for any other screen.
var _left_pair := -1
var _left_frame := -100


static func _pair_of_screen(sc: Control) -> int:
	if sc == null or not is_instance_valid(sc):
		return -1
	if sc is SystemMapScreen:
		var m := sc as SystemMapScreen
		return m.view.node.index if m.view != null and m.view.node != null else -1
	if sc is SectorScreen:
		var v := (sc as SectorScreen)._view
		if v != null and is_instance_valid(v.backdrop) and v.backdrop.node != null:
			return v.backdrop.node.index
	return -1


## A map or LOCAL is handed its pair by the picture before it, else it takes the party clock.
## Why: docs/why/Router.md#pair-handover
func pair_handed(at: int) -> bool:
	if current is SystemMapScreen and _pair_of_screen(current) == at:
		return true
	return _left_pair == at and _left_frame == Engine.get_process_frames()


## `chrome` says whether the HUD sits above the screen; the title has no ship to read.
## The outgoing screen is hidden, not just queued: a late redraw on moved-on state logs errors.
## Why: docs/why/Router.md#screen-swap
func _swap(screen: Control, chrome: bool = true) -> void:
	# The page sound is for moving between pages: boot and swaps to or from the title are silent.
	# Why: docs/why/Router.md#page-sound
	if current == null or is_front_door(current) or is_front_door(screen):
		Audio.suppress(&"ui_tab", 100)
	# ONE CAMERA, FOUR DISTANCES (`ZoomLadder`): the picture being left is held
	# here, before it goes, and carried into the one arriving
	if current != null:
		ZoomLadder.capture(current, screen)
	# (whose pair the screen being left showed, before its hide: `pair_handed`)
	_left_pair = _pair_of_screen(current)
	_left_frame = Engine.get_process_frames()
	if current != null:
		current.hide()
		current.queue_free()
	# a dock open over the station goes with it
	dock = null
	current = screen
	var sname: String = screen.get_class()
	if screen.get_script() != null and String(screen.get_script().get_global_name()) != "":
		sname = String(screen.get_script().get_global_name())
	crumb("[screen] %s" % sname)
	content.add_child(screen)
	var room: Variant = _room_for(screen)
	if room != null:
		Audio.room(room)
	if hud != null:
		hud.visible = chrome
	_refresh_sky()
	_fade_in(screen)
	Sig.screen_changed.emit()
	# Leaving the core's body by any other door still ends on the win screen (backstop).
	if final_loot and (screen is GameOverScreen or is_front_door(screen)):
		final_loot = false
	elif final_loot:
		finish_core_loot.call_deferred()
	# (in the middle of a move, written when it lands: `ZoomLadder.save_after`)
	if ZoomLadder.busy():
		ZoomLadder.save_after = true
	else:
		_autosave()


## The screens before a run is under way: the title, the party lobby, and the
## hull pick. Leaving the hull pick is launching, and that was still clicking.
func is_front_door(s: Control) -> bool:
	return s is LauncherScreen or s is LobbyScreen or s is ChassisSelect

## Short enough that nobody waits on it, long enough to read as a change of place.
const FADE_S := 0.13

## Only the arriving screen fades; the outgoing one is freed at once, as `-- quittest` requires.
## Why: docs/why/Router.md#screen-fade
var seamless_next := false

func _fade_in(screen: Control) -> void:
	if seamless_next:
		seamless_next = false
		return
	if screen == null or not animating() or ZoomLadder.takes(screen):
		return
	screen.modulate.a = 0.0
	var tw := screen.create_tween()
	tw.tween_property(screen, "modulate:a", 1.0, FADE_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## No fade for the sim, headless or `-- ...shot` tools, which would photograph a dim screen.
## Why: docs/why/Router.md#animation-gating
func animating() -> bool:
	# Reduced motion is answered here once, so no other screen needs its own check.
	if DisplaySettings.reduced_motion:
		return false
	# `-- menutest` turns the animations ON headless: the menu hang it guards
	# only happened on the animated way out, which headless never took.
	if animate_in_harness:
		return true
	if "sim" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return false
	for a in OS.get_cmdline_user_args():
		if (a as String).ends_with("shot"):
			return false
	return true

## Set only by `-- menutest`, which needs the animated paths headless.
var animate_in_harness := false


## Each screen without the sky is excluded for its own reason, so this is a list, not a rule.
## Why: docs/why/Router.md#sky-exclusions
static func nav_screen(s: Control) -> bool:
	return s is SectorScreen or s is SystemMapScreen or s is StarchartScreen


func _refresh_sky() -> void:
	if sky == null:
		return
	var interior := current is StationScreen
	var has_own := current is LauncherScreen or current is StarchartScreen \
		or current is SectorScreen or current is SystemMapScreen
	sky.set_active(not interior and not has_own)
	if Run.map.size() > 0:
		sky.setup(Run.node_at())
	if field != null:
		field.set_on(nav_screen(current))
		if Run.map.size() > 0:
			field.setup(Run.node_at())

## Every safe point is a screen swap, so this one chokepoint writes the run.
## Skipped in combat, at the chassis pick and with an empty map (index error).
## Why: docs/why/Router.md#autosave
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

## The room is decided here because every screen change passes through. Null means no change.
## Why: docs/why/Router.md#room-you-are-in
func _room_for(screen: Control) -> Variant:
	if screen is StationScreen:
		return &"amb_station"
	if screen is ChassisSelect:
		return Audio.YARD_ROOM
	if screen is SectorScreen or screen is SystemMapScreen:
		return _star_room()
	# (the refit page, reached only by the harnesses now, sounds like where your
	# ship is: the berth or the system)
	if screen is ShipScreen:
		return &"amb_station" if docked else _star_room()
	if screen is CardGalleryScreen \
			or screen is ModuleGalleryScreen or screen is TransferScreen \
			or screen is StarchartScreen or screen is HistoryScreen:
		return null
	return &""


## Open space plays the reactor hum (Jon cut the space tone as distracting).
## Revert a hunk, never a file: this line was lost once in a whole-file revert.
## Why: docs/why/Router.md#star-room
func _star_room() -> StringName:
	var n: MapGen.MapNode = Run.here()
	if n == null:
		return &""
	if n.type == MapGen.NodeType.PULSAR:
		return &"amb_pulsar"
	match n.star:
		MapGen.Star.RED: return &"amb_red"
		MapGen.Star.BLUE: return &"amb_blue"
	return &"amb_space"


func show_lobby() -> void:
	Audio.music_state(&"lobby")
	_swap(LobbyScreen.new(), false)
	(current as LobbyScreen).setup()

## Title screen. Boots here unless a development flag says otherwise.
func show_launcher() -> void:
	# `&"menu"`, not `&"sector"`: the launcher has no run and nothing asked for the sector state.
	Audio.music_state(&"menu")
	# The first title comes out of the boot splash, so it arrives unfaded to avoid a blink.
	# Why: docs/why/Router.md#boot-splash-handover
	var boot := current == null
	if boot:
		seamless_next = true
	_swap(LauncherScreen.new(), false)
	(current as LauncherScreen).setup()
	if boot:
		(current as LauncherScreen).fade_up_around_title()

## A new or restored run must drop the last run's fight, or `in_combat()` stays true forever.
## Hung on the signal, as `new_run()` and `load_into_run()` both emit it.
## Why: docs/why/Router.md#run-start-reset
func _on_run_started() -> void:
	# Let go of the `Sig` bus first: a dropped fight's connections would outlive it.
	drop_combat()
	final_loot = false
	# Quitting from a berth must not carry its dock into the next run's first arrival.
	docked = false
	# Parked ship spots are kept by system index, so a new run must not inherit them.
	SystemMapScreen._parked.clear()
	Moored.at = -1
	# Same for the event last opened on LOCAL, also kept by system index.
	LocalEventDrawer.last = []
	# (and where the map flew it, which LOCAL arrived at and which station is
	# lit: the last run's, by the same numbers)
	SectorScreen.forget_places()

## Dropping a fight must leave the party, or the partners sit on WAIT <name> (review, Nov 5).
## Why: docs/why/Router.md#dropping-a-fight
func drop_combat() -> void:
	if combat != null:
		combat.abandon()
	combat = null


## `start_new_run()` rolls a world and hull first so every screen has a valid hull to draw.
## A run abandoned here goes to the record as such, so restarts do not inflate the win rate.
## Why: docs/why/Router.md#new-run
func new_run(seed_value: int = 0) -> void:
	if Run.hull != null and not Run.dead and not Run.won:
		RunHistory.record(RunHistory.Outcome.ABANDONED, "Abandoned mid-run.")
	SaveGame.clear()
	var was := Rng.forced
	if seed_value != 0:
		Rng.forced = seed_value
	Run.start_new_run()
	Rng.forced = was
	# the run's star chart built on a worker while the hull is picked, not on
	# the click that first opens it (`MapChart.build_ahead`)
	MapChart.build_ahead()
	show_chassis_select()

func show_chassis_select() -> void:
	# The yard is a shipyard, not the title: no score, its own bed as the room (Jon, Nov 11).
	# Why: docs/why/Router.md#yard-sound
	Audio.music_state(&"yard")
	var s := ChassisSelect.new()
	# No HUD over the yard (Jon's W2 v10): the hall is the whole picture.
	_swap(s, false)
	s.setup()
	# A new run opens on LOCAL (Jon). No tour: hints teach each thing when it first matters.
	# Why: docs/why/Router.md#new-run-opening
	s.launched.connect(func() -> void: show_local())

## Falls back to the launcher, not a new run: CONTINUE never asked to start over.
func continue_run() -> void:
	if not SaveGame.load_into_run():
		Run.log_line("The save could not be read.", &"them")
		show_launcher()
		return
	crumb("[run] resumed, seed %d, jump %d, %s" % [Run.galaxy_seed, Run.jumps, BuildInfo.stamp()])
	# (and its star chart, as a new run's: `MapChart.build_ahead`)
	MapChart.build_ahead()
	# QUIT BETWEEN THE CORE'S KILL AND ITS BODY: back to the body, to click.
	if Run.won and core_body_here() != null:
		await_core_body()
		return
	resume_here()

## Resume lands on the sector and offers the pending fight (ENGAGE) rather than starting it.
## Why: docs/why/Router.md#resuming-a-run
func resume_here() -> void:
	var f := fight_on_resume
	fight_on_resume = {}
	show_sector()
	# A RUN SAVED MID-MOVE comes back to the move: nothing else shows the pad,
	# and nothing leaves while it is loaded. (Docked, the station opens it.)
	if not Run.pad.is_empty() and not docked:
		show_transfer()
		return
	# A fight saved out of restarts from its first turn with the same enemies.
	var ids: Array = f.get("ids", [])
	if ids.is_empty() or not DB.enemies.has(StringName(ids[0])):
		return
	if _saved_fight_over(f):
		Run.log_line("The fight ended while you were away.", &"them")
		return
	var extras: Array = []
	for i in range(1, ids.size()):
		if DB.enemies.has(StringName(ids[i])):
			extras.append(DB.enemies[StringName(ids[i])])
	start_combat(DB.enemies[StringName(ids[0])], extras,
		bool(f.get("clears", true)), bool(f.get("share", true)))

## A saved-out fight the party has since finished must not restart as a second fight.
## Why: docs/why/Router.md#saved-fight-over
func _saved_fight_over(saved: Dictionary) -> bool:
	if not Net.is_networked() or not bool(saved.get("share", true)):
		return false
	var ids: Array = saved.get("ids", [])
	var f := Net.fight_at(Run.at)
	if f != null and f.over and (f.paid > 0 or f.broke):
		var theirs: Array = []
		for id in f.foe_ids:
			theirs.append(String(id))
		if theirs == ids:
			return true
	var n: MapGen.MapNode = Run.node_at()
	if bool(saved.get("clears", true)) and n != null and n.cleared:
		return true
	return String(ids[0]) == "hellbender" and \
			(not Run.hellbender_alive() or Run.hellbender_at != Run.at)


## `back` is where LEAVE returns to, so three screens can reach the HUD.
func show_party() -> void:
	if in_combat():
		return
	var here := current
	var s := PartyScreen.new()
	_swap(s)
	s.setup((show_station if docked else show_local) if here is ShipScreen else (
		show_starchart if here is StarchartScreen else show_sector))

## Rescan before drawing: sight is a snapshot but reach is live, so they can disagree.
## Why: docs/why/Router.md#starchart-rescan
func show_starchart() -> void:
	# (no chart in a fight: back to it, or nothing if it is up -- `fight_up`)
	if in_combat() or fight_up():
		show_local()
		return
	Run.chart_from(Run.node_at())
	_show_starchart()


func _show_starchart() -> void:
	# The chart is the only place jumps are offered, so it is the one chokepoint
	# where being out of fuel has to resolve rather than stall.
	Run.check_stranded()
	if Run.dead:
		show_game_over()
		return
	# the screen being left moves toward the chart first (`ZoomLadder`)
	if ZoomLadder.preroll(ZoomLadder.CHART, _show_starchart):
		return
	Audio.music_state(&"chart")
	# (built ahead while the screen being left moved: shown as it is)
	var pre: Control = ZoomLadder.take_prebuilt(ZoomLadder.CHART)
	if pre != null:
		_swap(pre)
		return
	var s := StarchartScreen.new()
	_swap(s)
	s.setup()

## The callers that mean back to the place come through here and land where the place is.
## Why: docs/why/Router.md#show-sector
func show_sector() -> void:
	# A Hellbender at anchor no longer shuts the map; docked, back to the place is the berth.
	# Jon's Oct 22 and Oct 27 rulings.
	# Why: docs/why/Router.md#show-sector
	if over_berth():
		show_station()
		return
	# UNDOCKING IS ONE DISTANCE OUT (`ZoomLadder`): the station's berth to LOCAL,
	# beside the station, where DOCK takes you back in and the map is a Tab away
	if docked and current is StationScreen and ZoomLadder.chosen():
		# (LOCAL comes up mirrored, your ship moored on the station's right: built
		# ahead at this click)
		Moored.moor(Run.at)
		show_local()
		return
	if in_combat() or fight_up() or _post_depart >= 0:
		show_local()
	else:
		_undock()
		show_system()


## A view, not a move: from the berth it shows the system without undocking.
func show_system() -> void:
	if Run.dead:
		show_game_over()
		return
	# (and open with the Hellbender anchored here: its place is on the map, the
	# one way to it -- see `show_sector`)
	if in_combat() or fight_up():
		show_local()
		return
	if ZoomLadder.preroll(ZoomLadder.MAP, show_system):
		return
	# The map plays its own arrival, so the side-on approach is spent here.
	var arrived: bool = take_arrival()[0]
	if arrived:
		SectorScreen._approached_at = Run.at
		ZoomLadder.drop_prebuilt()
	Audio.music_state(&"sector")
	# (built ahead while the screen being left moved: shown as it is)
	var pre: Control = ZoomLadder.take_prebuilt(ZoomLadder.MAP) if not arrived else null
	if pre != null:
		_swap(pre)
		return
	var s := SystemMapScreen.new()
	# A jump's arrival is not a move between distances: the departure's LOCAL is another system.
	# Why: docs/why/Router.md#system-map-arrival
	if arrived:
		ZoomLadder.hold_off = true
	_swap(s)
	ZoomLadder.hold_off = false
	# Kept map clock, or the party's in co-op unless LOCAL just handed over the pair.
	s.show_system(Run.node_at(), Net.handed_clock(Run.at) if pair_handed(Run.at) and not arrived else Net.adopt_clock(Run.at), arrived)


## Leaving the berth, by whichever door.
func _undock() -> void:
	if docked:
		Audio.suppress(&"ui_tab", 200)
		if ResourceLoader.exists(Audio.SFX_PATH % &"station_undock"):
			Audio.play(&"station_undock", 0.03)
		SectorScreen._approached_at = Run.at
	docked = false


## UNDOCK is the only way out (Jon, Oct 27): a move from the berth is refused and says how.
## A loaded pad also holds the ship in space, so this is the backstop.
## Why: docs/why/Router.md#undock-only-way-out
func cast_off() -> bool:
	if docked:
		Audio.denied()
		Run.log_line(DOCKED_LINE, &"them")
		# (UNDOCK blinks, now or when the station is next up)
		undock_nudge = true
		Sig.undock_wanted.emit()
		return false
	if Run.pad.is_empty():
		return true
	Audio.denied()
	Run.log_line("Cannot leave: %d thing%s still on the pad." % [Run.pad.size(),
		"" if Run.pad.size() == 1 else "s"], &"them")
	return false


## Whether `cast_off` would let the ship go: what the map's second click and GO and
## the chart's JUMP read to say DOCKED (or CANNOT UNDOCK) before they are pressed.
func may_cast_off() -> bool:
	return not docked and Run.pad.is_empty()


## What every way off the berth but UNDOCK says (Jon, Oct 27): the HUD's LOCAL
## greyed at the station, the map's second click and GO, the chart's JUMP.
const DOCKED_LINE := "Docked. Press UNDOCK to leave."
## A way out was refused while the station was not up: it blinks UNDOCK when
## it is. Cleared by leaving the berth (`docked`).
var undock_nudge := false


## A page looked at from the berth: docked, with a screen up that is not the station.
func over_berth() -> bool:
	return docked and current != null and is_instance_valid(current) \
		and not (current is StationScreen) and not is_front_door(current)


## DOCK is offered only at the station itself (Jon, Oct 18), the other half of `cast_off`.
## Why: docs/why/Router.md#docking-place
func at_station(n: MapGen.MapNode = null) -> bool:
	if n == null:
		n = Run.node_at()
	if n == null or n.type != MapGen.NodeType.STATION:
		return false
	if docked and n == Run.node_at():
		return true
	var place := SystemLayout.of(n).dock_place()
	if place < 0:
		return false
	var m := current as SystemMapScreen
	if m != null and is_instance_valid(m) and m.view != null and m.view.node == n and m.flight != null:
		# (what the map keeps for LOCAL, so a LOCAL built ahead of the swap and
		# the one swapped in agree: `SystemMapScreen.ship_place`)
		return m.ship_place() == place
	return Run.site_here(n) == place


## What a DOCK says where the ship is not at the station (its tooltip, the map
## card's line). Plain, and the way to it.
const DOCK_AWAY := "Fly to the station to dock."


## Parks the ship at the station body, for harness and run-start doors, never a player.
func park_at_station(n: MapGen.MapNode = null) -> void:
	if n == null:
		n = Run.node_at()
	if n == null or n.type != MapGen.NodeType.STATION:
		return
	var place := SystemLayout.of(n).dock_place()
	if place >= 0:
		SystemMapScreen._parked[n.index] = {"at": place, "mode": &"rail"}


## No combat guard: `after_combat()` routes here from inside the fight.
## Docked, only UNDOCK comes here (Jon, Oct 27).
## Why: docs/why/Router.md#show-local
func show_local() -> void:
	if fight_up():
		return
	# Write where the map left the ship before LOCAL is built from it, or its sky is stale.
	if current is SystemMapScreen and is_instance_valid(current):
		(current as SystemMapScreen)._keep_ship()
	if ZoomLadder.preroll(ZoomLadder.LOCAL, show_local):
		return
	# (undocking: the station left lit on the LOCAL it lands on, `station_awake`)
	var undocking := docked
	# Set before the swap: `_swap` emits `screen_changed` and the HUD reads this flag in it.
	# Undocking is the ship moving, not a page change, so the thrusters sound.
	if docked:
		Audio.suppress(&"ui_tab", 200)
		# The clamps letting go, the other half of `play_dock`. Guarded on the
		# file: silent until a take is picked.
		if ResourceLoader.exists(Audio.SFX_PATH % &"station_undock"):
			Audio.play(&"station_undock", 0.03)
		# Undocking latches `_approached_at`: you do not fly in to a system you are already in.
		# Why: docs/why/Router.md#show-local
		SectorScreen._approached_at = Run.at
		# (and not at the station either: LOCAL's fly-in is for a place flown
		# to on the map, and the undock is this one's arrival)
		SectorScreen.arrived_here()
	docked = false
	Audio.music_state(&"sector")
	# (built ahead, at the click, while the map moved: shown as it is)
	var pre: Control = ZoomLadder.take_prebuilt(ZoomLadder.LOCAL)
	if pre != null:
		_swap(pre)
		if undocking and pre is SectorScreen:
			(pre as SectorScreen).station_awake()
		return
	var s := SectorScreen.new()
	_swap(s)
	# Hand the live fight back, or SECTOR after the card catalog shows an unwinnable empty sector.
	# Why: docs/why/Router.md#show-local
	s.setup(combat if in_combat() else null)
	# (a working station: lit as your ship leaves it, Jon, Oct 21)
	if undocking:
		s.station_awake()

## Refit screen. Reachable from the HUD any time you are not in a fight.
## Development only: every card in the game on one page. See CardGalleryScreen.
func show_cards() -> void:
	var here := current
	var s := CardGalleryScreen.new()
	_swap(s)
	s.setup(back_to(here))

## Dev only, as a catalogue answers a game about finding out what things do.
func show_modules() -> void:
	var here := current
	var s := ModuleGalleryScreen.new()
	_swap(s)
	s.setup(back_to(here))

## A gallery is not a place to go back to: anything unnamed falls to the sector.
## Why: docs/why/Router.md#back-from-galleries
func back_to(here: Control) -> Callable:
	if here is ShipScreen:
		# (the refit page has no tab now: back to where your ship is)
		return show_station if docked else show_local
	if here is StarchartScreen:
		return show_starchart
	if here is StationScreen:
		return show_station
	return show_sector

func show_ship() -> void:
	if in_combat():
		return
	Audio.music_state(&"ship")
	var s := ShipScreen.new()
	_swap(s)
	s.setup()

## No HUD: its tabs lead off a screen the ship cannot leave with crates on the ground.
## Opens over the Shipyard, so closing it leaves you in the same yard (Jon).
## Why: docs/why/Router.md#moving-day
func show_transfer() -> void:
	if move_open():
		return
	Audio.music_state(&"ship")
	var s := TransferScreen.new()
	if current is StationScreen and is_instance_valid(current):
		_open_dock(current as StationScreen, s)
		return
	_swap(s, false)
	s.setup()


## Whether the move (`TransferScreen`) is up: over the station, or a page of its
## own after a hull found in space.
func move_open() -> bool:
	if dock != null and is_instance_valid(dock):
		return true
	return current is TransferScreen and is_instance_valid(current)


## Back to where you stood: the yard, the berth, or LOCAL, not `show_station` everywhere.
func leave_transfer() -> void:
	if dock != null and is_instance_valid(dock):
		_close_dock()
	elif docked:
		show_station()
	else:
		show_local()


## A loaded pad at the berth must show the move, or UNDOCK refuses with no explanation.
## Why: docs/why/Router.md#moving-day
func _reopen_move() -> void:
	if Run.pad.is_empty() or move_open() or not docked:
		return
	if current is StationScreen:
		show_transfer()


## The dock over the station, while it is open. It is the station's own child,
## so anything that frees the station frees the dock with it.
var dock: Control = null

## How much of the station shows through: enough to know where you are standing.
const DOCK_DIM := 0.86


func _open_dock(station: StationScreen, s: TransferScreen) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UITheme.VOID, DOCK_DIM)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	layer.add_child(s)
	station.add_child(layer)
	s.setup()
	dock = layer
	if hud != null:
		hud.visible = false
	_fade_in(layer)
	Sig.screen_changed.emit()
	_autosave()


## Close the dock and hand the station back, brought up to date with the ship
## you are now standing beside.
func _close_dock() -> void:
	var station := current as StationScreen
	if is_instance_valid(dock):
		dock.queue_free()
	dock = null
	if hud != null:
		hud.visible = true
	Audio.music_state(&"station")
	if station != null:
		station._refresh()
	Sig.screen_changed.emit()
	_autosave()

func show_game_over() -> void:
	Audio.music_state(&"gameover")
	var s := GameOverScreen.new()
	# RUN ENDED draws over the picture the run ended on, with no fade and no HUD.
	var still := death_still
	var look := death_look
	death_still = null
	death_look = &""
	if still != null:
		seamless_next = true
	_swap(s, still == null)
	s.setup(still, look)

## Set by the fight as your ship is lost, read once by `show_game_over`.
var death_still: Texture2D = null
var death_look: StringName = &""

func jump_to(index: int) -> void:
	Run.jump_to(index)

# ---------------- the jump, as a journey ----------------
# A mailbox, not a mode: read once, so a screen that dies before commit cancels the jump.
# Not on `Run` and not saved, so a quit mid-departure is safe without a save version.
# Why: docs/why/Router.md#jump-mailbox
var _post_depart: int = -1
var _post_arrive: bool = false
var _post_skipped: bool = false

## The player has committed to a jump. Nothing is spent yet.
func begin_jump(index: int) -> void:
	if index < 0 or index >= Run.map.size():
		return
	# Guard anyway: a departure over a jump that no-ops leaves a screen with no ship.
	if not Run.can_jump_to(Run.map[index]):
		return
	# FROM THE BERTH (the chart is a view from it): refused, and says to press
	# UNDOCK; and in space, refused while anything is on the pad (`cast_off`)
	if not cast_off():
		return
	# No animation, no journey. The sim, the headless harnesses and every shot
	# tool take the instant path they have always taken.
	if not animating():
		jump_to(index)
		return
	_post_depart = index
	# Not a page change: a tab click on the jump's first frame reads as a misfire (Jon).
	Audio.suppress(&"ui_tab", 200)
	show_local()

## Read-and-clear: which jump this sector is departing on, or -1.
func take_depart() -> int:
	var i := _post_depart
	_post_depart = -1
	return i

## Read-and-clear: [flew_in_here, was_skipped].
func take_arrival() -> Array:
	var out := [_post_arrive, _post_skipped]
	_post_arrive = false
	_post_skipped = false
	return out

## The ship is gone. Everything past here is the path that already worked.
func commit_jump(index: int, skipped: bool = false) -> void:
	# Same three refusals as `_autosave`: a flare peaking after QUIT would jump an ended run.
	if Run.hull == null or Run.map.is_empty() or Run.dead:
		return
	var before := Run.jumps
	_post_arrive = true
	_post_skipped = skipped
	Run.jump_to(index)
	# `Run.jump_to` no-ops silently on a refused target, leaving the sector up with a hidden ship.
	if Run.jumps == before:
		_post_arrive = false
		_post_skipped = false
		show_sector()

func _on_jumped(_index: int) -> void:
	crumb("[jump] #%d to %s, fuel %d" % [Run.jumps, MapGen.star_name(Run.node_at()), Run.fuel])
	# A jump arrives at the edge, so an ambush leaves wrecks there, not at a fought world.
	# Why: docs/why/Router.md#jump-arrival
	SystemMapScreen._parked.erase(_index)
	Moored.at = -1
	# The event last opened on LOCAL is dropped with the place it stood at.
	LocalEventDrawer.last = []
	# (a jump in is not a flight on the map, and the station it finds is asleep:
	# LOCAL's fly-in and the station's wake are a visit's, `SectorScreen`)
	SectorScreen.forget_places(_index)
	# A jump into a station system arrives at the station (Jon, Oct 18), so DOCK is there.
	# Why: docs/why/Router.md#jump-arrival
	park_at_station(Run.node_at())
	resolve_current_node()

func resolve_current_node() -> void:
	var n: MapGen.MapNode = Run.node_at()
	Run.log_line("Jumped to %s. %s. Danger %d." % [
		MapGen.star_name(n), MapGen.place_line(n).capitalize(), n.danger], &"you")

	# Roll before the save: arriving is the safe point, so a suspend save cannot reject a draw.
	settle_arrival(n)
	# Saves on the sector at the flown-to node, or a force-quit fight refunded the fuel.
	# Why: docs/why/Router.md#arrival-save
	_autosave()

	# Every arrival lands on the sector; an ambush fights on the way to the door, not instead.
	# Why: docs/why/Router.md#arrival
	if n.ambush_pending and no_fights_at(n):
		n.ambush_pending = false
	if n.ambush_pending:
		# Asked for here, not stored: positional, so the same pack on any machine.
		var pack := ambush_pack(n)
		if pack.is_empty():
			n.ambush_pending = false
		else:
			# A partner already fighting here: the pack folds into their fight (Nov 5).
			var theirs := party_fight_here()
			if theirs.is_empty():
				Run.log_line("Contact. They saw your heat on the approach.", &"heat")
			else:
				Run.log_line("%s is already fighting here. You join their fight."
					% opener_name(Net.fight_at(n.index)), &"good")
			# SHARED, like every fight at a place (Oct 22): a partner landing
			# here while you are still in it can JOIN rather than watch.
			start_combat(pack[0], pack.slice(1), false, true, not theirs.is_empty())
			return

	# Not auto-engaged: a party cannot arrive in the same second, so the set piece would be solo.
	# Why: docs/why/Router.md#hellbender-arrival
	if Run.hellbender_alive() and Run.hellbender_at == n.index:
		Run.log_line("The Hellbender is anchored here, its holds glowing with what it has taken. It blocks the rest of this system.", &"big")
		show_local()
		return

	match n.type:
		# The core does not open on arrival: two ships never land together, so the boss was solo.
		# It also stops a cleared core rolling a fresh custodian for the next arrival.
		# Why: docs/why/Router.md#core-arrival
		MapGen.NodeType.CORE:
			if n.cleared:
				Run.log_line("The core is open. Its guard is gone.", &"good")
			else:
				Run.log_line("The core fills the viewport. The Custodian guards it. Engage when you are ready.", &"big")
			show_sector()
		_:
			show_sector()

## Its own function so `-- contracttest` arrives through the same door the game does.
func settle_arrival(n: MapGen.MapNode) -> void:
	_roll_here(n)
	# Contract work is an event on the map: posted at signing, and again here if emptied.
	Contracts.post_goals_at(n)
	# A fetch with no event to hold it still counts arrival as the pickup. Runs before autosave.
	if not Contracts.holds_goal(n):
		Run.reach_contract_target(n.index)


## Rolled once and saved on the node, so quit and resume cannot re-roll a bad draw.
## Why: docs/why/Router.md#rolling-a-system
func _roll_here(n: MapGen.MapNode) -> void:
	if n.cleared:
		return
	# Options are decided once on the node, before the autosave, so quitting cannot re-roll them.
	# Not for stations (the option list is the station) nor the hand-authored core.
	# Why: docs/why/Router.md#rolling-a-system
	OptionTable.ensure(n)
	_roll_ambush(n)

## Rolled on arrival, the safe point, so quitting cannot refuse a hostile your heat drew.
## No node inherently holds a fight now; only the core is excluded.
## Why: docs/why/Router.md#ambush-roll
func _roll_ambush(n: MapGen.MapNode) -> void:
	if n.ambush_rolled or n.type == MapGen.NodeType.CORE or no_fights_at(n):
		return
	n.ambush_rolled = true
	# The roll is a stream draw, not positional, so four arriving ships are not all jumped.
	if Rng.foe.randf() < Run.ambush_chance(n):
		# The flag is rolled per seat off `Rng.foe`; the pack is positional, asked at fight time.
		n.ambush_pending = true

## Positional: what flies at a system is a property of the system, saved once per node.
## Why: docs/why/Router.md#foes
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
	# BACK FROM THE DOCK: it was open over this station, so the station is
	# still here -- close it and stand in the same yard.
	if dock != null and is_instance_valid(dock) and current is StationScreen:
		# (not while anything is still on the pad: the move has no off it)
		if Run.pad.is_empty():
			_close_dock()
		return
	# DOCK is offered only at the station, and this door refuses a dock from anywhere else.
	# Why: docs/why/Router.md#station-docking
	var here: MapGen.MapNode = Run.node_at()
	if not docked and here != null and here.type == MapGen.NodeType.STATION and not at_station(here):
		Audio.denied()
		return
	# Only a real arrival plays the clamps; coming back to the desk is an ordinary tab.
	# From the map looked at from the berth, go straight in: LOCAL would undock (Jon, Oct 27).
	# Why: docs/why/Router.md#station-docking
	if not docked and current is SystemMapScreen and ZoomLadder.enabled() and ZoomLadder.design_for(3) in ["B", "D"] \
			and Run.node_at() != null and Run.node_at().type == MapGen.NodeType.STATION:
		ZoomLadder.chain = &"station"
		# (moored on the station's right: LOCAL with your ship where it is, then the
		# dock from there, black and the landing)
		if Moored.here():
			show_local()
			return
		# (LOCAL built with your ship off it: the dock's arrival brings it)
		SectorScreen.dock_hidden = true
		show_local()
		return
	# (from the station's right there is no flight in: black, then the landing)
	if not docked and current is SectorScreen and Moored.here():
		ZoomLadder.dock_fade_only = true
	if not (dock != null and is_instance_valid(dock)) and ZoomLadder.preroll(ZoomLadder.STATION, show_station):
		return
	var arriving := not docked
	docked = true
	ZoomLadder.dock_fade_only = false
	Audio.music_state(&"station")
	if arriving:
		Audio.suppress(&"ui_tab", 200)
		# A dock that flies the ship into the yard owes the clamps sound until it lands (Jon).
		# Why: docs/why/Router.md#station-docking
		if animating() and ZoomLadder.busy() and not ZoomLadder.active._cut \
				and ZoomLadder.active.r_new == ZoomLadder.STATION and ZoomLadder.active.seam == 3 \
				and ZoomLadder.active.design in ["B", "D"]:
			dock_clamps_owed = true
		else:
			play_dock()
	# (built ahead, at DOCK, while LOCAL moved: shown as it is)
	var pre: Control = ZoomLadder.take_prebuilt(ZoomLadder.STATION)
	if pre != null:
		_swap(pre)
		_reopen_move.call_deferred()
		return
	var s := StationScreen.new()
	_swap(s)
	s.setup()
	_reopen_move.call_deferred()

## The node is consumed when the outcome lands, not on open, or a force-quit loses the hail.
## The pick lives on the node, rolled on arrival, so leaving and returning cannot re-roll it.
## Why: docs/why/Router.md#opening-a-hail
var _open_option := -1


## Spends one option in place; `event_resolved` holds the bookkeeping.
## Why: docs/why/Router.md#option-bookkeeping
func option_resolved(index: int, result: StringName = &"done") -> void:
	_open_option = index
	event_resolved(result)


func event_resolved(result: StringName = &"done") -> void:
	var n: MapGen.MapNode = Run.node_at()
	# One option is spent, not the system: the node is finished when nothing is left in it.
	if _open_option >= 0:
		var oid := MapGen.OPTION_SITE + _open_option
		if not n.taken.has(oid):
			n.taken.append(oid)
		n.results[_open_option] = result
		# ONE ONLY is now enforced: the sim already played the rule, the game never did.
		# Why: docs/why/Router.md#one-only
		OptionTable.foreclose(n, _open_option)
		_open_option = -1
		for i in n.options.size():
			if not n.taken.has(MapGen.OPTION_SITE + i):
				return
	Run.consume_node(n)

## A deliberate trade: the densest fuel and exotic matter, paid for in hull from radiation.
## Why: docs/why/Router.md#pulsar-harvest
func harvest_pulsar() -> void:
	Run.harvest_pulsar()
	if Run.dead:
		show_game_over()
		return
	show_sector()

## A node's fight is positional and shared; an ambush is a stream draw, so it is not.
## No fights at stations (Jon). A site of -2 means none, so compare guarded.
## Why: docs/why/Router.md#fight-sharing
static func at_hellbender(n: MapGen.MapNode) -> bool:
	if n == null:
		return false
	var p := SystemLayout.of(n).hellbender_place()
	return p >= 0 and Run.site_here(n) == p


static func at_custodian(n: MapGen.MapNode) -> bool:
	if n == null:
		return false
	var p := SystemLayout.of(n).core_place()
	return p >= 0 and Run.site_here(n) == p


static func no_fights_at(n: MapGen.MapNode) -> bool:
	return n != null and n.type == MapGen.NodeType.STATION


## Test seam: skips the partner-fight lookup to force the same-second race. Never game code.
var forced_race: bool = false
## Counts asks to the party, so "Waiting for the host." is said only for the
## one still waiting.
var _ask_serial: int = 0


## `told`: the caller has already said whose fight this is (an arrival ambush
## folded into a partner's), so the "Fighting alongside" line is not said too.
func start_combat(template: EnemyTemplate, extras: Array = [],
		clears_node: bool = true, share: bool = true, told: bool = false) -> void:
	if no_fights_at(Run.node_at()):
		return
	# A fight clears `docked` itself, as it skips `show_sector()`, or the HUD shows STATION.
	docked = false
	Run.node_at().fled = false
	# Starting a fight where a partner is shooting joins theirs, built from the fight's own ids.
	# Why: docs/why/Router.md#joining-fights
	var blind := forced_race
	forced_race = false
	var folded := false
	if share and not blind:
		var open := party_fight_here()
		if not open.is_empty():
			template = open[0]
			extras = open.slice(1)
			folded = true
	Audio.music_state(fight_music(template))
	combat = Combat.new()
	combat.clears_node = clears_node
	var s := SectorScreen.new()
	# From LOCAL, not a fade: the fight raises its own hand, and a fade popped ships in (Jon).
	var wrecks: Array = []
	if animating() and current is SectorScreen and (current as SectorScreen).settled_local():
		seamless_next = true
		# the wrecks LOCAL drew go with the picture, not with the screen
		wrecks = (current as SectorScreen).hand_wrecks()
	_swap(s)
	# Connect before starting: turn one resolves inside `start()`, even an instant win.
	s.setup(combat)
	s.wrecks_out(wrecks)
	var node: MapGen.MapNode = Run.node_at()
	# Dev flag `-- fight foes=3` overrides the node's roll, as packs are rare to wait for.
	var forced := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("foes="):
			forced = clampi(int(a.split("=")[1]), 1, 4)
	if forced > 1:
		var pool0 := DB.fight_pool(maxi(node.danger, 1), false)
		extras = []
		for i in forced - 1:
			extras.append(DB.enemies[Rng.pick(Rng.foe, pool0)])
	# Written down so SAVE & EXIT can restart exactly this fight.
	var ids: Array = [String(template.id)]
	for e in extras:
		ids.append(String((e as EnemyTemplate).id))
	current_fight = {ids = ids, clears = clears_node, share = share}
	# `plan()` makes the hull numbers the host is told, so scaling stays in `Combat._spawn`.
	combat.plan(template, node.danger, extras)
	# The hellbender opens at its scarred hull, locally and in the party's copy.
	# Only a live one: with none in this run (below HELLBENDER_ASCENSION, or `-- fight foe=hellbender`)
	# the hull is 0, and clamping opened the fight at 1; it opens at its template hull instead.
	if template.miniboss and Run.hellbender_alive():
		# (kept between fights in one ship's terms, built here for the game's players: `PartyScale`)
		combat.enemies[0].hp = clampi(PartyScale.party_hull(Run.hellbender_hp, combat.party),
			1, combat.enemies[0].max_hp)
		# Re-read the intent at that hull so a hellbender on the ropes can escape from turn one.
		combat.enemies[0].pick_intent()
	var f: SharedFight = null
	if share:
		# Null means fight alone; a guest waits as long as the host takes (Nov 5).
		var cb := combat
		_ask_serial += 1
		var ask := _ask_serial
		if Net.is_networked() and not Net.is_host():
			get_tree().create_timer(NetSession.TAKE_TIMEOUT).timeout.connect(func() -> void:
				if _ask_serial == ask and combat == cb:
					Run.log_line("Waiting for the host.", &"them"))
		# (planned, not begun: nothing in it can be pressed until the answer)
		cb.asking_at = node.index
		# A START THAT FOUND A PARTNER'S FIGHT HERE ONLY JOINS (PROTOCOL 18):
		# the JOIN doors, ENGAGE and an arrival folded into it. If the fight
		# ends before the host hears the ask, the host opens nothing (it once
		# opened a fresh, full-hull copy of the enemy that had just died).
		f = await Net.open_fight(node.index, cb.foe_ids(),
			cb.foe_hp(), cb.foe_brace(), cb.foe_hp_now(), cb.grown, folded)
		cb.asking_at = -1
		_ask_serial += 1
		# If the fight was dropped or ended while asking, leave again or the party waits.
		if combat != cb or cb.finished:
			var kept := combat != null and combat != cb and \
					(combat.shared_at == node.index or combat.asking_at == node.index)
			if f != null and not kept:
				Net.leave_fight(node.index)
			Net.take_held_swings(node.index)
			return
		# THE FIGHT ENDED BEFORE THE ASK GOT THERE (a JOIN on the kill): the
		# answer is the fight that ended, without this ship in it. Nothing
		# was spent, and the ship goes back to where it was.
		if f != null and f.over and not f.crew.has(Net.local_id()):
			cb.release()
			combat = null
			Net.take_held_swings(node.index)
			Run.log_line("The fight ended before you got there.", &"them")
			show_sector()
			return
		if f != null:
			_take_answer(f, folded, told)
	combat.begin(f)


## A host can answer with a partner's fight, not the one asked for: take that one whole.
## Its own contact is spent, and `fight_door` records it for SAVE & EXIT.
## Why: docs/why/Router.md#host-answer
func _take_answer(f: SharedFight, folded: bool, told: bool) -> void:
	var theirs := f.crew.size() > 1 and f.crew[0] != Net.local_id()
	var other := f.foe_ids != combat.foe_ids()
	if other or (theirs and not folded):
		var door := fight_door(f)
		combat.clears_node = door.clears
		current_fight = {ids = door.ids, clears = door.clears, share = true}
		if other:
			Audio.music_state(door.cue)
	if theirs and not folded:
		Run.log_line("%s got here first. You join their fight." % opener_name(f), &"good")
	elif f.crew.size() > 1 and not told:
		var names := Net.fight_crew_names(f.at)
		Run.log_line("Fighting alongside %s." % ", ".join(names).to_upper(), &"good")


## Who is first in a fight's crew, by name, as the log says names, or "A
## PARTNER" for a ship the roster does not know.
func opener_name(f: SharedFight) -> String:
	var who := Net.name_of(f.crew[0]) if f != null and not f.crew.is_empty() else ""
	return who.to_upper() if who != "" else "A PARTNER"


## A party's fight as a door: one answer for JOIN FIGHT and host-answered starts, so no drift.
func fight_door(f: SharedFight) -> Dictionary:
	var templates := Combat.templates_of(f.foe_ids) if f != null else []
	var lead: EnemyTemplate = templates[0] if not templates.is_empty() else null
	var n: MapGen.MapNode = Run.node_at()
	var kind := &"contact"
	if lead != null and lead.miniboss:
		kind = &"hellbender"
	elif n != null and n.type == MapGen.NodeType.CORE and not n.cleared:
		kind = &"core"
	var ids: Array = []
	if f != null:
		for id in f.foe_ids:
			ids.append(String(id))
	return {templates = templates, ids = ids, kind = kind,
		# Only the core clears its node on a win; the hellbender is a visitor.
		clears = kind == &"core",
		cue = fight_music(lead)}


## The music a fight asks for: the Custodian its own cue (Jon, Nov 10), any other boss
## or the hellbender the dread cue, everything else the tier's fight.
## Why: docs/why/Audio.md#music-cues
func fight_music(lead: EnemyTemplate) -> StringName:
	if lead == null:
		return &"combat"
	if lead.id == DB.CORE_BOSS:
		return &"custodian"
	return &"boss" if lead.boss or lead.miniboss else &"combat"

## Only reachable after a resume, as arrival normally starts the fight itself.
## Why: docs/why/Router.md#engaging
func engage_here() -> void:
	var n: MapGen.MapNode = Run.node_at()
	# The hellbender comes first: it is the engagement, keeping one fight per system.
	if Run.hellbender_alive() and Run.hellbender_at == n.index:
		engage_hellbender()
		return
	if n.cleared or in_combat() or no_fights_at(n):
		return
	if n.type == MapGen.NodeType.CORE:
		start_combat(DB.core_boss())
		return
	# Idempotent roll, so a restored or older save still has its foes.
	_roll_here(n)
	var extras: Array = []
	for i in range(1, n.foes.size()):
		extras.append(DB.enemies[n.foes[i]])
	start_combat(DB.enemies[n.foes[0]], extras)

## The node is not consumed by winning: the hellbender is a visitor. Shared like any fight.
func engage_hellbender() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if in_combat() or not Run.hellbender_alive() or Run.hellbender_at != n.index:
		return
	start_combat(DB.enemies[&"hellbender"], [], false, true)


## Winning an option's fight does not consume the system; the option spends itself.
## Shared since Oct 22: private fights meant nobody in a party could join another's.
## Why: docs/why/Router.md#option-fights
func start_ambush(foe: StringName = &"") -> void:
	start_combat(option_foe(Run.node_at(), foe), [], false, true)


## The party's fight open at this system that this ship is not in, as
## templates lead first -- or empty: none open, already in it, or no party.
func party_fight_here() -> Array:
	var out: Array = []
	if Run.map.is_empty() or not Net.is_networked():
		return out
	var f := Net.fight_at(Run.at)
	if f == null or f.over or f.crew.has(Net.local_id()):
		return out
	for id in f.foe_ids:
		var t: EnemyTemplate = DB.enemies.get(StringName(id))
		if t == null:
			return []
		out.append(t)
	return out


## Whether there is a partner's fight HERE to join, now.
func can_join_fight() -> bool:
	return join_state() == JOIN_OPEN


## THE JOIN DOORS' STATE HERE: JOIN_NONE (no partner's fight to join),
## JOIN_OPEN, or JOIN_SHUT, a fight whose Hellbender is spooling its escape
## (the design's edge: a joiner past turn one is stunned, so it could only add
## a ship for the enemy to shoot as it leaves). The bars show JOIN FIGHT greyed
## then, with `JOIN_SHUT_WHY`.
const JOIN_NONE := 0
const JOIN_OPEN := 1
const JOIN_SHUT := 2
const JOIN_SHUT_WHY := "It is about to jump away."
func join_state() -> int:
	if Run.dead or in_combat() or fight_up() or no_fights_at(Run.node_at()):
		return JOIN_NONE
	if party_fight_here().is_empty():
		return JOIN_NONE
	var f := Net.fight_at(Run.at)
	for e in f.foes:
		if e.alive() and e.kind == SharedFight.Pick.ESCAPE:
			return JOIN_SHUT
	return JOIN_OPEN


## JOIN FIGHT's tooltip, the same on both bars (the SECTOR bar's and the map's
## system panel's).
func join_tip() -> String:
	if join_state() == JOIN_SHUT:
		return JOIN_SHUT_WHY
	return "%s is fighting here. After their first turn you arrive stunned. You can't act or flee until the enemy's turn is over, and it can shoot you." % join_fight_names()


## Who is in the fight here, by name, for the button's line.
func join_fight_names() -> String:
	return ", ".join(Net.fight_crew_names(Run.at)).to_upper()


## JOIN enters a partner's fight; the set pieces use their own doors, which already join.
## Why: docs/why/Router.md#joining-fights
func join_fight() -> void:
	if not can_join_fight():
		return
	var door := fight_door(Net.fight_at(Run.at))
	if door.templates.is_empty():
		return
	match door.kind:
		&"hellbender":
			engage_hellbender()
		&"core":
			engage_here()
		_:
			start_combat(door.templates[0], door.templates.slice(1), door.clears, true)

## No `foe` fields one ship; with a tag, that creature only. A bad tag is refused loudly.
## Why: docs/why/Router.md#option-foes
func option_foe(n: MapGen.MapNode, foe: StringName = &"") -> EnemyTemplate:
	if foe != &"":
		var t: EnemyTemplate = DB.enemies.get(foe)
		if t != null and t.fauna:
			return t
		push_error("Router.option_foe: '%s' is not a creature" % foe)
	return DB.enemies[Rng.pick(Rng.foe, DB.fight_pool(n.danger, false))]

## An arrival's ambush at `n` as templates, lead first: `_roll_foes`, the same
## pack whoever asks. The arrival and the headless sim both field it whole.
func ambush_pack(n: MapGen.MapNode) -> Array:
	var out: Array = []
	for id in _roll_foes(n):
		out.append(DB.enemies[id])
	return out

## The fight a loaded save was left in (see resume_here), and the one in
## progress now, as SaveGame.mark_fight writes it.
var fight_on_resume: Dictionary = {}
var current_fight: Dictionary = {}

func in_combat() -> bool:
	return combat != null and not combat.finished


## While the fight's screen is up every door does nothing, or Tab builds a second fight screen.
## Also from the last kill to `after_combat`, when `in_combat` is already false.
## Why: docs/why/Router.md#fight-holds-camera
func fight_up() -> bool:
	return combat != null and current is SectorScreen and (current as SectorScreen).combat == combat

func after_combat(_c: Combat) -> void:
	# A win stays by the wrecks, where the pay is; other endings go back to the map.
	var won_here := _c != null and _c.result == &"victory"
	combat = null
	current_fight = {}
	# An ambush is spent however it ended, or it fires again on the next arrival.
	Run.node_at().ambush_pending = false
	# Only the fight that won the run ends `won`, so only the core's boss comes through here.
	if Run.won and not Run.dead and _c != null and _c.result == &"won":
		var body := core_body_here()
		if body != null and Run.jetsam_left(Run.node_at(), body) > 0:
			await_core_body()
			return
	if Run.dead or Run.won:
		show_game_over()
		return
	if won_here:
		show_local()
		return
	show_loot_or_map()


## While open, the win screen is the only way on; any screen swapped in is followed by it.
## Why: docs/why/Router.md#final-loot
var final_loot: bool = false


## The custodian's wreck at this system, or null.
func core_body_here() -> MapGen.Jetsam:
	var n: MapGen.MapNode = Run.node_at()
	if n == null:
		return null
	for raw in n.jetsam:
		var h := raw as MapGen.Jetsam
		if h != null and h.art == &"custodian":
			return h
	return null


## The body waits to be clicked (Jon); the one allowed save returns a quit game to the body.
## Why: docs/why/Router.md#final-loot
func await_core_body() -> void:
	final_loot = false
	show_local()
	if not (current is SectorScreen) or core_body_here() == null:
		show_game_over()
		return
	final_loot = true
	if hud != null:
		hud.visible = false
	SaveGame.save_core_won()
	(current as SectorScreen)._refresh()


## The custodian's body clicked: its popup, the win screen behind DONE.
func open_core_body() -> void:
	var body := core_body_here()
	var s := current as SectorScreen
	if body == null or s == null:
		finish_core_loot()
		return
	_open_core_body(body)


func _open_core_body(body: MapGen.Jetsam) -> void:
	var s := current as SectorScreen
	if s == null:
		show_game_over()
		return
	final_loot = true
	if hud != null:
		hud.visible = false
	s.open_jetsam(body, "", finish_core_loot)
	if not s.has_open_container():
		final_loot = false
		show_game_over()


## DONE on the custodian's body, or Escape: the win screen.
func finish_core_loot() -> void:
	if not final_loot:
		return
	final_loot = false
	# the body's step is over: the won run's last save goes with it
	SaveGame.clear()
	show_game_over()

## Salvage is resolved where it was found, not on a screen of its own. The
## sector shows what is in the hold and lets you fit or scrap it there.
func show_loot_or_map() -> void:
	show_sector()

## Record and drop the save at run end: a surviving suspend save would resurrect them.
func _on_run_ended(won: bool, reason: String) -> void:
	SaveGame.clear()
	RunHistory.record(
		RunHistory.Outcome.WON if won else RunHistory.Outcome.DIED, reason)
	## screens call show_game_over() so the player sees the summary first

## Docking clamps. Sig has no "you docked" signal and adding one for a single
## sound would be noise in the bus, so the screen that opens plays it.
func play_dock() -> void:
	dock_clamps_owed = false
	Audio.play(&"station_dock", 0.03)


## The clamps not yet heard on a dock whose yard landing is still to come
## (`show_station`).
var dock_clamps_owed := false


## Your ship is on its stands: the clamps, if they are owed.
func pay_dock_clamps() -> void:
	if dock_clamps_owed:
		play_dock()
