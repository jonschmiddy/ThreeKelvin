class_name MapGravity
extends RefCounted

## WHAT PULLS A SHIP IN A SYSTEM, on map time, and what its autopilot must keep
## out of (ruling 20, Oct 30: "Prototype: twin:A giant:A"). Pure data: no Nodes,
## no textures, nothing changed after it is built, so one can be shared by a
## `FlightSolve` on a `WorkerThreadPool` task.
##
## THE PULL. One star holds still at the origin. TWO TURN (ruling 23, Jon, Nov
## 1, "Orbiting pair"): both circle the pair's balance point at the layout's
## `pair_n` (`SystemLayout.spin_pair`, four times Kepler), each where
## `SystemLayout.star_pos` has it at map time t (`sx`, `sz`), and every world
## round one of them is carried with it (`wo_hs`, `pl_hs`). Together they pull
## with `SystemLayout.GM_SHIP` in every system, star A with `star_share` of it.
## A giant pulls with its own `Body.gm` (gm_frac of GM_SHIP) and moves on its
## circle while the ship flies, exactly (`orbit`, `period`, `phase` about its
## centre). Worlds, stations and belts pull nothing. Flying by hand never reads this (Jon, Oct 3: the sun's pull made
## flying "clumsy and awkward").
##
## THE KEEP-OUT, in plane px from each centre:
## - a star: the larger of `L.keep_clear_of(p)` and the sun's drawn radius at
##   the zoom the layout is fitted to, plus STAR_MARGIN 6 (`keep_out_star`);
## - a giant: its drawn radius r + GIANT_MARGIN 3;
## - every other world (planets): its disc, r + WORLD_MARGIN 8, as
##   `ShipFlight._clean` keeps them. They pull nothing; they are only in the way.
##   (A flight's own departure and target world keep less: `FlightSolve`.)
##
## Positions and pulls are 64-bit scalars throughout (GDScript's float):
## Vector2 and Vector3 are 32-bit in Godot 4, too coarse for the finite
## differences the planner takes.
##
## Built from a layout with `from_layout`, or by hand for a harness with
## `add_star`, `add_giant`, `add_world` and `add_place`.

const STAR_MARGIN := 6.0
const GIANT_MARGIN := 3.0
const WORLD_MARGIN := 8.0
## The frame the map is laid out in before it has a size (`SystemMapScreen._fit_zoom`).
const FRAME := Vector2(655.0, 420.0)
## The sun's least drawn radius, screen px (`SystemView.STAR_FLOOR`), and the
## map's slant (`SystemView.TILT`).
const STAR_FLOOR := 10.0
const TILT := 0.38
const PULSAR_OPEN_K := 4.0 / 3.0

## The stars: place id (-1, SystemLayout.STAR_B), where AT MAP TIME 0 (named
## for its time: where a star is at t is `sx(k, t)`, `sz(k, t)`), pull,
## keep-out.
var star_id := PackedInt32Array()
var star_x0 := PackedFloat64Array()
var star_z0 := PackedFloat64Array()
var star_gm := PackedFloat64Array()
var star_keep := PackedFloat64Array()
## THE PAIR'S TURN: each star's circle -- its centre (the balance point), its
## signed radius along the pair's line (star B's side positive, star A's
## negative, as `SystemLayout._pair_r`; 0 holds it still at star_x0/star_z0) and
## the pair's angle at t = 0 (one for both: they are on one line) -- and the
## pair's one rate, rad/s (0 alone or held still).
var star_cx := PackedFloat64Array()
var star_cz := PackedFloat64Array()
var star_rad := PackedFloat64Array()
var star_ph := PackedFloat64Array()
var pair_n := 0.0
## The giants (bodies with gm > 0): which body, their circle, pull, keep-out.
var gi_body := PackedInt32Array()
var gi_hx := PackedFloat64Array()
var gi_hz := PackedFloat64Array()
var gi_orb := PackedFloat64Array()
var gi_n := PackedFloat64Array()
var gi_ph := PackedFloat64Array()
var gi_gm := PackedFloat64Array()
var gi_keep := PackedFloat64Array()
## (its drawn radius, under the keep-out)
var gi_r := PackedFloat64Array()
## WHAT EACH CIRCLE'S CENTRE RIDES WITH, giants, worlds and places alike: the
## index of the star it is carried round with (a world round one sun of a
## turning pair), or -1 for a centre that holds still at its hx, hz. Where it
## is at t is `hx_at(hs, hx, t)`, `hz_at(hs, hz, t)`: hx, hz are its place at
## t = 0.
var gi_hs := PackedInt32Array()
## The other worlds' discs, in the way but pulling nothing.
var wo_body := PackedInt32Array()
var wo_hx := PackedFloat64Array()
var wo_hz := PackedFloat64Array()
var wo_orb := PackedFloat64Array()
var wo_n := PackedFloat64Array()
var wo_ph := PackedFloat64Array()
var wo_keep := PackedFloat64Array()
var wo_r := PackedFloat64Array()
var wo_hs := PackedInt32Array()
## EVERY PLACE a flight can leave from or go to, by body index: the centre of
## its circle, its radius, rate (rad/s) and angle at t = 0. A belt's place is
## the point its beacon rides (as `ShipFlight.center` has it).
var pl_hx := PackedFloat64Array()
var pl_hz := PackedFloat64Array()
var pl_orb := PackedFloat64Array()
var pl_n := PackedFloat64Array()
var pl_ph := PackedFloat64Array()
var pl_hs := PackedInt32Array()
## How far out the system reaches; a flight further than 1.6 times this is lost.
var edge := 930.0
## The conic guesses' centres: each star, and in a twin the pair's balance
## point with their whole pull (`FlightSolve` seeds).
var twin := false
var bary := Vector2.ZERO


