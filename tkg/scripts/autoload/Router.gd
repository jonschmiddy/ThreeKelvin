extends Node
## Screen flow. Owns the single content container and swaps screens into it,
## and decides what happens when you arrive at a map node.

var content: Control
var hud: HudBar
var current: Control
var combat: Combat
## The sky, behind whatever screen is open. See SpaceLayer: it lives here rather
## than in a screen so that swapping screens changes what is in front of the
## world instead of replacing the world.
var sky: SpaceLayer
## Whether the ship is tied up at a station rather than flying the system.
##
## Not on Run and not a Sig signal: it is a fact about which side of the airlock
## you are on, and the two functions below are the only ways through it in
## either direction -- every arrival, every UNDOCK and every resume goes through
## show_sector(). The HUD reads it to decide whether its second tab says SECTOR
## or STATION, so that walking to SHIP from the berth and back does not make you
## re-dock to return.
var docked: bool = false

func register(content_holder: Control, hud_bar: HudBar) -> void:
	content = content_holder
	hud = hud_bar
	# FIRST CHILD, so every screen added after it draws in front. `_swap` frees
	# `current` and never this, so the sky outlives the screens the way the
	# place outlives the thing you happen to be looking at.
	sky = SpaceLayer.new()
	content.add_child(sky)
	Sig.jumped.connect(_on_jumped)
	Sig.run_started.connect(_on_run_started)
	Sig.run_ended.connect(_on_run_ended)

## `chrome` is whether the HUD belongs above this screen. The launcher and the
## record reached from it run before any run exists, and the HUD reads ship
## state — it bails on a null hull, but an empty bar above a title screen is a
## bug that looks like a decision.
##
## THE SCREEN BEING LEFT IS HIDDEN, not just queued. `queue_free` leaves it in
## the tree for the rest of the frame, and whatever redraws it there -- hiding
## the HUD for the title screen grows the content area and resizes it -- draws
## it against state that has already moved on. QUIT and SAVE & QUIT clear the
## hull before this runs, so the starchart drew once more with no ship and
## logged hundreds of errors for a frame no one ever saw. A hidden control is
## never drawn. `-- quittest` guards it.
func _swap(screen: Control, chrome: bool = true) -> void:
	# THE PAGE SOUND IS FOR MOVING BETWEEN PAGES, not for arriving in the game.
	# Jon: no click "when starting the game", nor "when launching the ship for
	# the first time". So booting, and every swap to or from the title or the
	# lobby, is silent; `screen_changed` below still fires for everything else
	# that listens to it.
	if current == null or is_front_door(current) or is_front_door(screen):
		Audio.suppress(&"ui_tab", 100)
	if current != null:
		current.hide()
		current.queue_free()
	current = screen
	content.add_child(screen)
	var room: Variant = _room_for(screen)
	if room != null:
		Audio.room(room)
	if hud != null:
		hud.visible = chrome
	_refresh_sky()
	_fade_in(screen)
	Sig.screen_changed.emit()
	_autosave()


## The screens before a run is under way: the title, the party lobby, and the
## hull pick. Leaving the hull pick is launching, and that was still clicking.
func is_front_door(s: Control) -> bool:
	return s is LauncherScreen or s is LobbyScreen or s is ChassisSelect

## How long a screen takes to arrive. Short enough that nobody waiting to click
## something is made to wait for it, long enough to read as a change of place
## rather than as a repaint.
const FADE_S := 0.13

