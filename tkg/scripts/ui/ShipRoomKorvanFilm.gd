class_name ShipRoomKorvanFilm
extends RefCounted

## Korvan's film (life2/korvan/r18/mix18.py) as numbers: its tables (film.json, exported from its own
## code), its clocks and plans, and the moving light it lays each frame.
## Why: docs/why/ShipRoomKorvan.md#clock

const T := 30.0
const NF := 900
const DIR := "res://art/sprites/station/shiprooms/korvan/"
const YARD := "res://art/sprites/station/yard/"
const ENGINE_AT := 8.6
const DOOR_AT := 18.8
const ARC := Color(0.70, 0.85, 1.0)
const WORK := Color(1.0, 0.86, 0.66)
const SODIUM := Color(1.0, 0.74, 0.42)
const FIRE := Color(1.0, 0.56, 0.22)
const PX := 882
const PY := 170
const BEACONS := [Vector2i(869, 148), Vector2i(938, 136)]
const FL_X := 186
const FORK_LANE := 399
const GRIND := [Vector2(0.5, 3.0), Vector2(6.0, 8.6), Vector2(12.5, 15.0), Vector2(19.5, 22.0), Vector2(26.0, 28.4)]
const A_RUNS := [Vector2(0.55, 3.35), Vector2(4.45, 6.75), Vector2(7.7, 9.45)]
const HULL_TOP := {&"heavy": 0.72, &"light": 0.92, &"medium": 0.92}
const DSTOPS := [Vector2(-20, 0.0), Vector2(300, 6.0), Vector2(300, 9.0), Vector2(650, 15.0), Vector2(650, 18.0),
	Vector2(990, 24.0), Vector2(990, 30.0)]
const LSTOPS := [Vector2(0.0, 748), Vector2(4.0, 776), Vector2(8.5, 792), Vector2(12.0, 764), Vector2(16.5, 742),
	Vector2(21.0, 758), Vector2(25.5, 784), Vector2(30.0, 748)]

## film.json (its tables), its numbers (`consts`), and yard.json's art (the crew and life strips).
static var D: Dictionary = {}
static var K: Dictionary = {}
static var Y: Dictionary = {}
## fx.json: the baked sparks' blocks and palette, the motes' draws, the wisps' draws.
static var FX: Dictionary = {}


static func ensure() -> void:
	if D.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "film.json"))
		D = d if d is Dictionary else {}
		K = D.get("consts", {})
	if FX.is_empty():
		var x: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "fx.json"))
		FX = x if x is Dictionary else {}
	if Y.is_empty():
		var y: Variant = JSON.parse_string(FileAccess.get_file_as_string(YARD + "yard.json"))
		Y = (y as Dictionary).get("art", {}) if y is Dictionary else {}


## Python's round: half to even, as the film placed things.
static func pyround(v: float) -> int:
	var r := roundf(v)
	if absf(v - floorf(v) - 0.5) < 1e-9:
		r = floorf(v) if int(floorf(v)) % 2 == 0 else floorf(v) + 1.0
	return int(r)


