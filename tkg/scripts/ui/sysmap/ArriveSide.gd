class_name ArriveSide
extends RefCounted

## A FLIGHT TO A WORLD ARRIVES ON ITS LIT SIDE, GOING ROUND WITH ITS SPIN (Jon, Nov 11: the
## lit/dark and Shift choice dropped as "too much noise"). The solver is asked for it
## (`FlightSolve`'s ring target: `sense`, `side`, `lit`), and the second click flies the line
## drawn. Why: docs/why/ArriveSide.md#arrive-side

const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
## The side asked: +1 the lit half, -1 the dark (the solver takes either); 0 a free arrival.
const LIT := 1
const DARK := -1


## Toward the light at world i on the plane at t: the map's own rule (`SystemViewS.toward_light_of`,
## which shades the lit half), so the side arrived on is the side that looks lit.
static func lit_dir(L: SystemLayout, i: int, t: float) -> Vector2:
	return SystemViewS.toward_light_of(L, L.bodies[i].pos(t), t)


## The world's spin as the map draws it (`PlanetView`'s spec), 0 LOCKED, under 0 BACKWARD.
static func spin_of(view, L: SystemLayout, i: int) -> float:
	var v: Node2D = view._views.get(i) if view != null else null
	var spec: Dictionary = v.get("spec") if v != null else {}
	if spec.is_empty():
		var b := L.bodies[i]
		if b.world == &"":
			return 0.0
		spec = Worlds.spec(b.world, b.seed, b.r)
	return float(spec.get("spin", 0.0))


## The way round that is WITH the world's spin, as the rail counts it (+1: the plane's angle
## growing, clockwise on screen, the way the worlds go round). The map turns a world's near
## face left for a spin over 0, the same way. A BACKWARD world spins the other way; a LOCKED
## world turns once an orbit, so its spin is its orbit's way. Why: docs/why/ArriveSide.md#spin-sense
static func spin_sense(view, L: SystemLayout, i: int) -> int:
	return -1 if spin_of(view, L, i) < 0.0 else 1


## What a click asks for at world i: the lit side, with its spin, and in a twin the light's
## way (`light_wish`).
static func wish_of(view, L: SystemLayout, i: int) -> Dictionary[String, Variant]:
	var w: Dictionary[String, Variant] = {"side": LIT, "sense": spin_sense(view, L, i)}
	w.merge(light_wish(L, i, float(view.t)))
	return w


## IN A TWIN the shader blends the two suns' light (`SystemView.toward_light_of`), and the pair
## turns, so the solver is handed the light's way at t and how fast it turns (rad/s, read over
## half a second) to carry to the arrival; alone, a sun's world is lit from its host, which the
## solver knows. Why: docs/why/ArriveSide.md#the-light-in-a-twin
static func light_wish(L: SystemLayout, i: int, t: float) -> Dictionary[String, Variant]:
	if not L.twin:
		return {}
	var u := lit_dir(L, i, t)
	var u2 := lit_dir(L, i, t + 0.5)
	return {"lit": u, "lit_w": angle_difference(u.angle(), u2.angle()) / 0.5, "lit_t": t}


## The wish as the map stands: the selected world, pointed at or not (GO-lit, Jon, Nov 11),
## out of another orbit; else none, and the autopilot arrives as it likes.
static func wish_now(overlay, view, flight) -> Dictionary[String, Variant]:
	return wish_for(view, flight, int(overlay.preview_to))


## The wish for a flight to world i, marked `to` i: only that world's flight wears it
## (`ShipFlight._tgt_of`). Belts and stations have no lit side; comets and keeps none.
static func wish_for(view, flight, i: int) -> Dictionary[String, Variant]:
	if i < 0 or i >= view.layout.bodies.size() or view.layout.bodies[i].world == &"":
		return {}
	if flight == null or flight.orbit_body() == i or flight.is_keep(i):
		return {}
	var w := wish_of(view, view.layout, i)
	w["to"] = i
	return w


## The solver's ring target for world i with the wish on it (`ShipFlight._tgt_of`).
static func ring_target(i: int, R: float, V: float, wish: Dictionary) -> Dictionary[String, Variant]:
	var t: Dictionary[String, Variant] = {"kind": &"ring", "place": i, "R": R, "V": V, "sense": int(wish.get("sense", 0))}
	if int(wish.get("side", 0)) != 0:
		t["side"] = int(wish.side)
		for k: String in ["lit", "lit_w", "lit_t"]:
			if wish.has(k):
				t[k] = wish[k]
	return t


## NO FLIGHT REACHES THE SIDE ASKED: the same flight solved with the side let go (the sense
## kept), its choice marked `sdx` with the side it stands in for, so the drawn line is still
## the click's (`plan_matches`). Why: docs/why/ArriveSide.md#when-no-flight-reaches-the-side
static func unsided_solve(G: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, prefer: Dictionary, opts: Dictionary) -> FlightSolve.Result:
	var g: Dictionary[String, Variant] = {}
	g.assign(tgt)
	for k: String in ["side", "lit", "lit_w", "lit_t"]:
		g.erase(k)
	var r := FlightSolve.solve(G, dep, g, t, prefer, opts)
	if r.found:
		r.choice["sdx"] = int(tgt.get("side", 0))
	return r


## The preview's key for a wish: a change plans the line again.
static func key(wish: Dictionary) -> String:
	return "%d:%d" % [int(wish.get("side", 0)), int(wish.get("sense", 0))]


## Whether the plan drawn is the wish's: a solved one by its choice (or the side it stands in
## for); today's planner's plans know no side, so one is the wish's only with no wish.
static func plan_matches(pl, wish: Dictionary) -> bool:
	if pl == null:
		return wish.is_empty()
	var c: Dictionary = pl.choice if pl.res != null else {}
	var side := int(wish.get("side", 0))
	var sided: bool = int(c.get("sd", 0)) == side or int(c.get("sdx", 0)) == side
	return sided and int(c.get("sn", 0)) == int(wish.get("sense", 0))


## The side the ship is on round world i at t, by the solver's own margin: LIT, DARK, or 0 on
## the terminator (a harness reads it).
static func side_now(flight, L: SystemLayout, i: int, t: float) -> int:
	var a := float(flight.rail.get("ang", 0.0))
	var d := Vector2(cos(a), sin(a)).dot(lit_dir(L, i, t))
	if d >= FlightSolve.SIDE_IN:
		return LIT
	return DARK if d <= -FlightSolve.SIDE_IN else 0
