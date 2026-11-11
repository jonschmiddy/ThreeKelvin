class_name FlightTurn
extends RefCounted

## Two legs round one sun where the target is behind the ship's motion: one straight burn
## turned past a right angle runs the ship's speed down to a cusp (`FlightSolve._waypoints`,
## here as FlightSolve.gd is at its length cap). Only where one leg found nothing.
## Why: docs/why/FlightTurn.md#turn-around-waypoints

## the target is behind the motion: its bearing more than this off the ship's way (rad)
const BEHIND := PI * 0.5
## the first leg's turn off the motion, each tried in turn (rad)
const LEG1_TURN := [PI * 110.0 / 180.0, PI * 95.0 / 180.0, PI * 80.0 / 180.0]
## the waypoint's half-angle at the ship at most (rad): past it the apex runs far off
const PHI_MAX := PI * 70.0 / 180.0
## the ship this slow (px/s, the flight's clock) has no way to turn round from
const V_MIN := 2.0 * FlightSolve.V_CUSP


## Waypoints for a target behind the ship's motion, best first; none otherwise. Each is the
## apex of the isosceles triangle on the ship-to-target line, on the motion's side, so the
## first leg turns by LEG1_TURN and the second by twice the apex's half-angle.
static func waypoints(G: MapGravity, dep: Dictionary, tgt: Dictionary, t: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if G.star_x0.size() != 1:
		return out
	var fs := FlightSolve.new()
	fs.G = G
	fs.t_now = t
	if not fs._setup_in(dep, tgt):
		return out
	var pd := fs._dep_pos(t)
	var v := _dep_vel(fs, t)
	fs._tgt_at(t + FlightSolve.CHAIN_T)
	var pt := Vector2(fs._cx + fs._toffx, fs._cz + fs._toffz)
	var line := pt - pd
	if v.length() < V_MIN or line.length() < 1.0:
		return out
	var th := v.angle_to(line)
	if absf(th) <= BEHIND:
		return out
	# (rotating the line toward the motion by phi: the first leg's turn is |th| - phi)
	var side := signf(th)
	var star := Vector2(G.star_x0[0], G.star_z0[0])
	var keep := G.star_keep[0] * FlightSolve.CHAIN_CLEAR
	var e := FlightSolve.CHAIN_EDGE * G.edge
	for t1: float in LEG1_TURN:
		var phi := absf(th) - t1
		if phi <= 0.0 or phi > PHI_MAX:
			continue
		var W := pd + line.rotated(-side * phi) * (0.5 / cos(phi))
		if W.length() > e or W.distance_to(star) < keep:
			continue
		out.append(W)
	return out


## The ship's velocity as it leaves (round its ring, alongside, or free).
static func _dep_vel(fs: FlightSolve, t: float) -> Vector2:
	if fs._dk == 2:
		return Vector2(fs._dvx, fs._dvz)
	fs._dep_at(t)
	if fs._dk == 1:
		return Vector2(fs._cvx, fs._cvz)
	return Vector2(fs._cvx - fs._dw * fs._drt * sin(fs._dang), fs._cvz + fs._dw * fs._drt * cos(fs._dang))