## The incoming screen arrives; it does not appear.
##
## THE OUTGOING SCREEN IS NOT CROSSFADED, and that is deliberate rather than
## lazy. It is hidden and freed on the same frame it always was, because the
## reason it is hidden is that drawing it again draws a run that has already
## moved on -- QUIT clears the hull before this runs, and the starchart drew
## once more with no ship and logged hundreds of errors for a frame nobody saw.
## Holding it on screen to fade it out would put those frames back. `-- quittest`
## is the test that found that and it still has to pass.
##
## So only the arriving half animates, and it works because of what is now
## BEHIND it: the sky belongs to the Router, so it does not blink between
## screens. The content fades up over a world that was already there, which is
## the whole reason this reads as continuity rather than as a dissolve.
##
## Modulate rather than a colour rect over the top: a rect would need to be
## above the HUD to cover it and below the cursor to not, and the ordering
## problem is not worth a fade.
func _fade_in(screen: Control) -> void:
	if screen == null or not animating():
		return
	screen.modulate.a = 0.0
	var tw := screen.create_tween()
	tw.tween_property(screen, "modulate:a", 1.0, FADE_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Whether anything should animate at all.
##
## Three cases, and the third is the one that is easy to miss. The SIM boots the
## whole project and swaps hundreds of screens with nobody watching, so a tween
## per swap is pure cost. HEADLESS has no frames to show it in.
##
## And every `-- ...shot` TOOL runs windowed, on purpose -- the dummy display
## server never emits `frame_post_draw` -- so without this line the fade caught
## all of them: they wait a fixed handful of frames and then photograph, which
## after this change means photographing a screen at whatever opacity it had got
## to. Every picture the project judges its own layout from would have come out
## dim, and the tools predate the fade so none of them knows to wait.
##
## Matched by suffix rather than by a list, because the list is nine long today
## and the next one would be added without anybody thinking about this.
func animating() -> bool:
	# REDUCED MOTION IS ANSWERED HERE, once, for the whole game: every screen
	# already asks this before it moves anything, so the setting needs no new
	# check anywhere else.
	if DisplaySettings.reduced_motion:
		return false
	if "sim" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return false
	for a in OS.get_cmdline_user_args():
		if (a as String).ends_with("shot"):
			return false
	return true


## Which screens the sky belongs behind.
##
## Every exclusion here is for its own reason, so this is a list and not a rule.
##
## The STATION is an interior and its cutaway says so: a starfield on a deck
## would contradict the one conceit that screen is built on.
##
## The LAUNCHER and the STARCHART are not excluded for being wrong — they
## already draw a galaxy of their own, and two skies is one more than anywhere
## has.
##
## THE SECTOR is the interesting one, because it is the screen this layer was
## lifted out of. `EncounterView` paints a region-tinted wash in its own `_draw`
## and its backdrop draws ON TOP of that wash, so the two are one composition
## rather than two layers that happen to be stacked. Moving half of it up here
## would put the wash over the sky and lose the thing it was built to do. It
## keeps its own pair, this one stands down behind it, and nothing bakes twice.
## Unifying them means moving the wash as well, which is a change to the best
## screen in the game and does not belong in the same step as giving nine bare
## screens a sky for the first time.
##
## Everything else is somewhere in space, which is the entire point of the layer.
func _refresh_sky() -> void:
	if sky == null:
		return
	var interior := current is StationScreen
	var has_own := current is LauncherScreen or current is StarchartScreen \
		or current is SectorScreen
	sky.set_active(not interior and not has_own)
	if Run.map.size() > 0:
		sky.setup(Run.node_at())

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
## THE ROOM YOU ARE IN, decided here because this is the one place every
## screen change passes. It used to be the station's own business -- on in
## `setup`, off in `_exit_tree` -- and that could not survive a second room:
## `_exit_tree` runs at the end of the frame, AFTER the next screen has
## started, so leaving a station for the sector would have switched open space
## on and then straight back off.
##
## null means NO CHANGE, and it is what the panels return. The ship, the
## cards, the chart and the rest are opened from wherever you are, so they
## keep that place's room -- the same rule `music_state` applies to the score.
func _room_for(screen: Control) -> Variant:
	if screen is StationScreen:
		return &"amb_station"
	if screen is SectorScreen:
		return _star_room()
	if screen is ShipScreen or screen is CardGalleryScreen \
			or screen is ModuleGalleryScreen or screen is TransferScreen \
			or screen is StarchartScreen or screen is ArchiveScreen \
			or screen is HistoryScreen:
		return null
	return &""


## OPEN SPACE, OR THE STAR OUTSIDE. Pulsars, red and blue hypergiants each have
## a room of their own -- Jon's picks from the sound pass, layered -- and every
## other system is plain open space. Read off the same fields `star_kind` reads,
## so what you hear and what the chart calls the star cannot disagree.
## AND PLAIN SPACE IS THE REACTOR. Its first room was space tone -- the noise
## outside the hull -- and Jon cut it for being distracting. What replaced it
## points the other way: "just like a reactor hum", the ship's own plant, which
## is the one sound that should be there in a system with nothing in it.
##
## THIS LINE HAS BEEN LOST ONCE ALREADY. I reverted this whole file to strip
## some timing prints out of it and took the room with them, and the symptom
## was Jon asking why open space had gone quiet again. Revert a hunk, never a
## file, when the file has other work in it.
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
	# Choosing a hull is still "before you launch", so it is the title music --
	# named rather than inherited, because this screen is also reachable cold.
	Audio.music_state(&"lobby")
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
	var f := fight_on_resume
	fight_on_resume = {}
	show_sector()
	# EXCEPT A FIGHT YOU SAVED OUT OF. SAVE & EXIT mid-fight leaves the save from
	# before it on disk and notes which fight it was (SaveGame.mark_fight); that
	# one starts again from its first turn, same enemies, as you went in.
	var ids: Array = f.get("ids", [])
	if ids.is_empty() or not DB.enemies.has(StringName(ids[0])):
		return
	var extras: Array = []
	for i in range(1, ids.size()):
		if DB.enemies.has(StringName(ids[i])):
			extras.append(DB.enemies[StringName(ids[i])])
	start_combat(DB.enemies[StringName(ids[0])], extras,
		bool(f.get("clears", true)), bool(f.get("share", true)))

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
	# From the launcher the archive is somewhere you went; from inside a run it
	# is a panel you opened, and a panel never touches the music.
	Audio.music_state(&"records" if from_launcher else &"archive")
	var s := ArchiveScreen.new()
	_swap(s, not from_launcher)
	s.setup(show_launcher if from_launcher else show_sector)

## Re-scan before drawing, because SIGHT IS A SNAPSHOT AND REACH IS LIVE.
##
## `chart_from` runs on arrival and `sensed` keeps that answer until the next
## one. `reachable` is computed from the ship's CURRENT thrust every time it is
## asked. Fit a thruster at a station and reach grows while the sight marks do
## not -- so a system becomes reachable, is drawn, prices its fuel, and cannot be
## jumped to, because `can_jump_to` wants `sensed` as well.
##
## Reported as a system inside both rings whose button read NOT ENOUGH FUEL, on a
## ship carrying 279 fuel against a 6-unit cap. The message was the screen's
## if-chain treating anything left over as an affordability problem; the cause
## was two answers to "how far can I see" taken at different times.
##
## Cheap enough to just do: one pass over the map, once per opening, against a
## draw that walks every node anyway.
func show_starchart() -> void:
	Run.chart_from(Run.node_at())
	_show_starchart()


func _show_starchart() -> void:
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
	# Before the swap, not after: `_swap` emits screen_changed, and the HUD reads
	# this flag inside the refresh that signal triggers.
	# UNDOCKING IS NOT A PAGE CHANGE either: leaving the berth is the ship
	# moving, and the thrusters say so.
	if docked:
		Audio.suppress(&"ui_tab", 200)
		# The clamps letting go, the other half of `play_dock`. Guarded on the
		# file: silent until a take is picked.
		if ResourceLoader.exists(Audio.SFX_PATH % &"station_undock"):
			Audio.play(&"station_undock", 0.03)
		# AND YOU DO NOT FLY IN TO A SYSTEM YOU ARE ALREADY IN.
		#
		# The approach plays once per node, latched on `_approached_at`, and a
		# station node never sets that latch: arriving at one docks you straight
		# away, so the sector screen is not built until you leave. Undocking was
		# therefore its FIRST sight of the node and flew the ship in from off
		# screen -- Jon: "You are already in the sector." Setting the latch here
		# says what is true, that this system has been arrived at.
		SectorScreen._approached_at = Run.at
	docked = false
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
	var here := current
	var s := CardGalleryScreen.new()
	_swap(s)
	s.setup(back_to(here))

## Development only: every module in the game on one page. See
## ModuleGalleryScreen — the sibling of show_cards, and dev-only for the same
## reason: a catalogue is the answer to a game about finding out what things do.
func show_modules() -> void:
	var here := current
	var s := ModuleGalleryScreen.new()
	_swap(s)
	s.setup(back_to(here))

## Where LEAVE goes from a page you opened OVER the run.
##
## The catalogues sit on the HUD, so they can be opened from any screen and
## "back" cannot be a constant -- this is the same question PartyScreen answers
## inline, asked once so the two galleries do not each answer it differently.
##
## A GALLERY IS NOT A PLACE TO BE SENT BACK TO. Opening MODULES from CARDS and
## pressing LEAVE should put you back in the game, not bounce you between two
## catalogues; anything not named here falls to the sector, which is the one
## screen that always exists mid-run.
func back_to(here: Control) -> Callable:
	if here is ShipScreen:
		return show_ship
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

## Moving day, after a hull swap that left something on the dock.
##
## NO HUD, and that is deliberate: the bar's SECTOR and STARCHART tabs are ways
## off this screen, and there is no off it -- the ship cannot leave with crates
## on the ground, so offering the exits and then refusing them is worse than not
## offering them. `chrome = false` is the same argument the chassis select makes.
func show_transfer() -> void:
	Audio.music_state(&"ship")
	var s := TransferScreen.new()
	_swap(s, false)
	s.setup()

func show_game_over() -> void:
	Audio.music_state(&"gameover")
	var s := GameOverScreen.new()
	_swap(s)
	s.setup()

func jump_to(index: int) -> void:
	Run.jump_to(index)

# ---------------- the jump, as a journey ----------------
## A MAILBOX, NOT A MODE, and the distinction is the whole safety of this.
##
## A jump used to be one frame: press the button, the fuel is gone and you are
## there. It is a sequence now — the ship revs and leaves the OLD system, and
## only then does anything get spent — so something has to carry "you committed
## to a jump" across a screen swap.
##
## These are written once and READ ONCE. The screen that takes a message owns
## it from then on, and if that screen dies before it commits, the jump is
## simply cancelled with nothing spent. A persistent flag would be a mode, and a
## mode is a thing that can be left switched on.
##
## NOT ON `Run`, for the same reason `docked` is not: it is a fact about which
## side of a transition you are on, it must not be saved, and a departure that
## has not committed is indistinguishable from being parked where you already
## were. That is what makes a quit mid-departure safe without a save version.
var _post_depart: int = -1
var _post_arrive: bool = false
var _post_skipped: bool = false

## The player has committed to a jump. Nothing is spent yet.
func begin_jump(index: int) -> void:
	if index < 0 or index >= Run.map.size():
		return
	# The chart's button is already disabled on this, but state can move between
	# the paint and the press — and a departure played over a jump that then
	# silently no-ops leaves a screen with no ship in it and no drawer.
	if not Run.can_jump_to(Run.map[index]):
		return
	# No animation, no journey. The sim, the headless harnesses and every shot
	# tool take the instant path they have always taken.
	if not animating():
		jump_to(index)
		return
	_post_depart = index
	# NOT A PAGE CHANGE. Leaving the chart here is the first frame of the jump --
	# the ship revs and goes -- and the tab click on top of it reads as a
	# misfire (Jon). SectorScreen suppresses the same sound again at the commit,
	# for the swap on the far side.
	Audio.suppress(&"ui_tab", 200)
	show_sector()

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
	# THE SAME THREE CONDITIONS `_autosave` REFUSES ON, and for the same reason.
	# `_swap` hides and queue_frees the outgoing screen, and queue_free leaves it
	# in the tree for the rest of the frame — so a flare that peaks after QUIT
	# has cleared the hull would run a jump against a run that has ended. That is
	# the quittest bug wearing new clothes.
	if Run.hull == null or Run.map.is_empty() or Run.dead:
		return
	var before := Run.jumps
	_post_arrive = true
	_post_skipped = skipped
	Run.jump_to(index)
	# `Run.jump_to` returns in silence on a target it will not take. If it did,
	# nothing swapped the screen and the departing sector is still up with its
	# ship hidden behind a flare that has already finished.
	if Run.jumps == before:
		_post_arrive = false
		_post_skipped = false
		show_sector()

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
	if n.ambush_pending:
		Run.log_line("Contact. Your heat bloom lit you up on the approach.", &"heat")
		# Asked for HERE rather than stored at arrival. Positional, so it is the
		# same pack however often it is asked and on whichever machine -- which
		# is what lets the flag be a boolean instead of a list.
		var pack := _roll_foes(n)
		if pack.is_empty():
			n.ambush_pending = false
		else:
			var extras: Array = []
			for i in range(1, pack.size()):
				extras.append(DB.enemies[pack[i]])
			start_combat(DB.enemies[pack[0]], extras, false, false)
			return

	# The hellbender holds this system. Nothing here is reachable past it — not the
	# dock, not anything the system was offering — so arrival lands on the sector
	# and the one button says what there is to do. NOT auto-engaged, for the
	# same reason the core stopped being: two people never arrive at a system on
	# the same second, and a set piece a party cannot gather at is fought alone
	# by design. See the CORE note below.
	if Run.hellbender_alive() and Run.hellbender_at == n.index:
		Run.log_line("The Hellbender rides at anchor here, holds glowing with everything it has taken. It is between you and the rest of the system.", &"big")
		show_sector()
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
		# since it was written; CORE never did.
		#
		# So the core is a place you arrive at now. The sector says what is out
		# there and the button says ENGAGE, which is the wiring a resumed run has
		# always used — `_on_action` and `_quiet_lines` both already had the
		# case, and this makes it the ordinary path instead of the restored one.
		MapGen.NodeType.CORE:
			if n.cleared:
				Run.log_line("The core is open. The light is behind you.", &"good")
			else:
				Run.log_line("The core fills the viewport. Something is guarding it. Engage when you are ready.", &"big")
			show_sector()
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
	# WHAT THERE IS TO DO HERE, decided once and written onto the node.
	#
	# Same contract as `foes` and `event_key` above and for the same reason: this
	# runs before the autosave, so quitting and coming back cannot re-roll it.
	# Save-scumming through the front door is what that rule exists to stop.
	#
	# Stations are excluded because a station IS its option list -- the shelf,
	# the hull on the rack, repair and fuel -- and it is the one node the chart
	# telegraphs. The core is excluded because it is a hand-authored boss.
	OptionTable.ensure(n)
	_roll_ambush(n)

## Whether anything followed your heat trail in.
##
## Rolled here with the rest of what a system holds, and for the same reason:
## arriving is the safe point, so a hostile your own throttle attracted cannot
## be refused by quitting and coming back cold.
##
## NO NODE INHERENTLY HOLDS A FIGHT ANY MORE, so the old exclusion went with the
## types: "being ambushed on the way to a fight is the fight" was true of a FIGHT
## node and is false of a system that merely OFFERS one. The ambush is a separate
## interrupt and the option is still sitting there when it is over. Only the core
## is excluded, because it is a hand-authored boss.
func _roll_ambush(n: MapGen.MapNode) -> void:
	if n.ambush_rolled or n.type == MapGen.NodeType.CORE:
		return
	n.ambush_rolled = true
	# The ambush roll itself is a stream draw, not a positional one, and that is
	# deliberate: whether something notices you depends on YOUR signature, so
	# four ships arriving at one system do not all get jumped or all slip past.
	# What is waiting IF you are jumped is positional, like everything else that
	# lives at a node.
	if Rng.foe.randf() < Run.ambush_chance(n):
		# THE FLAG, not the pack. Rolled off `Rng.foe` and therefore salted per
		# seat -- whether something notices you depends on YOUR signature, so
		# four ships arriving together do not all get jumped. What is waiting is
		# positional and is asked for at fight time.
		n.ambush_pending = true

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
	# ARRIVING, OR JUST COMING BACK TO THE DESK? Docking is a thing the ship
	# does once; walking back to the station from the chart or the ship screen
	# is a page change. Only the first plays the clamps, and only the first
	# swallows the page sound -- the rest are ordinary tabs (Jon).
	var arriving := not docked
	docked = true
	Audio.music_state(&"station")
	if arriving:
		Audio.suppress(&"ui_tab", 200)
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
## Which option of the current system is open, or -1.
##
## Held here rather than on the node because it is a screen's business, not a
## place's -- the node records which options are SPENT, in `taken`, and that is
## the part a save has to carry.
var _open_option := -1


## Open one named option as the detail view.
##
## RULING 2. The sector renders the list; this is the screen an option gets when
## it has earned one -- both a `body` and a check, so there is prose worth reading
## and a number worth weighing. Everything simpler resolves in its own row and
## never comes here, because two to four options across twenty-five systems is a
## great deal of reading and prose that is unavoidable stops being read.
##
## `EventScreen` is reused rather than replaced: an option is
## `{title, body, choices}` and it renders `{title, body, options}`. One key.
func show_option_at(index: int) -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n == null or n.cleared:
		return
	_roll_here(n)
	if index < 0 or index >= n.options.size():
		return
	if n.taken.has(MapGen.OPTION_SITE + index):
		return
	var opt := OptionTable.by_id(n.options[index])
	if opt.is_empty():
		# An id this build no longer has. Spend it rather than stalling the
		# system on a name nobody can resolve.
		n.taken.append(MapGen.OPTION_SITE + index)
		return
	_open_option = index
	Audio.music_state(&"event")
	var e := EventScreen.new()
	_swap(e)
	e.setup({title = opt.get("title", ""), body = opt.get("body", ""),
		options = opt.get("choices", [])})


## Mark one option spent without opening anything.
##
## What the sector calls when a row resolved IN PLACE. The bookkeeping is the
## same as `event_resolved`'s and lives in one function so the two paths cannot
## drift: an option spends itself, and the system is finished only when nothing
## is left in it.
func option_resolved(index: int, result: StringName = &"done") -> void:
	_open_option = index
	event_resolved(result)


## Ask the party for the option this event screen is standing in, BEFORE the
## screen rolls or pays anything. The other half of the seam `event_resolved`
## records: consumption is arbitrated here through `Run.take_option`, because
## an option two ships can race for must be asked for, not assumed -- roll
## first and apologise afterwards, and the loser has already pocketed the
## payout. See `_resolve_derelict` for the shape.
func claim_open_option() -> bool:
	var n: MapGen.MapNode = Run.node_at()
	if n == null or _open_option < 0:
		return false
	return await Run.take_option(n, MapGen.OPTION_SITE + _open_option)


func event_resolved(result: StringName = &"done") -> void:
	var n: MapGen.MapNode = Run.node_at()
	# ONE OPTION IS SPENT, NOT THE SYSTEM. A system holds several things to do
	# and taking one must not consume the rest -- which is what `taken` has
	# always been for, and what `OPTION_WHOLE`'s comment apologises for not
	# using. The node is only finished when nothing is left in it.
	if _open_option >= 0:
		var oid := MapGen.OPTION_SITE + _open_option
		if not n.taken.has(oid):
			n.taken.append(oid)
		n.results[_open_option] = result
		# ONE ONLY, ENFORCED. The list has promised this since exclusive sets
		# existed -- first as a bracket captioned ONE ONLY, now as the rival
		# greying under the cursor -- and nothing has ever made it true: taking
		# the auction left the queue sitting there, takeable. The SIMULATOR has
		# been playing the rule correctly all along (`Policy.take_options`
		# counts what it forwent), so the model the balance numbers come from
		# and the game you actually play have disagreed about it.
		OptionTable.foreclose(n, _open_option)
		_open_option = -1
		for i in n.options.size():
			if not n.taken.has(MapGen.OPTION_SITE + i):
				return
	Run.consume_node(n)

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
			n.region == MapGen.Region.DEEP or n.region == MapGen.Region.FAUNA, r))
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
	# the theme at full intensity. DREAD_NOTES §5, "boss reveal". The hellbender is
	# one of those in everything but what winning pays, so it gets the cue too.
	Audio.music_state(&"boss" if template.boss or template.miniboss else &"combat")
	# A FIGHT IS NOT SOMETHING YOU HAVE WHILE TIED UP. This builds its own
	# SectorScreen rather than going through show_sector(), so it has to clear
	# the flag itself -- otherwise the HUD's second tab still said STATION on the
	# far side of the fight and offered to walk you back into a berth you had
	# already left.
	docked = false
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
	# Written down so SAVE & EXIT can restart exactly this fight.
	var ids: Array = [String(template.id)]
	for e in extras:
		ids.append(String((e as EnemyTemplate).id))
	current_fight = {ids = ids, clears = clears_node, share = share}
	# Built, then offered to the party, then opened. `plan()` produces the hull
	# numbers the host is told, so danger scaling and the pack split stay in
	# `Combat._spawn` rather than being worked out a second time in the session
	# layer — see Combat.plan().
	combat.plan(template, node.danger, extras)
	# The hellbender opens at the hull it actually has. Damage from a previous
	# engagement is the whole point of the chase — see RunState.hellbender_scarred
	# — and both the local fight and the party's copy have to start from it.
	if template.miniboss:
		combat.enemies[0].hp = clampi(Run.hellbender_hp, 1, combat.enemies[0].max_hp)
		# And its intent re-read at that hull. _spawn picked one at full health,
		# so a hellbender caught already on the ropes would otherwise open with an
		# attack it is past making — the escape has to be on the table from
		# turn one, exactly as the host's _pick_intent would put it there.
		combat.enemies[0].pick_intent()
	var f: SharedFight = null
	if share:
		# One round trip on a client, none on the host, and null in the solo
		# game. Null means "fight it alone", which is what every one of those
		# three wants when there is nobody else here.
		f = await Net.open_fight(node.index, combat.foe_ids(),
			combat.foe_hp(), combat.foe_brace(), combat.foe_hp_now())
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
	# The hellbender before anything the node itself holds — while it is here it IS
	# the engagement, and this reroute is what keeps every caller (the sector's
	# button, a bot joining an open fight) pointed at one fight per system.
	if Run.hellbender_alive() and Run.hellbender_at == n.index:
		engage_hellbender()
		return
	if n.cleared or in_combat():
		return
	if n.type == MapGen.NodeType.CORE:
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

