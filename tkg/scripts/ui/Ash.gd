extends Node

## A.S.H. speaks approved lines at their moments and never talks over herself or covers anything.
## Once started a line plays out (Jon, Oct 22); losing the ship cuts her at once.
## Why: docs/why/Ash.md#ash-behaviour

const SECTION := "ash"
## The beat after her introduction before the first lesson (Jon: short beat, then the hint).
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
## Her box follows the goal line as it slides with the top plate (Jon, Oct 20).
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
## Where `_wrecks_open` was read: a new place's already-opened wrecks are not the pilot's.
var _wrecks_place := Vector2i(-1, -9)
var _greed_at := 0
var _jumps_since_doubt := 0
var _bags: Dictionary = {}
var _run_live := false
var _up := false

## The teaching line up, if any: its id, the hint, its subject and starting screen.
var lesson: StringName = &""
var lesson_hint: StringName = &""
var lesson_subject := Rect2()
var _lesson_on: Object = null
## The one lesson said over the escape menu: her box goes on the menu's own layer.
var _lesson_menu := false
var _lesson_host: Node = null
var _lesson_check := 0.0
var _outline: Outline = null

## Every line she has said aloud this run, for the COMMS tab (Jeremy, Oct 23); saved with the run.
## Why: docs/why/Ash.md#comms-log
var comms: Array = []
const COMMS_MAX := 300
## The line just started, until its words do.
var _comms_next: Dictionary = {}


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


## True while her introduction is up or could start; hints and goal steps wait for it.
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
	_wrecks_place = Vector2i(Run.at, Run.site_here())
	_wrecks_since_dock = 0
	_greed_at = 0
	_jumps_since_doubt = 0
	_bags.clear()
	_run_live = true
	_last_end = -INF
	if portrait != null:
		portrait.cut()
	# A NEW RUN'S COMMS start empty (a run picked up with CONTINUE has its own
	# put back by `SaveGame` after this)
	comms.clear()
	_comms_next = {}
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
	# A new hull arms only when bought at a yard (Jon, Oct 18); dropped if the move is undone.
	# Why: docs/why/Ash.md#ash-behaviour
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
	var place := Vector2i(Run.at, Run.site_here())
	for id in open:
		if place == _wrecks_place and not _wrecks_open.has(id):
			_wrecks_since_dock += 1
			if _wrecks_since_dock >= GREED_EVERY and _wrecks_since_dock - _greed_at >= GREED_EVERY:
				_greed_at = _wrecks_since_dock
				arm(&"greed")
	_wrecks_open = open
	_wrecks_place = place
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
	_comms_tick()
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


## A click does not send her away (Jon, Oct 22); covering her box, a screen change does.
func _must_go(r: Rect2) -> String:
	var why := _stay_block()
	if why != "" or force_spot != &"":
		return why
	var cur := Router.current
	var a := avoid_rects(cur)
	_opened_rects(cur as SectorScreen, a)
	for x in a:
		if (x as Rect2).size != Vector2.ZERO and r.intersects(x as Rect2):
			return "covered"
	return ""


## Hints, drags and click-opened panels are not stay blocks; `_must_go` asks if they cover her.
func _stay_block() -> String:
	if lesson != &"" or Hints.lesson != &"":
		return "hint"
	if Hints.menu_up() or ZoomLadder.busy():
		return "screen"
	var sc := Router.current as SectorScreen
	if sc == null or not is_instance_valid(sc) or not sc.is_visible_in_tree():
		return "screen"
	if Router.hud == null or not Router.hud.is_visible_in_tree():
		return "screen"
	if sc._phase != SectorScreen.Phase.NONE or sc._card != null:
		return "screen"
	if sc.fighting():
		# the enemy's turn, from the click on END TURN (`_hold`) to the new hand
		if sc._playing or sc._hold or sc._opening or sc._raising or not sc._breakups.is_empty() \
				or not sc._dying.is_empty() or sc.combat.waiting or sc.combat.finished:
			return "turn"
		if sc._end_button == null or not sc._end_button.is_visible_in_tree() or sc._end_button.disabled:
			return "turn"
	return ""


