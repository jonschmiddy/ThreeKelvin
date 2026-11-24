class_name ShipRoomSolariFx
extends RefCounted

## What flies over the lit room before the hulls (show18's after_room): the pours' splash sparks, the
## hot moulds' embers, the furnaces' embers, furnace 2's roar throwing embers and spill, the stacks'
## clank dust, the quench spray and its steam. Particles are born on the film's hashed schedule.
## Why: docs/why/ShipRoomSolari.md#fx

const C := preload("res://scripts/ui/ShipRoomSolariCycle.gd")
const FOOT := 207.0
const SPARK_COLS: Array[Color] = [Color8(255, 255, 240), Color8(255, 233, 168), Color8(255, 179, 71), Color8(192, 80, 26)]
const EMBER_COLS: Array[Color] = [Color8(255, 214, 120), Color8(255, 150, 50), Color8(210, 90, 30), Color8(130, 50, 22)]
const DUST_COLS: Array[Color] = [Color8(170, 150, 130), Color8(130, 112, 96), Color8(100, 86, 74), Color8(70, 60, 52)]


## show.Emitter: particles at (x, depth from the wall, height), born on a hash that wraps 30 s,
## falling and bouncing (or rising and drifting, embers), stepped at 90 Hz from birth.
class Emitter:
	const DT := 1.0 / 90.0
	var seed := 0
	var rate := 1.0
	var life := Vector2(1, 1)
	var g := 380.0
	var bounce := 0.32
	var rise := false
	var nl := 1
	var clock := NAN
	## [x, d, z, vx, vd, vz, age, life, h4, steps]
	var parts: Array[PackedFloat32Array] = []

	func _init(seed_: int, rate_: float, life_: Vector2, g_: float = 380.0, bounce_: float = 0.32, rise_: bool = false) -> void:
		seed = seed_
		rate = rate_
		life = life_
		g = g_
		bounce = bounce_
		rise = rise_
		nl = int(roundf(C.LOOP * rate))

	func hashes(nn: int) -> PackedFloat32Array:
		var h := PackedFloat32Array()
		for k in 6:
			h.append(fposmod(sin(nn * 12.9898 + seed * 78.233 + k * 37.719) * 43758.5453, 1.0))
		return h

	## Born since the last step (active(tb) -> bool, origin(tb, h) -> (x, d, z), vel(h) -> (vx, vd, vz)).
	func step(t: float, dt: float, active: Callable, origin: Callable, vel: Callable) -> void:
		if is_nan(clock) or absf(t - clock - dt) > 0.5:
			clock = t - life.y
			parts.clear()
		for n in range(int(floorf(clock * rate)) + 1, int(floorf(t * rate)) + 1):
			var tb := n / rate
			var tbm := fposmod(tb, C.LOOP)
			if not active.call(tbm):
				continue
			var h := hashes(posmod(n, nl))
			var lf := life.x + (life.y - life.x) * h[0]
			if t - tb > lf:
				continue
			var o: Vector3 = origin.call(tbm, h)
			var v: Vector3 = vel.call(h)
			parts.append(PackedFloat32Array([o.x, o.y, o.z, v.x, v.y, v.z, t - tb, lf, h[4], 0]))
		clock = t
		var keep: Array[PackedFloat32Array] = []
		for p in parts:
			if p[9] > 0:
				p[6] += dt
			if p[6] > p[7]:
				continue
			_fly(p)
			keep.append(p)
		parts = keep

	func _fly(p: PackedFloat32Array) -> void:
		var want := int(ceilf(p[6] / DT))
		while int(p[9]) < want:
			var s := int(p[9])
			if rise:
				p[5] += (25.0 - 0.6 * p[5]) * DT
				p[3] += (sin((s * DT + p[8] * 6.0) * 2.3) * 14.0 - 0.8 * p[3]) * DT
			else:
				p[5] -= g * DT
			p[0] += p[3] * DT
			p[1] += p[4] * DT
			p[2] += p[5] * DT
			if not rise and p[2] < 0.0 and p[5] < 0.0:
				p[2] = 0.0
				p[5] *= -bounce
				p[3] *= 0.7
				p[4] *= 0.7
			p[9] = s + 1
		p[9] = maxf(p[9], 1)

	func draw(ci: CanvasItem, cols: Array[Color], tracer: bool) -> void:
		for p in parts:
			var u := p[6] / p[7]
			var c := cols[0 if u < 0.15 else (1 if u < 0.4 else (2 if u < 0.7 else 3))]
			var sy := FOOT + p[1] - p[2]
			ci.draw_rect(Rect2(roundf(p[0]), roundf(sy), 1, 1), c)
			if not tracer:
				continue
			var vx := p[3]
			var vy := p[4] - p[5]
			var sp := Vector2(vx, vy).length()
			if sp <= 70.0 or u >= 0.6:
				continue
			for e: Vector2 in [Vector2(1, 0.75), Vector2(2, 0.45)]:
				if sp < 70.0 * e.x:
					break
				var bx := roundf(p[0] - vx / sp * e.x)
				var by := roundf(sy - vy / sp * e.x)
				ci.draw_rect(Rect2(bx, by, 1, 1), Color(c.r * e.y, c.g * e.y, c.b * e.y))


