extends Node

## One scheduler, two slots: a medium, showpiece or reactive event in A, a small one in B.
## Temperament sets how often, never how long. Silent: the ambience already sounds the beats.
## Why: docs/why/SkyWeather.md#weather-scheduler

const SkyBakeS := preload("res://scripts/ui/sysmap/SkyBake.gd")
const PulsarViewS := preload("res://scripts/ui/sysmap/PulsarView.gd")

const S := 0
const M := 1
const SP := 2
const R := 3
const TIER_NAMES := ["S", "M", "SP", "R"]
## per sky: name -> [tier, weight, lasts s (before precursor and chains), layer]
const TABLE := {
	&"emission": {&"strike": [M, 3, 1.6, &"neb"], &"tide": [M, 2, 10.0, &"neb"], &"jet": [M, 2, 14.0, &"neb"],
		&"glints": [S, 1, 5.1, &"neb"], &"newstar": [SP, 1, 22.0, &"neb"], &"nearstrike": [R, 0, 1.6, &"neb"]},
	&"reflection": {&"shaft": [M, 3, 9.0, &"neb"], &"spoke": [M, 2, 18.0, &"neb"], &"breathe": [M, 2, 28.0, &"neb"],
		&"glitter": [S, 1, 5.0, &"neb"], &"echo": [SP, 1, 26.0, &"neb"]},
	&"planetary": {&"ringrun": [M, 3, 8.0, &"neb"], &"flier": [M, 2, 14.0, &"neb"], &"halo": [M, 2, 26.0, &"neb"],
		&"lamps": [S, 1, 8.0, &"neb"], &"searchlights": [SP, 1, 16.0, &"neb"]},
	&"remnant": {&"shock": [M, 3, 6.0, &"neb"], &"flare": [M, 3, 8.0, &"neb"], &"shrapnel": [M, 2, 14.0, &"neb"],
		&"spark": [S, 1, 4.0, &"neb"], &"pearls": [SP, 1, 22.0, &"neb"], &"nearspark": [R, 0, 4.0, &"neb"]},
	&"dark": {&"strike": [M, 3, 1.6, &"neb"], &"rays": [M, 2, 14.0, &"neb"],
		&"dawn": [S, 1, 7.5, &"neb"], &"ember": [S, 1, 4.0, &"neb"], &"fan": [SP, 1, 26.0, &"neb"], &"nearstrike": [R, 0, 1.6, &"neb"]},
	&"calm": {&"sungrazer": [M, 2, 14.0, &"node"], &"starmood": [M, 2, 30.0, &"star"], &"globule": [M, 2, 50.0, &"sky"],
		&"microlens": [S, 1, 10.0, &"field"], &"comet": [SP, 1, 75.0, &"node"]},
	&"pulsar": {&"wisps": [M, 3, 12.0, &"pulsar"], &"fog": [M, 3, 20.0, &"sky"], &"firehose": [M, 2, 12.0, &"pulsar"],
		&"pulse": [S, 1, 3.0, &"pulsar"], &"microlens": [S, 1, 10.0, &"field"], &"magnetar": [SP, 1, 22.0, &"pulsar"]},
	&"core": {&"hotspot": [M, 3, 14.0, &"core"], &"flareecho": [M, 2, 30.0, &"sky"], &"einstein": [M, 1, 6.8, &"nova"],
		&"ringflash": [S, 1, 5.0, &"core"], &"microlens": [S, 1, 10.0, &"field"], &"lensstar": [SP, 1, 40.0, &"drift"]},
}
## every sky's: a collision in a belt in view, and (very rarely) a gravitational wave
const SHARED := {&"collision": [M, 1, 35.0, &"node"], &"gwave": [M, 1, 10.0, &"fabric"]}
## Cadence halved on Oct 5 (Jon): the rarest events took 30 to 45 minutes to come round.
## Why: docs/why/SkyWeather.md#event-cadence
const CADENCE := {&"emission": Vector2(12, 30), &"dark": Vector2(12, 30), &"remnant": Vector2(15, 40),
	&"reflection": Vector2(18, 45), &"planetary": Vector2(20, 45), &"pulsar": Vector2(20, 50),
	&"calm": Vector2(15, 40), &"core": Vector2(15, 40)}
## An event unseen for a while gains weight, so a light one comes round in minutes, not by chance.
const STARVE_S := 90.0
## Appended colours were measured: the plain sky moved
## only 0.03 to 0.28% of blocks, so the gate holds.
## Why: docs/why/SkyWeather.md#weather-colours
const RAMP := {}
const NEB_SKIES: Array[StringName] = [&"emission", &"reflection", &"planetary", &"remnant", &"dark"]
## which of its kind's events the nebula shader draws (`w_ev`, `s_ev`)
const EV := {&"strike": 0, &"nearstrike": 0, &"tide": 1, &"jet": 2, &"newstar": 3, &"glints": 1,
	&"shaft": 0, &"spoke": 1, &"breathe": 2, &"echo": 3, &"glitter": 1,
	&"ringrun": 0, &"flier": 1, &"halo": 2, &"searchlights": 3, &"lamps": 1,
	&"shock": 0, &"flare": 1, &"shrapnel": 2, &"pearls": 3, &"spark": 1, &"nearspark": 1,
	&"rays": 1, &"fan": 2, &"dawn": 1, &"ember": 2}
## which `sky.gdshader` draws (`e_ev`)
const SKY_EV := {&"starmood": 1, &"globule": 2, &"fog": 3, &"magnetar": 4, &"flareecho": 5}
## the age at each one's height: a held still (`hold`, ZoomProf `wev=`) and the clip's still
const PEAK := {&"strike": 0.03, &"nearstrike": 0.03, &"tide": 5.0, &"jet": 7.0, &"glints": 2.2, &"newstar": 10.0,
	&"shaft": 4.5, &"spoke": 8.0, &"breathe": 8.2, &"glitter": 2.0, &"echo": 9.0,
	&"ringrun": 4.3, &"flier": 6.0, &"halo": 10.0, &"lamps": 4.0, &"searchlights": 7.0,
	&"shock": 2.0, &"flare": 1.6, &"shrapnel": 6.0, &"spark": 1.5, &"nearspark": 1.5, &"pearls": 12.0,
	&"rays": 7.0, &"dawn": 3.5, &"ember": 0.5, &"fan": 10.0,
	&"microlens": 5.0, &"sungrazer": 9.0, &"starmood": 9.0, &"globule": 25.0, &"comet": 37.0,
	&"wisps": 5.0, &"fog": 8.0, &"firehose": 6.0, &"pulse": 2.5, &"magnetar": 1.5,
	&"hotspot": 6.0, &"flareecho": 8.0, &"einstein": 1.0, &"ringflash": 0.6, &"lensstar": 20.0,
	&"bowshock": 0.6, &"collision": 6.0, &"gwave": 6.0}
## how far from the ship each tier's place must be
const SHIP_R := {S: 60.0, M: 100.0, SP: 100.0, R: 50.0}
## the layers that are far sky: a supernova waits for them, and they for it
const FAR: Array[StringName] = [&"neb", &"sky", &"drift"]
## the strike's light colour, by kind
const LC_EMISSION := Color(1.0, 0.82, 0.9)
const LC_DARK := Color(0.82, 0.78, 1.0)

var view
## The comet you can fly to (`CometPath`), drawn in the system as the weather comet is.
var real_comet: Node2D = null
## the map's screen (`SystemMapScreen`), for the ship, the labels, the panel and
## the input clock; null for a harness without one
var screen
var index := 0
## the sky key (`sky_of`), its nebula's kind (-1 outside one) and shape
var sky: StringName = &"calm"
var neb := -1
var shape := 0
var star_kind := 0
## TEMPERAMENT: calm (gaps x1.5, no strike chains), steady, stormy (x0.65)
var temper: StringName = &"steady"
var tmul := 1.0
var chain_p := 0.35
var chain_max := 1
## the system's favourite medium event, three times as likely
var fav: StringName = &""
## A HARNESS'S FIXED STEP a frame; 0: real time
var step_s := 0.0
## the scheduler runs (a harness filming one event turns it off)
var auto := true
## the upgrades to the four events there were before (SystemShot `wup=0`: off)
var up := true
## a harness holds each live event at its height (`PEAK`)
var hold := false
## or at this age (SystemShot `wstill=`; a precursor's are negative); -999: not held
var hold_at := -999.0
## THE SCHEDULER ALONE (`-- weathertest`): no view, every place succeeds
var sim := false
var sim_hold := false
var sim_moving := false
## what started, for the harness: [visit s, name, slot, tier, lasts]
var log_starts: Array = []
var log_on := false

var _rng := RandomNumberGenerator.new()
var _a: Dictionary = {}
var _b: Dictionary = {}
var _bow: Dictionary = {}
var _clock_a := 0.0
var _clock_b := 0.0
var _visit := 0.0
var _next_a := 0.0
var _next_b := 0.0
var _a_free := 0.0
var _sp_due := 0.0
var _sp_first := 0.0
var _idle_sp := false
var _last_a: StringName = &""
## when each event last started, in visit seconds (`_weight`'s catch-up)
var _seen := {}
var _last_b: StringName = &""
var _pal_t := 0.0
var _bow_at := -1.0
var _react_next := 10.0
var _react_last := -999.0
var _idle_from := 0.0
var _ship_prev := Vector2.INF
var _ship_v := Vector2.ZERO
var _cleared := true
## the nebula's own seed, as `sky_nebula` reads it (`sd`), not SkyBake's
var _sd := 0.0


static func now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


## The sky key: the nebula's kind when the sky is the cloud, `pulsar`, `core`, or `calm`.
static func sky_of(star: int, neb_kind: int) -> StringName:
	if star == SystemLayout.StarKind.PULSAR:
		return &"pulsar"
	if star == SystemLayout.StarKind.CORE:
		return &"core"
	if neb_kind >= 0 and neb_kind < NEB_SKIES.size():
		return NEB_SKIES[neb_kind]
	return &"calm"


## A system's sky key, from its node (the harness picks systems by it).
static func sky_of_node(n: MapGen.MapNode) -> StringName:
	var L := SystemLayout.of(n)
	var kind: String = ["ORDINARY", "RED", "BLUE", "PULSAR", "CORE"][L.star]
	var look: Dictionary = SkyBakeS.look_for(n, kind)
	return sky_of(L.star, int(look.get("neb", -1)))


## The palette's extra colours for a sky.
static func ramp(key: StringName) -> PackedVector3Array:
	var out := PackedVector3Array()
	for h: String in RAMP.get(key, []):
		var c := Color(h)
		out.append(Vector3(c.r, c.g, c.b))
	return out


func setup(v, idx: int) -> void:
	view = v
	# the comet you can fly to, at the weather comet's depth (`RealComet`)
	real_comet = RealComet.new()
	real_comet.view = v
	v._scene.add_child(real_comet)
	var nk := -1
	if v._neb_mat != null:
		nk = int(v._sky_look.neb)
		shape = int(v._sky_look.get("shape", 0))
	star_kind = int(v.layout.star)
	_setup(idx, sky_of(star_kind, nk), nk)


## The scheduler alone, for `-- weathertest`: a sky and a temperament forced.
func setup_sim(key: StringName, idx: int, force_temper: StringName = &"") -> void:
	sim = true
	_setup(idx, key, NEB_SKIES.find(key))
	if force_temper != &"":
		_temper(force_temper)
	_reset_clocks()


func _setup(idx: int, key: StringName, nk: int) -> void:
	index = idx
	sky = key
	neb = nk
	_sd = float(idx % 97) * 0.731 + 3.0
	var h := SkyBakeS.hash2(idx, 23)
	_temper(&"calm" if h < 0.3 else (&"steady" if h < 0.75 else &"stormy"))
	var ms: Array = []
	for nm: StringName in TABLE[sky]:
		if int(TABLE[sky][nm][0]) == M:
			ms.append(nm)
	fav = ms[mini(ms.size() - 1, int(SkyBakeS.hash2(idx, 29) * ms.size()))] if not ms.is_empty() else &""
	_rng.seed = hash([idx, Time.get_ticks_usec(), 7])
	_reset_clocks()


func _temper(t: StringName) -> void:
	temper = t
	match t:
		&"calm":
			tmul = 1.3
			chain_p = 0.0
			chain_max = 0
		&"steady":
			tmul = 1.0
			chain_p = 0.35
			chain_max = 1
		_:
			tmul = 0.65
			chain_p = 0.8
			chain_max = 3


func _reset_clocks() -> void:
	_clock_a = 0.0
	_clock_b = 0.0
	_visit = 0.0
	_seen = {}
	_next_a = _rng.randf_range(8.0, 30.0) * tmul
	_next_b = _rng.randf_range(10.0, 25.0) * tmul
	_sp_first = _rng.randf_range(40.0, 90.0)
	_sp_due = _sp_first
	_a_free = 0.0
	_idle_sp = false
	_react_next = 10.0