static func smooth(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## An event's own clock (mix18.win): 0 before it starts and after it ends.
static func win(t: float, at: float, length: float = 10.0) -> float:
	var u := t - at
	return 0.0 if u < 0.0 or u >= length else u


static func in_any(t: float, spans: Array) -> bool:
	for s: Vector2 in spans:
		if t >= s.x and t < s.y:
			return true
	return false


# ------------------------------------------------------------------ the engine test (ideaB)
static func burn(t: float) -> float:
	if t < 1.4:
		return 0.0
	if t < 3.0:
		return smooth((t - 1.4) / 1.6)
	if t < 7.0:
		return 1.0 + (0.12 if t >= 4.5 and t < 4.9 else 0.0)
	if t < 8.2:
		return 1.0 - smooth((t - 7.0) / 1.2)
	return 0.0


static func heat(tb: float) -> float:
	var h: Array = K.get("heat", [])
	return float(h[pyround(tb * 30.0) % NF]) if not h.is_empty() else 0.0


static func beacon_on(tb: float) -> bool:
	return tb >= 0.9 and tb < 8.8


# ------------------------------------------------------------------ the loading door (ideaC)
static func opening(t: float) -> float:
	if t < 1.2:
		return 0.0
	if t < 2.8:
		return smooth((t - 1.2) / 1.6)
	if t < 7.6:
		return 1.0
	if t < 9.0:
		return 1.0 - smooth((t - 7.6) / 1.4)
	return 0.0


static func moving(t: float) -> bool:
	return (t >= 0.7 and t < 3.0) or (t >= 7.3 and t < 9.2)


# ------------------------------------------------------------------ the lift's weld (ideaA)
## (welder frame, 1 while the arc burns)
static func weld_pose(t: float) -> Vector2i:
	for r: Vector2 in A_RUNS:
		if t >= r.x and t < r.y:
			return Vector2i([0, 1, 2, 1][int(floorf((t - r.x) * 8.0)) % 4], 1)
	for r: Vector2 in A_RUNS:
		if t >= r.y and t < r.y + 0.39:
			return Vector2i(3 + mini(2, int((t - r.y) / 0.13)), 0)
		if t >= r.x - 0.39 and t < r.x:
			return Vector2i(5 - mini(2, int((t - (r.x - 0.39)) / 0.13)), 0)
	return Vector2i(5, 0)


static func arc_tip(f: int) -> Vector2i:
	var c := K
	var fr: Dictionary = (Y["life"]["welder_strip"]["frames"] as Array)[f]
	var tip: Array = fr["tip"]
	return Vector2i(int(floorf(float(c["wx"]) - float(c["wcx"]) + float(tip[0]) + 0.5)),
		int(c["wb"]) - int(c["wfoot"]) + int(tip[1]))


## The ladder jobs' beat (people8.weld_state): (frame, 1 on, run progress or -1, seconds since the last run).
static func weld_state(sp: Dictionary, t: float) -> Vector4:
	var cyc := float(sp["cyc"])
	var u := fposmod(t, cyc)
	var since := 99.0
	for r: Array in sp["runs"]:
		if u >= float(r[0]) and u < float(r[1]):
			return Vector4([6, 7, 8, 7][int(floorf((u - float(r[0])) * 8.0)) % 4], 1.0, (u - float(r[0])) / (float(r[1]) - float(r[0])), 0.0)
	for r: Array in sp["runs"]:
		since = minf(since, fposmod(u - float(r[1]), cyc))
	for r: Array in sp["runs"]:
		if float(r[0]) - u >= 0.0 and float(r[0]) - u < 0.15:
			return Vector4(4, 0.0, -1.0, since)
	return Vector4(5, 0.0, -1.0, since)


# ------------------------------------------------------------------ the crane (crane8, upper11)
class Crane:
	var x := 0
	var lx := 0
	var ly := 0
	var sway := 0.0
	var part := 1
	var lw := 0
	var lh := 0
	var vel := 0.0


static func crane(t: float) -> Crane:
	var c := K
	var cr: Dictionary = D["crane"]
	var f := pyround(t * 30.0) % NF
	var k := int(fposmod(t, T) / 15.0)
	var part := [1, 3][k % 2] as int
	var p: Dictionary = c["parts"][str(part)]
	var x := float(cr["x"][f])
	var sway := float(cr["sw"][str(part)][f]) * 40.0
	var lw := int(p["w"])
	var o := Crane.new()
	o.x = pyround(x)
	o.lx = pyround(x + sway) - lw / 2
	o.ly = int(c["load_top"]) + int(p["sag"])
	o.sway = sway
	o.part = part
	o.lw = lw
	o.lh = int(p["h"])
	o.vel = (float(cr["x"][(f + 1) % NF]) - x) * 30.0
	return o


class Drones:
	var pair := true
	var xc := 0
	var d: Array[Vector2i] = []
	var load := &"up_small0"
	var lw := 30
	var ly := 0


## The cargo drones trailing each crane pass (upper11.drones): null when off screen.
static func drones(t: float) -> Drones:
	var tt := fposmod(t, T)
	var k := int(tt / 15.0)
	var u := tt - k * 15.0
	if u < 3.8:
		k = posmod(k - 1, 2)
		u += 15.0
	var xc := -70.0 + (u - 3.8) * 80.0
	if xc > 960.0 + 70.0:
		return null
	var bob := pyround(1.2 * sin(TAU * t / 1.7))
	var o := Drones.new()
	o.xc = pyround(xc)
	o.pair = k == 0
	if o.pair:
		o.d = [Vector2i(o.xc - 22, 133 + bob), Vector2i(o.xc + 22, 133 + bob)]
		o.ly = 133 + 19 + bob
	else:
		o.d = [Vector2i(o.xc, 133 + bob)]
		o.load = &"up_crate"
		o.lw = 11
		o.ly = 133 + 18 + bob
	return o


# ------------------------------------------------------------------ the floor's people
static func lamp_spot(t: float) -> int:
	for i in LSTOPS.size() - 1:
		var a: Vector2 = LSTOPS[i]
		var b: Vector2 = LSTOPS[i + 1]
		if t >= a.x and t < b.x:
			return pyround(a.y + (b.y - a.y) * smooth((t - a.x) / 1.3))
	return int(LSTOPS[0].y)


static func drone_at(t: float) -> Vector2:
	for i in DSTOPS.size() - 1:
		var a: Vector2 = DSTOPS[i]
		var b: Vector2 = DSTOPS[i + 1]
		if t >= a.y and t <= b.y:
			if a.x == b.x:
				return Vector2(a.x, 1.0)
			return Vector2(a.x + (b.x - a.x) * smooth((t - a.y) / (b.y - a.y)), 0.0)
	return Vector2(990, 0.0)


## The forklift's left edge: it hauls a crate across the front of the hall; NAN off screen.
static func fork_x(t: float) -> float:
	if t < 1.0 or t >= 27.0:
		return NAN
	return -80.0 + 1120.0 * (t - 1.0) / 26.0


## The lamp tech's aim at the belly spot (mix18.tech_pose): (unit x, unit y, shoulder x, shoulder y), flipped
## when the spot is to his right.
static func tech_aim(spot: int) -> Vector4:
	var sy := int((K["under_m"] as Array)[spot]) - 1
	var flip := spot > int(K["tech_x"]) + 1
	var sx0 := float(int(K["tbx0"]) + (35 - 18 if flip else 18))
	var sy0 := float(int(K["tby0"]) + 17)
	var a := rad_to_deg(atan2(-(sy - sy0), absf(spot - sx0)))
	var aim := 72.0 if a > 64.0 else (57.0 if a > 48.0 else 42.0)
	var r := deg_to_rad(aim)
	return Vector4((1.0 if flip else -1.0) * cos(r), -sin(r), sx0, sy0)


static func lens_at(spot: int) -> Vector2i:
	var a := tech_aim(spot)
	return Vector2i(pyround(a.z + a.x * 15.0), pyround(a.w + a.y * 15.0))
