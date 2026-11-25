class_name TouchdownPilot
extends RefCounted

## A scripted Touchdown player (`MiniSolver`), through the two buttons and the pointer as a player
## would. In the nucleus's turning frame it steers over the middle of the ice with the main thruster
## (pulsed, pointed along the ground), and holds the brake to keep its fall under a speed that shrinks
## with height, coming straight down slowly once it sits over the middle moving with the ground.
## Why: docs/why/MiniGame.md#touchdown

## Waits this long on the start card before its first press (the film reads it).
const WAIT := 1.0
## Steering: the share of the thruster a move is planned at, the approach's gains.
const A_SHARE := 0.3
const KP := 1.2
const KV := 2.5
## Falling: the speed at the ground, the share of the brake's spare push planned on, the gain near
## the ground, the brake's band either side of the speed wanted.
const VF := 0.6
const B_SHARE := 0.5
const KH := 1.5
const BAND := 0.15
## Over the ice it hovers this high until it sits over the middle; over rock this far clear of it.
const HOVER := 8.0
const CLEAR := 6.0
## The pointer sits this far from the probe along the push.
const REACH := 20.0
## Each game's pulse accumulator and its last clock, by instance.
static var _st := {}


static func act(g: GameTouchdown, careless := false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var key := g.get_instance_id()
	if g.is_done() or g.over:
		_st.erase(key)
		return out
	if not g.started:
		if g.t >= WAIT:
			# the first press is the brake, under the probe (the run starts on it)
			var p0 := Vector2(g.prx, g.pry + 12.0).floor() + Vector2(0.5, 0.5)
			out.append({k = "move", p = p0})
			if not careless:
				out.append({k = "down", p = p0, b = 2})
			else:
				out.append({k = "down", p = p0})
		return out
	var st: Dictionary = _st.get(key, {acc = 0.0, gt = g.gt})
	var dt := maxf(0.0, g.gt - float(st.gt))
	st.gt = g.gt
	var f := frame(g)
	# steering: the push wanted along the ground, pulsed on and off to its share of the thruster
	var at := steer(g, f)
	var frac := clampf(absf(at) / g.THR, 0.0, 1.0)
	st.acc = float(st.acc) + frac * dt
	var thrust := float(st.acc) >= 0.5 * dt and g.fuel > 0.0 and dt > 0.0
	if thrust:
		st.acc = float(st.acc) - dt
	st.acc = clampf(float(st.acc), -dt, dt)
	_st[key] = st
	var dir: Vector2 = (f.ut as Vector2) * signf(at)
	var p := aim(g, dir)
	out.append({k = "move", p = p})
	if thrust != g.hold:
		out.append({k = "down" if thrust else "up", p = p})
	if not careless:
		var want := g.brake
		var vr_want := fall(g, f)
		if f.vr < vr_want - BAND:
			want = true
		elif f.vr > vr_want + BAND:
			want = false
		if want != g.brake:
			out.append({k = "down" if want else "up", p = p, b = 2})
	return out


## The probe in the nucleus's polar frame: radius, unit out and along, speed out, speed along
## relative to the turning ground at its radius, the error along the ground to the patch's middle.
static func frame(g: GameTouchdown) -> Dictionary:
	var rx := g.prx - GameTouchdown.CX
	var ry := g.pry - GameTouchdown.CY
	var r := GameSling.hyp(rx, ry)
	var ur := Vector2(rx / r, ry / r)
	var ut := Vector2(-ur.y, ur.x)
	var v := Vector2(g.prvx, g.prvy)
	var vt := v.dot(ut)
	var th := atan2(ry, rx)
	var e := GameTouchdown.wrap_a(th - (g.TP + g.rot))
	return {r = r, ur = ur, ut = ut, vr = v.dot(ur), vt = vt, u = vt - g.SPIN * r, e = e * r, th = th}


## The push wanted along the ground (px/s/s): toward the patch's middle near time-optimally, its
## speed matched to the ground's, the turning frame's own push as it falls taken out.
static func steer(g: GameTouchdown, f: Dictionary) -> float:
	var e: float = f.e
	var a := A_SHARE * g.THR
	var u_des := -signf(e) * minf(sqrt(2.0 * a * absf(e)), KP * absf(e))
	var om := float(f.vt) / float(f.r)
	return KV * (u_des - float(f.u)) + float(f.vr) * (om + g.SPIN)


## The speed out wanted (negative: falling): down to the ice once over its middle, else down to a
## hover clear of what is under it.
static func fall(g: GameTouchdown, f: Dictionary) -> float:
	var r: float = f.r
	var r_land := g.RP + GameTouchdown.FOOT
	var miss := maxf(0.0, absf(float(f.e)) - 0.6) * 3.0 + maxf(0.0, absf(float(f.u)) - 0.6) * 2.0
	var r_t := r_land + minf(HOVER, miss)
	# over rock, clear of the highest ground near it
	var th: float = f.th
	var top := 0.0
	for k in range(-4, 5):
		top = maxf(top, g.rad(th + k * 0.08 - g.rot))
	if absf(float(f.e)) / r > g.HW:
		r_t = maxf(r_t, top + GameTouchdown.FOOT + CLEAR)
	var h := r - r_t
	if h <= 0.0:
		return 0.0 if r_t > r_land + 0.01 else -VF
	var ab := B_SHARE * (g.BRK - g.G0)
	return -(VF + minf(sqrt(2.0 * ab * h), KH * h))


## The pointer along `dir` from the probe, kept on the glass (a pixel's middle).
static func aim(g: GameTouchdown, dir: Vector2) -> Vector2:
	var L := REACH
	var p := Vector2(g.prx, g.pry) + dir * L
	while L > 3.0 and (p.x < 0.0 or p.x > GameTouchdown.W - 1 or p.y < GameTouchdown.PY or p.y > GameTouchdown.H - 1):
		L -= 1.0
		p = Vector2(g.prx, g.pry) + dir * L
	p.x = clampf(p.x, 0.0, GameTouchdown.W - 1.0)
	p.y = clampf(p.y, GameTouchdown.PY, GameTouchdown.H - 1.0)
	return p.floor() + Vector2(0.5, 0.5)
