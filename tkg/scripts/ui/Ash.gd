extends Node

## A.S.H., THE SHIP'S AI, SPEAKING (Jon and Ashlee, Oct 17; `docs/ash.md`; the
## ruling "A.S.H. is the ship, not crew"). Her face comes up in a small hologram
## frame on LOCAL and in fights, says one of the thirty approved lines at the
## moment it was written for, and fades (`AshPortrait` draws it; `AshLines`
## holds the lines), in her voice as it types (`AshLines.VOICE`, `Audio.ash_voice`).
##
## THE MOMENTS, each line's own (`AshLines` has the list):
##   launch  a new run, once the ship is at rest on LOCAL; gone at the first jump
##   hull    the first time she is up in a hull BOUGHT at a station's yard mid-run
##           (after the dock, never in it); not if the move is called off, and
##           never for the chassis select, a load or a hull found in the field
##   hurt    the hull at a quarter or under, alive; again only after it has been
##           back over half
##   hot     over the heat cap in a fight; once a fight
##   haul    a chit of HAUL_CREDITS or more, or an epic or better part, taken
##           aboard on LOCAL
##   greed   the third wreck opened since you last docked, and every third after
##   doubt   arriving somewhere new, DOUBT_CHANCE a time, at least DOUBT_EVERY
##           jumps after the last one and never before jump DOUBT_FROM
## A moment waits for its chance (`WAIT_S`) and is dropped if it does not get
## one: a line about the heat said once the heat is gone would be about nothing.
##
## SHE INTRODUCES HERSELF EVERY NEW RUN (Jon, Oct 18, "intro:A"; Oct 20: "On the
## first LOCAL section you load into on a new game, A.S.H. should introduce
## herself. Short beat. THEN the first tutorial hint." -- every run, not once a
## profile). A new run's launch line is `AshLines.INTRO` (launch_04,
## "Autonomous Systems Handler, reporting..."), not a pick from the bag; a run
## picked up with CONTINUE does not hear it again (`SaveGame.restoring`), and
## its launch, if it is still before the first jump, is the bag's. Same moment
## and slot as any launch line; the one difference is the order: the hints and
## the goal steps wait for it (`intro_holds`, read by `Hints`), where every
## other bark waits for them, so her first words are her name and no lesson
## cuts them; and after it ends, a beat (`INTRO_BEAT_S`) before the first of
## them. The once-a-profile flag it had (`[hints] ash_intro`) is not read any
## more; an old settings file that has it loads as before.
##
## SHE NEVER TALKS OVER HERSELF OR EVERY TURN:
##   - one line at a time, and COOLDOWN_S of quiet after one before the next;
##     the big moments (hurt, hull) wait only BIG_GAP_S;
##   - at most ONE line a fight, unless the hull starts failing in it;
##   - in a fight, only on your turn with the hand settled: never during a card
##     drag, the enemy's turn, a number in the air, the flee or hail question;
##     a drag or END TURN mid-line sends her off at once;
##   - nothing over a jump, an arrival, the camera moving between distances, the
##     cutaway, a wreck's window, the event band, the escape menu.
## NOTHING AFTER THE SHIP IS LOST (Jon: "No lines after the ship is lost. The ship
## has blown up."): she is the ship. Up when it goes, she cuts with it, no fade.
## HINTS WIN (`Hints`): she does not start while a hint is up, settling or due
## on this screen, and goes the moment one starts to settle.
##
## SHE NEVER COVERS ANYTHING. She stands at the first of `SPOTS` that is clear of
## everything listed in `avoid_rects` (the HUD, the goal line's band, the event
## band and the bar under the view, the hand and its buttons, both ships and the
## words, plates and shield ovals round them, the wrecks, an event's subject, a
## number in the air, a hint card, a side bar) and inside the view; with none
## clear she waits. Once up she does not move: if something comes into her box
## she goes. `-- sheet=AshTest` holds her to that on every screen she shows on.
##
## OFF UNDER HARNESSES (`TestRun.active`) unless the run asks with `-- ash`;
## `-- sheet=AshTest` turns her on by hand (`forced`). Off for good with Settings'
## SHIP'S VOICE (`[ash] on` in the settings file, the harness's under a harness).
##
## IN CO-OP each machine's A.S.H. is its own ship's: she reads this process's
## `Run` and nothing else, sends nothing, and nothing waits on her, so a shared
## fight's barrier never does. A partner's hull failing is not yours.
##
## SHE TEACHES (Jon picked how A for the tutorial, Oct 17: "A.S.H. replaces the
## hint cards"). While she is on, each first-run hint (`Hints`) comes in her
## corner in her words (`AshTutorLines`), the thing she means outlined, instead
## of a card; and each goal step (`GoalLine`) is said once as it starts. The
## hints keep their triggers, their order, their subjects and their click
## (`Hints` still decides all of it and calls `teach`). A teaching line:
##   - outranks a bark: a bark up gives way at once, and none starts while a
##     teaching line is up, settling or due (her "hints win", unchanged);
##   - is not held to her quiet, her one line a fight, or her keeping off the
##     cutaway, a wreck's window and the event band;
##   - stands on the STARCHART, the SECTOR map and the station as well as LOCAL
##     and fights, at the first spot clear of everything there (`tut_avoid_rects`,
##     `covers`: every system and world a click picks, their words and orbits,
##     every button, the yard's ships, drones and screen);
##   - a hint's holds once it is out until a click lets it go (Jon: "let's have
##     them advance with a click"); a step's holds for its reading time and goes.
## Off in a party, as the hints are (`Hints.enabled`, "coop:B"). Off with her
## switch, and the cards come back exactly as they were.

const SECTION := "ash"
## THE BEAT after her introduction ends before the first lesson starts, s (game
## time; Jon: "Short beat. THEN the first tutorial hint."). A goal step takes its
## own settle (`Hints.SETTLE_S`) after the hold lets go, so the hold is this less
## that: the step starts this long after she stops.
const INTRO_BEAT_S := 1.5
## Highest first: when two are waiting, this one is said.
const ORDER: Array[StringName] = [&"hurt", &"hull", &"hot", &"haul", &"greed", &"launch", &"doubt"]
## The moments that may break the quiet early, and a fight's one-line rule.
const BIG: Array[StringName] = [&"hurt", &"hull"]
## Quiet after a line before the next, s (game time), and before a big one.
const COOLDOWN_S := 40.0
const BIG_GAP_S := 6.0
## How long each moment waits for its chance, s. INF waits for as long as it is
## true (the launch until the first jump, the hull until she is up in it).
const WAIT_S := {
	&"launch": INF, &"hull": INF, &"hurt": 20.0, &"hot": 12.0,
	&"haul": 20.0, &"greed": 30.0, &"doubt": 30.0,
}
## Hull failing: at or under this share of the hull; again only after the hull
## has been over REARM_HURT.
const HURT_AT := 0.25
const REARM_HURT := 0.5
## A big haul: a chit of this many credits, or a part of this rarity or better.
const HAUL_CREDITS := 60
const HAUL_RARITY := ModuleData.Rarity.EPIC
## One more wreck: every this many wrecks opened since you last docked.
const GREED_EVERY := 3
## Doubt: from this jump on, at least this many jumps apart, this chance a jump.
const DOUBT_FROM := 6
const DOUBT_EVERY := 10
const DOUBT_CHANCE := 0.3
## Where she may stand, in order (`_spot`): her face's corner of the view, under
## the goal line's band at the top, above the hand or the bar at the bottom.
const SPOTS: Array[StringName] = [&"top_left", &"bottom_left", &"top_right", &"bottom_right"]
## Every spot considered (the harnesses survey them all: `survey`).
const ALL_SPOTS: Array[StringName] = [&"top_left", &"top_third", &"top_mid", &"top_right",
	&"bottom_left", &"bottom_third", &"bottom_mid", &"bottom_right"]
