class_name TorchPilot
extends RefCounted

## A scripted Cutting Torch player (`MiniSolver`), the prototype's own test bot through the game's
## taps: follow the clean loop one point at a time, and wait where a pulsing line ahead is live.
## Why: docs/why/MiniGame.md#tests


static func act(g: GameTorch) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s: Dictionary = g.S
	if s.over or s.torch == null or not g.path.is_empty():
		return out
	var lp: Array = g.P.loop
	var k: int = g.get_meta(&"pilot_k", 1)
	if k > lp.size() + 2:
		return out
	var tgt: Vector2 = lp[mini(k, lp.size()) % lp.size()]
	var tp: Vector2 = s.torch
	var d := (tgt - tp).length()
	if d > 0.0:
		var ahead := tp + (tgt - tp) / d * 6.0
		for l: Dictionary in g.P.lines:
			if not l.pulse:
				continue
			var dd := TorchSim.poly_dist(l.pts, ahead.x, ahead.y) - float(l.half)
			var here := TorchSim.poly_dist(l.pts, tp.x, tp.y) - float(l.half)
			if dd < TorchSim.TR + 5.0 and here >= TorchSim.TR:
				var f := 0.0
				while f <= 0.45:
					if TorchSim.live(l, float(s.t) + f):
						return out
					f += 0.05
	g.set_meta(&"pilot_k", k + 1)
	out.append({k = "down", p = tgt / 2.0})
	out.append({k = "up", p = tgt / 2.0})
	return out
