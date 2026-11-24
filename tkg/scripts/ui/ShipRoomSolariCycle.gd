class_name ShipRoomSolariCycle
extends RefCounted

## THE CASTING CYCLE of Solari's bed (show18): one tap opens every 5 s in the order 2 5 3 6 4 1; each
## bay pours, cools, is quenched and its plate lifted by its jib onto its stack, on its own clock u.
## Pure functions of the room's clock, as the film's, so nothing pops when it wraps at 30 s.
## Why: docs/why/ShipRoomSolari.md#cycle

const LOOP := 30.0
const TAPS: Array[int] = [33, 206, 380, 560, 743, 920]
const ORDER: Array[int] = [1, 4, 2, 5, 3, 0]
## Which side of its mould a bay's jib and stack stand (bay 1's out of the picture).
const SIDE: Array[int] = [-1, 1, -1, 1, -1, -1]
const ARM := 34
const FALL := 0.13
const P_DUR := 2.60
const TAIL := 0.13
const QUENCH := Vector2(15.0, 17.0)
const JIB := {out = Vector2(19.0, 20.4), down = Vector2(20.4, 21.0), grip = Vector2(21.0, 21.3),
	lift = Vector2(21.3, 22.1), back = Vector2(22.1, 23.7), lower = Vector2(23.7, 24.7),
	release = Vector2(24.7, 25.0), up = Vector2(25.0, 25.5), notch = Vector2(25.1, 25.5)}
const MW := 22
const MY0 := 162
const MY1 := 172
const IN0 := 164
const IN1 := 171
const PLATE_H := 8
const SPOUT_Y := 139
const ARM_Y := 141
const HOOK_PARK := 156
const HOOK_MOULD := IN0 - 1
const HOOK_LIFT := 152
const STACK_N := 3
const FLOOR := 212
const HOOK_STACK := FLOOR - PLATE_H * STACK_N
const BREATH_N: Array[int] = [17, 13, 19, 11, 15, 23]
const GUTTER_R: Array[int] = [7, 9, 8, 10, 6, 11]
const ROAR_T: Array[float] = [4.2, 22.5, 17.3, 1.6, 26.8, 11.0]


## engine.hash1: the film's own hash, exact (GDScript's floats are the film's doubles).
static func hash1(v: Array) -> float:
	var s := 0.0
	for i in v.size():
		s += (i + 1) * 12.9898 * float(v[i])
	var x := sin(s + 78.233) * 43758.5453
	return x - floorf(x)