## Leaving the system: the hull's catch light goes with it (it is the
## overlay's, which outlives this sky).
func _exit_tree() -> void:
	if screen != null and screen.overlay != null:
		screen.overlay.catch_light = {}


## Only on arrival: Jon found it weird in every sky
## (Oct 5) until he heard it was the arrival's alone.
## Why: docs/why/SkyWeather.md#warp-in-weather
func arrive(warp_t: float) -> void:
	_bow_at = warp_t + 0.6
	_next_a = _rng.randf_range(8.0, 14.0) * tmul


# ---------------------------------------------------------------- the frame

func _process(d: float) -> void:
	if sim or view == null or not view._palette_built:
		return
	if DisplaySettings.reduced_motion:
		_clear_all()
		return
	var t0 := Time.get_ticks_usec()
	var dt := step_s if step_s > 0.0 else d
	_pal_t += dt
	_track_ship(dt)
	_step_bow(dt)
	if _pal_t >= 1.0:
		_tick(dt)
	advance(dt)
	_guard()
	view.tick("weather", t0)


## The scheduler alone a step on (`-- weathertest`), as `_process` steps it.
func sim_step(dt: float) -> void:
	if DisplaySettings.reduced_motion:
		# (the visit goes on; nothing else does)
		_visit += dt
		_clear_all()
		return
	if _bow_at >= 0.0 and _visit >= _bow_at:
		_bow_at = -1.0
		if log_on:
			log_starts.append([_visit, &"bowshock", 2, R, 2.5, _clock_a])
	_tick(dt)
	advance(dt)


## The scheduler a step on: its clocks, and whatever comes due.
func _tick(dt: float) -> void:
	_clock_b += dt
	_visit += dt
	if not _held():
		_clock_a += dt
	if not auto:
		return
	_idle_pull()
	_react()
	# (a busy hold starts nothing in slot A, even an event that was already due:
	# a showpiece waiting on a small one used to start the moment it ended)
	if _a.is_empty() and _clock_a >= _a_free and not _held():
		var sp_name := _first_of(SP)
		# (never the showpiece twice running: a medium one comes between)
		if sp_name != &"" and _clock_a >= _sp_due and _last_a != sp_name:
			# (a small one still live: the showpiece waits the seconds it has left,
			# as a small one never starts under a showpiece)
			if _b.is_empty() and not _start(sp_name, 0):
				_sp_due = _clock_a + 10.0
		elif _clock_a >= _next_a:
			if not _start_pick(M):
				_next_a = _clock_a + 10.0
	if _b.is_empty() and _clock_b >= _next_b and not _sp_live() and not _a_due_soon():
		if not _start_pick(S):
			_next_b = _clock_b + 10.0


## Every live event a step on, its uniforms pushed; ended ones cleared once.
func advance(dt: float) -> void:
	for slot in 2:
		var ev: Dictionary = _a if slot == 0 else _b
		if ev.is_empty():
			continue
		if hold_at > -100.0:
			ev.age = hold_at
		elif hold:
			ev.age = float(PEAK.get(ev.name, 0.0))
		else:
			ev.age = float(ev.age) + dt
		if float(ev.age) > float(ev.end):
			_end(slot)
		elif not sim:
			_apply(ev)
			_cleared = false


func _end(slot: int) -> void:
	var ev: Dictionary = _a if slot == 0 else _b
	if not sim:
		_clear(ev)
	if slot == 0:
		_a = {}
		_a_free = _clock_a + 6.0
		if int(ev.tier) == SP:
			_next_a = _clock_a + _rng.randf_range(CADENCE[sky].x, CADENCE[sky].y) * tmul
		_next_a = maxf(_next_a, _a_free)
	else:
		_b = {}


func _clear_all() -> void:
	_g_sent = Vector2.INF
	if _cleared:
		return
	for ev: Dictionary in [_a, _b, _bow]:
		if not ev.is_empty() and not sim:
			_clear(ev)
	_a = {}
	_b = {}
	_bow = {}
	_a_free = _clock_a + 6.0
	_cleared = true


## A showpiece is the screenshot: a supernova during
## a comet's minute made two of the rarest at once.
func far_busy() -> bool:
	return not _a.is_empty() and (FAR.has(StringName(_a.layer)) or int(_a.tier) == SP)


func live() -> Array:
	var out: Array = []
	for ev: Dictionary in [_a, _b, _bow]:
		if not ev.is_empty():
			out.append(ev)
	return out


# ---------------------------------------------------------------- holds, idle, the ship

func _held() -> bool:
	if sim:
		return sim_hold
	if screen == null:
		return false
	if screen.panel != null and screen.panel.mode == &"event":
		return true
	if not (screen._glide as Dictionary).is_empty():
		return true
	if screen.flight != null and screen.flight.inserting():
		return true
	return now() - float(screen.last_zoom_t) < 1.5


## 45 s WITH NO INPUT pulls the next slot-A start to within 6 s; once a visit,
## when the showpiece may come, it is the showpiece.
func _idle_pull() -> void:
	if screen == null or sim or not _a.is_empty():
		return
	var quiet := now() - maxf(float(screen.last_input_t), _idle_from)
	if quiet < 45.0:
		return
	_idle_from = now()
	if not _idle_sp and _clock_a >= _sp_first and _first_of(SP) != &"":
		_sp_due = minf(_sp_due, _clock_a + 6.0)
		_idle_sp = true
	elif _next_a > _clock_a + 6.0:
		_next_a = _clock_a + 6.0


## THE SHIP SETS IT OFF: while it is moving, now and then, a discharge or a
## spark just ahead of it.
func _react() -> void:
	if _visit < _react_next:
		return
	_react_next = _visit + 10.0
	var nm := &""
	for k: StringName in TABLE[sky]:
		if int(TABLE[sky][k][0]) == R:
			nm = k
	if nm == &"" or _visit - _react_last < 60.0:
		return
	var moving: bool = sim_moving if sim else (_ship_v.length() > 20.0 and screen != null and screen.flight != null and not screen.flight.inserting())
	if not moving or _rng.randf() > 0.25:
		return
	var slot := 1 if nm == &"nearspark" else 0
	if (slot == 0 and not _a.is_empty()) or (slot == 1 and not _b.is_empty()):
		return
	# slot A's own rules: its 6 s gap, its holds, never the same twice running;
	# slot B's: never under a showpiece
	if slot == 0 and (_clock_a < _a_free or _held() or _last_a == nm):
		return
	if slot == 1 and (_sp_live() or _last_b == nm):
		return
	if _start(nm, slot):
		_react_last = _visit


func _track_ship(dt: float) -> void:
	var s := _ship()
	if _ship_prev != Vector2.INF and dt > 0.0 and s.x > -9000.0:
		_ship_v = _ship_v.lerp((s - _ship_prev) / dt, 0.2)
	_ship_prev = s


func _ship() -> Vector2:
	if screen != null and screen.overlay != null and screen.flight != null:
		return screen.overlay._ship_at
	return Vector2(-9999, -9999)


func _labels() -> Array:
	if screen != null and screen.overlay != null:
		return screen.overlay.label_rects
	return []


## The status box is its own words' (`SystemOverlay.status_rect`):
## a fixed 300 x 24 missed a 327 px line.
## Why: docs/why/SkyWeather.md#frame-words
var _ui_at := -1
var _ui: Array = []
func _ui_rects() -> Array:
	if _ui_at == Engine.get_process_frames():
		return _ui
	_ui_at = Engine.get_process_frames()
	var w: Rect2 = view.window
	var out: Array = [Rect2(w.end - Vector2(160.0, 52.0), Vector2(160.0, 52.0))]
	var goal := Rect2(w.position, Vector2(300.0, 24.0))
	if screen != null and is_instance_valid(screen) and screen.get("_box") != null:
		var g := GoalLine.stack_rect(screen)
		if g.size.x > 0.0:
			goal = (screen._box.get_global_transform().affine_inverse() * g).grow(2.0)
	out.append(goal)
	if screen != null and is_instance_valid(screen) and screen.get("overlay") != null:
		var st: Array = screen.overlay.ship_status()
		if String(st[0]) != "":
			out.append(screen.overlay.status_rect(String(st[0])).grow(4.0))
	_ui = out
	return out


func _sel() -> Vector2:
	if screen == null or screen.overlay == null:
		return Vector2.INF
	var s: int = screen.overlay.selected
	# (either star of a pair: `star_screen` is star A's `origin` with one sun)
	if SystemLayout.is_star(s):
		return view.star_screen(s)
	if s >= 0 and s < view.at.size():
		return view.at[s]
	return Vector2.INF


# ---------------------------------------------------------------- picking

func _first_of(tier: int) -> StringName:
	for nm: StringName in TABLE[sky]:
		if int(TABLE[sky][nm][0]) == tier:
			return nm
	return &""


func _sp_live() -> bool:
	return not _a.is_empty() and int(_a.tier) == SP


func _a_due_soon() -> bool:
	return _a.is_empty() and minf(_next_a, _sp_due) - _clock_a < 2.0


## Whether this sky hosts event `nm` (the shared ones when they can be placed).
func hosts(nm: StringName) -> bool:
	if nm == &"bowshock":
		return true
	if TABLE[sky].has(nm):
		return true
	return SHARED.has(nm) and _can_host(nm)


func _spec(nm: StringName) -> Array:
	return TABLE[sky][nm] if TABLE[sky].has(nm) else SHARED[nm]


func _can_host(nm: StringName) -> bool:
	if sim:
		return true
	if nm == &"collision":
		return not _belt_spots().is_empty()
	return true


func _weight(nm: StringName) -> float:
	var w := float(_spec(nm)[1])
	if nm == &"flier" and (shape == 2 or shape == 3):
		w = 3.0
	if nm == fav:
		w *= 2.0
	return w * (1.0 + (_visit - float(_seen.get(nm, 0.0))) / STARVE_S)


## A weighted pick of the tier's events, each tried until one can be placed.
func _start_pick(tier: int) -> bool:
	var names: Array = []
	var last := _last_a if tier != S else _last_b
	for nm: StringName in TABLE[sky]:
		if int(TABLE[sky][nm][0]) == tier:
			names.append(nm)
	if tier == M:
		for nm: StringName in SHARED:
			if _can_host(nm):
				names.append(nm)
	# never the same twice running -- unless it is the tier's only one
	if names.size() > 1:
		names.erase(last)
	while not names.is_empty():
		var tot := 0.0
		for nm: StringName in names:
			tot += _weight(nm)
		var x := _rng.randf() * tot
		var pick: StringName = names[names.size() - 1]
		for nm: StringName in names:
			x -= _weight(nm)
			if x <= 0.0:
				pick = nm
				break
		if _start(pick, 1 if tier == S else 0):
			return true
		names.erase(pick)
	return false


## Start event `nm` in its slot; false when it cannot be placed.
func _start(nm: StringName, slot: int, at := Vector2.INF) -> bool:
	var spec := _spec(nm)
	var ev := {"name": nm, "tier": int(spec[0]), "layer": spec[3], "slot": slot, "age": 0.0, "pre": 0.0,
		"end": float(spec[2]), "k": 1.0, "at": at, "dir": Vector2.RIGHT, "seed": _rng.randf(), "size": 115.0,
		"pts": PackedVector4Array(), "n": 0}
	if not sim and (FAR.has(StringName(spec[3])) or int(spec[0]) == SP) and _nova_near():
		return false
	if not _place(ev):
		return false
	if slot == 1 and not sim and not _a.is_empty() and focus(ev).distance_to(focus(_a)) < 150.0:
		return false
	ev.age = -float(ev.pre)
	_seen[nm] = _visit
	if slot == 0:
		_a = ev
		_last_a = nm
		_idle_from = now()
		if int(ev.tier) == M:
			_next_a = _clock_a + _rng.randf_range(CADENCE[sky].x, CADENCE[sky].y) * tmul
		elif int(ev.tier) == SP:
			_sp_due = _clock_a + _rng.randf_range(90.0, 180.0)
	else:
		_b = ev
		_last_b = nm
		_next_b = _clock_b + _rng.randf_range(15.0, 40.0) * tmul
	_cleared = false
	if log_on:
		log_starts.append([_visit, nm, slot, int(ev.tier), float(ev.pre) + float(ev.end), _clock_a])
	return true


## A supernova is live, or went out less than 4 s ago.
func _nova_near() -> bool:
	if view == null or view._nova == null:
		return false
	return view._nova.busy_within(4.0)


## THE HARNESS: event `nm` now (at `at` on screen if given). "" when it started,
## else why not.
func force(nm: StringName, at := Vector2.INF) -> String:
	if nm == &"bowshock":
		_start_bow()
		return ""
	if not hosts(nm):
		var names: Array = TABLE[sky].keys()
		names.append_array(SHARED.keys())
		names.append(&"bowshock")
		return "no %s here; this sky hosts: %s" % [nm, ", ".join(PackedStringArray(names))]
	var slot := 1 if int(_spec(nm)[0]) == S or nm == &"nearspark" else 0
	if slot == 0 and not _a.is_empty():
		_end(0)
	if slot == 1 and not _b.is_empty():
		_end(1)
	if _start(nm, slot, at):
		return ""
	return "%s could not be placed in this view" % nm