## The band under the HUD the goal line lives in, px (`GoalLine`: 24 and 1).
const GOAL_BAND := 26.0
## Her margin from the view's edges and from what she stands over, px.
const EDGE := 6.0

## On for a harness that drives her by hand (`-- sheet=AshTest`).
var forced := false
## For the harness that photographs the spots she was not given
## (`-- sheet=AshShot mode=options`): stand here whatever is under it.
var force_spot: StringName = &""
## Game seconds since launch (the process delta summed: `GameClock`'s clock).
var now := 0.0
## Every line said since launch: {kind, line, at, spot, rect}.
var said_log: Array = []
## The portrait, while one is up or fading.
var portrait: AshPortrait = null
## Moments waiting: kind -> the time it was armed.
var waiting: Dictionary = {}
## Why she did not speak on the last poll she had something to say (harnesses).
var held_by := ""
## Settings' switch, loaded once.
var _on := true
var _loaded := false
## Her introduction: still to say this run, up now, and when it ended (GameClock
## s; -1 not yet).
var _intro_due := false
var _introducing := false
var _intro_end := -1.0
## HER BOX WITH THE GOAL (Jon, Oct 20: the goal, its step and her box one
## group): a top spot's y and the goal's when she came up, so while the goal
## slides with the top plate she goes with it (`_follow_goal`).
var _group := false
var _group_y := 0.0
var _goal_y := 0.0

var _last_end := -INF
var _fight: Object = null
var _fight_lines := 0
var _fight_hurt := false
var _fight_hot := false
var _hurt_latched := false
var _known_hull: HullData = null
var _left_hull: HullData = null
## `Run.hulls_bought` as of the last poll: a hull change with no purchase
## since then (the chassis select, a load, a found hull) says nothing.
var _bought := 0
var _hauls := 0
var _credits := 0
var _items: Dictionary = {}
var _wrecks_open: Dictionary = {}
var _wrecks_since_dock := 0
var _greed_at := 0
var _jumps_since_doubt := 0
var _bags: Dictionary = {}
var _run_live := false
var _up := false

## THE TEACHING LINE UP, if any (`teach`): its line id (`AshTutorLines`), the hint
## it says ("" for a goal step), what it points at (global), and the screen it
## started on.
var lesson: StringName = &""
var lesson_hint: StringName = &""
var lesson_subject := Rect2()
var _lesson_on: Object = null
var _lesson_check := 0.0
var _outline: Outline = null


func _ready() -> void:
	Sig.run_started.connect(_on_run_started)
	Sig.jumped.connect(_on_jumped)
	Sig.run_ended.connect(func(_w: bool, _r: String) -> void: _lost())


# ------------------------------------------------------------------ the switch

func enabled() -> bool:
	if not _loaded:
		_load()
	return _on and (forced or "ash" in OS.get_cmdline_user_args() or not TestRun.active())


func is_on() -> bool:
	if not _loaded:
		_load()
	return _on


func set_on(v: bool) -> void:
	_on = v
	_loaded = true
	var cfg := ConfigFile.new()
	cfg.load(DisplaySettings.path)
	cfg.set_value(SECTION, "on", v)
	cfg.save(DisplaySettings.path)
	if not v:
		_quiet()


func _load() -> void:
	var cfg := ConfigFile.new()
	_on = true
	if cfg.load(DisplaySettings.path) == OK:
		_on = bool(cfg.get_value(SECTION, "on", true))
	_loaded = true


## Re-read the file (a harness that wrote it behind our back).
func reload() -> void:
	_loaded = false


## HER INTRODUCTION: whether this run has had it (or a loaded run, which does
## not hear it again).
func intro_said() -> bool:
	return not _intro_due


## Mark it said this run (or not: a harness that wants a launch line from the
## bag, or the introduction again).
func mark_intro(v: bool = true) -> void:
	_intro_due = not v
	if v:
		_intro_end = -1.0


## Her introduction has just stopped being said: the beat starts.
func _intro_tick() -> void:
	if not _introducing:
		return
	if portrait != null and is_instance_valid(portrait) and portrait.speaking() and portrait.kind == &"launch":
		return
	_introducing = false
	# THE BEAT IS FROM HER LAST WORD (Jon, Oct 20: "The delay between the intro
	# and the first hint is WAY too long"), not from her box going
	_intro_end = GameClock.now()
	if portrait != null and is_instance_valid(portrait) and portrait.voice_started_at >= 0.0:
		_intro_end = minf(_intro_end, portrait.voice_started_at + portrait.voice_secs - AshPortrait.VOICE_TAIL_S)


## Her introduction is up, or it is next and could start now: the hints and the
## goal steps wait for it (`Hints.poll`, `Hints.step_due`), so it is her first
## line and none of them cuts it. False the moment anything else would keep it
## waiting (the screen, a hint card already up, no room), so a hint is never
## held for a line that is not coming.
func intro_holds() -> bool:
	if not _run_live or Run.hull == null or Run.dead or Run.hp <= 0 or not enabled():
		return false
	var up := portrait != null and is_instance_valid(portrait)
	_intro_tick()
	if _introducing:
		return true
	# THE BEAT after it, before the first lesson (less the step's own settle)
	if _intro_end >= 0.0:
		if GameClock.now() - _intro_end < INTRO_BEAT_S - Hints.SETTLE_S:
			return true
		_intro_end = -1.0
	if not waiting.has(&"launch") or intro_said() or lesson != &"" or _next() != &"launch":
		return false
	if up and portrait.phase != AshPortrait.Phase.GONE:
		return false
	if now - _last_end < COOLDOWN_S or (_fight != null and _fight_lines >= 1):
		return false
	if Hints.card != null and is_instance_valid(Hints.card):
		return false
	if _screen_only(true) != "":
		return false
	return not _spot(AshLines.line_of(AshLines.INTRO)).is_empty()


# ------------------------------------------------------------------ the moments

func _on_run_started() -> void:
	waiting.clear()
	_fight = null
	_fight_lines = 0
	_hurt_latched = false
	_known_hull = Run.hull
	_bought = Run.hulls_bought
	_hauls = Run.hauls
	_credits = Run.credits
	_items = _item_ids()
	_wrecks_open = _opened_here()
	_wrecks_since_dock = 0
	_greed_at = 0
	_jumps_since_doubt = 0
	_bags.clear()
	_run_live = true
	_last_end = -INF
	if portrait != null:
		portrait.cut()
	# HER INTRODUCTION, a new run's: not a run picked up with CONTINUE
	_intro_due = not SaveGame.restoring
	_introducing = false
	_intro_end = -1.0
	# A NEW RUN'S FIRST LAUNCH. A loaded run before its first jump hears it too:
	# the suspend save is a bookmark, and this is still the launch.
	if Run.jumps == 0:
		arm(&"launch")


