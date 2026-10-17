extends Node

## A.S.H., THE SHIP'S AI, SPEAKING (Jon and Ashlee, Oct 17; `docs/ash.md`; the
## ruling "A.S.H. is the ship, not crew"). Her face comes up in a small hologram
## frame on LOCAL and in fights, says one of the thirty approved lines at the
## moment it was written for, and fades (`AshPortrait` draws it; `AshLines`
## holds the lines). No voice yet: text.
##
## THE MOMENTS, each line's own (`AshLines` has the list):
##   launch  a new run, once the ship is at rest on LOCAL; gone at the first jump
##   hull    the first time she is up in a new hull (after the dock, never in it);
##           not if the move is called off
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
## HINTS WIN (`Hints`): she does not start while a hint is up or settling, and
## goes the moment one starts to settle.
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

const SECTION := "ash"
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

var _last_end := -INF
var _fight: Object = null
var _fight_lines := 0
var _fight_hurt := false
var _fight_hot := false
var _hurt_latched := false
var _known_hull: HullData = null
var _left_hull: HullData = null
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


# ------------------------------------------------------------------ the moments

func _on_run_started() -> void:
	waiting.clear()
	_fight = null
	_fight_lines = 0
	_hurt_latched = false
	_known_hull = Run.hull
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


## Off (Settings): nothing waiting, nothing up.
func _quiet() -> void:
	waiting.clear()
	if portrait != null:
		portrait.cut()


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
	# A NEW HULL: armed when the frame changes (a dock's move or a hull found
	# in the field), said the next time she is up, on LOCAL or in a fight, so
	# never mid-dock; and forgotten if the move is called off and the old frame
	# comes back (`Run.abandon_move`)
	if Run.hull != _known_hull:
		if Run.hull != null and Run.hull == _left_hull and waiting.has(&"hull"):
			waiting.erase(&"hull")
		elif _known_hull != null and Run.hull != null:
			arm(&"hull")
		_left_hull = _known_hull
		_known_hull = Run.hull
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
	_watch()
	# THE QUIET STARTS WHEN A LINE ENDS, however it ended
	if _up and (portrait == null or not portrait.speaking()):
		_up = false
		_last_end = now
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
	if _hint_up():
		return "hint"
	if _menu_up() or ZoomLadder.busy():
		return "screen"
	if FirstRunIntro.playing != null and is_instance_valid(FirstRunIntro.playing):
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
	if why != "":
		return why
	for a in avoid_rects(Router.current):
		if (a as Rect2).size != Vector2.ZERO and r.intersects(a as Rect2):
			return "covered"
	return ""


func _dragging(sc: SectorScreen) -> bool:
	return sc._grab_view != null or sc._aim_view != null or sc.get_viewport().gui_is_dragging()


func _hint_up() -> bool:
	if Hints.card != null and is_instance_valid(Hints.card):
		return true
	return Hints._cand != &""


## The escape menu is Main's (`Main.toggle_menu`), above the screens.
func _menu_up() -> bool:
	var n: Node = Router.content
	while n != null:
		if n.get_script() != null and "_menu" in n:
			return n.get("_menu") != null
		n = n.get_parent()
	return false


# ------------------------------------------------------------------ the lines

## A line of `kind`: never the one she said last time for it, and none again
## until the rest of its moment has been said (cosmetic: the global generator).
func pick_line(kind: StringName) -> String:
	var all := AshLines.of(kind)
	if all.is_empty():
		return ""
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
	portrait.say(line, kind)
	_up = true
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
		out.append({name = s, rect = Rect2(Vector2(float(xs[StringName(parts[1])]), y), sz),
			mirrored = parts[1] == "right"})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _rank(a.name) < _rank(b.name))
	return out


## The first spot clear of everything for `line`; {} if none is.
func _spot(line: String) -> Dictionary:
	if AshPortrait.lines_for(line) > 4:
		push_warning("Ash: '%s' is more than four lines in her column" % line)
	var cur := Router.current
	var v := view_rect(cur)
	var avoid := avoid_rects(cur)
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
		# THE GOAL LINE'S BAND under the HUD (`GoalLine`), wherever along it the
		# line has been set down, and the line itself if it is up
		out.append(Rect2(hud.position.x, hud.end.y, hud.size.x, GOAL_BAND))
		if Router.hud.has_method("goal_rect"):
			out.append(Router.hud.call("goal_rect"))
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