## What a click may have opened over LOCAL or a fight, global, into `out`: the
## cutaway, a wreck's or a reward's window, the pile's panel, the flee question.
static func _opened_rects(sc: SectorScreen, out: Array) -> void:
	if sc == null or not is_instance_valid(sc):
		return
	_cutaway_rects(sc._cutaway, out)
	var tv := Hints._transfer(sc)
	if tv != null:
		out.append(tv.window_rect())
	for c: Control in [sc._pile_panel, sc._exit_ask]:
		if c != null and is_instance_valid(c) and c.is_visible_in_tree():
			out.append(c.get_global_rect())


func _dragging(sc: SectorScreen) -> bool:
	return sc._grab_view != null or sc._aim_view != null or sc.get_viewport().gui_is_dragging()


## Hints win: she does not start a line the next hint would cut short.
func _hint_up(starting: bool = true) -> bool:
	if Hints.card != null and is_instance_valid(Hints.card):
		return true
	# her own teaching line, or one of a goal step's on its way (`Hints.step_due`)
	if lesson != &"" or Hints.lesson != &"":
		return true
	# Her introduction goes first, so it does not wait for hints; the beat after holds everything.
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
	# (one the pacing holds back is not due: her lines need not wait for it)
	for id in Hints.ORDER:
		if not Hints.seen(id) and not Hints.resting(id) and Hints._pace_ok(id) and not Hints.probe(id).is_empty():
			return true
	return false


## A line of hers that is not a teaching line is up and saying (a quip, her
## introduction): a hint coming due waits for it (`Hints`).
func bark_up() -> bool:
	return portrait != null and is_instance_valid(portrait) and portrait.speaking() \
		and not String(portrait.kind).begins_with("tut_")


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
	_comms_tick()
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
	_comms_due(kind, line, portrait.voice, false)


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


## A top spot on the goal moves under it (Jon, Oct 20); in a fight it goes beside it.
## Why: docs/why/Ash.md#spot-placement
static func _under_goal(r: Rect2, cur: Control) -> Rect2:
	var st := GoalLine.stack_rect(cur)
	if st.size != Vector2.ZERO and r.intersects(st.grow(EDGE - 1.0)):
		if GoalLine._fighting(cur) and r.position.y >= st.position.y + GoalLine._goal_h():
			r.position.y = roundf(st.end.y + EDGE)
		elif GoalLine._fighting(cur):
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
		# The goal and its step as drawn plus reserved room, so a step arriving never lands on her.
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


# ------------------------------------------------------------------ the comms log

## A line of hers has started: in the log once its words do (`_comms_tick`).
func _comms_due(kind: StringName, line: String, voice: String, tutorial: bool) -> void:
	_comms_next = {kind = kind, line = line, voice = voice, jump = Run.jumps, tutorial = tutorial}


## The line started last: its words have started (in the log), or it went
## before a word (dropped).
func _comms_tick() -> void:
	if _comms_next.is_empty():
		return
	var p := portrait
	if p == null or not is_instance_valid(p) or p.kind != StringName(_comms_next.kind) or p.line != String(_comms_next.line):
		_comms_next = {}
		return
	if p.typed_at >= 0.0:
		comms.append(_comms_next)
		while comms.size() > COMMS_MAX:
			comms.pop_front()
		_comms_next = {}
	elif p.phase == AshPortrait.Phase.GOING or p.phase == AshPortrait.Phase.GONE:
		_comms_next = {}


## Replay comms voice: not over a line she is saying, and not for text-only lines.
func replay(i: int) -> bool:
	if i < 0 or i >= comms.size() or not can_replay():
		return false
	var v := String((comms[i] as Dictionary).get("voice", ""))
	if v == "" or not ResourceLoader.exists(v):
		return false
	return Audio.ash_voice(v) > 0.0


## Nothing of hers is speaking now: a line up and talking, or one replayed.
func can_replay() -> bool:
	if portrait != null and is_instance_valid(portrait) and (portrait.phase == AshPortrait.Phase.UP
			or portrait.phase == AshPortrait.Phase.TYPING):
		return false
	return not Audio.ash_speaking()


## The log for the run's save: the entries as plain values.
func comms_to() -> Array:
	var out: Array = []
	for raw in comms:
		var e: Dictionary = raw
		out.append({kind = String(e.kind), line = String(e.line), voice = String(e.get("voice", "")),
			jump = int(e.get("jump", 0)), tutorial = bool(e.get("tutorial", false))})
	return out


