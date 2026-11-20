class_name KelvinPilot
extends RefCounted

## A scripted Four Kelvin pilot (`MiniSolver`): it steers for the next ore it has not taken, else
## the lane's middle ahead, holding a modest speed, by the keys a player presses (W, A, D).
## Why: docs/why/MiniGame.md#tests

const AHEAD := 40.0
const CRUISE := 26.0
const GAIN := 1.4


static func act(g: GameFourKelvin) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if g.fired or g.mode == "end":
		return out
	var s: Dictionary = g.s
	var x: float = s.x
	var y: float = s.y
	# where to aim: the nearest ore ahead in reach, else the lane ahead
	var tx := x + AHEAD
	var ty := GameFourKelvin.cen(g.F.nodes, tx)
	for q: Dictionary in g.F.glints:
		if not q.got and float(q.x) > x - 2.0 and float(q.x) < x + 70.0:
			tx = maxf(float(q.x), x + 6.0)
			ty = q.y
			break
	var want := Vector2(CRUISE, clampf((ty - y) * GAIN, -CRUISE, CRUISE))
	var err := want - Vector2(s.vx, s.vy)
	var press := {"w": false, "a": false, "d": false}
	if err.length() > 2.0:
		var face := g.facing()
		var d := wrapf(err.angle() - face, -PI, PI)
		if d > 0.12:
			press.d = true
		elif d < -0.12:
			press.a = true
		press.w = absf(d) < 0.5
	for k: String in press:
		if bool(press[k]) != bool(g.keys[k]):
			out.append({k = "key" if press[k] else "keyup", key = StringName(k)})
	return out
