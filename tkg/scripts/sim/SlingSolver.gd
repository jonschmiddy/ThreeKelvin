class_name SlingSolver
extends RefCounted

## Gravity Sling's scripted player: the shot nearest the ring's centre round the deal's good one,
## then the AIM dial turned to it and the sling pulled to its power and let go.
## Why: docs/why/MiniGame.md#gravity-sling

## How close to the centre a first launch must land to score about 1 (`score_hit` 0.967).
const CLOSE := 0.15


## The [angle, power] that hits nearest the centre: round the deal's good shot, wider if need be.
static func shot(g: GameSling) -> Vector2i:
	var sol: Array = g.P.sol
	var best := Vector2i(int(sol[0]), int(sol[1]))
	var best_d := INF
	var tr := float(g.P.tr)
	for span: Vector2i in [Vector2i(3, 9), Vector2i(8, 30), Vector2i(20, 90)]:
		for a in range(maxi(GameSling.AMIN, int(sol[0]) - span.x), mini(GameSling.AMAX, int(sol[0]) + span.x) + 1):
			for pw in range(maxi(GameSling.PMIN, int(sol[1]) - span.y), mini(GameSling.PMAX, int(sol[1]) + span.y) + 1):
				var r := GameSling.sim(g.P, a, pw, 0, false)
				if int(r.end) == GameSling.HIT and float(r.hitD) < best_d:
					best_d = float(r.hitD)
					best = Vector2i(a, pw)
		if best_d < tr * CLOSE:
			break
	return best


static func _dial_at(deg: float) -> Vector2:
	var a := deg * PI / 180.0
	return Vector2(GameSling.DX + 10.0 * cos(a), GameSling.DY - 10.0 * sin(a))


## The dial turned from the game's angle to the shot's in steps of at most 20 degrees, then the
## sling pulled back in two moves and let go.
static func plan(g: GameSling) -> Array[Dictionary]:
	var s := shot(g)
	var out: Array[Dictionary] = []
	var from := float(g.ang)
	out.append({k = "down", p = _dial_at(from)})
	var steps := maxi(1, ceili(absf(s.x - from) / 20.0))
	for i in range(1, steps + 1):
		out.append({k = "move", p = _dial_at(from + (s.x - from) * i / steps), wait = 0.05})
	out.append({k = "up", p = _dial_at(float(s.x)), wait = 0.2})
	var off := 14.0 + (s.y - GameSling.PMIN) * (GameSling.PULLMAX - 14.0) / (GameSling.PMAX - GameSling.PMIN)
	var y := float(GameSling.RY)
	out.append({k = "down", p = Vector2(float(GameSling.PX0), y), wait = 0.1})
	out.append({k = "move", p = Vector2(GameSling.PX0 - off / 2.0, y), wait = 0.15})
	out.append({k = "move", p = Vector2(GameSling.PX0 - off, y), wait = 0.3})
	out.append({k = "up", p = Vector2(GameSling.PX0 - off, y)})
	return out
