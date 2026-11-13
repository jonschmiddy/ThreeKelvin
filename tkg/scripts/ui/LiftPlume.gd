class_name LiftPlume
extends Control

## THE STEAM a hull throws up as it lifts off or sets down (Jon's "AB-23", Nov 12):
## sculpted lobes in three layers of depth, every lift its own. All of it leaves the
## hull's jets: down to the floor in streams, pooled there, rolled out to both sides.
## The host (`ShipLift`) moves it with the hull, lays `back_layer` under the hull, and
## sets `thrust`; once the jets cut, it clears.
## Why: docs/why/ShipLift.md#plume

## The shape changes ten times a second (the steam's own clock), the lobes move every frame.
const HZ := 10.0
const MAX_LOBES := 96
## HOW HEAVY (Jon, Nov 13: "more smoke and it needs to be heavier"), as `weight`:
## 0 AB-23 as first built, 1 heavy, 2 heavier. Puffs a second, their size, the
## layers' alpha (far, mid, near), the ragged edge's share of it, the jets' push
## down and how fast it dies, the bank's roll out and how fast it slows, how much
## longer it lingers, how much it lifts, the curl's size, the floor shadow, the
## darker undersides; and once the jets cut, how long it takes to go (s), whether
## it lifts (+) or settles (-) as it goes, and how fast it spreads (px/s).
const WEIGHTS := [
	{"rate": 28.0, "size": 1.0, "alpha": [0.42, 0.8, 0.94], "edge": 0.5, "fall": 1.0, "fall_drag": 1.0,
		"out": 1.0, "roll_drag": 1.3, "linger": 0.0, "lift": 1.0, "curl": 1.0, "shadow": 0.34, "under": 0.0,
		"clear": Vector2(1.4, 2.0), "clear_lift": 10.0, "clear_spread": 0.0, "flat": 1.0, "contrast": 1.0, "warm": 1.0},
	{"rate": 32.0, "size": 1.35, "alpha": [0.62, 0.9, 1.0], "edge": 0.7, "fall": 1.15, "fall_drag": 0.8,
		"out": 0.75, "roll_drag": 1.5, "linger": 0.5, "lift": 0.5, "curl": 1.3, "shadow": 0.46, "under": 0.25,
		"clear": Vector2(4.0, 5.0), "clear_lift": -3.0, "clear_spread": 4.0, "flat": 0.85, "contrast": 1.0, "warm": 1.0},
	# (heavier, Jon's pick, Nov 13: "spread wider along the floor", "dissipate quicker";
	# then "the stills do not match the movie": big chunky billows to the stand tops,
	# the bands reading, a hot glow under the jets -- wider, not flatter)
	{"rate": 44.0, "size": 1.3, "alpha": [0.8, 0.96, 1.0], "edge": 0.85, "fall": 1.3, "fall_drag": 0.7,
		"out": 1.55, "roll_drag": 1.1, "linger": 0.6, "lift": 1.6, "curl": 2.2, "shadow": 0.56, "under": 0.4,
		"clear": Vector2(1.8, 2.2), "clear_lift": -2.0, "clear_spread": 6.0, "flat": 1.3, "contrast": 1.5, "warm": 1.0},
]
static var weight := 2
## The steam's texture (`lift_plume.gdshader`'s `style`): 0 as built, 1 cel,
## 2 patterned, 3 outlined. Stills for Jon to pick from (Nov 13).
static var style := 1
## A harness's fixed seed for the steam, so two textures can be shown on one
## frame; -1, every lift its own.
static var seed := -1
const BURST := 12
## The light it gives eases after the thrust over a few tenths of a second: steady,
## never stepping frame to frame (Jon's F1, Nov 12).
const LIGHT_TC := 0.15
## Its five tones, crease to lit rim: halfway between grey steam and warm exhaust.
const TONES := [Color(0.23, 0.225, 0.235), Color(0.365, 0.36, 0.36), Color(0.51, 0.5, 0.49),
	Color(0.65, 0.64, 0.62), Color(0.8, 0.785, 0.755)]