static func from_layout(L: SystemLayout) -> MapGravity:
	var G := MapGravity.new()
	G.edge = L.edge
	G.twin = L.twin
	G.bary = L.bary
	for p in L.stars():
		var at := L.star_pos(p, 0.0)
		G.add_star(p, at.x, at.y, L.star_gm(p), keep_out_star(L, p))
	# THE PAIR TURNS: both suns on its circle round the balance point
	if L.twin and L.pair_n != 0.0:
		G.pair_n = L.pair_n
		for k in G.star_id.size():
			G.star_cx[k] = L.bary.x
			G.star_cz[k] = L.bary.y
			G.star_rad[k] = L._pair_r(G.star_id[k])
			G.star_ph[k] = L.pair_ph
	for b in L.bodies:
		var hs := G.star_index(b.host_id) if b.hr != 0.0 else -1
		G.add_place(b.host0.x, b.host0.y, b.orbit, b.period, b.phase, hs)
		if b.gm > 0.0:
			G.add_giant(b.index, b.host0.x, b.host0.y, b.orbit, b.period, b.phase, b.gm, b.r + GIANT_MARGIN, b.r, hs)
		elif b.world != &"":
			G.add_world(b.index, b.host0.x, b.host0.y, b.orbit, b.period, b.phase, b.r + WORLD_MARGIN, b.r, hs)
	return G


## STAR k's PLACE AT t (x, z; k its index here, `star_index`), exactly as
## `SystemLayout.star_pos` has it but in 64 bits; one that holds still is at
## star_x0, star_z0 at every t.
func sx(k: int, t: float) -> float:
	if star_rad[k] == 0.0:
		return star_x0[k]
	return star_cx[k] + star_rad[k] * cos(star_ph[k] + pair_n * t)


func sz(k: int, t: float) -> float:
	if star_rad[k] == 0.0:
		return star_z0[k]
	return star_cz[k] + star_rad[k] * sin(star_ph[k] + pair_n * t)


## Star k's motion at t (px/s): 0 for one that holds still.
func svx(k: int, t: float) -> float:
	return -star_rad[k] * pair_n * sin(star_ph[k] + pair_n * t)


func svz(k: int, t: float) -> float:
	return star_rad[k] * pair_n * cos(star_ph[k] + pair_n * t)


## The centre of a circle at t: carried with star hs, or (hs -1) still at its
## t = 0 place hx (hz).
func hx_at(hs: int, hx: float, t: float) -> float:
	return hx if hs < 0 else sx(hs, t)


func hz_at(hs: int, hz: float, t: float) -> float:
	return hz if hs < 0 else sz(hs, t)


## THE ZOOM A SYSTEM OPENS AT (`SystemMapScreen._fit_zoom`, its frame before
## layout, 655 x 420): the edge with a margin in the frame.
static func open_zoom(L: SystemLayout) -> float:
	return clampf(minf(FRAME.x / (2.0 * (L.edge + 20.0)), FRAME.y / (2.0 * (L.edge + 20.0) * TILT + 60.0)), 0.1, 1.0)