## Commit to the galaxy's other harvester, wherever it was caught. The node is
## NOT consumed by winning — the hellbender is a visitor here, and whatever the
## system itself holds is still in it after the wreckage cools. Shared, like
## any fight at a place: its position is a host-owned fact every machine
## agrees on, so two ships engaging it are engaging one ship.
func engage_hellbender() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if in_combat() or not Run.hellbender_alive() or Run.hellbender_at != n.index:
		return
	start_combat(DB.enemies[&"hellbender"], [], false, true)


## Events can drop you straight into a fight (distress-beacon bait).
##
## Not shared, and not because of the enemy: the fight is drawn from `Rng.foe`
## rather than from the node, so two players who took the same bait are not
## looking at the same ship. The event that produced it was a private
## conversation and so is what came out of it.
## A fight an option's outcome opened.
##
## WINNING DOES NOT CONSUME THE SYSTEM, and that changed with the type collapse.
## An EVENT node held one event, so consuming on victory was harmless -- by the
## time this ran, `event_resolved` had already consumed it. A SYSTEM holds about
## three options, and clearing it here would delete the two the player had not
## reached yet: engage the hostile, win, and the wreck and the beacon that shared
## the system quietly stop existing.
##
## The option consumes ITSELF, through `taken`. The system is finished when
## nothing is left in it, which is `event_resolved`'s rule.
func start_ambush() -> void:
	var pool := DB.fight_pool(Run.node_at().danger, false)
	start_combat(DB.enemies[Rng.pick(Rng.foe, pool)], [], false, false)

## The fight a loaded save was left in (see resume_here), and the one in
## progress now, as SaveGame.mark_fight writes it.
var fight_on_resume: Dictionary = {}
var current_fight: Dictionary = {}

func in_combat() -> bool:
	return combat != null and not combat.finished

func after_combat(_c: Combat) -> void:
	combat = null
	current_fight = {}
	# An ambush is spent whatever happened to it — killed, pacified or shaken
	# off. Left on the node it would fire again the next time you flew in here,
	# and the heat that attracted it is not the heat you are carrying now.
	Run.node_at().ambush_pending = false
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