static func smooth(v: float) -> float:
	v = clampf(v, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


static func seg(u: float, ab: Vector2) -> float:
	return clampf((u - ab.x) / (ab.y - ab.x), 0.0, 1.0)


static func pour_t(j: int) -> float:
	return 0.8 + 5.0 * ORDER.find(j)


static func u_of(j: int, t: float) -> float:
	return fposmod(t - pour_t(j), LOOP)


## Rows of metal in the mould (0..8); -1 once the plate has been lifted out.
static func fill_of(u: float) -> int:
	if u >= JIB.lift.x:
		return -1
	if u < FALL:
		return 0
	if u < P_DUR + TAIL:
		return mini(PLATE_H, int(floorf((u - FALL) / (P_DUR - FALL - 0.15) * PLATE_H)) + (1 if u >= FALL + 0.05 else 0))
	return PLATE_H


static func heat_of(u: float) -> float:
	if u < 5.0:
		return 1.0
	if u < QUENCH.x:
		return 1.0 - 0.58 * (u - 5.0) / (QUENCH.x - 5.0)
	if u < QUENCH.y:
		return 0.42 - 0.18 * smooth((u - QUENCH.x) / (QUENCH.y - QUENCH.x))
	return maxf(0.0, 0.24 - 0.24 * (u - QUENCH.y) / 12.0)


static func pouring(u: float) -> bool:
	return u < P_DUR + TAIL


static func pour_k(u: float) -> float:
	if u < 0.07:
		return 0.45
	if u < 0.14:
		return 0.75
	if u < P_DUR:
		return 1.0
	if u < P_DUR + TAIL:
		return 0.6
	return 0.0


## A jib's pose: phi 0 over the stack .. PI over the mould, the hook's row, carrying, gripping.
class Jib:
	var phi := 0.0
	var hy := 0
	var carry := false
	var grip := false


static func jib_state(u: float) -> Jib:
	var phi := 0.0
	var hy := float(HOOK_PARK)
	var carry := false
	var grip := false
	if u >= JIB.out.x and u < JIB.out.y:
		phi = PI * smooth(seg(u, JIB.out))
	elif u >= JIB.down.x and u < JIB.down.y:
		phi = PI
		hy = HOOK_PARK + (HOOK_MOULD - HOOK_PARK) * smooth(seg(u, JIB.down))
	elif u >= JIB.grip.x and u < JIB.grip.y:
		phi = PI
		hy = HOOK_MOULD
		grip = seg(u, JIB.grip) > 0.5
	elif u >= JIB.lift.x and u < JIB.lift.y:
		phi = PI
		hy = HOOK_MOULD + (HOOK_LIFT - HOOK_MOULD) * smooth(seg(u, JIB.lift))
		carry = true
		grip = true
	elif u >= JIB.back.x and u < JIB.back.y:
		phi = PI * (1.0 - smooth(seg(u, JIB.back)))
		hy = HOOK_LIFT
		carry = true
		grip = true
	elif u >= JIB.lower.x and u < JIB.lower.y:
		hy = HOOK_LIFT + (HOOK_STACK - HOOK_LIFT) * smooth(seg(u, JIB.lower))
		carry = true
		grip = true
	elif u >= JIB.release.x and u < JIB.release.y:
		hy = HOOK_STACK
		grip = seg(u, JIB.release) < 0.5
	elif u >= JIB.up.x and u < JIB.up.y:
		hy = HOOK_STACK + (HOOK_PARK - HOOK_STACK) * smooth(seg(u, JIB.up))
	var o := Jib.new()
	o.phi = phi
	o.hy = int(roundf(hy))
	o.carry = carry
	o.grip = grip
	return o


static func jib_moving(u: float) -> bool:
	return u >= JIB.out.x and u < JIB.up.y


static func jib_tip_x(j: int, phi: float) -> int:
	var p := TAPS[j] + SIDE[j] * ARM
	return int(roundf(p + SIDE[j] * ARM * cos(phi)))


static func stack_x(j: int) -> int:
	return TAPS[j] + 2 * SIDE[j] * ARM


## A pour's flare on its furnace, in quarters: up over 0.2 s, held, eased back over 2 s.
static func pour_flare(j: int, t: float) -> float:
	var u := u_of(j, t)
	var end := P_DUR + TAIL
	var v := 0.0
	if u < 0.2:
		v = u / 0.2
	elif u < end:
		v = 1.0
	elif u < end + 2.0:
		v = 1.0 - smooth((u - end) / 2.0)
	return floorf(v * 4.0) / 4.0


## Furnace 2's roar, in sixths: builds 6.8-8.3 s, holds to 11.5, dies back by 12.85.
static func roar_k(t: float) -> float:
	t = fposmod(t, LOOP)
	if t >= 6.8 and t < 8.3:
		return (floorf(6.0 * (t - 6.8) / 1.5) + 1.0) / 6.0
	if t >= 8.3 and t < 11.5:
		return 1.0
	if t >= 11.5 and t < 12.85:
		return ceilf(6.0 * (1.0 - (t - 11.5) / 1.35)) / 6.0
	return 0.0


static func fire_k0(i: int, t: float) -> float:
	var per := LOOP / BREATH_N[i]
	var b := 1.0 + 0.07 * sin(TAU * t / per + 1.7 * i)
	var g := 0.95 + 0.09 * hash1([31 + i, floorf(fposmod(t, LOOP) * GUTTER_R[i])])
	var u := fposmod(t - ROAR_T[i], LOOP)
	var r := 0.0
	if u < 0.25:
		r = u / 0.25
	elif u < 1.3:
		r = 1.0
	elif u < 2.2:
		r = 1.0 - (u - 1.3) / 0.9
	r = floorf(r * 4.0) / 4.0
	return b * g * (1.0 + 0.32 * r)


## The furnace's own clock times its pour's flare (brighter, a faster flicker), and furnace 2's roar.
static func fire_k(i: int, t: float) -> float:
	var fl := pour_flare(i, t)
	var k := fire_k0(i, t)
	if fl > 0.0:
		k *= (1.0 + 0.55 * fl) * (0.92 + 0.16 * hash1([70 + i, int(t * 14.0)]))
	if i == 1:
		var r := roar_k(t)
		if r > 0.0:
			k *= (1.0 + 1.1 * r) * (0.9 + 0.2 * hash1([90, int(t * 16.0)]))
	return k