## engine.Particles: sparks in screen rows (gravity down, a floor to bounce on), a 10 s hashed schedule.
class Sparks:
	const DT := 1.0 / 120.0
	var seed := 0
	var rate := 1.0
	var life := Vector2(1, 1)
	var g := 240.0
	var bounce := 0.35
	var clock := NAN
	## [x, y, vx, vy, age, life, steps, floor y]
	var parts: Array[PackedFloat32Array] = []

	func _init(seed_: int, rate_: float, life_: Vector2, g_: float, bounce_: float) -> void:
		seed = seed_
		rate = rate_
		life = life_
		g = g_
		bounce = bounce_

	func step(t: float, dt: float, on: bool, src: Vector2, vel: Callable, floor_at: Callable) -> void:
		if is_nan(clock) or absf(t - clock - dt) > 0.5:
			clock = t
			parts.clear()
		for n in range(int(floorf(clock * rate)) + 1, int(floorf(t * rate)) + 1):
			if not on:
				continue
			var nn := posmod(n, int(roundf(10.0 * rate)))
			var lf := life.x + (life.y - life.x) * C.hash1([seed, nn, 2])
			var v: Vector2 = vel.call(C.hash1([seed, nn]), C.hash1([seed, nn, 1]))
			var age := t - n / rate
			if age <= lf:
				parts.append(PackedFloat32Array([src.x, src.y, v.x, v.y, age, lf, 0, float(floor_at.call(src.x))]))
		clock = t
		var keep: Array[PackedFloat32Array] = []
		for p in parts:
			if p[6] > 0:
				p[4] += dt
			if p[4] > p[5]:
				continue
			var want := int(ceilf(p[4] / DT))
			while int(p[6]) < want:
				p[3] += g * DT
				p[0] += p[2] * DT
				p[1] += p[3] * DT
				if p[1] >= p[7] and p[3] > 0.0:
					p[1] = p[7]
					p[3] *= -bounce
					p[2] *= 0.6
				p[6] += 1
			p[6] = maxf(p[6], 1)
			keep.append(p)
		parts = keep

	func draw(ci: CanvasItem) -> void:
		for p in parts:
			var u := p[4] / p[5]
			var c := SPARK_COLS[0] if u < 0.15 else (SPARK_COLS[1] if u < 0.4 else (SPARK_COLS[2] if u < 0.7 else SPARK_COLS[3]))
			ci.draw_rect(Rect2(roundf(p[0]), roundf(p[1]), 1, 1), c)
			var sp := Vector2(p[2], p[3]).length()
			if u < 0.5 and sp > 40.0:
				var bx := roundf(p[0] - p[2] / sp * 1.2)
				var by := roundf(p[1] - p[3] / sp * 1.2)
				if bx != roundf(p[0]) or by != roundf(p[1]):
					ci.draw_rect(Rect2(bx, by, 1, 1), Color(c.r * 0.7, c.g * 0.7, c.b * 0.7))