func _on_jumped(_i: int) -> void:
	_jumps_since_doubt += 1
	waiting.erase(&"launch")
	_wrecks_open = {}
	if Run.jumps >= DOUBT_FROM and _jumps_since_doubt >= DOUBT_EVERY and randf() < DOUBT_CHANCE:
		arm(&"doubt")


## A moment has come: it waits for its chance (`WAIT_S`). Public so a harness can
## arm one directly.
func arm(kind: StringName) -> void:
	if not AshLines.MOMENTS.has(kind):
		return
	if not waiting.has(kind):
		waiting[kind] = now


## The ship is gone: so is she, and everything she was going to say.
func _lost() -> void:
	waiting.clear()
	if portrait != null and portrait.phase != AshPortrait.Phase.GONE:
		portrait.cut()
	_clear_lesson()


## Off (Settings): nothing waiting, nothing up.
func _quiet() -> void:
	waiting.clear()
	if portrait != null:
		portrait.cut()
	_clear_lesson()


## Watch the run for the moments that are a state rather than an event.
func _watch() -> void:
	var cur := Router.current
	var sc := cur as SectorScreen
	# a fight is one fight however many frames it lasts
	var c: Object = Router.combat if sc != null and sc.fighting() else null
	if c != _fight:
		_fight = c
		_fight_lines = 0
		_fight_hurt = false
		_fight_hot = false
		if c == null:
			waiting.erase(&"hot")
	# HULL FAILING, alive
	var top := float(maxi(1, Run.max_hp()))
	if Run.hp > 0 and float(Run.hp) <= top * HURT_AT:
		if not _hurt_latched:
			_hurt_latched = true
			arm(&"hurt")
	elif float(Run.hp) > top * REARM_HURT:
		_hurt_latched = false
		waiting.erase(&"hurt")
	# OVER THE HEAT CAP, in a fight; gone when it is not
	if _fight != null and Run.heat > Run.heat_cap():
		if not _fight_hot:
			_fight_hot = true
			arm(&"hot")
	else:
		waiting.erase(&"hot")
	# A NEW HULL: armed when the frame changes BECAUSE ONE WAS BOUGHT at a
	# station's yard (`Run.hulls_bought`; Jon, Oct 18: only "when a player buys
	# a new ship mid run" -- never the chassis select's picks before launch, a
	# load, or a hull found in the field), said the next time she is up, on
	# LOCAL or in a fight, so never mid-dock; and forgotten if the move is
	# called off and the old frame comes back (`Run.abandon_move`)
	if Run.hull != _known_hull:
		if Run.hull != null and Run.hull == _left_hull and waiting.has(&"hull"):
			waiting.erase(&"hull")
		elif _known_hull != null and Run.hull != null and Run.hulls_bought > _bought:
			arm(&"hull")
		_left_hull = _known_hull
		_known_hull = Run.hull
	_bought = Run.hulls_bought
	# A BIG HAUL, taken aboard on LOCAL
	var items := _item_ids()
	if Run.hauls > _hauls and sc != null:
		var big := Run.credits - _credits >= HAUL_CREDITS
		for id in items:
			if not _items.has(id):
				var m := instance_from_id(id) as ModuleData
				if m != null and int(m.rarity) >= int(HAUL_RARITY) \
						and int(m.rarity) != int(ModuleData.Rarity.CONTRABAND):
					big = true
		if big:
			arm(&"haul")
	_hauls = Run.hauls
	_credits = Run.credits
	_items = items
	# ONE MORE WRECK
	if cur is StationScreen:
		_wrecks_since_dock = 0
		_greed_at = 0
	var open := _opened_here()
	for id in open:
		if not _wrecks_open.has(id):
			_wrecks_since_dock += 1
			if _wrecks_since_dock >= GREED_EVERY and _wrecks_since_dock - _greed_at >= GREED_EVERY:
				_greed_at = _wrecks_since_dock
				arm(&"greed")
	_wrecks_open = open
	# the launch is a launch only before the first jump
	if Run.jumps > 0:
		waiting.erase(&"launch")
	# what has waited too long is about nothing now
	for k in waiting.keys():
		if now - float(waiting[k]) > float(WAIT_S.get(k, 20.0)):
			waiting.erase(k)


func _item_ids() -> Dictionary:
	var out := {}
	for m in Run.installed:
		out[m.get_instance_id()] = true
	for m in Run.cargo:
		out[m.get_instance_id()] = true
	for m in Run.pad:
		out[m.get_instance_id()] = true
	return out


## The wrecks here that have been opened, by instance.
func _opened_here() -> Dictionary:
	var out := {}
	var n := Run.node_at()
	if n == null:
		return out
	for raw in Run.wrecks_here(n):
		var h: MapGen.Jetsam = raw
		if h.is_wreck() and h.opened:
			out[h.get_instance_id()] = true
	return out


# ------------------------------------------------------------------ the clock

func _process(delta: float) -> void:
	poll(delta)


## One step. Public so `-- sheet=AshTest` can step her on its own clock.
func poll(delta: float) -> void:
	now += delta
	if Run.hull == null or not _run_live:
		return
	if Run.dead or Run.hp <= 0:
		_lost()
		return
	if not enabled():
		_quiet()
		return
	_follow_goal()
	_intro_tick()
	_watch()
	# THE QUIET STARTS WHEN A LINE ENDS, however it ended
	if _up and (portrait == null or not portrait.speaking()):
		_up = false
		_last_end = now
	# A TEACHING LINE: its own rules (`_lesson_must_go`), and the outline on its
	# subject while it is up
	if lesson != &"":
		if not lesson_up():
			_clear_lesson()
		else:
			_lesson_check -= delta
			if _lesson_check <= 0.0:
				_lesson_check = LESSON_CHECK_S
				var why := _lesson_must_go()
				if why != "":
					held_by = why
					if why == "turn":
						portrait.cut()
					else:
						portrait.leave(true)
					_clear_lesson()
			return
	if portrait != null and portrait.speaking():
		portrait.hurt = _hurt_latched
		var why := _must_go(portrait.rect())
		if why != "":
			held_by = why
			# END TURN: gone that frame, before the turn's numbers can land where
			# she was; a hint or a drag: a quick fade; anything else: her fade
			if why == "turn":
				portrait.cut()
			else:
				portrait.leave(why == "hint" or why == "drag")
		return
	if portrait != null and portrait.phase == AshPortrait.Phase.GOING:
		return
	if waiting.is_empty():
		held_by = ""
		return
	var kind := _next()
	var why := _cannot_start(kind)
	held_by = why
	if why != "":
		return
	var line := pick_line(kind)
	var spot := _spot(line)
	if spot.is_empty():
		held_by = "room"
		return
	_say(kind, line, spot)


## Her box up on a top spot moves with the goal as it slides with the top plate
## (`GoalLine.fixed_at`), the same pixels, so the three never part or touch.
func _follow_goal() -> void:
	if not _group or portrait == null or not is_instance_valid(portrait) or not portrait.visible:
		return
	portrait.position.y = _group_y + (GoalLine.fixed_at().y - _goal_y)


func _group_from(spot: Dictionary) -> void:
	_group = String(spot.get("name", "")).begins_with("top")
	_group_y = (spot.rect as Rect2).position.y
	_goal_y = GoalLine.fixed_at().y