## The system's original weather now (SystemShot's old `wclip`).
func start_default(at := Vector2.INF) -> void:
	var nm: StringName = {&"emission": &"strike", &"dark": &"strike", &"remnant": &"shock", &"reflection": &"shaft"}.get(sky, &"")
	if nm != &"":
		force(nm, at)


# ---------------------------------------------------------------- placement helpers

func _star_disc() -> float:
	if view.layout.star == SystemLayout.StarKind.CORE:
		return 116.0 * view.star_k()
	return view.layout.star_r * view.star_k()


## Where star A is drawn now: the origin with one sun, the pair's own spot in a pair (ruling 23).
func _sa() -> Vector2:
	return view.star_screen(-1)


## Is screen point p clear of the ship (by `ship_r`), the star's disc + 40, every
## world + 30, the labels and the selection (each grown by `grow`)?
func clear_at(p: Vector2, ship_r: float, grow: float = 0.0) -> bool:
	if p.distance_to(_ship()) < ship_r:
		return false
	if p.distance_to(_sa()) < _star_disc() + 40.0 + grow:
		return false
	# (and star B's, with two suns)
	if view.star2 != null and p.distance_to(view.star_screen(SystemLayout.STAR_B)) < view.star_disc(SystemLayout.STAR_B) + 40.0 + grow:
		return false
	var L: SystemLayout = view.layout
	for i in mini(view.at.size(), L.bodies.size()):
		var b: SystemLayout.Body = L.bodies[i]
		if b.kind == &"belt":
			continue
		var rr: float = view.draw_r(b) if view._views.has(i) else 8.0
		if p.distance_to(view.at[i]) < rr + 30.0 + grow:
			return false
	# A negative grow turned a 14 px label box inside
	# out; Rect2 complained hundreds of times a visit.
	# Why: docs/why/SkyWeather.md#label-clearance
	for r: Rect2 in _labels():
		var rg := r.grow(grow)
		if r.size.x > 0.0 and rg.size.x > 0.0 and rg.size.y > 0.0 and rg.has_point(p):
			return false
	for r2: Rect2 in _ui_rects():
		var rg2 := r2.grow(grow)
		if rg2.size.x > 0.0 and rg2.size.y > 0.0 and rg2.has_point(p):
			return false
	var s := _sel()
	if s != Vector2.INF and p.distance_to(s) < 60.0 + grow:
		return false
	return true


func _in_view(p: Vector2, margin: float = 0.0) -> bool:
	return (view.window as Rect2).grow(-margin).has_point(p)


## A clear point in view (24 tries), or INF.
func spot(ship_r: float, margin: float = 30.0, grow: float = 0.0) -> Vector2:
	var w: Rect2 = (view.window as Rect2).grow(-margin)
	for _i in 24:
		var p := Vector2(_rng.randf_range(w.position.x, w.end.x), _rng.randf_range(w.position.y, w.end.y))
		if clear_at(p, ship_r, grow):
			return p
	return Vector2.INF


func _unit() -> Vector2:
	var a := _rng.randf() * TAU
	return Vector2(cos(a), sin(a))


## A screen point in the nebula's own pixels, on a 2x2 block's middle.
func _neb_sp(p: Vector2) -> Vector2:
	var sp: Vector2 = p - view.neb_off()
	return (sp / 2.0).floor() * 2.0 + Vector2.ONE


func _neb_scr(sp: Vector2) -> Vector2:
	return sp + view.neb_off()


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ---------------------------------------------------------------- the cloud's noise, ported
# Ported from `sky_nebula.gdshader`: its hash floors arguments and its fbm offsets each octave.
# Evaluated without the churn: a small miss shows a little less, never a glow in empty sky.

static func nhash(x: float, y: float) -> float:
	return SkyBakeS.hash2(floori(x), floori(y))


static func nnoise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3, 3) - 2.0 * f)
	var a := nhash(i.x, i.y)
	var b := nhash(i.x + 1.0, i.y)
	var c := nhash(i.x, i.y + 1.0)
	var d := nhash(i.x + 1.0, i.y + 1.0)
	return a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y


static func nfbm(p: Vector2, o: int) -> float:
	var a := 0.5
	var s := 0.0
	var n := 0.0
	for _i in o:
		s += a * nnoise(p)
		n += a
		p = p * 2.03 + Vector2(17.1, 9.3)
		a *= 0.5
	return s / n


static func ridge(v: float, k: float) -> float:
	return pow(1.0 - absf(2.0 * v - 1.0), k)


static func sm(a: float, b: float, x: float) -> float:
	if absf(b - a) < 1e-6:
		return 1.0 if x >= a else 0.0
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func env(a: float, r: float, h: float, f: float) -> float:
	return sm(0.0, r, a) * (1.0 - sm(r + h, r + h + f, a))


func _u(sp: Vector2) -> Vector2:
	return sp / 430.0 + Vector2(_sd * 1.7, _sd * 0.9)


func nspot(k: float, lo: Vector2, hi: Vector2) -> Vector2:
	return lo + Vector2(nhash(k * 13.0 + _sd * 17.0, 5.0), nhash(k * 17.0 + _sd * 13.0, 9.0)) * (hi - lo)


func _bil(sp: Vector2) -> float:
	return nfbm(_u(sp) * 1.4, 5)


## In SIMPLIFIED the cluster is the system's sun (two
## suns: their balance point).
## Why: docs/why/SkyWeather.md#emission-cluster
func em_cc() -> Vector2:
	if view != null and view.has_method(&"sky_c"):
		return view.sky_c()
	return Vector2(480, 270)


## A lit pillar tip's strength at sp: near the head of a pillar the bake raised.
func em_tip(sp: Vector2) -> float:
	var best := 0.0
	for p: Array in em_tips():
		best = maxf(best, exp(-(sp - Vector2(p[1])).length_squared() / (24.0 * 24.0)))
	return best


## The cloud's pillars as [base, tip, w0, w1, seed] in sky pixels.
func em_tips() -> Array:
	return SkyBakeS.em_pillars(_sd, em_cc())


func em_lane(sp: Vector2) -> float:
	return ridge(nfbm(_u(sp) * 2.2 + Vector2(_sd, 11.0), 3), 9.0)


func rf_star(k: int) -> Vector2:
	return nspot(float(k) + 2.0, Vector2(60, 50), Vector2(900, 490))


func rf_haze(sp: Vector2) -> float:
	return 0.1 + 0.6 * sm(0.2, 0.75, _bil(sp))


func pn_cc() -> Vector2:
	return nspot(1.0, Vector2(-80, -60), Vector2(1040, 600))


func pn_aa() -> float:
	return nhash(_sd, 77.0) * PI


func pn_r0() -> float:
	return maxf(380.0, pn_cc().distance_to(Vector2(480, 270)) * (0.75 + 0.35 * nhash(_sd, 41.0)))


## the shell's frame for a sky point: d turned by aa, stretched for the
## elliptical and bipolar shells
func pn_dd(sp: Vector2) -> Vector2:
	var d := sp - pn_cc()
	var aa := pn_aa()
	var dd := Vector2(d.x * cos(aa) - d.y * sin(aa), d.x * sin(aa) + d.y * cos(aa))
	if shape == 1 or shape == 2:
		dd.y *= 1.5
	return dd


## back from the shell's frame to the sky
func pn_sky(dd: Vector2) -> Vector2:
	var aa := pn_aa()
	var e := dd
	if shape == 1 or shape == 2:
		e.y /= 1.5
	return pn_cc() + Vector2(e.x * cos(aa) + e.y * sin(aa), -e.x * sin(aa) + e.y * cos(aa))


## the rim's direction nearest the view's middle, in the shell's frame
func pn_theta0() -> float:
	var vc: Vector2 = Vector2(480, 270) - view.neb_off()
	var dd := pn_dd(vc)
	return atan2(dd.y, dd.x)


func rm_cc() -> Vector2:
	return nspot(1.0, Vector2(-300, -260), Vector2(1260, 800))


func rm_fil(sp: Vector2) -> float:
	return ridge(nfbm(_u(sp) * 2.4 + Vector2(_sd, 2.0), 4), 14.0)


func rm_fil2(sp: Vector2) -> float:
	return ridge(nfbm(_u(sp) * 3.6 + Vector2(3.0, _sd), 4), 16.0)


## the strand through sp: along it (the perpendicular of its noise's gradient)
func rm_tangent(sp: Vector2) -> Vector2:
	var second := rm_fil2(sp) > rm_fil(sp)
	var f := func(q: Vector2) -> float:
		return nfbm(_u(q) * 3.6 + Vector2(3.0, _sd), 4) if second else nfbm(_u(q) * 2.4 + Vector2(_sd, 2.0), 4)
	var e := 1.5
	var g := Vector2(float(f.call(sp + Vector2(e, 0))) - float(f.call(sp - Vector2(e, 0))), float(f.call(sp + Vector2(0, e))) - float(f.call(sp - Vector2(0, e))))
	if g.length() < 1e-9:
		return Vector2.RIGHT
	return Vector2(-g.y, g.x).normalized()


func dk_d(sp: Vector2) -> float:
	var fine := nfbm(_u(sp) * 4.2 + Vector2(5.0, _sd), 4)
	return sm(0.3, 0.66, _bil(sp) + 0.15 * (fine - 0.5))


func dk_ld() -> Vector2:
	var la := nhash(_sd, 31.0) * TAU
	return Vector2(cos(la), sin(la))


## THE CALM SKY'S GALAXY BAND: through (480, 270) in sky pixels, along this
func band_dir() -> Vector2:
	var a := float(index) * 0.731 * 2.7
	return Vector2(cos(a), sin(a))


## The points the harness's `wprobe` marks over the sky, on screen: [label, point].
func probe_points() -> Array:
	var out: Array = []
	match sky:
		&"emission":
			out.append(["cc", _neb_scr(em_cc())])
			for p: Array in em_tips():
				out.append(["tip", _neb_scr(Vector2(p[1]))])
		&"reflection":
			for k in 3:
				out.append(["st%d" % k, _neb_scr(rf_star(k))])
		&"planetary":
			out.append(["cc", _neb_scr(pn_cc())])
			var th := pn_theta0()
			out.append(["rim", _neb_scr(pn_sky(Vector2(cos(th), sin(th)) * pn_r0()))])
		&"remnant":
			out.append(["cc", _neb_scr(rm_cc())])
			var w: Rect2 = view.window
			for k in 40:
				var p := Vector2(w.position.x + 20.0 + fmod(float(k) * 97.3, w.size.x - 40.0), w.position.y + 20.0 + fmod(float(k) * 53.7, w.size.y - 40.0))
				var sp := _neb_sp(p)
				if maxf(rm_fil(sp), rm_fil2(sp)) > 0.5:
					out.append(["fil", p])
		&"dark":
			var w2: Rect2 = view.window
			for k in 40:
				var p2 := Vector2(w2.position.x + 20.0 + fmod(float(k) * 97.3, w2.size.x - 40.0), w2.position.y + 20.0 + fmod(float(k) * 53.7, w2.size.y - 40.0))
				var dv := dk_d(_neb_sp(p2))
				if absf(dv - 0.5) < 0.1:
					out.append(["edge", p2])
		&"calm":
			var bd := band_dir()
			for k in range(-6, 7):
				out.append(["band", Vector2(480, 270) + bd * float(k) * 80.0 + view.sky_off()])
	return out


## WHERE AN EVENT IS on screen this frame (the harness crops its stills round it).
func focus(ev: Dictionary) -> Vector2:
	var nm := StringName(ev.name)
	var at: Vector2 = ev.get("at", Vector2.INF)
	match StringName(ev.layer):
		&"neb":
			if nm == &"tide" or nm == &"glints":
				return _neb_scr(em_cc())
			if nm == &"ringrun" or nm == &"halo" or nm == &"lamps" or nm == &"searchlights":
				var th := pn_theta0()
				return _neb_scr(pn_sky(Vector2(cos(th), sin(th)) * pn_r0()))
			if nm == &"rays" or nm == &"dawn":
				return (view.window as Rect2).get_center()
			return _neb_scr(at) if at != Vector2.INF else (view.window as Rect2).get_center()
		&"sky":
			if nm == &"globule":
				return at + Vector2(ev.dir) * 3.0 * float(ev.age) + view.sky_off()
			if nm == &"fog":
				return _sa() + Vector2(ev.dir) * float(view.zoom) / maxf(float(view.home_zoom), 0.01)
			return _sa()
		&"field":
			return view._fields[int(ev.field)].star_at(int(ev.star))
		&"node":
			if nm == &"collision":
				var b: SystemLayout.Body = view.layout.bodies[int(ev.body)]
				var a0 := float(ev.a0) + float(view.t) / b.period * TAU
				# (round the belt's own centre: a twin's belts circle the balance point)
				return view.screen(b.host_at(float(view.t)).x + cos(a0) * float(ev.r0), b.host_at(float(view.t)).y + sin(a0) * float(ev.r0))
			# (a comet flies round star A where the pair has it now, `Comet.at`)
			var p: Vector2 = Comet.comet_pos(ev, maxf(float(ev.age), 0.0)) + view.layout.star_pos(-1, float(view.t))
			return view.screen(p.x, p.y)
		&"depth":
			return _ship()
		&"fabric":
			return (view.window as Rect2).get_center()
	return _sa()


