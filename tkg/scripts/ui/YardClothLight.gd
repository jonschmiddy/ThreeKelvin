class_name YardClothLight
extends RefCounted

## The banners' light in each ship-select room: the banner page's ROOMS (Jon, Nov 24), each light where
## the room shows its source, over the whole hall's seven banners (frame px; z toward you, the wall at -8).
## Why: docs/why/YardBanner.md#light

## Korvan's ceiling cone lamps (its top tubes' centres), just in front of the gantry.
const TOP_TUBES: Array[int] = [22, 102, 180, 263, 352, 401, 451, 503, 560, 615, 675, 734, 800, 860, 919]
## Solari's furnace rings in the wall behind every tap, and each one's flicker phase.
const TAP_Y: Array[int] = [101, 102, 100, 101, 101, 101]
const TAP_FIRE: Array[float] = [3.9, 0.0, 1.7, 2.9, 0.8, 2.3]
## The Old hangar's one sodium lamp.
const SODIUM := Vector3(483, 24, 16)
const CT := 38.0
const CH := 100.0
const ROD_Y := 34.0


## One light: a point (`pos`) or a direction (`dir`), and how cloth takes it.
class Light extends RefCounted:
	var point := true
	var p := Vector3.ZERO
	var col := Vector3.ONE
	var pw := 1.0
	var ir2 := 0.0
	var reach := 1.0
	var wrap := 0.0
	var trans := 0.0
	var rim := 0.0
	var spec := false
	var shadow := false
	## The flicker's phase, or below zero for a steady light.
	var fire := -1.0
	## Its strength down the cloth: vw.x + vw.y v/100 (the floor's bounce).
	var vw := Vector2(1, 0)


## A room's banner light: its lights, ambient, the level the brightest banner's face sits at.
class Room extends RefCounted:
	var lights: Array[Light] = []
	var amb := Vector3.ZERO
	var target := 1.0
	var tp := 50.0
	var shadow := 0.0
	var contact := false
	## Worked out over the hall's banners (`fit`).
	var expo := 1.0
	var sh: Array[Light] = []
	var sh_s := PackedFloat32Array()
	var rig: Array[Vector3] = []


static func _pt(p: Vector3, col: Vector3, pw: float, reach: float, wrap: float) -> Light:
	var L := Light.new()
	L.p = p
	L.col = col
	L.pw = pw
	L.reach = reach
	L.ir2 = 1.0 / (reach * reach)
	L.wrap = wrap
	return L


static func _dir(d: Vector3, col: Vector3, pw: float, wrap: float) -> Light:
	var L := Light.new()
	L.point = false
	L.p = d.normalized()
	L.col = col
	L.pw = pw
	L.wrap = wrap
	return L


## The page's ROOMS at their sources in the game's hall.
static func room(id: StringName) -> Room:
	var r := Room.new()
	match id:
		&"solari":
			r.target = 0.72
			r.shadow = 0.2
			r.amb = Vector3(0.26, 0.20, 0.16)
			r.contact = true
			for i in ShipRoomSolariCycle.TAPS.size():
				var L := _pt(Vector3(ShipRoomSolariCycle.TAPS[i], TAP_Y[i], -16),
					Vector3(1.0, 0.6, 0.28) if i % 2 else Vector3(1.0, 0.58, 0.26), 1.6, 70, 0.5)
				L.trans = 0.1
				L.rim = 2.4
				L.fire = TAP_FIRE[i]
				r.lights.append(L)
			var bounce := _dir(Vector3(0, 0.75, 0.66), Vector3(0.45, 0.30, 0.16), 0.7, 0.2)
			bounce.vw = Vector2(0.15, 0.85)
			r.lights.append(bounce)
		&"old":
			r.tp = 22.0
			r.shadow = 0.55
			r.amb = Vector3(0.09, 0.095, 0.12)
			var L := _pt(SODIUM, Vector3(1.0, 0.66, 0.26), 1.4, 46, 0.05)
			L.spec = true
			L.shadow = true
			r.lights.append(L)
		_:
			r.target = 0.9
			r.shadow = 0.42
			r.amb = Vector3(0.27, 0.29, 0.34)
			for x in TOP_TUBES:
				var L := _pt(Vector3(x, 13, 22), Vector3(0.88, 0.92, 1.0), 1.0, 95, 0.1)
				L.spec = true
				L.shadow = true
				r.lights.append(L)
			var rim := _dir(Vector3(1, -0.2, -0.5), Vector3(0.34, 0.50, 0.78), 0.5, 0.45)
			rim.rim = 0.9
			r.lights.append(rim)
	return r


## Light reaching a point with normal `n`, unstepped and unexposed, every light steady (the page's lightAt, q 0).
static func light_at(r: Room, w: Vector3, n: Vector3, v: float) -> Vector3:
	var c := r.amb
	for L in r.lights:
		var l := L.p
		var att := 1.0
		if L.point:
			l = L.p - w
			var d2 := l.length_squared()
			l /= sqrt(d2)
			att = 1.0 / (1.0 + d2 * L.ir2)
		att *= L.vw.x + L.vw.y * v / CH
		var nl := n.dot(l)
		var k := maxf(0.0, (nl + L.wrap) / (1.0 + L.wrap)) + L.trans * maxf(0.0, -nl)
		c += L.col * (k * att * L.pw)
	return c


## The page's setRoom over the hall's banners (left edges `bxs`): the exposure that sits the brightest
## banner's face at the room's level, each banner's shadow light and strength, and its rig's light.
static func fit(r: Room, bxs: Array) -> void:
	var best := 0.0
	for bx: int in bxs:
		var l := light_at(r, Vector3(bx + 24, CT + r.tp, 0), Vector3(0, 0, 1), r.tp)
		best = maxf(best, 0.3 * l.x + 0.59 * l.y + 0.11 * l.z)
	r.expo = r.target / best
	var max_a := 0.0
	var atts: Array[float] = []
	r.sh.clear()
	r.rig.clear()
	for bx: int in bxs:
		var pick: Light = null
		var pa := 0.0
		for L in r.lights:
			if L.shadow:
				var dd := Vector3(L.p.x - bx - 24, L.p.y - CT - 50, L.p.z).length()
				var a := 1.0 / (1.0 + pow(dd / L.reach, 2.0)) * L.pw
				if a > pa:
					pa = a
					pick = L
		if pick == null and r.contact:
			pick = _dir(Vector3(0, -0.25, 1), Vector3.ONE, 1.0, 0.0)
			pa = 1.0
		r.sh.append(pick)
		atts.append(pa)
		max_a = maxf(max_a, pa)
		var rl := light_at(r, Vector3(bx + 24, ROD_Y, 0), Vector3(0, -0.6, 0.8), 0.0) * r.expo
		r.rig.append(Vector3(_tenth(rl.x), _tenth(rl.y), _tenth(rl.z)))
	r.sh_s.resize(bxs.size())
	for i in bxs.size():
		r.sh_s[i] = r.shadow * atts[i] / max_a if max_a > 0.0 else 0.0


static func _tenth(v: float) -> float:
	return roundf(clampf(v, 0.15, 1.5) * 10.0) / 10.0


## A furnace's flicker at `t` (the page's fireAt), 1 for a steady light.
static func fire_at(L: Light, t: float) -> float:
	if L.fire < 0.0:
		return 1.0
	var u := t + L.fire
	return 1.0 + 0.10 * sin(TAU * u / 2.9) + 0.07 * sin(TAU * u / 1.7 + 1.1) + 0.05 * sin(TAU * u / 4.3 + 2.0)
