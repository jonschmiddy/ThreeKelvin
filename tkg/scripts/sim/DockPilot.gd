class_name DockPilot
extends RefCounted

## A scripted Tumble Dock pilot (`MiniSolver`), pressing the game's own thruster buttons: the drift
## first, stopped as its rest point enters the bracket; then the spin tapered a turn ahead and
## stopped as the port's rest point reaches the bracket's near edge, so the clamp latches slowly.
## Why: docs/why/MiniGame.md#tumble-dock

## Degrees of a turn left at one notch after the taper, and how far inside the bracket's edge to stop.
const RUN_IN := 12.0
const RUN_SPAN := 30.0
const EDGE := 1.0


static func act(g: GameDock) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s: Dictionary = g.S
	if s.over or g.is_done():
		return out
	var p: Dictionary = g.P
	var lag: float = p.lag
	var settled := true
	if int(p.drift) != 0:
		var d := _drift(s, p, lag)
		if d != "":
			_press(out, g, d)
		settled = int(s.vk) == 0 and absf(s.vx) < 0.3
	var w := _spin(s, p, lag, settled)
	if w != "":
		_press(out, g, w)
	return out


## The slide to press now, or "": stop once the rest point is in the bracket, turn back if it drifts away.
static func _drift(s: Dictionary, p: Dictionary, lag: float) -> String:
	var x: float = s.x
	var vk: int = s.vk
	var win := 1.0 if int(p.sway) != 0 else GameDock.TOLX - 0.6
	var rest := x + float(s.vx) * lag
	var back := "left" if vk > 0 else "right"
	if vk != 0:
		if absf(rest) <= win or signi(vk) != int(signf(-x)) or absi(vk) > 1:
			return back
	elif absf(s.vx) < 0.5 and absf(rest) > win + 0.5:
		return "right" if x < 0.0 else "left"
	return ""


## The turn to press now, or "": one notch left a turn ahead, then stop for the bracket's near edge.
static func _spin(s: Dictionary, p: Dictionary, lag: float, settled: bool) -> String:
	var e := GameDock.err(s)
	var tol: float = p.tol
	var wk: int = s.wk
	var w: float = s.w
	var back := "ccw" if wk > 0 else "cw"
	if wk == 0:
		if absf(w) < 1.0 and absf(GameDock.wrap180(e + w * lag)) > tol - 0.2:
			return "ccw" if e > 0.0 else "cw"
		return ""
	if absi(wk) > 1:
		var sg := float(signi(wk))
		var d := fposmod(sg * (-sg * (tol - EDGE) - e), 360.0)
		var dec := (absf(w) - GameDock.STEP) * lag
		return back if settled and d >= dec + RUN_IN and d <= dec + RUN_IN + RUN_SPAN else ""
	return back if absf(GameDock.wrap180(e + w * lag)) <= tol - EDGE else ""


static func _press(out: Array[Dictionary], g: GameDock, what: String) -> void:
	var at := g.btn_at(what)
	out.append({k = "down", p = at})
	out.append({k = "up", p = at})