## The three layers of depth, far to near: alpha, tone shift (paler), contrast.
const LAYERS := [[0.42, 0.7, 0.45], [0.8, 0.2, 0.8], [0.94, 0.0, 1.15]]

## Knobs: how big, how hard, and the floor row it rises from.
var size_k: float = 1.0
var strength: float = 1.0
var floor_y: float = 372.0
## The hull's belly middle and half its length (host px), this frame.
var src := Vector2(480, 300)
var src_w: float = 60.0
## The hull's inked box (host px), this frame: the steam climbs past its nose and tail.
var hull := Rect2()
## 0..1, set by the host each frame: how hard the lift jets burn.
var thrust: float = 0.0
## Where under the hull the steam comes from this frame: (x, belly row, weight),
## and how far either side of each it starts.
var sources: Array[Vector3] = []
var spread: float = 10.0
## The hall's lamps over the berth (x, reach), for the light on its tops.
var lamps: Array[Vector2] = []
## The far and middle layers and the steam's shadow, which the host lays under the hull.
var back_layer: Control

var _front: ColorRect
var _back: ColorRect
var _shadow: ColorRect
var _fmat: ShaderMaterial
var _bmat: ShaderMaterial
var _smat: ShaderMaterial
var _lobes: Array = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _fired := -1.0
var _acc := 0.0
var _burned := false
var _clearing := false
var _lk := 0.0
## The hull's jets' velocity (host px/s), eased; every puff born takes it along.
var _ship_v := Vector2.ZERO
var _w: Dictionary = WEIGHTS[0]
var _nback := 0
var _nfront := 0
## Packed for the shader at the steam's own rate (`HZ`); between, the shader carries
## each lobe on by the velocity it was packed with (`tdt`).
var _packed_tick := -1.0
var _packed_t := 0.0
## THE BANK GOES AS ONE (Jon, Nov 13: "it should also dissipate together"): once the
## jets cut, every puff thins on one shared fade from `_fade_t0` over `_fade_s`.
var _fade_t0 := -1.0
var _fade_s := 2.0
## LIFTING (`ShipLift.lift_at`): the floor gets steam only while the jets are near
## enough to reach it -- from the belly's height at rest (`rest_gap`, px over the
## floor) up by the hull's own height, thinning all the way (Jon, Nov 13: "some that
## reaches the floor as the ship flies to the right"). The landing is not gated.
var reach_gate := false
var rest_gap := 40.0
## THE FLAME'S LIGHT ON IT (Jon, Nov 13: "more lit by the flame and cooler further
## out"): the main flame's place (host px) and how hard it burns, set by the host
## each frame; the jets' are `src` and the thrust. Eased like the floor's light.
var main_g := Vector2(-9999, -9999)
var main_k := 0.0
var _mk := 0.0
const LIGHT_REACH := 75.0
## How many hulls' height over its rest the jets still put steam on the floor, thinning
## all the way (one put it out before the hull had moved off: no trail).
const REACH_HULLS := 2.5
## A trail's puffs: this much bigger than the bank's and this flat, so they run together.
const TRAIL_R := 1.9
## A takeoff's shared fade, s: within `ShipLift.HOLD_S` of the exit.
const TAKEOFF_FADE_S := 0.8
## Px of floor the hull crosses that earn one more rest-rate's worth of steam.
const TRAIL_STEP := 70.0
const TRAIL_FLAT := 0.45
## THE CLUMPS the bank rolls out in (Jon, Nov 13: the painted still's separate chunky
## puffs, gaps between them): its share of the roll-out speed, so each clump comes to
## rest at its own distance from the middle. The first pools under the hull; the last,
## furthest out, climbs the sides past the hull.
const CLUMPS := [0.12, 0.5, 0.85, 1.15]
const CLIMB := 16.0
## (Jon, Nov 13: "spread out vertically" too: the clump inside the outermost climbs as well)
const CLIMB_NEXT := 7.0
## THE FLOOR LAYER (Jon, Nov 13: "it should stick to the ground somewhat too"): this
## share of what lands hugs the floor across the whole roll-out, low, wide and heavy,
## never lifting, and fades where it lies; the billows rise from it.
const HUG := 0.45
const HUG_FLAT := 0.7
## HEAT (Jon, Nov 13: "Smoke rises when it is hot, but can sink once it cools down"):
## a puff's heat is 1 off the jets and falls with this time constant, s. Above
## `COOL_AT` it rises, below it sinks back to the floor at up to `SINK_V` px/s and
## spreads there; its warm glow is its heat.
const HEAT_TC := 1.6
const COOL_AT := 0.3
const SINK_V := 40.0