## The first waiting moment, by `ORDER`.
func _next() -> StringName:
	for k in ORDER:
		if waiting.has(k):
			return k
	return &""


## Why she may not start `kind` now; "" if she may.
func _cannot_start(kind: StringName) -> String:
	var gap := BIG_GAP_S if BIG.has(kind) else COOLDOWN_S
	if now - _last_end < gap:
		return "cooldown"
	if _fight != null:
		if _fight_lines >= 1 and not (kind == &"hurt" and not _fight_hurt):
			return "fight"
	return _screen_block()


## Why the screen is not one she may speak on now; "" if it is. `starting`: to
## come up, rather than to stay up.
func _screen_block(starting: bool = true) -> String:
	if _hint_up(starting):
		return "hint"
	return _screen_only(starting)


## `_screen_block` without the hints: the screen itself.
func _screen_only(starting: bool = true) -> String:
	if Hints.menu_up() or ZoomLadder.busy():
		return "screen"
	var sc := Router.current as SectorScreen
	if sc == null or not is_instance_valid(sc) or not sc.is_visible_in_tree():
		return "screen"
	if Router.hud == null or not Router.hud.is_visible_in_tree():
		return "screen"
	if sc._phase != SectorScreen.Phase.NONE or sc._card != null:
		return "screen"
	if sc._cutaway != null or sc._transfer != null:
		return "screen"
	var d := sc._events
	if d != null and is_instance_valid(d) and (d.page != &"" or d._transfer != null):
		return "screen"
	if sc.fighting():
		if _dragging(sc):
			return "drag"
		# the enemy's turn, from the click on END TURN (`_hold`) to the new hand,
		# or a shared fight waiting on the others
		if sc._playing or sc._hold or sc._opening or sc._raising or not sc._breakups.is_empty() \
				or not sc._dying.is_empty() or sc._exit_ask != null or sc._pile_panel != null \
				or sc.combat.waiting or sc.combat.finished:
			return "turn"
		if sc._end_button == null or not sc._end_button.is_visible_in_tree() or sc._end_button.disabled:
			return "turn"
		# not into a volley: she starts when the numbers have settled (once up, a
		# number only sends her off if it lands on her: `_must_go`)
		if starting and sc._view != null and not sc._view.fx._pops.is_empty():
			return "turn"
	return ""


## Why she must go now she is up; "" to stay.
func _must_go(r: Rect2) -> String:
	var why := _screen_block(false)
	if why != "" or force_spot != &"":
		return why
	for a in avoid_rects(Router.current):
		if (a as Rect2).size != Vector2.ZERO and r.intersects(a as Rect2):
			return "covered"
	return ""


func _dragging(sc: SectorScreen) -> bool:
	return sc._grab_view != null or sc._aim_view != null or sc.get_viewport().gui_is_dragging()


## A hint is up, settling, or between two of a run (its gap), or one this
## screen would show has not been seen yet: hints win, and she does not start
## a line the next hint would cut short. `starting` false: only up or settling.
func _hint_up(starting: bool = true) -> bool:
	if Hints.card != null and is_instance_valid(Hints.card):
		return true
	# her own teaching line, or one of a goal step's on its way (`Hints.step_due`)
	if lesson != &"" or Hints.lesson != &"":
		return true
	# HER INTRODUCTION GOES FIRST (intro:A): the hints and steps wait for it
	# (`intro_holds`), so it does not wait for them; the beat after it holds
	# everything
	if starting and intro_holds():
		# (the beat after it: her other lines wait too, one thing at a time)
		return _intro_end >= 0.0
	if starting and Hints.step_due():
		return true
	if Hints._cand != &"":
		return true
	if not starting or not Hints.enabled():
		return false
	if Hints._quiet > 0.0:
		return true
	for id in Hints.ORDER:
		if not Hints.seen(id) and not Hints.probe(id).is_empty():
			return true
	return false


# ------------------------------------------------------------------ the lines

## A line of `kind`: never the one she said last time for it, and none again
## until the rest of its moment has been said (cosmetic: the global generator).
func pick_line(kind: StringName) -> String:
	var all := AshLines.of(kind)
	if all.is_empty():
		return ""
	# A NEW RUN'S LAUNCH introduces her (intro:A, every run); the bag is untouched
	if kind == &"launch" and not intro_said():
		return AshLines.line_of(AshLines.INTRO)
	var bag: Array = _bags.get(kind, [])
	if bag.is_empty():
		bag = all.duplicate()
		bag.shuffle()
		var last := ""
		for i in range(said_log.size() - 1, -1, -1):
			if StringName(said_log[i].kind) == kind:
				last = String(said_log[i].line)
				break
		if bag.size() > 1 and String(bag[0]) == last:
			bag.push_back(bag.pop_front())
	var line := String(bag.pop_front())
	_bags[kind] = bag
	return line


func _say(kind: StringName, line: String, spot: Dictionary) -> void:
	waiting.erase(kind)
	if portrait == null or not is_instance_valid(portrait):
		portrait = AshPortrait.new()
		portrait.top_level = true
		portrait.z_index = 50
	var host := _host()
	if host == null:
		return
	if portrait.get_parent() != host:
		if portrait.get_parent() != null:
			portrait.get_parent().remove_child(portrait)
		host.add_child(portrait)
	portrait.theme = _theme()
	portrait.mirrored = bool(spot.mirrored)
	portrait.position = (spot.rect as Rect2).position
	portrait.size = Vector2(AshPortrait.W, AshPortrait.H)
	var is_intro := kind == &"launch" and not intro_said() and AshLines.id_of(line) == AshLines.INTRO
	# (her introduction goes with her voice: the beat after it is the wait)
	portrait.say(line, kind, {quick = true} if is_intro else {})
	_group_from(spot)
	_up = true
	# her introduction, said: not again this run
	if is_intro:
		mark_intro(true)
		_introducing = true
	if _fight != null:
		_fight_lines += 1
		if kind == &"hurt":
			_fight_hurt = true
	said_log.append({kind = kind, line = line, at = now, spot = spot.name, rect = spot.rect})
	print("[ash] %s: %s" % [kind, line])


## Where she goes: a column after the screens, beside the HUD, so she is over
## the picture and under the escape menu (the goal line's place).
func _host() -> Node:
	if Router.hud == null or not is_instance_valid(Router.hud):
		return null
	return Router.hud.get_parent()


func _theme() -> Theme:
	var n: Node = Router.content
	while n != null:
		if n is Control and (n as Control).theme != null:
			return (n as Control).theme
		n = n.get_parent()
	return null


# ------------------------------------------------------------------ the place

## The view she stands in, global: under the HUD, above the hand (a fight) or
## the bar under the view (LOCAL), between the screen's margins.
static func view_rect(cur: Control) -> Rect2:
	var sc := cur as SectorScreen
	if sc == null or sc._view == null or Router.hud == null:
		return Rect2()
	var v := sc._view.get_global_rect()
	var hud := Router.hud.get_global_rect()
	var top := hud.end.y
	var bottom := v.end.y
	for c: Control in [sc._hand_wrap, sc._quiet_wrap]:
		if c != null and is_instance_valid(c) and c.is_visible_in_tree() and c.size.y > 0.0:
			bottom = minf(bottom, c.get_global_rect().position.y)
	return Rect2(Vector2(maxf(v.position.x, hud.position.x), top),
		Vector2(minf(v.end.x, hud.end.x) - maxf(v.position.x, hud.position.x), bottom - top))


