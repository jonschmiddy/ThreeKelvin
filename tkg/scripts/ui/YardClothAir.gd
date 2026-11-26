class_name YardClothAir
extends RefCounted

## What moves the banners (the banner page's wind, stir and pointer, Jon Nov 24): each banner's slow lean
## and turn, the drifting folds and breeze, a gust walking the hall left to right, the pointer's shove, and a
## gentle stir across one banner now and then when nobody points. Frame px; the page's tSim in seconds.
## Why: docs/why/YardBanner.md#pointer

const CW := 48.0
const CH := 100.0
const CT := 38.0
const HS := YardCloth.HS

## This banner's forces, as the sim shader takes them (`YardCloth._step`).
var fa := Vector4.ZERO
var fb := Vector4.ZERO
var fc := Vector4.ZERO

var _bx := PackedFloat32Array()
## Each banner's lean and turn (period s, phase) and fold phase: the page's seven-banner hall (its MAKERS7).
var _lean: Array[Vector2] = []
var _twist: Array[Vector2] = []
var _ph := PackedFloat32Array()
var _n := 0
var _span := 0.0
var _kick := PackedFloat32Array()
var _kdx := PackedFloat32Array()
var _kdy := PackedFloat32Array()
var _was := PackedByteArray()
# the pointer (frame px), its smoothed velocity, the cloth clock it last moved at
var _on := false
var _px := 0.0
var _py := 0.0
var _vx := 0.0
var _vy := 0.0
var _wall := 0.0
var _last_user := -99.0
# the stir
var _idle_next := 6.0
var _idle_on := false
var _idle_t0 := 0.0
var _idle_ci := 0
var _idle_cycle := 0
var _ix0 := 0.0
var _ix1 := 0.0
var _iy0 := 0.0
var _iy1 := 0.0
var _gust_at := 9.0
## The seeded random the page's reference shares (MINSTD), so a film is the same every run.
var _rs := 12345
# this step's pointer on the banner being pushed
var _pp := false
var _pp_real := false
var _pp_x := 0.0
var _pp_y := 0.0
var _pp_s := 0.0
var _pp_dx := 0.0
var _pp_dy := 0.0
var _pp_sp := 0.0
## The banner the pointer shoved this step and how hard (-1 none): its push sound (`YardCloth._step`).
var pushed := -1
var push_k := 0.0


func setup(bx: PackedFloat32Array, n: int) -> void:
	_bx = bx
	_n = n
	_span = (bx[n - 1] - bx[mini(2, n - 1)]) / 70.0 if n > 0 else 0.0
	for i in 7:
		_lean.append(Vector2(8.3 + fmod(i * 1.37, 2.6), fmod(i * 2.1, TAU)))
		_twist.append(Vector2(6.4 + fmod(i * 0.97, 2.5), fmod(i * 1.3 + 0.8, TAU)))
		_ph.append(fmod(i * 2.1, TAU))
	_kick.resize(7)
	_kdx.resize(7)
	_kdy.resize(7)
	_was.resize(7)


func _rnd() -> float:
	_rs = (_rs * 48271) % 2147483647
	return float(_rs) / 2147483647.0


## The page's simStep before the cloths: a stir now and then, the gust, the pointer's speed dying away.
func tick(t: float) -> void:
	if t > _idle_next and t - _last_user > 5.0:
		_idle_ci = _idle_cycle % _n
		_idle_cycle += 1
		var dir := 1.0 if _rnd() < 0.5 else -1.0
		_idle_on = true
		_idle_t0 = t
		_iy0 = CT + 45.0 + _rnd() * 35.0
		_iy1 = _iy0 + 8.0 - _rnd() * 16.0
		var cx := _bx[_idle_ci] + CW / 2.0
		_ix0 = cx - dir * 34.0
		_ix1 = cx + dir * 34.0
		_idle_next = t + 7.0 + _rnd() * 5.0
	if _idle_on and t - _idle_t0 > 1.8:
		_idle_on = false
	# the page lets its gust go 8 s on, past its third banner; here past the seventh
	if t > _gust_at + 8.0 + _span:
		_gust_at = t + 4.0 + _rnd() * 8.0
	_vx *= exp(-HS / 0.15)
	_vy *= exp(-HS / 0.15)