## The log from a save (`comms_to`); anything else, or none (a save from before
## it), is an empty log.
func comms_from(raw: Variant) -> void:
	comms.clear()
	_comms_next = {}
	if typeof(raw) != TYPE_ARRAY:
		return
	for x in (raw as Array):
		if typeof(x) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = x
		var line := str(e.get("line", ""))
		if line == "":
			continue
		var v := str(e.get("voice", ""))
		# (a take this build does not have is said as text alone, and a save names no other folder)
		if v != "" and not (v.begins_with(AshTutorLines.VOICE_DIR) and not v.contains("..") and ResourceLoader.exists(v)):
			v = ""
		comms.append({kind = StringName(str(e.get("kind", ""))), line = line, voice = v,
			jump = int(e.get("jump", 0)), tutorial = bool(e.get("tutorial", false))})
	while comms.size() > COMMS_MAX:
		comms.pop_front()


# ------------------------------------------------------------------ teaching

## How often a teaching line looks again at what may have come into its box, s.
const LESSON_CHECK_S := 0.1


## SHE TEACHES while she is on and the run is live (her switch; a harness that
## asked). `Hints` asks this to choose her corner or a card.
func teaches() -> bool:
	return enabled() and Run.hull != null and _run_live and not Run.dead and Run.hp > 0


## Returns false if she is off or no spot is clear; a hint's line holds until the lesson is done.
## Why: docs/why/Ash.md#teaching-lines
func teach(lid: StringName, text: String, hint: StringName, subject: Rect2, opts: Dictionary = {}) -> bool:
	if not teaches():
		return false
	var cur := Router.current
	if cur == null or not is_instance_valid(cur):
		return false
	_comms_tick()
	var over_menu := opts.has("host")
	var spot: Dictionary = opts.get("spot", {}) if over_menu else tut_spot(cur, text, subject)
	if spot.is_empty():
		held_by = "room"
		return false
	var host: Node = opts.get("host") if over_menu else _host()
	if host == null or not is_instance_valid(host):
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
	var quiet := bool(opts.get("quiet", false))
	portrait.say(text, StringName("tut_" + String(lid)), {
		voice = String(opts.get("voice", "")), spoken = String(opts.get("spoken", "")),
		held = bool(opts.get("held", hint != &"")), quiet = quiet})
	# (not `_up`: a teaching line does not start her barks' quiet, so they keep
	# the timing they had beside the cards)
	lesson = lid
	lesson_hint = hint
	lesson_subject = subject
	_lesson_on = cur
	_lesson_check = LESSON_CHECK_S
	_lesson_menu = over_menu
	_lesson_host = host if over_menu else null
	_outline_to(subject)
	said_log.append({kind = StringName("tut_" + String(lid)), line = text, at = now, spot = spot.name,
		rect = spot.rect, tutorial = true, hint = hint, subject = subject, quiet = quiet})
	if quiet:
		print("[ash] tut %s (back, text only): %s" % [lid, text])
	else:
		print("[ash] tut %s: %s" % [lid, text])
		_comms_due(StringName("tut_" + String(lid)), text, portrait.voice, true)
	return true


## Her teaching line is up and saying (not going).
func lesson_up() -> bool:
	return lesson != &"" and portrait != null and is_instance_valid(portrait) and portrait.speaking() \
		and portrait.kind == StringName("tut_" + String(lesson))


## Her teaching line is up and still being SPOKEN: coming up or typing, not yet
## holding (the soft lock's window, `Hints.soft_lock`).
func lesson_speaking() -> bool:
	return lesson_up() and (portrait.phase == AshPortrait.Phase.UP or portrait.phase == AshPortrait.Phase.TYPING)


## Teaching line `lid` was the last she said and it ended of itself, after its
## reading time (an information line, `Hints.INFO`), not sent off.
func ended_of_itself(lid: StringName) -> bool:
	return portrait != null and is_instance_valid(portrait) and portrait._natural \
		and portrait.kind == StringName("tut_" + String(lid))


## The subject moved (`Hints` keeps it each frame): the outline goes with it.
func aim_lesson(subject: Rect2) -> void:
	if lesson == &"":
		return
	lesson_subject = subject
	_outline_to(subject)


## Let the teaching line go: its action done (`quick`), or its subject left.
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
	_lesson_menu = false
	_lesson_host = null


## A teaching line skips bark rules; it goes with the screen, the enemy turn or an intruder.
func _lesson_must_go() -> String:
	# (over the escape menu: up while the menu is, gone with it)
	if _lesson_menu:
		return "" if Hints.menu_up() else "screen"
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