## Each spot's box for a portrait on `cur`, global: {name, rect, mirrored}.
static func spot_boxes(cur: Control) -> Array:
	var out: Array = []
	var v := view_rect(cur)
	if v.size.x <= 0.0:
		return out
	var sz := Vector2(AshPortrait.W, AshPortrait.H)
	var top := roundf(v.position.y + GOAL_BAND + 2.0)
	var bottom := roundf(v.end.y - EDGE - sz.y)
	var xs := {
		&"left": roundf(v.position.x + EDGE),
		&"third": roundf(v.position.x + v.size.x / 3.0),
		&"mid": roundf(v.get_center().x - sz.x * 0.5),
		&"right": roundf(v.end.x - EDGE - sz.x),
	}
	for s in ALL_SPOTS:
		if not SPOTS.has(s) and not _survey:
			continue
		var parts := String(s).split("_")
		var y := top if parts[0] == "top" else bottom
		var r := _under_goal(Rect2(Vector2(float(xs[StringName(parts[1])]), y), sz), cur)
		out.append({name = s, rect = r, mirrored = parts[1] == "right"})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _rank(a.name) < _rank(b.name))
	return out


## A TOP SPOT THAT WOULD STAND ON THE GOAL OR ITS STEP (`GoalLine`: at the top
## left of the picture on LOCAL, the map and the chart, Jon, Oct 20) stands
## under the two of them instead, EDGE below the step's room. In a fight beside
## the goal's line instead, at the same height (a fight has no step, and under
## the goal is your hull: the 65 screens of `AshTest` measured that corner as
## the one clear in every fight).
static func _under_goal(r: Rect2, cur: Control) -> Rect2:
	var st := GoalLine.stack_rect(cur)
	if st.size != Vector2.ZERO and r.intersects(st.grow(EDGE - 1.0)):
		if GoalLine._fighting(cur):
			r.position.x = roundf(st.end.x + EDGE)
		else:
			r.position.y = roundf(st.end.y + EDGE)
	return r


## The first spot clear of everything for `line`; {} if none is.
func _spot(line: String) -> Dictionary:
	if AshPortrait.lines_for(line) > 4:
		push_warning("Ash: '%s' is more than four lines in her column" % line)
	var cur := Router.current
	var v := view_rect(cur)
	var avoid := avoid_rects(cur)
	if force_spot != &"":
		for s: Dictionary in survey_boxes(cur):
			if s.name == force_spot:
				return s
	for s: Dictionary in spot_boxes(cur):
		if clear(s.rect, avoid, v):
			return s
	return {}


static var _survey := false


## Every spot, for the harnesses that compare them.
static func survey_boxes(cur: Control) -> Array:
	_survey = true
	var out := spot_boxes(cur)
	_survey = false
	return out


static func _rank(s: StringName) -> int:
	var i := SPOTS.find(s)
	return i if i >= 0 else 100 + ALL_SPOTS.find(s)


static func clear(r: Rect2, avoid: Array, inside: Rect2) -> bool:
	if not inside.grow(0.5).encloses(r):
		return false
	for a in avoid:
		if (a as Rect2).size != Vector2.ZERO and r.intersects(a as Rect2):
			return false
	return true


## EVERYTHING SHE MUST NOT COVER on `cur`, global. Public: `AshTest` measures
## against the same list.
static func avoid_rects(cur: Control) -> Array:
	var out: Array = []
	if Router.hud != null and is_instance_valid(Router.hud) and Router.hud.is_visible_in_tree():
		var hud := Router.hud.get_global_rect()
		out.append(hud)
		# the band under the HUD, kept clear as it always was on LOCAL
		out.append(Rect2(hud.position.x, hud.end.y, hud.size.x, GOAL_BAND))
		# THE GOAL AND ITS STEP (`GoalLine`, at the picture's top left, Jon, Oct
		# 20): the two lines as drawn, and the room they keep whether a step is
		# pending or not, so a step arriving never lands on her
		if Router.hud.has_method("goal_rect"):
			out.append(Router.hud.call("goal_rect"))
		var gl: Variant = Router.hud.get("goal")
		if gl is GoalLine and is_instance_valid(gl):
			out.append((gl as GoalLine).step_rect())
		out.append(GoalLine.stack_rect(cur))
	if Hints.card != null and is_instance_valid(Hints.card) and Hints.card.visible:
		out.append(Hints.card.get_global_rect())
	if cur == null or not is_instance_valid(cur):
		return out
	if cur.has_method("ladder_side"):
		var side: Control = cur.call("ladder_side")
		if side != null and is_instance_valid(side) and side.is_visible_in_tree():
			out.append(side.get_global_rect())
	var sc := cur as SectorScreen
	if sc == null:
		return out
	# the fight log's LOG button, and the log while it is open (`FightLog`)
	out.append_array(FightLog.rects(sc))
	var d := sc._events
	if d != null and is_instance_valid(d) and d.visible:
		out.append(d.get_global_rect())
	for c: Control in [sc._quiet_wrap, sc._hand_wrap, sc._end_button, sc._flee_button, sc._hail_button]:
		if c != null and is_instance_valid(c) and c.is_visible_in_tree():
			out.append(c.get_global_rect())
	if sc._self_plate != null and sc._self_plate.is_visible_in_tree():
		out.append(sc._self_plate.get_global_rect())
	var v := sc._view
	if v == null:
		return out
	var ship := v.ship_view()
	if ship != null and ship.is_visible_in_tree():
		# (not the numbers a hit on you pops: they land on the enemy's turn and
		# at END TURN, and she is never up then: `_screen_block`)
		out.append(ship.get_global_transform() * ship.ship_rect())
		# your shield's oval, up or not
		var L: HitLayers = sc._ship_fx
		if L != null and is_instance_valid(L) and L.shield != null and L.shield.is_visible_in_tree():
			var sh := L.shield
			var rad := Vector2(sh._rx, sh._ry)
			out.append(sh.get_global_transform() * Rect2(sh._origin + sh._cc - rad, rad * 2.0))
	for i in 16:
		var sl := v.slot(i)
		if sl == null or not is_instance_valid(sl) or not sl.is_visible_in_tree():
			continue
		out.append(sl.get_global_transform() * sl.ink_rect())
		for r: Rect2 in [sl.intent_rect_global(), sl.readout_rect_global()]:
			if r.size != Vector2.ZERO:
				out.append(r)
		if sl.art != null:
			for p in sl.rooms(sl.art.draw_scale):
				out.append(sl.get_global_transform() * (p[1] as Rect2))
		# where the numbers your cards land on it pop: above its words (or its
		# ink), three high and risen (`SectorScreen._pop_at`)
		if sc.fighting():
			var ink := sl.get_global_transform() * sl.ink_rect()
			var words := sl.intent_rect_global()
			var top := minf(ink.position.y, words.position.y) if words.size.y > 0.0 else ink.position.y
			var reach := 2.0 * HitText.LINE + HitText.CAP + 1.0 + HitText.RISE + 4.0
			var wide := HitText.ink_width("BLOCKED 99") + 8.0
			out.append(Rect2(ink.get_center().x - wide * 0.5, top - reach, wide, reach))
	# the numbers in the air now
	if v.fx != null:
		var inv := v.fx.get_global_transform()
		for p in v.fx._pops:
			var at: Vector2 = (p.at + Vector2(-HitText.ink_width(p.text) * 0.5, 0.0)).round()
			out.append(inv * HitText.ink_rect(at, p.text).grow(2.0))
	var subj := LocalSubject.of(v)
	if subj != null:
		out.append_array(subj.drawn_rects())
	return out