## How much of the jets' steam reaches the floor now, 0..1 (1 unless lifting).
func _reach() -> float:
	if not reach_gate:
		return 1.0
	var gap := floor_y - src.y
	return clampf(1.0 - (gap - rest_gap) / maxf(20.0, REACH_HULLS * hull.size.y), 0.0, 1.0)


func _heat(l: Dictionary) -> float:
	return exp(-float(l.age) / HEAT_TC)
var _last_src := Vector2(INF, INF)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# every launch and landing its own steam (Jon, Nov 12)
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	_w = WEIGHTS[clampi(weight, 0, WEIGHTS.size() - 1)]


## `w` x `h` is the host's picture; the steam may run `pad` px past each edge of it.
func setup(w: float, h: float, pad: float = 0.0) -> void:
	size = Vector2(w, h)
	back_layer = Control.new()
	back_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_layer.size = size
	_smat = _material(pad)
	_smat.set_shader_parameter(&"shadow_pass", true)
	_shadow = _rect(_smat, pad)
	back_layer.add_child(_shadow)
	_bmat = _material(pad)
	_back = _rect(_bmat, pad)
	back_layer.add_child(_back)
	_fmat = _material(pad)
	_front = _rect(_fmat, pad)
	add_child(_front)
	_push()


func _material(pad: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/lift_plume.gdshader")
	m.set_shader_parameter(&"rect_size", size + Vector2(2.0 * pad, 2.0 * pad))
	m.set_shader_parameter(&"org", Vector2(-pad, -pad))
	var tones := PackedVector4Array()
	for c: Color in TONES:
		tones.append(Vector4(c.r, c.g, c.b, 1.0))
	m.set_shader_parameter(&"tones", tones)
	m.set_shader_parameter(&"style", style)
	# (each layer's tone shift and contrast, and how far a billow's own shade strays)
	m.set_shader_parameter(&"layer_shift", Vector3(float(LAYERS[0][1]), float(LAYERS[1][1]), float(LAYERS[2][1])))
	m.set_shader_parameter(&"layer_contrast", Vector3(float(LAYERS[0][2]), float(LAYERS[1][2]), float(LAYERS[2][2])) * float(_w.contrast))
	m.set_shader_parameter(&"shade_var", 0.6 * (float(_w.contrast) - 1.0))
	m.set_shader_parameter(&"warm_k", float(_w.warm))
	m.set_shader_parameter(&"edge_a", float(_w.edge))
	m.set_shader_parameter(&"under_k", float(_w.under))
	m.set_shader_parameter(&"shadow_k", float(_w.shadow))
	return m


func _rect(m: ShaderMaterial, pad: float) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = Vector2(-pad, -pad)
	r.size = size + Vector2(2.0 * pad, 2.0 * pad)
	r.material = m
	return r


## Start it: the first billows go up at once.
func fire() -> void:
	_fired = _t
	for i in BURST:
		_spawn()


func fired() -> bool:
	return _fired >= 0.0


## How many lobes are in the air.
func puffs() -> int:
	return _lobes.size()


## The stands take the weight: a last breath out of the jets.
func touchdown() -> void:
	# (never once the bank is going: nothing may appear in the fade)
	if _clearing:
		return
	for i in 6:
		_spawn()


## The floor and stands it lights this tick, as the yard's small lights
## (`YardLight.dyn`: x, y, radius x, y, strength, colour, beat).
func lights() -> Array:
	var out: Array = []
	var k := _lk
	if _fired < 0.0 or k <= 0.02:
		return out
	out.append([src.x, floor_y - 2.0, 150.0 * size_k, 46.0 * size_k, 1.6 * k * float(_w.warm), Color(1.0, 0.55, 0.22), 1.0])
	out.append([src.x, src.y + 4.0, 90.0 * size_k, 50.0 * size_k, 1.1 * k, Color(1.0, 0.75, 0.45), 1.0])
	return out


## The light's level now (the thrust, eased).
func light_level() -> float:
	return _lk


## Done: nothing of it left to draw.
func cleared() -> bool:
	return _clearing and _lobes.is_empty()


func _process(dt: float) -> void:
	_t += dt
	_lk += (thrust * strength - _lk) * (1.0 - exp(-dt / LIGHT_TC))
	if dt > 0.0:
		var sv := Vector2.ZERO if _last_src.x == INF else ((src - _last_src) / dt).limit_length(600.0)
		_ship_v = _ship_v.lerp(sv, 1.0 - exp(-dt / 0.08))
		_last_src = src
	if _fired < 0.0:
		return
	# (lifting, what the floor gets: nothing once the jets are too high to reach it --
	# and the bank's shared fade starts then, as it does when a landing's jets cut)
	var feed := thrust * _reach()
	if feed > 0.05:
		_burned = true
	elif _burned and not _clearing:
		_clear()
	if not _clearing:
		# (a weak burn thins the steam more than it spaces it out: the streams stay streams)
		# (and going sideways, as many to the stretch of floor as at rest, so the trail
		# it lays is one streak and not a puff here and there)
		var along := 1.0 + absf(_ship_v.x) / (TRAIL_STEP * size_k)
		_acc += float(_w.rate) * feed * (0.5 + 0.5 * minf(strength, 1.0)) * along * dt
		while _acc >= 1.0:
			_acc -= 1.0
			_spawn()
	_step(dt)
	var tick := floorf(_t * HZ)
	if tick != _packed_tick:
		_packed_tick = tick
		_packed_t = _t
		_push()
	else:
		for m: ShaderMaterial in [_bmat, _fmat, _smat]:
			if m != null:
				m.set_shader_parameter(&"tdt", _t - _packed_t)
	_mk += (main_k - _mk) * (1.0 - exp(-dt / LIGHT_TC))
	for m: ShaderMaterial in [_bmat, _fmat]:
		if m != null:
			m.set_shader_parameter(&"jet_g", src)
			m.set_shader_parameter(&"jet_k", _lk)
			m.set_shader_parameter(&"main_g", main_g)
			m.set_shader_parameter(&"main_k", _mk)
			m.set_shader_parameter(&"light_reach", LIGHT_REACH * size_k)
	if _smat != null:
		_smat.set_shader_parameter(&"fade_all", clampf(1.0 - (_t - _fade_t0) / _fade_s, 0.0, 1.0) if _fade_t0 >= 0.0 else 1.0)


## THE JETS CUT: no more steam, and what is there thins, lifts and is gone within
## `CLEAR_S` (its alpha steps down through the dither, so nothing pops out).
func _clear() -> void:
	_clearing = true
	var c: Vector2 = _w.clear
	_fade_t0 = _t
	# (a takeoff's goes faster, done by the front door's cut to LOCAL; the landing's
	# slower one Jon called perfect -- Nov 13)
	_fade_s = TAKEOFF_FADE_S if reach_gate else _rng.randf_range(c.x, c.y)
	for l: Dictionary in _lobes:
		# (every puff kept to the end of the shared fade: none goes early on its own)
		l.life = float(l.age) + _fade_s + 0.05
		l.c0 = float(l.age)
		# (the floor layer fades where it lies; a billow still hot lifts a little as it goes)
		if not bool(l.hug):
			l.buoy = maxf(0.0, float(l.buoy) + float(_w.clear_lift) * size_k)


## One lobe, born at the hull: where, how fast, radius, its layer (0 far .. 2 near),
## warmth, life s. It falls (`roll` false) until it reaches the floor.
func _add(at: Vector2, v: Vector2, r: float, layer: int, warm: float, life: float) -> void:
	# (full: no new puff, rather than an old one gone at once)
	if (_nback if layer < 2 else _nfront) >= MAX_LOBES:
		return
	if layer < 2:
		_nback += 1
	else:
		_nfront += 1
	_lobes.append({"p": at, "d": at, "v": v, "dv": v, "clump": -1, "hug": false, "trail": false, "c0": -1.0, "r": r * size_k * float(_w.size), "gr": _rng.randf_range(7, 12) * size_k, "layer": layer,
		"warm": warm, "life": life, "age": 0.0, "buoy": _rng.randf_range(3, 7) * size_k * float(_w.lift), "seed": _rng.randf(),
		"k": clampf(0.4 + 0.6 * strength, 0.0, 1.0), "roll": false, "rolled": 0.0, "side": 1.0, "R": 0.0, "phi": 0.0, "w": 0.0})


## A jet, by weight, and a spot either side of it.
func _jet() -> Vector2:
	if sources.is_empty():
		return Vector2(src.x + _rng.randf_range(-0.6, 0.6) * src_w, src.y)
	var q := sources[_rng.randi() % sources.size()]
	return Vector2(q.x + _rng.randf_range(-spread, spread), q.y)


## THE SHIP IS THE SOURCE (Jon, Nov 12): every puff leaves a belly jet, driven straight
## down. Whatever reaches the floor pools there and rolls out sideways from under the
## hull; what does not (the hull too high) thins out in the air.
func _spawn() -> void:
	var j := _jet()
	var q := _rng.randf()
	var layer := 0 if q < 0.3 else (1 if q < 0.7 else 2)
	# (carried along with the hull: its velocity, which fades as the puff falls)
	_add(Vector2(j.x, j.y + 2.0), _ship_v + Vector2(_rng.randf_range(-8, 8) * size_k, _rng.randf_range(230, 300) * size_k * float(_w.fall)),
		_rng.randf_range(7, 10), layer, 0.9, _rng.randf_range(0.8, 1.1))


## Falling: the jet's push dies off as it goes. On the floor it turns into the bank:
## out from under the hull, slowing, each lobe riding a roll at the front (low and
## forward, up the front, back over the top: Jon's curl), and late on lifting a little.
func _step(dt: float) -> void:
	var keep: Array = []
	var mid := hull.get_center().x if hull.size.x > 0.0 else src.x
	var half := 0.5 * hull.size.x if hull.size.x > 0.0 else src_w * 1.4
	for l: Dictionary in _lobes:
		l.age = float(l.age) + dt
		if float(l.age) >= float(l.life):
			continue
		var v: Vector2 = l.v
		var pos: Vector2 = l.p
		var r := float(l.r)
		var d0: Vector2 = l.d
		if not bool(l.roll):
			v *= exp(-float(_w.fall_drag) * dt)
			pos += v * dt
			l.r = r + float(l.gr) * 0.6 * dt
			if pos.y + 0.4 * r >= floor_y:
				if _clearing:
					# (the bank going: what was still falling stops on the floor and goes
					# with the rest, no splash, nothing new)
					pos.y = floor_y - 0.4 * r
					v = Vector2.ZERO
				else:
					_land(l, pos, mid, half)
					pos = l.p
					v = l.v
			l.d = pos
		else:
			l.rolled = float(l.rolled) + dt
			v.x *= exp(-float(_w.roll_drag) * dt)
			# hot, it billows up off the rolling front; cooled, it sinks back to the floor
			var lift := (_heat(l) - COOL_AT) / (1.0 - COOL_AT)
			var ramp := clampf((float(l.rolled) - 0.2) / 0.5, 0.0, 1.0)
			v.y = -float(l.buoy) * maxf(lift, 0.0) * ramp + SINK_V * size_k * maxf(-lift, 0.0) * 2.0
			pos += v * dt
			pos.y = minf(pos.y, floor_y - float(l.R) - 0.4 * float(l.r))
			l.phi = minf(float(l.phi) + float(l.w) * dt * exp(-float(l.rolled) * 0.4), 1.3 * PI)
			l.r = r + float(l.gr) * dt * exp(-float(l.rolled) * 0.5)
			# (going, a heavy bank settles and spreads as it thins)
			if float(l.c0) >= 0.0:
				l.r = float(l.r) + float(_w.clear_spread) * size_k * dt
				pos.y = minf(pos.y, floor_y - 0.3 * float(l.r))
			var rr := float(l.R)
			l.d = pos + Vector2(float(l.side) * rr * sin(float(l.phi)), rr * cos(float(l.phi)))
		# (how fast it is drawn moving, which the shader carries it on by between packs)
		if dt > 0.0:
			var dv := ((l.d as Vector2) - d0) / dt
			# (never carried down past the floor between packs)
			var room := floor_y - 0.4 * float(l.r) - (l.d as Vector2).y
			dv.y = minf(dv.y, maxf(0.0, room) / (1.0 / HZ))
			l.dv = dv
		l.v = v
		l.p = pos
		keep.append(l)
	_lobes = keep
	_nback = 0
	_nfront = 0
	for l: Dictionary in _lobes:
		if int(l.layer) < 2:
			_nback += 1
		else:
			_nfront += 1


## A falling lobe reaches the floor: a third pools under the hull, the rest roll out,
## each side away from the middle.
func _land(l: Dictionary, at: Vector2, mid: float, half: float) -> void:
	var s := size_k
	var off := at.x - mid
	var side := signf(off) if absf(off) > 0.12 * half else (-1.0 if _rng.randf() < 0.5 else 1.0)
	var rr := _rng.randf_range(8, 16) * s * float(_w.curl)
	# (into one of the clumps, at its own speed out)
	var k := _rng.randi_range(0, CLUMPS.size() - 1)
	var out := float(CLUMPS[k]) * 150.0 * _rng.randf_range(0.95, 1.05) * float(_w.out)
	l.clump = k
	l.hug = _rng.randf() < HUG
	# THE TRAIL (the hull going sideways): it lies down low and flat where it lands,
	# barely rolling, a little wider, so the trail is one streak joined to the bank
	var trail := absf(_ship_v.x) > 60.0 * s
	if trail:
		l.hug = true
		l.trail = true
		k = mini(k, 1)
		out = float(CLUMPS[k]) * 150.0 * float(_w.out) * 0.5
	if bool(l.hug):
		l.buoy = 0.0
		rr *= 0.3
	elif k == CLUMPS.size() - 1:
		l.buoy = float(l.buoy) * CLIMB
	elif k == CLUMPS.size() - 2:
		l.buoy = float(l.buoy) * CLIMB_NEXT
	# the floor takes the splash: it spreads at once
	l.r = maxf(float(l.r), _rng.randf_range(13, 17) * s * float(_w.size))
	l.gr = _rng.randf_range(10, 16) * s * float(_w.size)
	# (a trail's puff lies long and low, so the next one along runs into it: one streak)
	if trail:
		l.r = float(l.r) * TRAIL_R
		l.gr = float(l.gr) * 1.5
	l.roll = true
	l.side = side
	l.R = rr
	l.phi = 0.0
	l.w = _rng.randf_range(1.6, 2.8)
	l.p = Vector2(at.x, floor_y - rr - 0.4 * float(l.r))
	# (and shifted the way the hull was going, by what of its push is left)
	l.v = Vector2(side * out * s + 0.6 * (l.v as Vector2).x, 0.0)
	l.life = float(l.age) + _rng.randf_range(2.0, 2.8) + float(_w.linger)


## A rolling lobe's height over its width as it ages (`WEIGHTS[].flat`: under 1 it
## flattens along the floor, over 1 it grows taller, Jon's "spread out vertically");
## a falling one is round.
func _aspect(l: Dictionary) -> float:
	if not bool(l.roll):
		return 1.0
	# (a hot billow stands tall; cooled, it lies flat along the floor like the base)
	var tall := lerpf(HUG_FLAT, float(_w.flat), clampf((_heat(l) - COOL_AT) / (1.0 - COOL_AT), 0.0, 1.0))
	var lie := TRAIL_FLAT if bool(l.trail) else HUG_FLAT
	return lerpf(1.0, lie if bool(l.hug) else tall, clampf(float(l.rolled) / 1.5, 0.0, 1.0))


func _push() -> void:
	if _fmat == null:
		return
	var back: Array = []
	var front: Array = []
	for l: Dictionary in _lobes:
		(front if int(l.layer) == 2 else back).append(l)
	# painted far to near, and within a layer top first, so the lower ones roll over
	back.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.layer) < int(b.layer) or (int(a.layer) == int(b.layer) and (a.d as Vector2).y < (b.d as Vector2).y))
	front.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.d as Vector2).y < (b.d as Vector2).y)
	var lamp_arr := PackedVector2Array()
	lamp_arr.resize(8)
	for i in mini(8, lamps.size()):
		lamp_arr[i] = lamps[i]
	for pair: Array in [[_bmat, back], [_fmat, front], [_smat, _lobes]]:
		_fill(pair[0], pair[1], lamp_arr)