static func _sstep(a: float, b: float, v: float) -> float:
	var u := clampf((v - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func breeze(t: float, ph: float) -> float:
	return 0.5 * sin(TAU * t / 5.3 + ph) + 0.3 * sin(TAU * t / 8.9 + 2.0 * ph) + 0.2 * sin(TAU * t / 13.1 + 3.0 * ph)


func _gust(t: float, cx: float) -> float:
	var dt := t - _gust_at - (cx - YardCloth.GUST_X0 + 40.0) / 70.0
	return exp(-pow(dt / 1.1, 2.0))


## Banner `b`'s forces at `t` (the page's step before its integration): into `fa`, `fb`, `fc`.
func forces(b: int, t: float) -> void:
	var ph := _ph[b]
	var ge := _gust(t, _bx[b] + CW / 2.0) * YardCloth.W_GUST
	var ln := _lean[b]
	var tw := _twist[b]
	var lean := YardCloth.W_LEAN * sin(TAU * t / ln.x + ln.y) + YardCloth.W_BREEZE * 1.2 * breeze(t, ph) + 45.0 * ge
	var twist := YardCloth.W_TWIST * sin(TAU * t / tw.x + tw.y)
	var bz := YardCloth.W_BREEZE * breeze(t * 0.8 + 3.0, ph + 1.0) + 16.0 * ge
	var fold := YardCloth.W_FOLD * (1.0 + 1.2 * ge)
	_pointer_for(b, t)
	# coming onto a banner shoves it the way the hand was moving
	if _pp_real and _was[b] == 0:
		_kick[b] = 1.2 + minf(_pp_sp / 70.0, 2.6)
		_kdx[b] = _pp_dx
		_kdy[b] = _pp_dy
		pushed = b
		push_k = _kick[b]
	_was[b] = 1 if _pp_real else 0
	_kick[b] *= exp(-HS / 0.35)
	var ps := _pp_s + _kick[b] if _pp else 0.0
	var pdx := _pp_s * _pp_dx + _kick[b] * _kdx[b] if _pp else 0.0
	var pdy := _pp_s * _pp_dy + _kick[b] * _kdy[b] if _pp else 0.0
	fa = Vector4(lean, twist, bz, fold)
	fb = Vector4(ph, ps, pdx, pdy)
	fc = Vector4(_pp_x, _pp_y, _bx[b], 0.0)


## The page's pointerFor: the stir's sweep over its banner, else the pointer within 6 px of the cloth.
func _pointer_for(b: int, t: float) -> void:
	_pp = false
	_pp_real = false
	_pp_x = 0.0
	_pp_y = 0.0
	_pp_s = 0.0
	_pp_dx = 0.0
	_pp_dy = 0.0
	_pp_sp = 0.0
	if _idle_on and _idle_ci == b:
		var u := (t - _idle_t0) / 1.8
		if u >= 0.0 and u <= 1.0:
			var e := _sstep(0.0, 1.0, u)
			_pp = true
			_pp_x = _ix0 + (_ix1 - _ix0) * e
			_pp_y = _iy0 + (_iy1 - _iy0) * e
			_pp_s = 0.22 * sin(PI * u)
			_pp_dx = signf(_ix1 - _ix0)
			return
	if not _on:
		return
	var bx := _bx[b]
	if _px < bx - 6.0 or _px > bx + CW + 6.0 or _py < CT - 4.0 or _py > CT + CH + 6.0:
		return
	var sp := sqrt(_vx * _vx + _vy * _vy)
	_pp = true
	_pp_real = true
	_pp_x = _px
	_pp_y = _py
	_pp_sp = sp
	_pp_dx = _vx / sp if sp > 8.0 else 0.0
	_pp_dy = _vy / sp if sp > 8.0 else 0.0
	_pp_s = 0.12 + minf(sp / 90.0, 3.0)


## The page's pointermove, on the cloth's clock.
func move(p: Vector2, now: float, t: float) -> void:
	var dt := now - _wall
	if _on and dt > 0.004:
		var k := minf(1.0, dt / 0.05)
		_vx += (clampf((p.x - _px) / dt, -450.0, 450.0) - _vx) * k
		_vy += (clampf((p.y - _py) / dt, -450.0, 450.0) - _vy) * k
	if dt > 0.004 or not _on:
		_px = p.x
		_py = p.y
		_wall = now
	_last_user = t
	_on = true


## A click is a push of its own, straight in, on the banner it lands on.
func down(p: Vector2, now: float, t: float) -> void:
	_px = p.x
	_py = p.y
	_wall = now
	_vx = 0.0
	_vy = 0.0
	_last_user = t
	_on = true
	for b in _n:
		if p.x > _bx[b] - 6.0 and p.x < _bx[b] + CW + 6.0 and p.y > CT - 4.0 and p.y < CT + CH + 6.0:
			_kick[b] = 2.4
			_kdx[b] = 0.0
			_kdy[b] = 0.0
			_was[b] = 1


func leave() -> void:
	_on = false