## The room, weakly: it owns this.
var _room: WeakRef
var splash: Array[Emitter] = []
var members: Array[Emitter] = []
var clank: Array[Emitter] = []
var fembers := Emitter.new(203, 26.0, Vector2(1.6, 3.2), 380.0, 0.32, true)
var dembers := Emitter.new(206, 40.0, Vector2(1.0, 2.2), 380.0, 0.32, true)
var spill := Emitter.new(204, 60.0, Vector2(0.5, 1.2), 380.0, 0.35)


func _init(r: ShipRoomSolari) -> void:
	_room = weakref(r)
	for j in 6:
		splash.append(Emitter.new(201, 70.0, Vector2(0.25, 0.75), 380.0, 0.32))
		members.append(Emitter.new(202, 22.0, Vector2(1.2, 2.6), 380.0, 0.32, true))
		clank.append(Emitter.new(205, 40.0, Vector2(0.3, 0.6), 200.0, 0.2))


## show18.particles: every emitter's births since the last frame, and the flight of the living.
func step(t: float, dt: float) -> void:
	for j in 6:
		splash[j].step(t, dt, _splash_on.bind(j), _splash_at.bind(j), _splash_v)
		members[j].step(t, dt, _hot.bind(j), _member_at.bind(j), _member_v)
		clank[j].step(t, dt, _clank_on.bind(j), _clank_at.bind(j), _clank_v)
	fembers.step(t, dt, _always, _fember_at, _fember_v)
	dembers.step(t, dt, _roaring, _dember_at, _dember_v)
	spill.step(t, dt, _spilling, _spill_at, _spill_v)


func _splash_on(tb: float, j: int) -> bool:
	var u := C.u_of(j, tb)
	return u >= C.FALL and u < C.P_DUR


func _splash_at(tb: float, h: PackedFloat32Array, j: int) -> Vector3:
	var n := maxi(0, C.fill_of(C.u_of(j, tb)))
	return Vector3(C.TAPS[j] + 0.5 + (h[5] - 0.5) * 3.0, -32.0, 175.0 - (C.IN1 - n + 1))


func _splash_v(h: PackedFloat32Array) -> Vector3:
	return Vector3((h[1] - 0.5) * 150.0, (h[2] - 0.2) * 30.0, 50.0 + 95.0 * h[3])


func _hot(tb: float, j: int) -> bool:
	var u := C.u_of(j, tb)
	return u < C.JIB.lift.x and C.heat_of(u) > 0.55


func _member_at(_tb: float, h: PackedFloat32Array, j: int) -> Vector3:
	return Vector3(C.TAPS[j] - 9.0 + 18.0 * h[5], -32.0, 175.0 - C.IN0 + 1.0)


func _member_v(h: PackedFloat32Array) -> Vector3:
	return Vector3((h[1] - 0.5) * 14.0, 0.0, 14.0 + 20.0 * h[2])


func _clank_on(tb: float, j: int) -> bool:
	var u := C.u_of(j, tb)
	return (u >= C.JIB.lower.y - 0.05 and u < C.JIB.lower.y + 0.1) 		or (u >= C.JIB.notch.y - 0.08 and u < C.JIB.notch.y + 0.05)


func _clank_at(_tb: float, h: PackedFloat32Array, j: int) -> Vector3:
	return Vector3(C.stack_x(j) - 10.0 + 20.0 * h[5], 3.0, 1.0)


func _clank_v(h: PackedFloat32Array) -> Vector3:
	return Vector3((h[1] - 0.5) * 50.0, (h[2] - 0.5) * 6.0, 20.0 + 40.0 * h[3])


func _always(_tb: float) -> bool:
	return true


func _fember_at(_tb: float, h: PackedFloat32Array) -> Vector3:
	return Vector3(C.TAPS[int(h[5] * 6.0) % 6] - 20.0 + 40.0 * h[4], -40.0, FOOT - 40.0 - 135.0 + 10.0 * h[3])