# ------------------------------------------------------------------ teaching

## How often a teaching line looks again at what may have come into its box, s.
const LESSON_CHECK_S := 0.1


## SHE TEACHES while she is on and the run is live (her switch; a harness that
## asked). `Hints` asks this to choose her corner or a card.
func teaches() -> bool:
	return enabled() and Run.hull != null and _run_live and not Run.dead and Run.hp > 0


## Say teaching line `lid` (`AshTutorLines`) now, its words `text` (filled),
## pointing at `subject` (global; Rect2() for none). `hint`: the hint it says,
## held until let go; "" for a goal step, which goes after its reading time.
## `opts`: `voice` and `spoken` (`AshTutorLines.voice_path` / `spoken`). False
## if she cannot: off, or nowhere on this screen clear for her (`tut_spot`).
func teach(lid: StringName, text: String, hint: StringName, subject: Rect2, opts: Dictionary = {}) -> bool:
	if not teaches():
		return false
	var cur := Router.current
	if cur == null or not is_instance_valid(cur):
		return false
	var spot := tut_spot(cur, text, subject)
	if spot.is_empty():
		held_by = "room"
		return false
	var host := _host()
	if host == null:
		return false
	# A TEACHING LINE OUTRANKS A BARK: whatever she was saying, she is not now
	if portrait != null and is_instance_valid(portrait) and portrait.phase != AshPortrait.Phase.GONE:
		portrait.cut()
	if portrait == null or not is_instance_valid(portrait):
		portrait = AshPortrait.new()
		portrait.top_level = true
		portrait.z_index = 50
	if portrait.get_parent() != host:
		if portrait.get_parent() != null:
			portrait.get_parent().remove_child(portrait)
		host.add_child(portrait)
	portrait.theme = _theme()
	portrait.mirrored = bool(spot.mirrored)
	portrait.position = (spot.rect as Rect2).position
	_group_from(spot)
	portrait.say(text, StringName("tut_" + String(lid)), {
		voice = String(opts.get("voice", "")), spoken = String(opts.get("spoken", "")),
		held = hint != &""})
	# (not `_up`: a teaching line does not start her barks' quiet, so they keep
	# the timing they had beside the cards)
	lesson = lid
	lesson_hint = hint
	lesson_subject = subject
	_lesson_on = cur
	_lesson_check = LESSON_CHECK_S
	_outline_to(subject)
	said_log.append({kind = StringName("tut_" + String(lid)), line = text, at = now, spot = spot.name,
		rect = spot.rect, tutorial = true, hint = hint, subject = subject})
	print("[ash] tut %s: %s" % [lid, text])
	return true


## Her teaching line is up and saying (not going).
func lesson_up() -> bool:
	return lesson != &"" and portrait != null and is_instance_valid(portrait) and portrait.speaking() \
		and portrait.kind == StringName("tut_" + String(lesson))


## The subject moved (`Hints` keeps it each frame): the outline goes with it.
func aim_lesson(subject: Rect2) -> void:
	if lesson == &"":
		return
	lesson_subject = subject
	_outline_to(subject)


## Let the teaching line go: a click spent it (`quick`), or its subject left.
func end_lesson(quick: bool = true) -> void:
	if lesson_up():
		portrait.leave(quick)
	_clear_lesson()


func _clear_lesson() -> void:
	lesson = &""
	lesson_hint = &""
	lesson_subject = Rect2()
	_lesson_on = null
	_outline_to(Rect2())


## Why a teaching line must go now; "" to stay. Not her bark rules: it may stand
## over the cutaway, a wreck's window and the event band, and on the chart, the
## map and the station. It goes when the screen does (a swap, the camera moving,
## a jump, the escape menu), on the enemy's turn, or when something comes into
## its box.
func _lesson_must_go() -> String:
	var cur := Router.current
	if cur == null or not is_instance_valid(cur) or cur != _lesson_on or not cur.is_visible_in_tree():
		return "screen"
	if Hints.menu_up() or ZoomLadder.busy():
		return "screen"
	if Router.hud == null or not Router.hud.is_visible_in_tree():
		return "screen"
	var sc := cur as SectorScreen
	if sc != null:
		if sc._phase != SectorScreen.Phase.NONE:
			return "screen"
		if sc.fighting() and (sc._playing or sc._hold or sc.combat.finished):
			return "turn"
	var r := portrait.rect()
	var a := tut_avoid_rects(cur)
	if lesson_subject.size != Vector2.ZERO:
		a.append(lesson_subject)
	for x in a:
		if (x as Rect2).size != Vector2.ZERO and r.intersects(x as Rect2):
			return "covered"
	if covers(cur, r) != "":
		return "covered"
	return ""


# ------------------------------------------------------------------ where she teaches

## Where a teaching line `text` stands on `cur`, pointing at `subject`: the
## first spot clear of everything (`tut_avoid_rects`, `covers`, the subject)
## inside the view (`tut_view_rect`); {} if none is.
static func tut_spot(cur: Control, text: String, subject: Rect2 = Rect2()) -> Dictionary:
	var v := tut_view_rect(cur)
	if v.size.x <= 0.0:
		return {}
	var avoid := tut_avoid_rects(cur)
	if subject.size != Vector2.ZERO:
		avoid.append(subject)
	for s: Dictionary in tut_spot_boxes(cur, AshPortrait.size_for(text)):
		if clear(s.rect, avoid, v) and covers(cur, s.rect) == "":
			return s
	return {}


## The view she may teach in on `cur`, global. LOCAL and a fight: hers
## (`view_rect`), right of the cutaway's panel while it is open. The chart and
## the map: their picture inside its frame. The station: the deck's picture,
## right of the decks.
static func tut_view_rect(cur: Control) -> Rect2:
	if cur == null or not is_instance_valid(cur) or Router.hud == null:
		return Rect2()
	var hud := Router.hud.get_global_rect()
	if cur is SectorScreen:
		var sc := cur as SectorScreen
		var v := view_rect(cur)
		var cut := sc._cutaway
		if _cut_open(cut):
			var left := cut._hold_panel.get_global_rect().end.x
			v = Rect2(Vector2(left, v.position.y), Vector2(v.end.x - left, v.size.y))
		return v
	if cur is StarchartScreen or cur is SystemMapScreen:
		var p := GoalLine.picture_rect(cur)
		if p.size == Vector2.ZERO:
			return Rect2()
		var top := maxf(p.position.y, hud.end.y)
		return Rect2(Vector2(p.position.x, top), Vector2(p.size.x, p.end.y - top))
	if cur is StationScreen:
		var st := cur as StationScreen
		var page := _station_page(st)
		if page == null:
			return Rect2()
		var p := page.get_global_rect()
		var cut := st._cutaway
		if _cut_open(cut):
			# (the deck's picture is zoomed round your ship under it: the cutaway's own)
			var cr := cut.get_global_rect()
			var left := cut._hold_panel.get_global_rect().end.x
			p = Rect2(Vector2(left, cr.position.y), Vector2(cr.end.x - left, cr.size.y))
		var top := maxf(p.position.y, hud.end.y)
		return Rect2(Vector2(p.position.x, top), Vector2(p.size.x, p.end.y - top))
	return Rect2()