# ---------------------------------------------------------------- place: where, how long

## Where and how long; false when it has nowhere to go. Every event's timing
## (`pre`, `end`) is set here, so the scheduler alone (`sim`) times it the same.
func _place(ev: Dictionary) -> bool:
	var nm: StringName = ev.name
	match nm:
		&"strike", &"nearstrike":
			return _p_strike(ev, nm == &"nearstrike")
		&"shaft":
			ev.pre = 2.0 if up else 0.0
			ev.k = _rng.randf_range(0.75, 1.0)
			return sim or _p_random(ev, 100.0)
		&"shock":
			ev.pre = 1.5 if up else 0.0
			ev.k = _rng.randf_range(0.75, 1.0)
			return sim or _p_random(ev, 100.0)
		&"echo":
			ev.pre = 1.5
	if sim:
		_p_timing(ev)
		return true
	match nm:
		&"tide":
			ev.at = em_cc()
			return true
		&"jet":
			return _p_jet(ev)
		&"glints":
			return _in_view(_neb_scr(em_cc()), -200.0)
		&"newstar":
			return _p_newstar(ev)
		&"spoke", &"breathe":
			return _p_star(ev, false)
		&"echo":
			return _p_star(ev, true)
		&"glitter":
			return _p_glitter(ev)
		&"ringrun", &"halo", &"lamps":
			return _p_rim(ev)
		&"flier":
			return _p_flier(ev)
		&"searchlights":
			return _p_searchlights(ev)
		&"flare":
			return _p_flare(ev)
		&"shrapnel":
			return _p_shrapnel(ev)
		&"pearls":
			return _p_pearls(ev)
		&"spark":
			return _p_spark(ev, false)
		&"nearspark":
			return _p_spark(ev, true)
		&"rays":
			ev.seed = _rng.randf()
			return true
		&"dawn":
			ev.at = Vector2(480, 270) - view.neb_off()
			return true
		&"ember":
			return _p_ember(ev)
		&"fan":
			return _p_fan(ev)
		&"microlens":
			return _p_microlens(ev)
		&"sungrazer":
			return _p_sungrazer(ev)
		&"comet":
			return _p_comet(ev)
		&"starmood":
			return _p_starmood(ev)
		&"globule":
			return _p_globule(ev)
		&"wisps", &"firehose":
			return view.star != null and _in_view(_sa(), -60.0)
		&"fog":
			return _p_fog(ev)
		&"pulse":
			return _p_pulse(ev)
		&"magnetar":
			return _p_magnetar(ev)
		&"hotspot":
			return view.star != null and bool(view.star.get("ready_to_draw")) and _in_view(_sa(), -80.0)
		&"ringflash":
			return _p_ringflash(ev)
		&"flareecho":
			ev.at = _sa() - view.sky_off()
			return view.star != null and bool(view.star.get("ready_to_draw"))
		&"einstein":
			return _p_einstein(ev)
		&"lensstar":
			return _p_lensstar(ev)
		&"collision":
			return _p_collision(ev)
		&"gwave":
			return _p_gwave(ev)
	return true


## The timing of the events placed only on screen, for the scheduler alone.
func _p_timing(ev: Dictionary) -> void:
	match StringName(ev.name):
		&"newstar":
			ev.size = 48.0
		&"starmood":
			ev.end = 26.0 if star_kind == SystemLayout.StarKind.RED else 30.0
		&"globule":
			ev.end = _rng.randf_range(40.0, 60.0)
		&"comet":
			ev.end = _rng.randf_range(60.0, 80.0)
		&"sungrazer":
			ev.end = _rng.randf_range(10.0, 14.0) + 1.0
		&"magnetar":
			ev.pre = _rng.randf_range(0.05, 1.0)
		&"ringflash":
			ev.pre = _rng.randf_range(0.5, 5.0)
		&"pulse":
			ev.end = _rng.randf_range(2.6, 3.6)
		&"gwave":
			ev.end = 14.0


func _p_random(ev: Dictionary, ship_r: float) -> bool:
	var p: Vector2 = ev.at
	if p == Vector2.INF:
		var w: Rect2 = view.window
		for _i in 24:
			p = Vector2(_rng.randf_range(w.position.x + 70.0, w.end.x - 70.0), _rng.randf_range(w.position.y + 50.0, w.end.y - 50.0))
			if clear_at(p, ship_r):
				break
			p = Vector2.INF
		if p == Vector2.INF:
			return false
	ev.at = _neb_sp(p)
	return true


func _p_strike(ev: Dictionary, near: bool) -> bool:
	ev.k = _rng.randf_range(0.75, 1.0)
	ev.size = 60.0 if near else 115.0
	ev.pre = _rng.randf_range(1.8, 3.0) if (up and not near) else 0.0
	ev.end = 1.6 + (3.0 if up else 0.0)
	ev.dir = _unit()
	# A STORM THAT WALKS: one to three smaller strikes after it, each further out
	# from the young cluster, always from the same quarter
	var links := 0
	if up and not near and chain_max > 0 and _rng.randf() < chain_p:
		links = _rng.randi_range(1, chain_max)
	var t0s: Array[float] = []
	var tt := 0.0
	for _i in links:
		tt += _rng.randf_range(0.6, 1.4)
		t0s.append(tt)
	if sim:
		ev.n = links
		if links > 0:
			ev.end = maxf(float(ev.end), t0s[links - 1] + 4.5)
		return true
	var p: Vector2 = ev.at
	if p == Vector2.INF:
		if near:
			p = _near_ship(50.0, 110.0)
			if p == Vector2.INF:
				return false
		else:
			p = _strike_spot()
			if p == Vector2.INF:
				return false
	ev.at = _neb_sp(p)
	var walk: Vector2
	if sky == &"emission":
		walk = (Vector2(ev.at) - em_cc()).normalized()
	else:
		var ha := SkyBakeS.hash2(index, 31) * TAU
		walk = Vector2(cos(ha), sin(ha))
	var pts := PackedVector4Array()
	var prev: Vector2 = ev.at
	var ship := _ship()
	for i in links:
		var q := prev + walk * _rng.randf_range(60.0, 120.0)
		var qs := _neb_scr(q)
		if not _in_view(qs, 20.0) or not clear_at(qs, SHIP_R[M]) or _seg_dist(ship, _neb_scr(prev), qs) < 60.0:
			break
		pts.append(Vector4(q.x, q.y, t0s[i], pow(0.7, float(i + 1))))
		prev = q
	ev.n = pts.size()
	if pts.size() > 0:
		ev.end = maxf(float(ev.end), pts[pts.size() - 1].z + 4.5)
	pts.resize(6)
	ev.pts = pts
	return true


## A strike goes 160 px from the ship; in a dark cloud the broken dust lets the light show through.
func _strike_spot() -> Vector2:
	var best := Vector2.INF
	var bd := 9.0
	for _i in 12:
		var p := spot(160.0, 70.0)
		if p == Vector2.INF:
			break
		if sky != &"dark" or not up:
			return p
		var d := absf(dk_d(_neb_sp(p)) - 0.45)
		if d < bd:
			bd = d
			best = p
	return best


## Onto the crest of the nearest strand, within a few pixels (the strands are
## sharp ridges: a random point is rarely right on one).
func _onto_strand(sp: Vector2) -> Vector2:
	var best := sp
	var bf := maxf(rm_fil(sp), rm_fil2(sp))
	for dy in range(-6, 7, 2):
		for dx in range(-6, 7, 2):
			var q := sp + Vector2(dx, dy)
			var f := maxf(rm_fil(q), rm_fil2(q))
			if f > bf:
				bf = f
				best = q
	return best


## A point 50-110 px ahead of the moving ship, turned up to 40 degrees, clear
## of everything but the ship.
func _near_ship(lo: float, hi: float) -> Vector2:
	var s := _ship()
	if s.x < -9000.0:
		return Vector2.INF
	var dir := _ship_v.normalized()
	if _ship_v.length() < 1.0:
		# (a harness's parked ship: toward the middle of the view)
		if auto:
			return Vector2.INF
		dir = ((view.window as Rect2).get_center() - s).normalized()
	for _i in 16:
		var p := s + dir.rotated(_rng.randf_range(-0.7, 0.7)) * _rng.randf_range(lo, hi)
		if _in_view(p, 10.0) and clear_at(p, lo * 0.9):
			return p
	return Vector2.INF