## THE ZOOM A STAR'S KEEP-OUT IS MEASURED AT: the layout's own `fit_zoom` (the
## opening zoom with no signed job and no Hellbender out) where the layout has
## one, else the opening zoom. A job or the Hellbender out past the edge opens
## the map further out and draws the suns wider, but moves no ring: measured
## there, the keep-out grew past a twin star's close orbit in 44 of 1,710 stars
## with the Hellbender in, by up to 3.9 px, so nothing could fly to or from it
## (planner review, Oct 30). So it is the layout's, and a sun drawn wider while
## one is out may be crossed by up to that much.
static func keep_zoom(L: SystemLayout) -> float:
	var fz: Variant = L.get(&"fit_zoom")
	if fz != null and float(fz) > 0.0:
		return float(fz)
	return open_zoom(L)


## A STAR'S KEEP-OUT, plane px from its centre: the larger of the layout's
## keep-clear and the sun as drawn at `keep_zoom` plus STAR_MARGIN. Drawn
## (`SystemView._star_k_raw`, not LEGACY): a sun at sqrt((r z)^2 + 10^2) screen
## px, eased up to its floor; the black hole at r max(z, 1); a pulsar at 4/3 r
## (`PULSAR_OPEN_K` at the zoom it opens at). Screen px over the zoom is plane
## px across the map (the slant only shortens it top to bottom). A one-star
## sun of r 16 in a system of edge 930 opens at z 0.345: drawn 11.4 screen px,
## 33.1 plane px, 39.1 with the margin, under its keep-clear 48. A twin's
## keep-clear is this already (the layout's `_twin_ladder`), so there the two
## agree exactly: its close orbit (`star_rail_of`) is 2 px outside it.
## THE BLACK HOLE keeps a flight out of its lens, not its disc: STAR_MARGIN
## inside its close orbit (`star_rail_of`, 150, set there because "the black
## hole's lens reaches far past its disc"), 144. Kept to its disc as drawn
## (52 px) the solved flights dove across the shadow and the lens -- 33 of 252
## of the core's flights from the game's starts inside 150 px, 8 under 70,
## where today's planner never came inside 161 (the one-sun review, Oct 31) --
## and the Custodian's ENGAGE flies there in every won run.
static func keep_out_star(L: SystemLayout, p: int) -> float:
	var z := keep_zoom(L)
	var r := L.star_radius(p)
	var drawn := 0.0
	match L.star_kind_of(p):
		SystemLayout.StarKind.CORE:
			drawn = r * maxf(z, 1.0)
			return maxf(maxf(L.keep_clear_of(p), drawn / z + STAR_MARGIN), L.star_rail_of(p) - STAR_MARGIN)
		SystemLayout.StarKind.PULSAR:
			drawn = r * PULSAR_OPEN_K
		_:
			drawn = sqrt(pow(r * z, 2.0) + STAR_FLOOR * STAR_FLOOR)
	return maxf(L.keep_clear_of(p), drawn / z + STAR_MARGIN)


## (still, at x, z: `from_layout` sets a turning pair's circles after)
func add_star(id: int, x: float, z: float, gm: float, keep: float) -> void:
	star_id.append(id)
	star_x0.append(x)
	star_z0.append(z)
	star_gm.append(gm)
	star_keep.append(keep)
	star_cx.append(x)
	star_cz.append(z)
	star_rad.append(0.0)
	star_ph.append(0.0)


## (r: the drawn radius under the keep-out, which a flight to or from this
## giant keeps at the least; -1 means keep - GIANT_MARGIN; hs the star its
## centre is carried with, -1 none)
func add_giant(body: int, hx: float, hz: float, orbit: float, period: float, phase: float, gm: float, keep: float, r: float = -1.0, hs: int = -1) -> void:
	gi_body.append(body)
	gi_hx.append(hx)
	gi_hz.append(hz)
	gi_orb.append(orbit)
	gi_n.append(TAU / period if period > 0.0 else 0.0)
	gi_ph.append(phase)
	gi_gm.append(gm)
	gi_keep.append(keep)
	gi_r.append(r if r >= 0.0 else keep - GIANT_MARGIN)
	gi_hs.append(hs)


## (r as for `add_giant`; -1 means keep - WORLD_MARGIN; hs as there)
func add_world(body: int, hx: float, hz: float, orbit: float, period: float, phase: float, keep: float, r: float = -1.0, hs: int = -1) -> void:
	wo_body.append(body)
	wo_hx.append(hx)
	wo_hz.append(hz)
	wo_orb.append(orbit)
	wo_n.append(TAU / period if period > 0.0 else 0.0)
	wo_ph.append(phase)
	wo_keep.append(keep)
	wo_r.append(r if r >= 0.0 else keep - WORLD_MARGIN)
	wo_hs.append(hs)