## The first spot clear of everything inside the view; empty if there is none.
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


## Over the escape menu: the first picture corner right of the drawer; it never follows the goal.
static func menu_spot(text: String, drawer: Rect2, subject: Rect2, vs: Vector2) -> Dictionary:
	var sz := AshPortrait.size_for(text)
	var left := maxf(drawer.end.x + EDGE * 2.0, EDGE)
	var view := Rect2(Vector2(left, EDGE), Vector2(vs.x - left - EDGE, vs.y - EDGE * 2.0))
	for at: Vector2 in [view.position, Vector2(view.end.x - sz.x, view.position.y),
			Vector2(view.position.x, view.end.y - sz.y), Vector2(view.end.x - sz.x, view.end.y - sz.y)]:
		var r := Rect2(at.round(), sz)
		if view.encloses(r) and not r.intersects(drawer) and not r.intersects(subject):
			return {name = &"menu", rect = r, mirrored = false}
	return {}


## The view she may teach in on each kind of screen.
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
		elif st._tab == &"work" and st._board != null and is_instance_valid(st._board):
			# THE HIRING BOARD fills its deck edge to edge, the work down its left:
			# she teaches over the town's own side (`PostingBoard.town_rect`)
			p = p.intersection(st._board.get_global_transform() * st._board.town_rect())
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


## Four corners then middles; on LOCAL and fights they sit under the goal band, as barks do.
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


## Teaching lines avoid the bark list plus per-screen controls; clickable things are in `covers`.
## Why: docs/why/Ash.md#teaching-lines
static func tut_avoid_rects(cur: Control) -> Array:
	var out := avoid_rects(cur)
	if cur == null or not is_instance_valid(cur):
		return out
	# The goal band is LOCAL's; elsewhere the line lives in the toolbar row.
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
			out.append_array(tv.rest_rects())
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
static func _chart_rects(ch: StarchartScreen, out: Array, quests: bool = true) -> void:
	var mc := ch._chart
	if mc == null or not is_instance_valid(mc) or not mc.is_visible_in_tree():
		return
	var g := mc.get_global_transform()
	# the quests' tags (`MapChart.place_quest_tags`), which keep off her in turn
	if quests:
		for r in mc.quest_rects:
			if (r as Rect2).size != Vector2.ZERO:
				out.append(g * (r as Rect2))
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
	var pad := MapChart.BAR_PAD
	var w := MapChart.BAR_MAX_PX + 8.0
	var h := MapChart.BAR_LABEL_H + 18.0
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


## Station rects: decks, UNDOCK, every button and word, the yard's ships and drones.
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
	# the board's app bar (its tabs), its ticker, a popup up on it, and every job
	# note on it whole, real or drawn (`PostingBoard.job_rects`)
	var bd := st._board
	if bd != null and is_instance_valid(bd) and bd.is_visible_in_tree():
		var bg := bd.get_global_transform()
		for r: Rect2 in bd.chrome_rects() + bd.job_rects():
			out.append(bg * r)
		if bd.pop_rect.has_area():
			out.append(bg * bd.pop_rect)
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


## Asked of the picture's own hit tests every 3 px, so nothing clickable is missed.
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
				var hit: int = MapChart.node_among(inv * Vector2(x, y), near)
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
		var tilt: float = SystemMapScreen.SystemViewS.TILT
		for b in L.bodies:
			if b.orbit <= 0.0:
				continue
			# Round each body's centre where it is at the map's t, for star A or the pair.
			var bh: Vector2 = b.host_at(float(v.t))
			for k in 180:
				var a := TAU * float(k) / 180.0
				var p: Vector2 = g * (o + Vector2(bh.x + cos(a) * b.orbit, (bh.y + sin(a) * b.orbit) * tilt) * v.zoom)
				if r.grow(1.0).has_point(p):
					return "an orbit"
		return ""
	return ""


## A 1 px ice outline round what a teaching line means, under the escape menu.
func _outline_to(r: Rect2) -> void:
	if r.size == Vector2.ZERO:
		if _outline != null and is_instance_valid(_outline):
			_outline.subject = Rect2()
			_outline.visible = false
		return
	var host: Node = _lesson_host if _lesson_host != null and is_instance_valid(_lesson_host) else _host()
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