func _p_jet(ev: Dictionary) -> bool:
	var cc := em_cc()
	var at := Vector2.INF
	var tips := em_tips()
	var k0 := _rng.randi() % maxi(1, tips.size())
	for j in tips.size():
		var sp: Vector2 = tips[(k0 + j) % tips.size()][1]
		var q := _neb_scr(sp)
		if _in_view(q, 30.0) and clear_at(q, SHIP_R[M]):
			at = sp
			break
	if at == Vector2.INF:
		return false
	ev.at = (at / 2.0).floor() * 2.0 + Vector2.ONE
	var rad := (Vector2(ev.at) - cc).normalized()
	ev.dir = Vector2(-rad.y, rad.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
	return true


func _p_newstar(ev: Dictionary) -> bool:
	ev.size = _rng.randf_range(40.0, 55.0)
	var cc := em_cc()
	var best := -1.0
	var at := Vector2.INF
	for _i in 20:
		var sp := cc + _unit() * _rng.randf_range(150.0, 400.0)
		var p := _neb_scr(sp)
		if not _in_view(p, float(ev.size) + 10.0) or not clear_at(p, 130.0, float(ev.size) + 20.0):
			continue
		var ln := em_lane(sp)
		if ln > best:
			best = ln
			at = sp
	if at == Vector2.INF:
		return false
	ev.at = (at / 2.0).floor() * 2.0 + Vector2.ONE
	return true


## A reflection cloud's lighting star in view, 150 px from the ship: for the
## echo the one nearest the middle of the view, so its rings spread over it.
func _p_star(ev: Dictionary, far: bool) -> bool:
	var ship := _ship()
	var pick := -1
	var bd := -1.0
	var ks := [0, 1, 2]
	ks.shuffle()
	for k: int in ks:
		var p := _neb_scr(rf_star(k))
		if not _in_view(p, 110.0 if far else 60.0) or p.distance_to(ship) < 150.0:
			continue
		if not far:
			pick = k
			break
		var d := -p.distance_to((view.window as Rect2).get_center())
		if d > bd or pick < 0:
			bd = d
			pick = k
	if pick < 0:
		return false
	ev.at = rf_star(pick)
	ev.seed = _rng.randf()
	return true


func _p_glitter(ev: Dictionary) -> bool:
	for _i in 24:
		var p := spot(SHIP_R[S], 60.0)
		if p == Vector2.INF:
			return false
		var sp := _neb_sp(p)
		if rf_haze(sp) > 0.4:
			ev.at = sp
			return true
	return false


func _p_rim(ev: Dictionary) -> bool:
	var th := pn_theta0()
	ev.dir = Vector2(cos(th), sin(th))
	var rim := _neb_scr(pn_sky(Vector2(cos(th), sin(th)) * pn_r0()))
	return _in_view(rim, -40.0)


func _p_flier(ev: Dictionary) -> bool:
	# where a knot reaches the rim (and flares it) must be in view, and most of
	# its way there
	var R0 := pn_r0()
	for side in [-1.0, 1.0]:
		var end := _neb_scr(pn_sky(Vector2(side * R0, 0.0)))
		var mid := _neb_scr(pn_sky(Vector2(side * R0 * 0.6, 0.0)))
		if _in_view(end, 40.0) and _in_view(mid, 0.0):
			ev.at = pn_sky(Vector2(side * R0, 0.0))
			return true
	return false


func _p_searchlights(ev: Dictionary) -> bool:
	ev.seed = _rng.randf()
	ev.n = 4 if _rng.randf() < 0.7 else 2
	return (view.window as Rect2).grow(500.0).has_point(_neb_scr(pn_cc()))


func _p_flare(ev: Dictionary) -> bool:
	var best := 0.3
	var at := Vector2.INF
	for _i in 40:
		var p := spot(SHIP_R[M], 40.0)
		if p == Vector2.INF:
			break
		var sp := _neb_sp(p)
		var f := maxf(rm_fil(sp), rm_fil2(sp))
		if f > best:
			best = f
			at = sp
	if at == Vector2.INF:
		return false
	ev.at = (_onto_strand(at) / 2.0).floor() * 2.0 + Vector2.ONE
	ev.dir = rm_tangent(ev.at)
	return true


func _p_shrapnel(ev: Dictionary) -> bool:
	var cc := rm_cc()
	var best := 0.45
	var at := Vector2.INF
	for _i in 30:
		var p := spot(SHIP_R[M], 40.0)
		if p == Vector2.INF:
			break
		var sp := _neb_sp(p)
		var rag := sp.distance_to(cc) / 760.0 + (_bil(sp) - 0.5) * 0.3
		var sh := exp(-pow((rag - 0.85) / 0.14, 2.0))
		if sh > best:
			best = sh
			at = sp
	if at == Vector2.INF:
		return false
	var n := (at - cc).normalized()
	var across := Vector2(-n.y, n.x)
	var pts := PackedVector4Array()
	var ship := _ship()
	var cnt := _rng.randi_range(3, 5)
	for j in cnt:
		var st := at + across * _rng.randf_range(-20.0, 20.0)
		var ang := atan2(n.y, n.x) + _rng.randf_range(-0.15, 0.15)
		var spd := _rng.randf_range(10.0, 16.0)
		var e := st + Vector2(cos(ang), sin(ang)) * spd * 14.0
		if _seg_dist(ship, _neb_scr(st), _neb_scr(e)) < 100.0:
			continue
		# (most of its flight in view: placed near the edge, the volley left the
		# frame at once and read as a smudge)
		if not _in_view(_neb_scr(st + Vector2(cos(ang), sin(ang)) * spd * 9.0), 10.0):
			continue
		pts.append(Vector4(st.x, st.y, ang, spd))
	if pts.size() < 3:
		return false
	ev.at = at
	ev.n = pts.size()
	pts.resize(6)
	ev.pts = pts
	return true


func _p_pearls(ev: Dictionary) -> bool:
	for _i in 24:
		var p := spot(120.0, 80.0, 70.0)
		if p == Vector2.INF:
			return false
		# the whole ring clear of every world's disc by its radius + 70
		var ok := true
		for i in mini(view.at.size(), view.layout.bodies.size()):
			if view._views.has(i) and p.distance_to(view.at[i]) < view.draw_r(view.layout.bodies[i]) + 70.0:
				ok = false
		if ok:
			ev.at = _neb_sp(p)
			ev.dir = _unit()
			return true
	return false


func _p_spark(ev: Dictionary, near: bool) -> bool:
	if near:
		var p: Vector2 = ev.at if ev.at != Vector2.INF else _near_ship(40.0, 80.0)
		if p == Vector2.INF:
			return false
		ev.at = _neb_sp(p)
		var vd := _ship_v.normalized() if _ship_v.length() >= 1.0 else (p - _ship()).normalized()
		ev.dir = vd.rotated(_rng.randf_range(-0.5, 0.5))
		return true
	for _i in 24:
		var p2 := spot(80.0, 60.0)
		if p2 == Vector2.INF:
			return false
		var sp := _onto_strand(_neb_sp(p2))
		if maxf(rm_fil(sp), rm_fil2(sp)) > 0.5:
			ev.at = sp
			ev.dir = rm_tangent(sp) * (1.0 if _rng.randf() < 0.5 else -1.0)
			return true
	return false


func _p_ember(ev: Dictionary) -> bool:
	ev.seed = _rng.randf()
	for _i in 20:
		var p := spot(SHIP_R[S], 40.0)
		if p == Vector2.INF:
			return false
		var sp := _neb_sp(p)
		if dk_d(sp) > 0.7:
			ev.at = sp
			return true
	return false


func _p_fan(ev: Dictionary) -> bool:
	for _i in 24:
		var p := spot(120.0, 60.0)
		if p == Vector2.INF:
			return false
		if p.distance_to(_sa()) < 150.0:
			continue
		# (and off star B, with two suns)
		if view.star2 != null and p.distance_to(view.star_screen(SystemLayout.STAR_B)) < 150.0:
			continue
		var sp := _neb_sp(p)
		var d := dk_d(sp)
		if absf(d - 0.5) >= 0.1:
			continue
		var e := 4.0
		var g := Vector2(dk_d(sp + Vector2(e, 0)) - dk_d(sp - Vector2(e, 0)), dk_d(sp + Vector2(0, e)) - dk_d(sp - Vector2(0, e)))
		if g.length() < 1e-5:
			continue
		var dir := -g.normalized()
		# the cone's length clear of the labels
		var tip := p + dir * 90.0
		var ok := _in_view(tip, 0.0)
		for r: Rect2 in _labels():
			if r.size.x > 0.0 and (r.has_point(tip) or r.has_point(p + dir * 45.0)):
				ok = false
		if not ok:
			continue
		ev.at = sp
		ev.dir = dir
		return true
	return false


func _p_microlens(ev: Dictionary) -> bool:
	var ship := _ship()
	for fi in [1, 2]:
		var f = view._fields[fi]
		var ids: Array = range(f._stars.size())
		ids.shuffle()
		for i: int in ids:
			var s: Array = f._stars[i]
			if float(s[2]) > 0.35 or s[4]:
				continue
			var p: Vector2 = f.star_at(i)
			if not _in_view(p, 30.0) or p.distance_to(ship) < 60.0 or not clear_at(p, 60.0):
				continue
			ev.field = fi
			ev.star = i
			ev.u0 = _rng.randf_range(0.3, 0.6)
			return true
	return false


func _p_comet(ev: Dictionary) -> bool:
	var L: SystemLayout = view.layout
	# (a real comet passing here takes the sky: never two at once)
	if L.comet != null:
		return false
	var inner := INF
	# Perihelion uses the inner orbit round A; a close pair
	# uses one round both, so it passes outside the pair.
	# Why: docs/why/SkyWeather.md#comet-orbit
	for b in L.bodies:
		if b.kind != &"belt" and (b.host_id == -1 or L.close):
			inner = minf(inner, b.orbit)
	if inner == INF:
		inner = L.star_r * 6.0
	var q := inner * _rng.randf_range(0.6, 1.2)
	var re := L.edge
	var De := sqrt(maxf(re / q - 1.0, 0.1))
	var T := _rng.randf_range(60.0, 80.0)
	ev.q = q
	ev.w = _rng.randf() * TAU
	ev.K = T / (De + De * De * De / 3.0)
	ev.tp = T / 2.0
	ev.end = T
	ev.mode = &"comet"
	return true


func _p_sungrazer(ev: Dictionary) -> bool:
	var L: SystemLayout = view.layout
	if not _in_view(_sa(), 40.0):
		return false
	# (at the opening zoom the star is a few blocks across and the whole dive a
	# speck nobody sees: the slot goes to an event that shows)
	if L.star_r * view.star_k() < 14.0:
		return false
	var R0 := L.star_r
	var sk: float = view.star_k() / maxf(view.zoom, 0.01)
	for _try in 12:
		var q := R0 * _rng.randf_range(0.6, 0.9)
		var w := _rng.randf_range(-PI * 0.85, -PI * 0.15)
		var T := _rng.randf_range(10.0, 14.0)
		var D5 := sqrt(5.0 * R0 / q - 1.0)
		ev.q = q
		ev.w = w
		ev.K = 2.0 * T / (D5 + D5 * D5 * D5 / 3.0)
		ev.tp = T
		ev.mode = &"sungrazer"
		ev.breakup = _rng.randf() < 0.25
		# where it meets the disc on screen, it must be behind the star
		var ok := true
		for k in 200:
			var a := T * float(k) / 200.0
			var p := Comet.comet_pos(ev, a)
			if Vector2(p.x, p.y * view.TILT).length() < R0 * sk * 1.02:
				ok = p.y < 0.0
				break
		if ok:
			ev.end = T + 1.0
			if bool(ev.breakup):
				# it breaks up at 2.5 star radii, and fades over three seconds
				for k in 400:
					var a2 := T * float(k) / 400.0
					if Comet.comet_pos(ev, a2).length() <= 2.5 * R0:
						ev.break_age = a2
						ev.end = a2 + 3.0
						break
			return true
	return false


func _p_starmood(ev: Dictionary) -> bool:
	if star_kind == SystemLayout.StarKind.RED:
		ev.end = 26.0
		ev.dir = Vector2.DOWN.rotated(_rng.randf_range(-PI / 3.0, PI / 3.0))
		ev.mode = &"red"
		return view.star != null and _in_view(_sa(), -40.0)
	if star_kind == SystemLayout.StarKind.BLUE:
		ev.end = 30.0
		ev.mode = &"blue"
		ev.seed = _rng.randf() * 40.0
		return view.star != null and _in_view(_sa(), -60.0)
	return false


func _p_globule(ev: Dictionary) -> bool:
	if float(view._sky_look.get("band", 0.0)) <= 0.0:
		return false
	var bd := band_dir()
	var w: Rect2 = view.window
	var so: Vector2 = view.sky_off()
	ev.end = _rng.randf_range(40.0, 60.0)
	ev.size = _rng.randf_range(22.0, 34.0)
	for _i in 24:
		# a point on the band in view, and a slow drift along it or across at a shallow angle
		var s := _rng.randf_range(-400.0, 400.0)
		var start := Vector2(480, 270) + bd * s + Vector2(-bd.y, bd.x) * _rng.randf_range(-30.0, 30.0)
		var dir := bd.rotated(_rng.randf_range(-0.35, 0.35)) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var mid := start + dir * 3.0 * float(ev.end) * 0.5
		if w.grow(-40.0).has_point(start + so) and w.grow(-40.0).has_point(mid + so):
			ev.at = start
			ev.dir = dir
			ev.seed = _rng.randf() * 30.0
			return true
	return false


## It was placed at a random angle with no keep-out: filmed under the ship, now in the darker shell.
## Why: docs/why/SkyWeather.md#pulsar-knot
func _p_fog(ev: Dictionary) -> bool:
	ev.seed = _rng.randf() * 30.0
	if not _in_view(_sa(), -100.0):
		return false
	var sk := float(view.zoom) / maxf(float(view.home_zoom), 0.01)
	for _i in 24:
		var a := _rng.randf() * TAU
		var d := Vector2(cos(a), sin(a)) * _rng.randf_range(70.0, 130.0)
		var p: Vector2 = _sa() + d * sk
		if _in_view(p, 40.0) and clear_at(p, SHIP_R[M], 20.0):
			ev.dir = d
			return true
	return false


## the pulsar's beat clock: where its sound is
func _beat_t() -> float:
	return float(view.t) + float(view._beat_off)


func _p_pulse(ev: Dictionary) -> bool:
	if view.star == null:
		return false
	var tb := _beat_t() - PulsarViewS.PEAK_S - PulsarViewS.OFF_S
	var n := roundi(tb) + 3
	ev.n = n
	ev.end = float(n) + 0.7 - tb
	return _in_view(_sa(), -60.0)


func _p_magnetar(ev: Dictionary) -> bool:
	if view.star == null:
		return false
	var tb := _beat_t() - PulsarViewS.PEAK_S - PulsarViewS.OFF_S
	var nb := ceilf(tb + 0.15)
	ev.pre = nb - tb
	ev.t0 = _beat_t() + float(ev.pre)
	return _in_view(_sa(), -60.0)


func _p_ringflash(ev: Dictionary) -> bool:
	if view.star == null or not view.star.has_method("next_plunge"):
		return false
	var np: Vector2 = view.star.call("next_plunge", float(view.t), 0.6, 6.0)
	if np.x < 0.0:
		return false
	ev.pre = np.x
	ev.dir = Vector2(cos(np.y), sin(np.y))
	ev.seed = np.y
	return true


func _p_einstein(ev: Dictionary) -> bool:
	if view._nova == null or view._nova.busy_within(20.0):
		return false
	# a supernova just behind the hole: the lens bends it into a ring by itself
	ev.at = _sa() + _unit() * _rng.randf_range(8.0, 20.0)
	view.nova_now(ev.at)
	return true


func _p_lensstar(ev: Dictionary) -> bool:
	if not _in_view(_sa(), -40.0):
		return false
	ev.dir = _unit()
	ev.speed = _rng.randf_range(8.0, 12.0)
	ev.b = _rng.randf_range(0.0, 6.0) if _rng.randf() < 0.5 else _rng.randf_range(10.0, 25.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
	ev.c = _sa() - view.sky_off()
	return true


## Where a belt's arc is in view: [body, angle] for clear points along each.
func _belt_spots() -> Array:
	var out: Array = []
	if view == null or view.layout == null:
		return out
	var ship := _ship()
	for b in view.layout.bodies:
		if b.kind != &"belt":
			continue
		for k in 48:
			var a := float(k) / 48.0 * TAU
			var p: Vector2 = view.screen(b.host_at(float(view.t)).x + cos(a) * b.orbit, b.host_at(float(view.t)).y + sin(a) * b.orbit)
			if _in_view(p, 24.0) and p.distance_to(ship) >= 80.0 and clear_at(p, 80.0, -20.0):
				out.append([b.index, a])
	return out


func _p_collision(ev: Dictionary) -> bool:
	var sp := _belt_spots()
	if sp.is_empty():
		return false
	var pick: Array = sp[_rng.randi() % sp.size()]
	var b: SystemLayout.Body = view.layout.bodies[int(pick[0])]
	ev.body = b.index
	ev.a0 = float(pick[1]) - float(view.t) / b.period * TAU
	ev.r0 = b.orbit + _rng.randf_range(-10.0, 10.0)
	ev.vt0 = float(view.t)
	var parts: Array = []
	for i in _rng.randi_range(30, 44):
		parts.append([_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0), i % 3 == 0, _rng.randf_range(14.0, 34.0), _rng.randf()])
	ev.parts = parts
	return true


func _p_gwave(ev: Dictionary) -> bool:
	ev.dir = _unit()
	ev.end = 3.4 + 2.0 * view.layout.edge / 160.0
	return true


# ---------------------------------------------------------------- apply: each frame

func _apply(ev: Dictionary) -> void:
	# PAINTED: the event drawn as hand animation, its age held in poses (8 a
	# second) so it steps from drawing to drawing and holds each, never a strobe
	if view != null and bool(view.get("painted")):
		var real: float = float(ev.age)
		ev.age = view.pose(real)
		_apply_layer(ev)
		ev.age = real
	else:
		_apply_layer(ev)


func _apply_layer(ev: Dictionary) -> void:
	match StringName(ev.layer):
		&"neb":
			_apply_neb(ev)
		&"sky":
			_apply_sky(ev)
		&"field":
			_apply_field(ev)
		&"node":
			_apply_node(ev)
		&"star":
			_apply_star(ev)
		&"pulsar":
			_apply_pulsar(ev)
		&"core":
			_apply_core(ev)
		&"drift":
			_apply_drift(ev)
		&"fabric":
			_apply_fabric(ev)
		&"depth":
			_apply_bow(ev)


func _clear(ev: Dictionary) -> void:
	match StringName(ev.layer):
		&"neb":
			if view._neb_mat != null:
				view._neb_mat.set_shader_parameter("w_k" if int(ev.slot) == 0 else "s_k", 0.0)
			if StringName(ev.name) == &"nearstrike" and screen != null and screen.overlay != null:
				screen.overlay.catch_light = {}
			if view._points != null and not (view._points.pts as Array).is_empty():
				view._points.pts = []
				view._points.queue_redraw()
		&"sky":
			view._sky_mat.set_shader_parameter("e_k", 0.0)
			view._sky_mat.set_shader_parameter("e_ev", 0)
			if StringName(ev.name) == &"globule":
				view._fields[0].hide = Vector3(-9999, -9999, 0)
			if StringName(ev.name) == &"flareecho" and view.star != null:
				view.star.set("breath_add", 0.0)
			if StringName(ev.name) == &"flareecho" and view._neb_mat != null:
				view._neb_mat.set_shader_parameter("e_k", 0.0)
		&"field":
			view._fields[int(ev.field)].lens = {}
		&"node":
			if StringName(ev.name) == &"collision":
				view._puff.ev = {}
				view._puff.queue_redraw()
			else:
				view._comet.ev = {}
				view._comet.queue_redraw()
		&"star":
			_clear_star()
			view._sky_mat.set_shader_parameter("e_k", 0.0)
		&"pulsar":
			_clear_pulsar()
			view._sky_mat.set_shader_parameter("e_k", 0.0)
			view._sky_mat.set_shader_parameter("e_ev", 0)
		&"core":
			if view.star != null:
				var hm: ShaderMaterial = view.star.get("_hmat")
				hm.set_shader_parameter("hs", Vector4.ZERO)
				hm.set_shader_parameter("rf", Vector2(0.0, -1.0))
		&"drift":
			view._drift.ev = {}
			view._drift.queue_redraw()
		&"fabric":
			view._fabric._mat.set_shader_parameter("gw", Vector4.ZERO)
		&"depth":
			for e: Array in view._depth:
				(e[0] as ShaderMaterial).set_shader_parameter("ev", Vector4(-9999, -9999, 0, 0))


## Sent only when the ship moved and something is live: a uniform every frame was most of the cost.
var _g_sent := Vector2.INF


func _guard() -> void:
	if _cleared:
		return
	var s := _ship()
	if s == _g_sent:
		return
	_g_sent = s
	var g := Vector4(s.x, s.y, 30.0, 90.0)
	if view._neb_mat != null:
		view._neb_mat.set_shader_parameter("g_ship", g)
	view._sky_mat.set_shader_parameter("g_ship", g)


func _apply_neb(ev: Dictionary) -> void:
	var m: ShaderMaterial = view._neb_mat
	if m == null:
		return
	var nm := StringName(ev.name)
	# what does not change over an event is sent once, its age every frame
	var first := not ev.has("sent")
	ev.sent = true
	if int(ev.slot) == 0:
		m.set_shader_parameter("w_age", float(ev.age))
		if first:
			m.set_shader_parameter("w_ev", int(EV[nm]))
			m.set_shader_parameter("w_at", ev.at)
			m.set_shader_parameter("w_k", float(ev.k))
			m.set_shader_parameter("w_dir", ev.dir)
			m.set_shader_parameter("w_seed", float(ev.seed))
			m.set_shader_parameter("w_size", float(ev.size))
			m.set_shader_parameter("w_pre", float(ev.pre))
			m.set_shader_parameter("w_up", up)
			var pts: PackedVector4Array = ev.pts
			if pts.size() < 6:
				pts.resize(6)
			m.set_shader_parameter("w_pts", pts)
			m.set_shader_parameter("w_n", int(ev.n))
		if nm == &"nearstrike" and screen != null and screen.overlay != null:
			# THE HULL CATCHES IT: the edge facing the flash, for 0.3 s
			var a := float(ev.age)
			var f := sm(0.0, 0.05, a) * (1.0 - sm(0.1, 0.3, a))
			var lc := LC_EMISSION if sky == &"emission" else LC_DARK
			screen.overlay.catch_light = {"at": _neb_scr(ev.at), "col": lc, "f": f} if f > 0.0 else {}
		if nm == &"newstar" or nm == &"pearls" or nm == &"fan":
			_push_points(ev)
	else:
		m.set_shader_parameter("s_age", float(ev.age))
		if first:
			m.set_shader_parameter("s_ev", int(EV[nm]))
			m.set_shader_parameter("s_at", ev.at)
			m.set_shader_parameter("s_k", float(ev.k))
			m.set_shader_parameter("s_dir", ev.dir)
			m.set_shader_parameter("s_seed", float(ev.seed))


## The new star's hot points, worked out as the cloud's shader does, at the cloud's parallax.
func _push_points(ev: Dictionary) -> void:
	if view._points == null:
		return
	var a := float(ev.age)
	var k := float(ev.k)
	var at: Vector2 = _neb_scr(ev.at)
	var out: Array = []
	match StringName(ev.name):
		&"newstar":
			# the star blinks on over a second and a half and holds
			var st := env(a, 1.5, 16.5, 4.0) * k
			if st > 0.0:
				out.append([at, Color(0.86, 0.93, 1.0, st), 0.4 * sm(0.3, 1.0, st)])
		&"fan":
			# the hidden star at the fan's apex, brightening with it
			var e := env(a, 4.0, 14.0, 8.0) * k
			if e > 0.0:
				out.append([at, Color(1.0, 0.66, 0.4, 0.9 * e), 0.0])
		&"pearls":
			# the eighteen beads, each lighting in its turn (the shader's own times)
			var d: Vector2 = ev.dir
			var perp := Vector2(-d.y, d.x)
			var fade := 1.0 - sm(14.0, 20.0, a)
			for j in 18:
				var A := TAU * float(j) / 18.0 + (nhash(float(j), float(ev.seed) * 50.0) - 0.5) * 0.2
				var tj := 1.0 + 8.0 * nhash(float(j), float(ev.seed) * 50.0 + 1.0)
				var b := sm(tj, tj + 0.6, a) * fade * k
				if b <= 0.0:
					continue
				var q := Vector2(45.0 * cos(A), 31.5 * sin(A))
				out.append([at + d * q.x + perp * q.y, Color(1.0, 0.8, 0.82, 0.85 * b), 0.0])
	view._points.pts = out
	view._points.queue_redraw()


func _apply_sky(ev: Dictionary) -> void:
	var m: ShaderMaterial = view._sky_mat
	var nm := StringName(ev.name)
	var a := float(ev.age)
	m.set_shader_parameter("e_ev", int(SKY_EV[nm]))
	m.set_shader_parameter("e_age", a)
	m.set_shader_parameter("e_seed", float(ev.seed))
	match nm:
		&"globule":
			var c: Vector2 = Vector2(ev.at) + Vector2(ev.dir) * 3.0 * a
			var k := sm(0.0, 5.0, a) * (1.0 - sm(float(ev.end) - 5.0, float(ev.end), a))
			m.set_shader_parameter("e_at", c)
			m.set_shader_parameter("e_r", float(ev.size))
			m.set_shader_parameter("e_k", k)
			view._fields[0].hide = Vector3(c.x + view.sky_off().x, c.y + view.sky_off().y, float(ev.size) * 0.85 if k > 0.3 else 0.0)
		&"fog":
			var bs := Vector2(view.CX, view.CY) + Vector2.ONE * float(SkyBakeS.M) - Vector2(0.5, 0.5)
			m.set_shader_parameter("e_at", bs + Vector2(ev.dir))
			m.set_shader_parameter("e_k", env(a, 3.0, 14.0, 3.0))
		&"flareecho":
			m.set_shader_parameter("e_at", ev.at)
			m.set_shader_parameter("e_r", 40.0 + 25.0 * maxf(a, 0.0))
			m.set_shader_parameter("e_k", env(a, 1.5, 18.0, 10.0))
			# (SIMPLIFIED: the core's gas is its cloud, which lights the ring as it passes)
			if view._neb_mat != null:
				view._neb_mat.set_shader_parameter("e_r", 40.0 + 25.0 * maxf(a, 0.0))
				view._neb_mat.set_shader_parameter("e_k", env(a, 1.5, 18.0, 10.0))
			if view.star != null:
				var br := 0.6 * (sm(0.0, 1.5, a) if a < 1.5 else exp(-(a - 1.5) / 0.6))
				view.star.set("breath_add", br)


func _apply_field(ev: Dictionary) -> void:
	var a := float(ev.age)
	var u := sqrt(pow(float(ev.u0), 2.0) + pow((a - 5.0) / 2.5, 2.0))
	var A := (u * u + 2.0) / (u * sqrt(u * u + 4.0))
	# rises and falls once: the curve's tails eased to nothing at the ends
	A = 1.0 + (A - 1.0) * sm(0.0, 1.0, a) * (1.0 - sm(9.0, 10.0, a))
	view._fields[int(ev.field)].lens = {"i": int(ev.star), "A": A}


func _apply_node(ev: Dictionary) -> void:
	if StringName(ev.name) == &"collision":
		view._puff.ev = ev
		view._puff.queue_redraw()
	else:
		view._comet.ev = ev
		view._comet.queue_redraw()


func _apply_star(ev: Dictionary) -> void:
	if view.star == null:
		return
	var a := float(ev.age)
	var mat: ShaderMaterial = view.star.get("_mat")
	var P: Dictionary = view.star.get("P")
	if StringName(ev.mode) == &"red":
		# THE GREAT DIMMING: dust gathers off one side over 6 s, holds, clears over 14
		var k := env(a, 6.0, 6.0, 14.0)
		var spread := 0.35 + 0.5 * sm(0.0, 8.0, a)
		mat.set_shader_parameter("dim", Vector4(k, atan2(ev.dir.y, ev.dir.x), spread, float(ev.seed) * 10.0))
		mat.set_shader_parameter("glow_i", float(P.glow_i) * (1.0 - 0.35 * k))
	else:
		# AN ERUPTION SHELL: a thin round shell lifts off and spreads through the inner system
		var sr: float = view.layout.star_r * view.star_k()
		var m: ShaderMaterial = view._sky_mat
		m.set_shader_parameter("e_ev", 1)
		m.set_shader_parameter("e_age", a)
		m.set_shader_parameter("e_r", sr + 6.0 * a * view.zoom)
		m.set_shader_parameter("e_rmax", sr + 6.0 * float(ev.end) * view.zoom)
		m.set_shader_parameter("e_k", env(a, 2.0, 14.0, 14.0))
		m.set_shader_parameter("e_seed", float(ev.seed))
		mat.set_shader_parameter("glow_i", float(P.glow_i) * (1.0 + 0.3 * env(a, 1.0, 2.0, 3.0)))


func _clear_star() -> void:
	if view.star == null:
		return
	var mat: ShaderMaterial = view.star.get("_mat")
	var P: Dictionary = view.star.get("P")
	if mat != null and not P.is_empty():
		mat.set_shader_parameter("dim", Vector4.ZERO)
		mat.set_shader_parameter("glow_i", float(P.glow_i))


func _apply_pulsar(ev: Dictionary) -> void:
	var st = view.star
	if st == null:
		return
	var mat: ShaderMaterial = st.get("_mat")
	var a := float(ev.age)
	# the ship in the pulsar's box: its corner is the pulsar's place, rounded, less half the box
	var half := Vector2(st.get("_half"))
	mat.set_shader_parameter("g_ship", _ship() - ((st.position as Vector2).round() - half))
	match StringName(ev.name):
		&"wisps":
			mat.set_shader_parameter("wisp_age", a)
			mat.set_shader_parameter("wisp_k", 1.0)
		&"firehose":
			mat.set_shader_parameter("hose_age", a)
			mat.set_shader_parameter("hose_k", 1.0)
			mat.set_shader_parameter("jets_fade", 1.0 - env(a, 2.0, 7.0, 3.0))
		&"pulse":
			st.set("giant_n", int(ev.n))
		&"magnetar":
			st.set("mag_t0", float(ev.t0))
			st.set("mag_k", 1.0)
			# three rings racing out through the remnant gas (`sky.gdshader`)
			var m: ShaderMaterial = view._sky_mat
			m.set_shader_parameter("e_ev", 4)
			m.set_shader_parameter("e_age", maxf(a, 0.0))
			m.set_shader_parameter("e_k", env(a, 0.1, 6.0, 14.0) * (1.0 if a >= 0.0 else 0.0))


func _clear_pulsar() -> void:
	var st = view.star
	if st == null or not (st is PulsarViewS):
		return
	var mat: ShaderMaterial = st.get("_mat")
	mat.set_shader_parameter("wisp_k", 0.0)
	mat.set_shader_parameter("hose_k", 0.0)
	mat.set_shader_parameter("jets_fade", 1.0)
	mat.set_shader_parameter("mag_k", 0.0)
	st.set("giant_n", -999999)
	st.set("mag_k", 0.0)


func _apply_core(ev: Dictionary) -> void:
	var st = view.star
	if st == null:
		return
	var hm: ShaderMaterial = st.get("_hmat")
	var a := float(ev.age)
	var kt: float = float(st.get("drawn_zoom"))
	const RIN := 15.0 * 1.16
	if StringName(ev.name) == &"hotspot":
		# A clump rides where the disc is still orange: just
		# outside the shadow the whitest colour shows nothing.
		var u := clampf(a / float(ev.end), 0.0, 1.0)
		var rr := lerpf(3.0, 2.2, u)
		if not ev.has("ang"):
			ev.ang = _rng.randf() * TAU
			ev.last = a
		var da := a - float(ev.last)
		ev.last = a
		ev.ang = fposmod(float(ev.ang) + 1.1 * pow(rr, -1.5) * da, TAU)
		hm.set_shader_parameter("hs", Vector4(rr * RIN * kt, float(ev.ang), env(a, 1.5, 10.5, 2.0), 0.0))
	else:
		hm.set_shader_parameter("rf", Vector2(float(ev.seed), a))


func _apply_drift(ev: Dictionary) -> void:
	view._drift.ev = ev
	view._drift.queue_redraw()


func _apply_fabric(ev: Dictionary) -> void:
	var E: float = view.layout.edge
	view._fabric._mat.set_shader_parameter("gw", Vector4(ev.dir.x, ev.dir.y, float(ev.age) - E / 160.0, 1.2))


# ---------------------------------------------------------------- the bowshock

func _step_bow(dt: float) -> void:
	if _bow_at > 0.0 and float(view.t) >= _bow_at:
		_bow_at = -1.0
		_start_bow()
	if _bow.is_empty():
		return
	_bow.age = float(PEAK.bowshock) if hold else float(_bow.age) + dt
	if float(_bow.age) > 2.5:
		_clear(_bow)
		_bow = {}
	else:
		_apply_bow(_bow)


func _start_bow() -> void:
	if view == null or view._depth.is_empty():
		return
	_bow = {"name": &"bowshock", "tier": R, "layer": &"depth", "slot": 2, "age": 0.0, "pre": 0.0, "end": 2.5, "at": _ship()}
	var col := Vector3(0.55, 0.62, 0.8)
	if view._neb_mat != null:
		var hue: Vector3 = view._sky_look.hue
		var p1: Vector3 = view._sky_look.pal[1]
		col = hue.lerp(p1, 0.5)
		if neb == NebulaField.Kind.DARK:
			col = Vector3(0.55, 0.5, 0.75)
	_bow.col = col
	_cleared = false
	if log_on:
		log_starts.append([_visit, &"bowshock", 2, R, 2.5, _clock_a])


func _apply_bow(ev: Dictionary) -> void:
	var a := float(ev.age)
	var s := _ship()
	var e := Vector4(s.x, s.y, (16.0 + 19.0 * a) * maxf(float(view.zoom), 1.0), pow(maxf(0.0, 1.0 - a / 2.5), 2.0) * sm(0.0, 0.12, a))
	for d: Array in view._depth:
		if int(d[2]) < 0:
			var mm: ShaderMaterial = d[0]
			mm.set_shader_parameter("ev", e)
			mm.set_shader_parameter("ev_col", ev.col)


# ---------------------------------------------------------------- the in-system pictures

## Drawn in 2x2 blocks with 2 degree tail steps, so nothing between moves by part of a block.
## Why: docs/why/SkyWeather.md#comet-drawing
class Comet extends Node2D:
	var view
	var ev: Dictionary = {}

	## A parabola about star A (Barker's equation); with
	## two suns it rides the balance point (ruling 23).
	static func comet_pos(e: Dictionary, age: float) -> Vector2:
		return CometPath.barker(float(e.q), float(e.w), float(e.K), float(e.tp), age)

	## Star A at map time: the origin with one sun, so a lone sun's comet is drawn as it always was.
	func a_at(tt: float) -> Vector2:
		return view.layout.star_pos(-1, tt)

	func _blk(p: Vector2, c: Color) -> void:
		draw_rect(Rect2((p / 2.0).floor() * 2.0, Vector2(2, 2)), c)

	## a block on the screen's own checker (not one laid from the head: moved a
	## block, a checker laid from the head flips every block round it)
	static func _on_checker(p: Vector2) -> bool:
		var q := (p / 2.0).floor()
		return (int(q.x) + int(q.y)) % 2 == 0

	func _draw() -> void:
		if ev.is_empty() or view == null:
			return
		var a := float(ev.age)
		if a < 0.0:
			return
		var grazer := StringName(ev.mode) == &"sungrazer"
		var R0: float = view.layout.star_r
		# (round star A where it is drawn now: the pair turns)
		var o: Vector2 = view.star_screen(-1)
		var z: float = view.zoom
		var vt := float(view.t)
		var sa := a_at(vt)
		# (in star A's frame, `p`; on the plane, `pw`)
		var p := comet_pos(ev, a)
		var pw := p + sa
		var hs: Vector2 = view.block_round(view.screen(pw.x, pw.y))
		var r := p.length()
		var q := float(ev.q)
		var A := clampf(pow(2.5 * q / maxf(r, 1.0), 2.0), 0.0, 1.0)
		if grazer:
			A = clampf(pow(5.0 * R0 / maxf(r, 1.0), 1.5) * 0.6, 0.0, 1.0)
		# the comet comes in and goes out over its first and last five seconds
		var fade := 1.0
		if not grazer:
			fade = clampf(a / 5.0, 0.0, 1.0) * clampf((float(ev.end) - a) / 5.0, 0.0, 1.0)
		# THE SUNGRAZER ENDS: into the star (a warm puff at the limb), or broken up
		var sr: float = view.layout.star_r * view.star_k()
		if grazer:
			if ev.has("plunged"):
				var pa := a - float(ev.plunged)
				if pa > 0.6:
					return
				var lp: Vector2 = ev.limb
				var c := Color("#ffdc96").lerp(Color("#ec7a26"), pa / 0.6)
				var k := 1.0 - pa / 0.6
				_blk(lp, Color(c, 0.9 * k))
				var tang := (lp - o).normalized().orthogonal()
				_blk(lp + tang * 2.0, Color(c, 0.6 * k))
				_blk(lp - tang * 2.0, Color(c, 0.6 * k))
				return
			if hs.distance_to(o) < sr * 1.02:
				ev.plunged = a
				ev.limb = view.block_round(o + (hs - o).normalized() * sr * 1.04)
				ev.end = a + 0.6
				return
			if ev.has("break_age") and a >= float(ev.break_age):
				var ba := a - float(ev.break_age)
				var bp: Vector2 = ev.get("break_at", hs)
				if not ev.has("break_at"):
					ev.break_at = hs
					bp = hs
				var k2 := clampf(1.0 - ba / 3.0, 0.0, 1.0)
				for bx in range(-2, 3):
					for by in range(-2, 3):
						var qb := bp + Vector2(bx, by) * 2.0 + ((bp - o).normalized() * ba * 2.0).round()
						if not _on_checker(qb):
							continue
						var dd := Vector2(bx, by).length() / 2.6
						_blk(qb, Color(Color("#e6f6ff"), 0.4 * k2 * (1.0 - dd)))
				return
		# Tails point away from where the head truly is, not
		# its block, or they flicked between 2 degree steps.
		# Why: docs/why/SkyWeather.md#comet-tails
		var away: Vector2 = view.screen(pw.x, pw.y) - view.screen(sa.x, sa.y)
		# Two suns: away from the merged light (`SystemView.toward_light`),
		# as a comet passing B trailed across B.
		var twin: bool = view.layout.twin
		if twin:
			var lu: Vector2 = view.toward_light(pw)
			var tl: float = view.TILT
			away = -Vector2(lu.x, lu.y * tl)
		if away.length() < (1e-3 if twin else 0.5):
			away = Vector2.RIGHT
		var ang := atan2(away.y, away.x)
		ang = roundf(ang / deg_to_rad(2.0)) * deg_to_rad(2.0)
		var ad := Vector2(cos(ang), sin(ang))
		var cap := 30.0 * z if grazer else 1e9
		# (at least as long as at the zoom it opens at, or it is a speck)
		var zt := maxf(z, 0.9)
		# ion tail: straight, blue, thin
		var n_ion := int(minf((16.0 + 14.0 * A) * A * zt, cap / 2.0))
		var ion_cols := [Color("#c8f0ff"), Color("#8ad0f0"), Color("#4a8ad8"), Color("#2a5ab8")]
		for k3 in range(1, n_ion + 1):
			var step := int(floor(float(k3 - 1) / maxf(1.0, float(n_ion) / 4.0)))
			if step > 3:
				break
			_blk(hs + ad * 2.0 * float(k3), Color(ion_cols[step], 0.5 * fade))
		# dust tail: the syndyne, where the dust it shed is now
		var dust_cols := [Color("#ffdc96"), Color("#ffb054"), Color("#84280c")]
		var beta := 1.3 * A * zt / maxf(z, 0.05)
		var last := Vector2.INF
		var head_a := atan2(p.y, p.x)
		for j in range(1, 13):
			var tau := 0.5 * float(j)
			if a - tau < 0.0:
				break
			var pj := comet_pos(ev, a - tau)
			# (round the star the path behind it curls back on itself: the tail
			# stops where it would wrap)
			if absf(wrapf(atan2(pj.y, pj.x) - head_a, -PI, PI)) > 0.7:
				break
			# (the dust shed tau ago, where star A was then: on the plane it stays
			# where it was shed while the sun moves on)
			pj += a_at(vt - tau)
			# (pushed away from the light: star A with one sun, both suns' with two)
			var push: Vector2 = -(view.toward_light(pj) as Vector2) if twin else pj.normalized()
			pj += push * beta * tau * tau
			var sj: Vector2 = view.screen(pj.x, pj.y)
			if sj.distance_to(hs) > cap:
				break
			if last != Vector2.INF and sj.distance_to(last) < 2.0:
				continue
			last = sj
			var col: Color = dust_cols[mini(2, (j - 1) / 4)]
			var al := 0.5 * A * fade * (1.0 - float(j) / 14.0)
			_blk(sj, Color(col, al))
			if j > 6:
				_blk(sj + ad.orthogonal() * 2.0, Color(col, al * 0.7))
		# the coma, a soft plus growing to a dithered disc, and the head
		if A > 0.15:
			for bx in range(-2, 3):
				for by in range(-2, 3):
					var dd := Vector2(bx, by).length()
					if dd < 0.5 or dd > 2.3 or (dd > 1.2 and (not _on_checker(hs + Vector2(bx, by) * 2.0) or A < 0.5)):
						continue
					_blk(hs + Vector2(bx, by) * 2.0, Color(Color("#e6f6ff"), (0.55 if dd < 1.2 else 0.3) * A * fade))
		_blk(hs, Color(Color("#fff6e2") if A > 0.3 else Color("#c9d8ea"), 0.9 * fade))


## The comet you can fly to (`CometPath`): the weather comet's drawing, its path
## ahead dotted on the plane, and in RADIANT its coma lit as light.
## Why: docs/why/SkyWeather.md#real-comet
class RealComet extends Comet:
	## Path dots every this many screen px, in blocks, so it reads as no world's ring.
	const DOT_PX := 7.0
	const PATH_C := Color("#8ad0f0")
	const PATH_A := 0.3
	## Bigger and brighter than the weather's (Jon, Nov 9, "K3"): a thing to go after.
	## Why: docs/why/SkyWeather.md#real-comet-look
	const ION := [Color("#e6f8ff"), Color("#a8e0ff"), Color("#5aa8f0"), Color("#2c64c8")]
	const DUST := [Color("#fff0c0"), Color("#ffd070"), Color("#f0a030"), Color("#b86018"), Color("#6a2c0c")]
	## Its parts at size k = 1, in 2x2 blocks: the ion tail's length, the dust tail's, the coma's radius.
	const ION_N := 28.0
	const DUST_N := 36.0
	const COMA_R := 4.0
	## How hard the dust tail bends off the away line (blocks per block squared).
	const BEND := 0.012
	## How far off the away line the dust tail leaves (about 14 degrees toward its trailing side).
	const DUST_OFF := 0.25

	## At the view's clock; PAINTED holds its age in poses, as the weather's. Reduced motion
	## keeps it: it is a place, not weather.
	## Frames since the palette was cut: it shows only after, so its gold never enters the cut.
	## Why: docs/why/SkyWeather.md#real-comet-and-the-palette
	var _since_pal := 0
	const PAL_WAIT := 4

	func _process(_d: float) -> void:
		_since_pal = _since_pal + 1 if view != null and bool(view._palette_built) else 0
		visible = _since_pal > PAL_WAIT
		var c: CometPath = view.layout.comet if view != null and view.layout != null else null
		if c == null:
			if not ev.is_empty():
				ev = {}
				queue_redraw()
			return
		if ev.is_empty():
			ev = c.ev()
		ev.age = view.pose(c.age(float(view.t)))
		queue_redraw()

	func _draw() -> void:
		if ev.is_empty() or view == null:
			return
		var a := float(ev.age)
		if a > float(ev.end):
			return
		_path(maxf(a, 0.0))
		if a < 0.0:
			return
		var sa: Vector2 = a_at(float(view.t))
		var p := comet_pos(ev, a)
		var pw := p + sa
		var hs: Vector2 = view.block_round(view.screen(pw.x, pw.y))
		# away from the light: star A with one sun, both suns' with two
		var away: Vector2 = view.screen(pw.x, pw.y) - view.screen(sa.x, sa.y)
		if view.layout.twin:
			var lu: Vector2 = view.toward_light(pw)
			away = -Vector2(lu.x, lu.y * float(view.TILT))
		var ad := away.normalized() if away.length() > 1e-3 else Vector2.RIGHT
		# the dust trails behind its motion
		var pn := comet_pos(ev, a + 0.5) + sa
		var side := trailing_side(ad, view.screen(pn.x, pn.y) - view.screen(pw.x, pw.y))
		var A := clampf(pow(2.5 * float(ev.q) / maxf(p.length(), 1.0), 2.0), 0.0, 1.0)
		var fade := clampf(a / 5.0, 0.0, 1.0) * clampf((float(ev.end) - a) / 5.0, 0.0, 1.0)
		# (bigger near the star and when zoomed in, never below its floor's size)
		var k := lerpf(0.75, 1.0, maxf(A, float(ev.get("a_min", 0.0)))) * clampf(float(view.zoom), 0.9, 1.5)
		paint(self, hs, ad, side, k, fade, bool(view.get("radiant")))

	## The side of the away line the dust lies on: away from where the head is going.
	static func trailing_side(ad: Vector2, going: Vector2) -> Vector2:
		var side := ad.orthogonal()
		return -side if side.dot(going) > 0.0 else side

	## THE LOOK, shared with LOCAL's band (`LocalComet`): a long gold dust tail bending off
	## the away line, a straight blue ion tail, a dithered coma and a white head, in 2x2 blocks.
	## RADIANT adds a wider halo. Each block is laid once, so nothing doubles up.
	static func paint(ci: CanvasItem, hs: Vector2, ad: Vector2, side: Vector2, k: float, fade: float, radiant: bool) -> void:
		var laid := {}
		var n_ion := int(round(ION_N * k))
		for i in range(1, n_ion + 1):
			var f2 := float(i) / float(n_ion)
			var q2 := hs + ad * 2.0 * float(i)
			if f2 > 0.6 and not _on_checker(q2):
				continue
			_lay(ci, laid, q2, Color(ION[mini(3, int(f2 * 4.0))], 0.9 * (1.0 - f2 * 0.6) * fade))
		# (the dust leaves a little off the away line, so the blue tail shows beside it)
		var dd := (ad + side * DUST_OFF).normalized()
		var n_dust := int(round(DUST_N * k))
		for i in range(2, 2 * n_dust + 1):
			var u := float(i) * 0.5
			var f := u / float(n_dust)
			var c := hs + dd * 2.0 * u * 0.85 + side * 2.0 * BEND * u * u
			var w := int(f * 3.0 * k)
			for j in range(-w, w + 1):
				var q := c + side * 2.0 * float(j)
				if w > 0 and absi(j) == w and not _on_checker(q):
					continue
				var al := 0.85 * (1.0 - f * 0.75) * fade * (1.0 - 0.35 * absf(float(j)) / float(w + 1))
				_lay(ci, laid, q, Color(DUST[mini(4, int(f * 5.0))], al))
		var R := COMA_R * k * (1.6 if radiant else 1.0)
		var r := int(ceil(R))
		for bx in range(-r, r + 1):
			for by in range(-r, r + 1):
				var d := Vector2(bx, by).length() / R
				if d > 1.0:
					continue
				var q3 := hs + Vector2(bx, by) * 2.0
				var I := pow(1.0 - d, 1.5)
				# (dithered steps: the faint outer rings on the checker only)
				if I < 0.3 and not _on_checker(q3):
					continue
				var col := Color("#ffffff") if d < 0.3 else (Color("#d8f4ff") if d < 0.6 else Color("#8ccaf0"))
				ci.draw_rect(Rect2((q3 / 2.0).floor() * 2.0, Vector2(2, 2)), Color(col, (0.3 + 0.65 * I) * fade))
		# the head, 4 px, white
		ci.draw_rect(Rect2((hs / 2.0).floor() * 2.0 - Vector2(2, 2), Vector2(4, 4)), Color(Color("#fffaf0"), fade))

	static func _lay(ci: CanvasItem, laid: Dictionary, p: Vector2, c: Color) -> void:
		var b := Vector2i((p / 2.0).floor())
		if laid.has(b):
			return
		laid[b] = true
		ci.draw_rect(Rect2(Vector2(b) * 2.0, Vector2(2, 2)), c)

	## Where it is going, from now to the edge: dots on the screen's block grid.
	func _path(from: float) -> void:
		var sa: Vector2 = a_at(float(view.t))
		var end := float(ev.end)
		var last := Vector2.INF
		var age := from
		while age <= end:
			var p: Vector2 = comet_pos(ev, age) + sa
			var sp: Vector2 = view.screen(p.x, p.y)
			if last == Vector2.INF or sp.distance_to(last) >= DOT_PX:
				# (the first dots under the head are skipped: the coma is there)
				if age - from > 1.2 or from == 0.0:
					_blk(sp, Color(PATH_C, PATH_A))
				last = sp
			age += 0.1


## The comet page's picture: the map's comet at the panel's size, in its 2x2 blocks,
## the head left and both tails streaming right, the dust tail bending down.
class CometPortrait extends Node2D:
	const HEAD := Vector2(-64, -16)

	func step(_t: float) -> void:
		pass

	func _draw() -> void:
		var ad := Vector2(1.0, 0.25).normalized()
		RealComet.paint(self, HEAD, ad, -ad.orthogonal(), 0.95, 1.0, false)


## A belt collision: a warm flash, then dust that grows and smears into an arc over half a minute.
class Puff extends Node2D:
	var view
	var ev: Dictionary = {}

	static func sm(a: float, b: float, x: float) -> float:
		var u := clampf((x - a) / (b - a), 0.0, 1.0)
		return u * u * (3.0 - 2.0 * u)

	func _draw() -> void:
		if ev.is_empty() or view == null:
			return
		var a := float(ev.age)
		var b: SystemLayout.Body = view.layout.bodies[int(ev.body)]
		var w := TAU / b.period
		var spin: float = float(view.t) / b.period * TAU
		var r0 := float(ev.r0)
		var a0 := float(ev.a0) + spin
		# THE FLASH: up over 4 frames, down over 11
		var fl := sm(0.0, 4.0 / 60.0, a) * (1.0 - sm(4.0 / 60.0, 15.0 / 60.0, a))
		var c0: Vector2 = view.block(view.screen(b.host_at(float(view.t)).x + cos(a0) * r0, b.host_at(float(view.t)).y + sin(a0) * r0))
		if fl > 0.0:
			draw_rect(Rect2(c0, Vector2(2, 2)), Color(Color("#ffdc96"), fl))
			for bx in range(-1, 2):
				for by in range(-1, 2):
					if (bx + by) % 2 != 0 or (bx == 0 and by == 0):
						continue
					draw_rect(Rect2(c0 + Vector2(bx, by) * 2.0, Vector2(2, 2)), Color(Color("#ffdc96"), 0.4 * fl))
		if a < 0.1:
			return
		# (a cloud a few blocks across at the zoom the map opens at, not a speck)
		var grow := maxf(1.0, 0.8 / maxf(float(view.zoom), 0.05))
		var sig := (5.0 + 12.0 * sqrt(a)) * grow
		var fade := 1.0 - sm(28.0, 35.0, a)
		for p: Array in ev.parts:
			var life := float(p[3])
			if a > life:
				continue
			var dr := float(p[0]) * sig
			if p[2]:
				dr += 0.06 * a * a * grow
			var dphi := clampf(-1.5 * (dr / r0) * w * 40.0 * a, -0.7, 0.7) + float(p[1]) * sig / r0
			var rr := r0 + dr
			var ph := a0 + dphi
			var x := b.host_at(float(view.t)).x + cos(ph) * rr
			var zz := b.host_at(float(view.t)).y + sin(ph) * rr
			var s: Vector2 = view.block(view.screen(x, zz))
			# dims in three steps over its own life
			var step := floorf(clampf(a / life, 0.0, 0.999) * 3.0)
			var al := (1.0 - step / 3.0) * fade * (0.55 if p[2] else 0.9)
			var col: Color
			if dr < 0.0 or p[2]:
				var t: Vector3 = view.tone(x, zz, Vector3(0.84, 0.76, 0.62))
				col = Color(t.x, t.y, t.z, al)
			else:
				col = Color(Color("#6a5a4a"), al)
			draw_rect(Rect2(s, Vector2(2, 2)), col)


## A far star behind the black hole, dimmed so the lens brings its ring only to photon ring level.
class Drift extends Node2D:
	var view
	var ev: Dictionary = {}

	static func env(a: float, r: float, h: float, f: float) -> float:
		var u := clampf(a / r, 0.0, 1.0)
		var v := clampf((a - r - h) / f, 0.0, 1.0)
		return u * u * (3.0 - 2.0 * u) * (1.0 - v * v * (3.0 - 2.0 * v))

	func _draw() -> void:
		if ev.is_empty() or view == null:
			return
		var a := float(ev.age)
		var k := env(a, 3.0, 34.0, 3.0)
		if k <= 0.0:
			return
		var dir: Vector2 = ev.dir
		var c: Vector2 = ev.c
		var p: Vector2 = c + dir * float(ev.speed) * (a - 20.0) + dir.orthogonal() * float(ev.b) + view.sky_off()
		var q := (p / 2.0).floor() * 2.0
		var col := Color(0.5, 0.78, 1.0, k)
		draw_rect(Rect2(q, Vector2(2, 2)), col)
		for d in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
			draw_rect(Rect2(q + d, Vector2(2, 2)), Color(col, 0.6 * k))
			draw_rect(Rect2(q + d * 2.0, Vector2(2, 2)), Color(col, 0.22 * k))
		for d2 in [Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2), Vector2(-2, -2)]:
			draw_rect(Rect2(q + d2, Vector2(2, 2)), Color(col, 0.3 * k))


## Drawn after the depth sheets: under them the dust dims a white star to a grey speck.
## Why: docs/why/SkyWeather.md#points-of-light
class Points extends Node2D:
	var pts: Array = []

	func _draw() -> void:
		for e: Array in pts:
			var q := ((e[0] as Vector2) / 2.0).floor() * 2.0
			var c: Color = e[1]
			draw_rect(Rect2(q, Vector2(2, 2)), c)
			var pa := float(e[2])
			if pa > 0.0:
				for o in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
					draw_rect(Rect2(q + o, Vector2(2, 2)), Color(c, c.a * pa))