## The deck's picture on the station: the yard's hall, or the deck's page.
static func _station_page(st: StationScreen) -> Control:
	if st._tab == &"services" and st._scene != null and is_instance_valid(st._scene) and st._scene.is_visible_in_tree():
		return st._scene
	var page: Control = st._pages.get(st._tab)
	if page != null and is_instance_valid(page) and page.is_visible_in_tree():
		return page
	return null


## A teaching line's spots on `cur`, global, for a frame of `sz`: her four
## corners first, then the middles. On LOCAL and in a fight under the goal
## line's band, as her barks stand; elsewhere the picture's own corners.
static func tut_spot_boxes(cur: Control, sz: Vector2) -> Array:
	var out: Array = []
	var v := tut_view_rect(cur)
	if v.size.x <= 0.0:
		return out
	var top := roundf(v.position.y + (GOAL_BAND + 2.0 if cur is SectorScreen else EDGE))
	var bottom := roundf(v.end.y - EDGE - sz.y)
	var xs := {
		&"left": roundf(v.position.x + EDGE),
		&"third": roundf(v.position.x + v.size.x / 3.0),
		&"mid": roundf(v.get_center().x - sz.x * 0.5),
		&"right": roundf(v.end.x - EDGE - sz.x),
	}
	for s in ALL_SPOTS:
		var parts := String(s).split("_")
		var y := top if parts[0] == "top" else bottom
		var r := _under_goal(Rect2(Vector2(float(xs[StringName(parts[1])]), y), sz), cur)
		out.append({name = s, rect = r, mirrored = parts[1] == "right"})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _rank(a.name) < _rank(b.name))
	return out


## EVERYTHING A TEACHING LINE MUST NOT COVER on `cur`, global: her bark list
## (`avoid_rects`), and the toolbar row's pieces; over the cutaway its panel,
## its exploded ship and its popup; over a wreck's window the window; on the
## chart and the map every control in the picture, the scale and the words; on
## the station the decks, UNDOCK, every button and word, the yard's ships and
## their names, its drones and its screen. What a click picks in a picture
## (a system, a world, a beacon) is `covers`.
static func tut_avoid_rects(cur: Control) -> Array:
	var out := avoid_rects(cur)
	if cur == null or not is_instance_valid(cur):
		return out
	# THE GOAL LINE'S BAND is LOCAL's: on the chart and the map the line lives
	# in the toolbar row (its own rect is still in the list), and the station
	# has none, so the band under the HUD is free there
	if not (cur is SectorScreen) and Router.hud != null:
		var hud := Router.hud.get_global_rect()
		var band := Rect2(hud.position.x, hud.end.y, hud.size.x, GOAL_BAND)
		out = out.filter(func(r: Rect2) -> bool: return r != band)
	if cur.has_method("ladder_bar"):
		var bar: Control = cur.call("ladder_bar")
		if bar != null and is_instance_valid(bar) and bar.is_visible_in_tree():
			GoalLine._inked(bar, out)
	if cur is SectorScreen:
		var sc := cur as SectorScreen
		_cutaway_rects(sc._cutaway, out)
		var tv := Hints._transfer(sc)
		if tv != null:
			out.append(tv.window_rect())
		return out
	if cur is StarchartScreen:
		_chart_rects(cur as StarchartScreen, out)
	elif cur is SystemMapScreen:
		_map_rects(cur as SystemMapScreen, out)
	elif cur is StationScreen:
		_station_rects(cur as StationScreen, out)
	return out


## The cutaway is open, its left panel up.
static func _cut_open(cut: CutawayView) -> bool:
	return cut != null and is_instance_valid(cut) and cut.is_open() and cut._hold_panel != null \
		and cut._hold_panel.is_visible_in_tree()


## The cutaway's left panel (the hold, the attributes, DONE), the card a pointed
## part shows, the exploded ship and the pile's popup.
static func _cutaway_rects(cut: CutawayView, out: Array) -> void:
	if cut == null or not is_instance_valid(cut) or not cut.is_open():
		return
	for c: Control in [cut._hold_panel, cut._panel]:
		if c != null and c.is_visible_in_tree():
			out.append(c.get_global_rect())
	if cut._pic.size.x > 0.0:
		out.append(cut.get_global_transform() * cut._pic)
	# the rings' layer over the exploded ship takes the clicks (a part dropped on
	# a ring) a little past the picture's own box
	var mp: Control = cut._mounts
	if mp != null and is_instance_valid(mp) and mp.is_visible_in_tree() and mp.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		out.append(mp.get_global_rect())
	if cut._popup != null and is_instance_valid(cut._popup) and cut._popup.is_visible_in_tree():
		out.append(cut._popup.get_global_rect())


## The chart's own: its corner toggles and labels (children of the picture),
## YOU and the selected star's name, the Hellbender's, the scale in its corner.
static func _chart_rects(ch: StarchartScreen, out: Array) -> void:
	var mc := ch._chart
	if mc == null or not is_instance_valid(mc) or not mc.is_visible_in_tree():
		return
	var g := mc.get_global_transform()
	for c in mc.find_children("*", "Control", true, false):
		var k := c as Control
		if k != null and k.is_visible_in_tree() and k.size.x > 0.0 and (k is BaseButton or k is Label):
			out.append(k.get_global_rect())
	var here := Run.node_at()
	if here != null:
		var hp := mc._screen_pos(here)
		out.append(g * Rect2(hp + Vector2(-18, 18), Vector2(40, 16)))
	# (the name a hovered star wears follows the pointer, and she is drawn over
	# it: only the one a click left selected)
	if mc.selected >= 0 and mc.selected < Run.map.size():
		var sp := mc._screen_pos(Run.map[mc.selected])
		out.append(g * Rect2(sp + Vector2(-42, 20), Vector2(96, 14)))
	if mc.show_icons and Run.hellbender_alive() and Run.hellbender_at < Run.map.size():
		var c := mc._screen_pos(Run.map[Run.hellbender_at])
		out.append(g * Rect2(c + Vector2(-48, -24), Vector2(96, 34)))
	# the scale block in the bottom right corner (`_draw_scale`)
	var sz := mc.size
	var pad := StarchartScreen.MapChart.BAR_PAD
	var w := StarchartScreen.MapChart.BAR_MAX_PX + 8.0
	var h := StarchartScreen.MapChart.BAR_LABEL_H + 18.0
	out.append(g * Rect2(Vector2(sz.x - pad - w, sz.y - pad - h), Vector2(w + pad, h + pad)))