func _fill(m: ShaderMaterial, lobes: Array, lamp_arr: PackedVector2Array) -> void:
	var a := PackedVector4Array()
	var b := PackedVector4Array()
	a.resize(MAX_LOBES)
	b.resize(MAX_LOBES)
	var x0 := 1e9
	var y0 := 1e9
	var x1 := -1e9
	var y1 := -1e9
	var n := 0
	for l: Dictionary in lobes:
		if n >= MAX_LOBES:
			break
		var u := float(l.age) / float(l.life)
		# in over a sixth of a second, out over the last third of its life
		var fade := minf(1.0, float(l.age) * 6.0) * clampf((1.0 - u) / 0.35, 0.0, 1.0)
		# (going: the whole bank on one fade)
		if _fade_t0 >= 0.0:
			fade = minf(minf(1.0, float(l.age) * 6.0), clampf(1.0 - (_t - _fade_t0) / _fade_s, 0.0, 1.0))
		var pos: Vector2 = (l.d as Vector2).floor()
		var r := floorf(float(l.r))
		a[n] = Vector4(pos.x, pos.y, maxf(3.0, r), float((_w.alpha as Array)[int(l.layer)]) * fade * float(l.k))
		# (its velocity as drawn, the warmth only on what is fresh off the jets, and its
		# seed, squash and layer in one number: `lift_plume.gdshader`)
		var dv: Vector2 = l.dv
		b[n] = Vector4(dv.x, dv.y, float(l.warm) * pow(_heat(l), 2.0 + 2.0 * (float(_w.warm) - 1.0)) * _lk,
			float(l.seed) + floorf(_aspect(l) * 100.0) + 1000.0 * float(l.layer))
		# (the box holds it to the next pack too)
		var reach := r + 16.0 + dv.length() * 0.12
		x0 = minf(x0, pos.x - reach)
		y0 = minf(y0, pos.y - reach)
		x1 = maxf(x1, pos.x + reach)
		y1 = maxf(y1, pos.y + reach + 12.0)
		n += 1
	m.set_shader_parameter(&"n", n)
	m.set_shader_parameter(&"lobe", a)
	m.set_shader_parameter(&"lobe2", b)
	m.set_shader_parameter(&"tstep", floorf(_t * HZ))
	m.set_shader_parameter(&"tdt", 0.0)
	m.set_shader_parameter(&"box", Vector4(x0, y0, x1, y1) if n > 0 else Vector4(0, 0, -1, -1))
	m.set_shader_parameter(&"floor_y", floor_y)
	m.set_shader_parameter(&"nlamps", mini(8, lamps.size()))
	m.set_shader_parameter(&"lamps", lamp_arr)