func _fember_v(h: PackedFloat32Array) -> Vector3:
	return Vector3((h[1] - 0.5) * 16.0, 0.0, 10.0 + 20.0 * h[2])


func _roaring(tb: float) -> bool:
	return C.roar_k(tb) > 0.6


func _dember_at(_tb: float, h: PackedFloat32Array) -> Vector3:
	return Vector3(207.0 - 22.0 + 44.0 * h[5], -40.0, FOOT - 40.0 - 114.0 + 6.0 * h[3])


func _dember_v(h: PackedFloat32Array) -> Vector3:
	return Vector3((h[1] - 0.5) * 30.0, 0.0, 30.0 + 40.0 * h[2])


func _spilling(tb: float) -> bool:
	return 0.85 * C.roar_k(tb) >= 0.5


func _spill_at(_tb: float, h: PackedFloat32Array) -> Vector3:
	return Vector3(C.TAPS[1] - 22.0 + 44.0 * h[5], -32.0, 175.0 - 133.0)


func _spill_v(h: PackedFloat32Array) -> Vector3:
	return Vector3((h[1] - 0.5) * 80.0, 10.0 + 40.0 * h[2], -10.0 + 40.0 * h[3])


## The particles, the quench spray and the steam, in show18's order.
func paint(ci: CanvasItem, t: float) -> void:
	var tl := fposmod(t, C.LOOP)
	dembers.draw(ci, EMBER_COLS, false)
	for e in splash:
		e.draw(ci, SPARK_COLS, true)
	for e in members:
		e.draw(ci, EMBER_COLS, false)
	for e in clank:
		e.draw(ci, DUST_COLS, false)
	spill.draw(ci, SPARK_COLS, true)
	fembers.draw(ci, EMBER_COLS, false)
	for j in 6:
		_hose(ci, j, tl)
	for j in 6:
		_steam(ci, j, tl)


## Water arcing from the fixed nozzle on the bed's lip up into the mould, lit by the plate and room.
func _hose(ci: CanvasItem, j: int, tl: float) -> void:
	var u := C.u_of(j, tl)
	if u < C.QUENCH.x or u >= C.QUENCH.y:
		return
	var s := C.SIDE[j]
	var T := C.TAPS[j]
	var sx := float(T + s * 14)
	var ex := float(T + s * 3)
	var tk := int(tl * 10.0)
	for k in 26:
		var v := fposmod(k / 26.0 + tl * 2.4, 1.0)
		var px := sx + (ex - sx) * v + (C.hash1([j, k, tk]) - 0.5) * 2.0
		var py := 175.0 + (166.0 - 175.0) * v - 104.0 * v * (1.0 - v)
		var m := _m(int(roundf(px)), int(roundf(py)))
		var c := Color(196.0 / 255.0 * (0.9 + 0.9 * m.x), 220.0 / 255.0 * (0.9 + 0.9 * m.y), 236.0 / 255.0 * (0.9 + 0.9 * m.z))
		ci.draw_rect(Rect2(roundf(px), roundf(py), 1, 1), c)