## The map's own: LOCATION and the scale in the corner, the words on the
## picture (`SystemOverlay.label_rects`), your ship.
static func _map_rects(map: SystemMapScreen, out: Array) -> void:
	var fr := map._frame
	if fr == null or not is_instance_valid(fr) or not fr.is_visible_in_tree():
		return
	for c in fr.find_children("*", "Control", true, false):
		var k := c as Control
		if k != null and k.is_visible_in_tree() and k.size.x > 0.0 and (k is BaseButton or k is Label):
			out.append(k.get_global_rect())
	var pad := SystemMapScreen.BAR_PAD
	var w := SystemMapScreen.BAR_MAX_PX + 8.0
	var h := SystemMapScreen.BAR_LABEL_H + 18.0
	out.append(fr.get_global_transform() * Rect2(Vector2(fr.size.x - pad - w, fr.size.y - pad - h), Vector2(w + pad, h + pad)))
	var ov = map.overlay
	if ov == null or map._box == null:
		return
	var g := map._box.get_global_transform()
	for r: Rect2 in ov.label_rects:
		out.append(g * r)
	# what the ship is doing, in the frame's top left (`SystemOverlay._draw`)
	var st: Array = ov.ship_status()
	if String(st[0]) != "":
		out.append(g * (ov.status_rect(String(st[0])) as Rect2).grow(2.0))
	var ship: Vector2 = ov._ship_at
	out.append(g * Rect2(ship - Vector2(12, 12), Vector2(24, 24)))


## The station's own: the decks and UNDOCK down the left, every button and word
## on the screen, and in the yard the two ships and their names, the drones and
## the deal's screen.
static func _station_rects(st: StationScreen, out: Array) -> void:
	for v in st._tabs.values():
		if v is Control and (v as Control).is_visible_in_tree():
			out.append((v as Control).get_global_rect())
	if st._undock != null and st._undock.is_visible_in_tree():
		out.append(st._undock.get_global_rect())
	if st._header != null and st._header.is_visible_in_tree():
		out.append(st._header.get_global_rect())
	for c in st.find_children("*", "", true, false):
		var k := c as Control
		if k == null or not k.is_visible_in_tree() or k.size.x <= 0.0:
			continue
		if k is BaseButton or k is Label or k is RichTextLabel:
			out.append(k.get_global_rect())
	for c: Control in [st._mine_hit, st._scene_hit, st._mine_slab, st._scene_slab]:
		if c != null and is_instance_valid(c) and c.is_visible_in_tree():
			out.append(c.get_global_rect())
	_cutaway_rects(st._cutaway, out)
	var ys := st._scene
	if ys == null or not is_instance_valid(ys) or not ys.is_visible_in_tree():
		return
	var g := ys.get_global_transform()
	# the ships' names over them (`YardScene._names`: 16 px over 8 px)
	for i in 2:
		var P: Dictionary = ys.placed[i]
		if P.is_empty():
			continue
		out.append(g * Rect2(Vector2(float(P["x0"]), float(P["top"]) - 28.0), Vector2(maxf(float(P["w"]), 120.0), 30.0)))
	if ys.drones != null:
		for d: Dictionary in ys.drones.D:
			if not d.has("r"):
				continue
			var r: Dictionary = d["r"]
			var x0 := minf(float(r["fx0"]), float(r["sx"])) - 3.0
			var x1 := maxf(float(r["fx0"]) + float(r["fw"]), float(r["sx"]) + float(r["w"])) + 3.0
			out.append(g * Rect2(Vector2(x0, float(r["fy0"]) - 3.0), Vector2(x1 - x0, float(r["sy"]) + float(r["h"]) + 6.0 - float(r["fy0"]))))
	if ys.deal_tv != null:
		var tv := ys.deal_tv
		out.append(g * Rect2(Vector2(tv.X, tv.Y), Vector2(float(tv.IW), float(tv.IH))))


## WHAT A CLICK PICKS UNDER `r` in a picture, named; "" for nothing: a system
## on the chart (`MapChart._node_at`), a world, a beacon, the star or a belt on
## the map (`SystemOverlay.hit`), and an orbit's line drawn through it. Asked of
## the picture's own hit tests at every 3 px, so nothing it can click is missed.
static func covers(cur: Control, r: Rect2) -> String:
	if cur is StarchartScreen:
		var mc := (cur as StarchartScreen)._chart
		if mc == null or not is_instance_valid(mc):
			return ""
		var inv := mc.get_global_transform().affine_inverse()
		# (the systems near her box asked for once, not the whole map at every
		# point: 1.2 s a check on a 410-system chart, `MapChart.nodes_near`)
		var near: Dictionary = mc.nodes_near(inv * r)
		if (near.nodes as Array).is_empty():
			return ""
		var y := r.position.y
		while y <= r.end.y:
			var x := r.position.x
			while x <= r.end.x:
				var hit: int = StarchartScreen.MapChart.node_among(inv * Vector2(x, y), near)
				if hit >= 0:
					return "a system (%s)" % MapGen.star_name(Run.map[hit])
				x += 3.0
			y += 3.0
		return ""
	if cur is SystemMapScreen:
		var map := cur as SystemMapScreen
		var ov = map.overlay
		if ov == null or map._box == null:
			return ""
		var inv := map._box.get_global_transform().affine_inverse()
		var y := r.position.y
		while y <= r.end.y:
			var x := r.position.x
			while x <= r.end.x:
				var h: Dictionary = ov.hit(inv * Vector2(x, y))
				if not h.is_empty():
					return "a %s" % String(h.kind)
				x += 3.0
			y += 3.0
		# the orbits' lines, all the way round
		var v = map.view
		var L: SystemLayout = v.layout
		if L == null:
			return ""
		var o: Vector2 = v.origin()
		var g := map._box.get_global_transform()
		for b in L.bodies:
			if b.orbit <= 0.0:
				continue
			for k in 180:
				var a := TAU * float(k) / 180.0
				var p: Vector2 = g * (o + Vector2(cos(a), sin(a) * SystemMapScreen.SystemViewS.TILT) * b.orbit * v.zoom)
				if r.grow(1.0).has_point(p):
					return "an orbit"
		return ""
	return ""


## THE OUTLINE on what a teaching line means: a 1 px line round it in her ice,
## as the goal line outlines a tab. Drawn in her column, over the picture and
## under the escape menu; takes no click.
func _outline_to(r: Rect2) -> void:
	if r.size == Vector2.ZERO:
		if _outline != null and is_instance_valid(_outline):
			_outline.subject = Rect2()
			_outline.visible = false
		return
	var host := _host()
	if host == null:
		return
	if _outline == null or not is_instance_valid(_outline):
		_outline = Outline.new()
	if _outline.get_parent() != host:
		if _outline.get_parent() != null:
			_outline.get_parent().remove_child(_outline)
		host.add_child(_outline)
	_outline.subject = r
	_outline.visible = true
	_outline.queue_redraw()


## The outline she puts on what she means, global; empty when none is up.
func outline_rect() -> Rect2:
	if _outline == null or not is_instance_valid(_outline) or not _outline.visible:
		return Rect2()
	return _outline.drawn()


class Outline extends Control:
	var subject := Rect2()

	func _init() -> void:
		name = "AshOutline"
		top_level = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		z_index = 49
		position = Vector2.ZERO

	func _process(_d: float) -> void:
		var vs := get_viewport_rect().size
		if size != vs:
			size = vs

	## The line's own box, global: the subject and one pixel out, on whole pixels.
	func drawn() -> Rect2:
		return Rect2(subject.position.round(), subject.size.round()).grow(1.0)

	func _draw() -> void:
		if subject.size == Vector2.ZERO:
			return
		var r := drawn()
		draw_rect(Rect2(r.position - global_position, r.size), UITheme.ICE, false, 1.0)