## A place's circle, in body order (`from_layout` adds one for every body); hs
## as for `add_giant`.
func add_place(hx: float, hz: float, orbit: float, period: float, phase: float, hs: int = -1) -> void:
	pl_hx.append(hx)
	pl_hz.append(hz)
	pl_orb.append(orbit)
	pl_n.append(TAU / period if period > 0.0 else 0.0)
	pl_ph.append(phase)
	pl_hs.append(hs)


## The star with place id p, or -1.
func star_index(p: int) -> int:
	for k in star_id.size():
		if star_id[k] == p:
			return k
	return -1


## THE PULL at (x, z) at map time t, px/s^2: [ax, az]. The planner inlines this
## sum for speed (`FlightSolve._integrate`); this is the reference it is held to.
func acc(x: float, z: float, t: float) -> PackedFloat64Array:
	var ax := 0.0
	var az := 0.0
	for k in star_x0.size():
		var dx := sx(k, t) - x
		var dz := sz(k, t) - z
		var r2 := dx * dx + dz * dz
		var f := star_gm[k] / (r2 * sqrt(r2))
		ax += f * dx
		az += f * dz
	for k in gi_hx.size():
		var a := gi_ph[k] + gi_n[k] * t
		var dx := hx_at(gi_hs[k], gi_hx[k], t) + gi_orb[k] * cos(a) - x
		var dz := hz_at(gi_hs[k], gi_hz[k], t) + gi_orb[k] * sin(a) - z
		var r2 := dx * dx + dz * dz
		var f := gi_gm[k] / (r2 * sqrt(r2))
		ax += f * dx
		az += f * dz
	return PackedFloat64Array([ax, az])


## Giant k's centre at t: [x, z].
func giant_at(k: int, t: float) -> PackedFloat64Array:
	var a := gi_ph[k] + gi_n[k] * t
	return PackedFloat64Array([hx_at(gi_hs[k], gi_hx[k], t) + gi_orb[k] * cos(a), hz_at(gi_hs[k], gi_hz[k], t) + gi_orb[k] * sin(a)])


## THE LEAST MARGIN to every keep-out at (x, z) at t, px (negative: inside one).
func margin(x: float, z: float, t: float) -> float:
	var least := INF
	for k in star_x0.size():
		var qx := sx(k, t)
		var qz := sz(k, t)
		least = minf(least, sqrt((x - qx) * (x - qx) + (z - qz) * (z - qz)) - star_keep[k])
	for k in gi_hx.size():
		var a := gi_ph[k] + gi_n[k] * t
		least = minf(least, sqrt(pow(x - hx_at(gi_hs[k], gi_hx[k], t) - gi_orb[k] * cos(a), 2.0) + pow(z - hz_at(gi_hs[k], gi_hz[k], t) - gi_orb[k] * sin(a), 2.0)) - gi_keep[k])
	for k in wo_hx.size():
		var a := wo_ph[k] + wo_n[k] * t
		least = minf(least, sqrt(pow(x - hx_at(wo_hs[k], wo_hx[k], t) - wo_orb[k] * cos(a), 2.0) + pow(z - hz_at(wo_hs[k], wo_hz[k], t) - wo_orb[k] * sin(a), 2.0)) - wo_keep[k])
	return least


## THE SAME, LEAVING OUT THE KEEP-OUTS OF THE BODIES IN `own` (a flight's
## departure and target: the solver keeps their keep-outs only to the rings it
## leaves and lands on, `FlightSolve._setup`), every sun's always in. What a
## test measures a found flight against (SolveTest, FlightTest, review 2).
func margin_but(x: float, z: float, t: float, own: Array) -> float:
	var least := INF
	for k in star_x0.size():
		var qx := sx(k, t)
		var qz := sz(k, t)
		least = minf(least, sqrt((x - qx) * (x - qx) + (z - qz) * (z - qz)) - star_keep[k])
	for k in gi_hx.size():
		if own.has(gi_body[k]):
			continue
		var a := gi_ph[k] + gi_n[k] * t
		least = minf(least, sqrt(pow(x - hx_at(gi_hs[k], gi_hx[k], t) - gi_orb[k] * cos(a), 2.0) + pow(z - hz_at(gi_hs[k], gi_hz[k], t) - gi_orb[k] * sin(a), 2.0)) - gi_keep[k])
	for k in wo_hx.size():
		if own.has(wo_body[k]):
			continue
		var a := wo_ph[k] + wo_n[k] * t
		least = minf(least, sqrt(pow(x - hx_at(wo_hs[k], wo_hx[k], t) - wo_orb[k] * cos(a), 2.0) + pow(z - hz_at(wo_hs[k], wo_hz[k], t) - wo_orb[k] * sin(a), 2.0)) - wo_keep[k])
	return least