## Quench steam: round puffs with lobed edges, born over the quench, boiling up fast and rolling along
## the wall, growing and thinning; a dense core and a thinner rim; lit warm from the plate below.
func _steam(ci: CanvasItem, j: int, tl: float) -> void:
	var u := C.u_of(j, tl)
	if u < C.QUENCH.x or u >= C.QUENCH.y + 5.5:
		return
	var T := float(C.TAPS[j])
	var heat := C.heat_of(u)
	var nb := int((C.QUENCH.y + 1.5 - C.QUENCH.x) * 90.0)
	for i in nb:
		var b := C.QUENCH.x + i / 90.0
		var life := 3.6 + 2.0 * C.hash1([j, i, 3])
		var age := u - b
		if age < 0.0 or age >= life:
			continue
		if b > C.QUENCH.y and C.hash1([j, i, 9]) < 0.55:
			continue
		var v := age / life
		var h1 := C.hash1([j, i])
		var h2 := C.hash1([j, i, 1])
		var h3 := C.hash1([j, i, 2])
		var rise := (70.0 + 120.0 * h2) * (1.0 - pow(1.0 - v, 2.2))
		var px := T + (h1 - 0.5) * 14.0 + (h1 - 0.5) * 40.0 * v + 10.0 * v * v + 5.0 * sin(age * 1.9 + h3 * 6.0)
		var py := C.MY0 - 1 - rise
		var a := pow(1.0 - v, 1.1) * (0.20 + 0.22 * h3)
		var rad := 2.0 + 5.5 * v
		var xi := int(roundf(px))
		var yi := int(roundf(py))
		var m := _m(xi, yi)
		var un := maxf(0.0, heat - 0.08) * 1.6 * maxf(0.0, 1.0 - 2.2 * v)
		var col := Color(clampf((222.0 * clampf(0.75 + 0.9 * m.x, 0.0, 1.5) + 255.0 * un) / 255.0, 0.0, 1.0),
			clampf((212.0 * clampf(0.75 + 0.9 * m.y, 0.0, 1.5) + 150.0 * un) / 255.0, 0.0, 1.0),
			clampf((200.0 * clampf(0.75 + 0.9 * m.z, 0.0, 1.5) + 70.0 * un) / 255.0, 0.0, 1.0))
		ci.draw_colored_polygon(_puff(xi, yi, rad, h1, h2, 1.0), Color(col, 0.5 * a))
		var ac := 1.0 - (1.0 - a) / maxf(1e-3, 1.0 - 0.5 * a)
		ci.draw_colored_polygon(_puff(xi, yi, rad, h1, h2, 0.65), Color(col, ac))


static func _puff(x: int, y: int, rad: float, h1: float, h2: float, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 20:
		var th := TAU * i / 20.0
		var e := rad * k * (1.0 + 0.22 * sin(3.0 * th + 6.28 * h1) + 0.14 * sin(5.0 * th + 6.28 * h2))
		out.append(Vector2(x + 0.5 + cos(th) * e, y + 0.5 + sin(th) * e))
	return out


## Dust drifting through the hall air, seen only in furnace 2's beam while it roars (show.dust).
func paint_dust(ci: CanvasItem, t: float) -> void:
	var tl := fposmod(t, C.LOOP)
	var op := 0.85 * C.roar_k(tl)
	if op <= 0.0:
		return
	for i in 900:
		var x0 := C.hash1([501, i]) * 960.0
		var y0 := 20.0 + C.hash1([502, i]) * 360.0
		if absf(x0 - 206.0) > 50.0 or y0 < 90.0 or y0 > 220.0:
			continue
		var p1 := C.hash1([503, i]) * TAU
		var p2 := C.hash1([504, i]) * TAU
		var kk := 1 + int(C.hash1([505, i]) * 2.0)
		var x := x0 + 9.0 * sin(TAU * kk * tl / C.LOOP + p1) + 6.0 * sin(TAU * 3.0 * tl / C.LOOP + p2)
		var y := y0 + 7.0 * sin(TAU * 2.0 * tl / C.LOOP + p2) - 3.0 * cos(TAU * tl / C.LOOP + p1)
		x = floorf(x / 2.0) * 2.0
		y = floorf(y / 2.0) * 2.0
		if y < 104.0 or y >= FOOT or absf(x - 206.0) >= 30.0:
			continue
		var u := clampf((y - 104.0) / (FOOT - 104.0), 0.0, 1.0)
		var s := 0.34 * op * (1.0 - 0.6 * u) * (1.0 if absf(x - 206.0) < 18.0 else 0.55)
		if s > 0.05:
			ci.draw_rect(Rect2(x, y, 2, 2), Color(1.0, 0.94, 0.8, 0.35 * minf(1.0, s * 3.0)))


func _m(x: int, y: int) -> Vector3:
	var r := _room.get_ref() as ShipRoomSolari
	return r.m_at(x, y) if r != null else Vector3.ONE
