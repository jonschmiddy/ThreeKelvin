class_name SystemLayout
extends RefCounted

## Derived from `Rng.derive` and the node's facts, never saved: same system, same layout.
## Ported rule for rule from the approved system-map mockup (`layout()` in `template.html`).
## Why: docs/why/SystemLayout.md#layout-rules

## Three times the old spread (Jon), so there is room to fly between worlds.
const HI := 900.0
const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

## The star's look: a sun, a red hypergiant, a blue hypergiant, a pulsar, the
## core's black hole.
enum StarKind { ORDINARY, RED, BLUE, PULSAR, CORE }

## The star's drawn radius, and how deep its well sinks the fabric under it.
const STAR_R := {StarKind.ORDINARY: 16.0, StarKind.RED: 48.0, StarKind.BLUE: 24.0, StarKind.PULSAR: 3.0, StarKind.CORE: 16.0}
const STAR_MASS := {StarKind.ORDINARY: 46.0, StarKind.RED: 62.0, StarKind.BLUE: 56.0, StarKind.PULSAR: 66.0, StarKind.CORE: 110.0}

## KAPPA times the Kepler GM: on map time a ship flies about 100 times faster than worlds.
## Only autopilot flights feel it. Flying by hand has no gravity (Jon, Oct 3).
## Why: docs/why/SystemLayout.md#ship-gravity
const GM_KEPLER := 61.685
const KAPPA := 3376.0
const GM_SHIP := 208250.0
## A GIANT'S WEIGHT against its star (ruling 20: "1/4 - 1/10 ... purely because
## it's more fun"), rolled per giant; every autopilot flight feels it.
const GIANT_MIN := 0.10
const GIANT_MAX := 0.25
## Star B takes -4, which no other place id uses. Test with `is_star`/`is_place`, never `>= -1`.
const STAR_B := -4

## Star A's mass share is capped: a higher share shrinks star B's steady zone.
## Measured on 1,633 twins (Oct 30): a 0.58 cap left none past 380 px, 0.60 left 5%.
## Why: docs/why/SystemLayout.md#two-suns
const TWIN_SHARE_LO := 0.52
const TWIN_SHARE_HI := 0.58
## A pair whose worlds will not fit is moved apart by `_twin` until they do.
## Measured: none past 380 px in 5,014 twins (Oct 30).
## Why: docs/why/SystemLayout.md#two-suns
const TWIN_SEP_LO := 320.0
const TWIN_SEP_HI := 380.0
## One binary in three, rolled off its own stream (`is_close`) so wide pairs keep their draws.
## Numbers are option B of the binary-kinds sheet (Jon, Nov 1); SystemTest checks the gaps.
## Why: docs/why/SystemLayout.md#close-pair
const CLOSE_SHARE := 1.0 / 3.0
const CLOSE_SEP_LO := 150.0
const CLOSE_SEP_HI := 170.0
## (`open_zoom`'s floor: every ring a close pair's ladder can have is at most its
## size here, `_close`)
const ZOOM_FLOOR := 0.1
## Star B stays within 40 degrees of the level line: higher, the slant reads two suns as one.
const TWIN_TURN := 0.6981317
## Farthest steady orbit round one star of a pair (Holman and Wiegert 1999, circular orbits).
const HW_0 := 0.464
const HW_MU := 0.380
## Where in that zone a world round one star goes: 0.70 to 0.90 of the limit.
const S_LO := 0.70
const S_HI := 0.90
## Holman and Wiegert's circumbinary limit, never under the build's 2.423.
## The formula peaks at 2.434, so 2.423 alone sat inside it for star A above about 0.555.
## Why: docs/why/SystemLayout.md#two-suns
const P_LIMIT := 2.423
const HW_P0 := 1.60
const HW_P1 := 4.12
const HW_P2 := 5.09
const P_MARGIN := 1.03
## Kept close: every pixel out shrinks the whole map at its opening zoom.
const P_SPREAD := 1.25
## A pair world's ring is 20 px: the prototype's 38.4 did not fit the 70 to 105 px steady zone.
const S_RING := 20.0
## Keep-out, close orbit and ring are fitted to `fit_zoom`, so a job or Hellbender moves nothing.
## The first fit left the close orbit inside the drawn sun (layout review, Oct 30).
## Why: docs/why/SystemLayout.md#twin-star-ladder
const TWIN_KEEP := 10.0
const RING_OUT := 6.0
const TWIN_RIDE := 2.0
const TWIN_TAKE := 2.0
## How far a world's ring keeps from its star's close-orbit ring (px).
const RING_CLEAR := 8.0
## Counted as drawn: `SystemView` holds sizes in 2 px blocks, so true sizes gave 2.75 px, not 4.
## Why: docs/why/SystemLayout.md#twin-side-gap
const SIDE_GAP := 3.0
## `SystemView.HOLD_PX`: a held size moves to the nearest block only once the
## true size is this far from it; and the sun's least held radius.
const HOLD_PX := 1.4
const SUN_LEAST := 2.0
## The drawing constants the twins' numbers are fitted to (`SystemView`, `SystemMapScreen`).
const SUN_FLOOR := 10.0
const WORLD_MIN_R := 10.0
const WORLD_FLOOR := 5.0
const S_WORLD_MOST := 12.0
const FIT_FRAME := Vector2(655.0, 420.0)
## In a twin, zones go by light, not index. 380 and 600 px match a one-star system's index rule.
## Why: docs/why/SystemLayout.md#twin-zones
const ZONE_NEAR := 380.0
const ZONE_FAR := 600.0

## Worlds by distance out: scorched and burning close in, living in the middle, frozen far.
const POOLS := [
	[&"lava", &"iron", &"desert", &"rock", &"toxic", &"cracked", &"volcanic", &"scorched", &"carbonA", &"carbonB", &"eyeball"],
	[&"verdant", &"ocean", &"desert", &"iron", &"rock", &"toxic", &"crystal", &"hurricane", &"haze", &"biolum", &"aurora", &"lightning", &"swamp", &"eyeball", &"carbonC"],
	[&"ice", &"moon", &"rock", &"ice", &"crystal", &"europa", &"carbonC", &"rogue"],
]
const GIANTS := [&"banded", &"icegiant", &"storm", &"violet"]
## A giant close in is a hot one, glowing or boiling away.
const HOT_GIANTS := [&"hotjup", &"comet"]
const CORE_WORLDS := [&"moon", &"rock", &"lava", &"crystal", &"shattered", &"cracked", &"scorched"]
const PULSAR_WORLDS := [&"iron", &"rock", &"moon", &"scorched", &"shattered"]
const BELT_KINDS := ["ROCK AND METAL", "ICE AND DUST", "CARBON, DARK", "NICKEL-IRON"]


## One beacon: an option of the system's, the station's DOCK, or the core's custodian.
class Beacon extends RefCounted:
	var opt: int = -1
	var dock: bool = false
	var core: bool = false
	## The Hellbender, anchored here (or dead here: its wreck's place).
	var hellbender: bool = false


class Body extends RefCounted:
	## planet, giant, belt, station, derelict, contact
	var kind: StringName = &"planet"
	var beacons: Array[Beacon] = []
	var orbit: float = 0.0
	## Seconds for one turn round the star.
	var period: float = 1.0
	## Where on its orbit it starts, in radians.
	var phase: float = 0.0
	## 0 near, 1 middle, 2 far: which pool its world is drawn from.
	var zone: int = 0
	var index: int = 0
	var name: String = ""
	## The planet painter's world, for a planet or a giant; empty otherwise.
	var world: StringName = &""
	## The painter's seed for this world.
	var seed: int = 0
	## Drawn radius in game pixels.
	var r: float = 0.0
	## Round a pulsar only the bare, scorched cores of planets survive.
	var scorched: bool = false
	## What a belt is made of, for its panel.
	var comp: String = ""
	## The dent it makes in the fabric: how deep, and how wide.
	var mass: float = 0.0
	var well_w: float = 10.0
	## Its ring: let go inside it slow enough and you are on its orbit
	## (`ShipFlight`). Worlds only; 0 for everything else.
	var soi: float = 0.0
	## Centre at map time 0, named for its time so nobody takes it for where it is now.
	## The pair turns (ruling 23, Jon, Nov 1): use `host_at(t)` for the live centre.
	## Why: docs/why/SystemLayout.md#body-centres
	var host0: Vector2 = Vector2.ZERO
	## Which: -1 star A, STAR_B star B, -9 both (round the balance point).
	var host_id: int = -1
	## The centre's own circle round the balance point, set where `star_pos` puts its sun.
	var hc: Vector2 = Vector2.ZERO
	var hr: float = 0.0
	var hn: float = 0.0
	var hph: float = 0.0
	## The pull a ship feels from it (px^3/s^2): a giant's, `gm_frac` of the
	## stars' whole GM_SHIP; 0 for every other body (worlds pull nothing).
	var gm: float = 0.0
	## A giant's weight against its star(s), 0 for others. `mass` and `soi` do not follow it.
	var gm_frac: float = 0.0

	## Where it is at time `t`, on the plane: x across, z toward the viewer.
	## Its footprint on the plane: where it is at time t, x across, z toward the viewer.
	func pos(t: float) -> Vector2:
		var p := point3(t)
		return Vector2(p.x, p.z)

	## Every world is on the plane: tilted orbits do not work on a flat plane here (Jon).
	func point3(t: float) -> Vector3:
		return orbit_point(phase + t / period * TAU, t)

	## The point at angle `a` on its circle as the circle is at time t (a world
	## round one sun of a turning pair: round where its sun is then).
	func orbit_point(a: float, t: float) -> Vector3:
		if hr == 0.0 or t == 0.0:
			return Vector3(host0.x + cos(a) * orbit, 0.0, host0.y + sin(a) * orbit)
		var h := host_at(t)
		return Vector3(h.x + cos(a) * orbit, 0.0, h.y + sin(a) * orbit)

	## THE CENTRE OF ITS CIRCLE AT t: `host0` but for a world round one sun of a
	## turning pair, carried round the balance point with its sun.
	func host_at(t: float) -> Vector2:
		if hr == 0.0 or t == 0.0:
			return host0
		var a := hph + hn * t
		return hc + Vector2(cos(a), sin(a)) * hr

	## How fast its centre moves at t (plane px/s): zero but where it is carried.
	func host_vel(t: float) -> Vector2:
		if hr == 0.0:
			return Vector2.ZERO
		var a := hph + hn * t
		return Vector2(-sin(a), cos(a)) * (hr * hn)

	## How fast it moves at t (plane px/s): round its circle, and with its
	## centre where that is carried.
	func vel(t: float) -> Vector2:
		var a := phase + t / period * TAU
		var n := TAU / period
		return Vector2(-sin(a), cos(a)) * (orbit * n) + host_vel(t)


var star: StarKind = StarKind.ORDINARY
var star_r: float = 16.0
var star_mass: float = 46.0
var bodies: Array[Body] = []
## Events on the star itself (red or blue star): open from a close orbit, as body -1.
var star_beacons: Array[Beacon] = []
## How far out the outermost orbit reaches, plus a margin: from star A, round
## whatever centre each body circles.
var edge: float = HI + 30.0
## Opening zoom with no job and no Hellbender, which come and go and must move nothing.
## Twin rings and the autopilot keep-out use it, so a posted job cannot move the keep-out.
## Why: docs/why/SystemLayout.md#fit-zoom
var fit_zoom: float = 0.0

## Star A is `star` at the origin at t 0, B at `star2_at0`. The pair turns (ruling 23, Jon, Nov 1).
## With `twin` false every field keeps its one-star value.
## Why: docs/why/SystemLayout.md#two-suns
var twin: bool = false
var star2: StarKind = StarKind.ORDINARY
var star2_r: float = 0.0
## Star B's place at map time 0, the pair as it was laid out. Named for its time
## so a reader that wants "where star B is" cannot take it by mistake.
var star2_at0: Vector2 = Vector2.ZERO
## Star A's share of the stars' mass (1 alone); star B has the rest.
var star_share: float = 1.0
## The pair's balance point, which worlds round both stars circle. It holds
## still at every t: the pair turns round it.
var bary: Vector2 = Vector2.ZERO
## The stars' distance apart (0 alone).
var sep: float = 0.0
## Every body goes round both suns, none round one. False alone and in a wide pair.
var close: bool = false
## The pair's turn (`spin_pair`): rate, B's angle at t 0, A's distance from the balance point.
var pair_n: float = 0.0
var pair_ph: float = 0.0
var pair_ra: float = 0.0
## Each star's close-orbit rail, ring and keep-clear, set where the layout is
## built (`star_rail_of`). A one-star system keeps today's numbers.
var _rail := {}
var _ring := {}
var _keep := {}


static func is_star(p: int) -> bool:
	return p == -1 or p == STAR_B


## A place a ship can be at: a body, star A or star B.
static func is_place(p: int) -> bool:
	return p >= -1 or p == STAR_B


## A star's name: the system's own for one star, 'A' and 'B' suffixes for a pair. Lays out nothing.
func star_title(n: MapGen.MapNode, p: int = -1) -> String:
	var s := MapGen.star_name(n)
	if not twin:
		return s
	return s + (" B" if p == STAR_B else " A")


## The stars a system has, as places: [-1] or [-1, STAR_B].
func stars() -> Array[int]:
	var out: Array[int] = [-1]
	if twin:
		out.append(STAR_B)
	return out


## Star p at map time t. `t` has no default: a caller must say which moment it means.
## Why: docs/why/SystemLayout.md#star-positions
func star_pos(p: int, t: float) -> Vector2:
	if pair_n == 0.0 or t == 0.0:
		return star2_at0 if p == STAR_B else Vector2.ZERO
	var a := pair_ph + pair_n * t
	return bary + Vector2(cos(a), sin(a)) * _pair_r(p)


## How fast star p moves at t (plane px/s): zero alone or held still.
func star_vel(p: int, t: float) -> Vector2:
	if pair_n == 0.0:
		return Vector2.ZERO
	var a := pair_ph + pair_n * t
	return Vector2(-sin(a), cos(a)) * (_pair_r(p) * pair_n)


## For frames that turn with the pair (co-op spots, LOCAL's band): rotate by -pair_angle(t).
func pair_angle(t: float) -> float:
	return pair_ph + pair_n * t


## Signed distance of star p from the balance point. `Body.hr` is the same for a carried world.
func _pair_r(p: int) -> float:
	return (sep - pair_ra) if p == STAR_B else -pair_ra


func star_radius(p: int) -> float:
	return star2_r if p == STAR_B else star_r


func star_kind_of(p: int) -> StarKind:
	return star2 if p == STAR_B else star


## The pull a ship feels from star p (px^3/s^2).
func star_gm(p: int) -> float:
	return GM_SHIP * ((1.0 - star_share) if p == STAR_B else star_share)


## In a twin the rail is the orbit to ride, 2 px outside the keep-out, and the ring 2 px past it.
## One star keeps today's numbers. There, ring - 8 would sit inside a twin's keep-out.
## Why: docs/why/SystemLayout.md#star-rail
func star_rail_of(p: int = -1) -> float:
	if _rail.has(p):
		return _rail[p]
	if star == StarKind.CORE:
		return 150.0
	return star_radius(p) + 44.0


## (a twin's ring is set on its own, TWIN_TAKE past the rail: 35 would not fit
## inside its world's orbit)
func star_ring_of(p: int = -1) -> float:
	if _ring.has(p):
		return _ring[p]
	return star_rail_of(p) + 35.0


## One star: star_r + 32. A twin: the drawn sun at `fit_zoom` plus RING_OUT, the autopilot keep-out.
func keep_clear_of(p: int = -1) -> float:
	if _keep.has(p):
		return _keep[p]
	return star_radius(p) + 32.0


## The farthest steady orbit round one star of a pair, as a share of the
## separation; `mu` is the OTHER star's share (Holman and Wiegert 1999).
static func s_limit(mu: float) -> float:
	return HW_0 - HW_MU * mu


## Nearest steady orbit round both, as a share of the separation. Never under P_LIMIT.
static func p_limit(mu: float) -> float:
	return maxf(P_LIMIT, HW_P0 + HW_P1 * mu - HW_P2 * mu * mu)


## Largest drawn size while `SystemView` holds sizes in 2 px blocks, never under `least`.
static func held_most(raw: float, least: float) -> float:
	return maxf(maxf(roundf(raw / 2.0) * 2.0, floorf((raw + HOLD_PX) / 2.0) * 2.0), ceilf(least / 2.0) * 2.0)


## Mirrors `SystemMapScreen._fit_zoom` before layout. A wide pair opens nearer, on `pair_box`.
static func open_zoom(edge: float) -> float:
	return clampf(minf(FIT_FRAME.x / (2.0 * (edge + 20.0)), FIT_FRAME.y / (2.0 * (edge + 20.0) * SLANT + 60.0)), ZOOM_FLOOR, 1.0)


## A wide pair opens framed on its own part (Jon, Nov 1): fitted to all, worlds sat 5 px off a sun.
## Framed on the pair they sit 28 to 45 px off. Empty for one sun and for a close pair.
## Why: docs/why/SystemLayout.md#pair-box
func pair_box(t: float) -> Rect2:
	if not twin or close:
		return Rect2()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in stars():
		lo = lo.min(star_pos(p, t) - Vector2.ONE * star_radius(p))
		hi = hi.max(star_pos(p, t) + Vector2.ONE * star_radius(p))
	for b in bodies:
		if is_star(b.host_id):
			var rr := b.orbit + reach_of(b)
			lo = lo.min(b.host_at(t) - Vector2.ONE * rr)
			hi = hi.max(b.host_at(t) + Vector2.ONE * rr)
	var c := (lo + hi) * 0.5
	var half := Vector2.ZERO
	for p in stars():
		half = half.max((star_pos(p, t) - c).abs() + Vector2.ONE * (star_radius(p) + PAIR_SUN_PAD))
	for b in bodies:
		if is_star(b.host_id):
			half = half.max((b.host_at(t) - c).abs() + Vector2.ONE * (b.orbit + reach_of(b)))
	half += Vector2.ONE * PAIR_PAD
	return Rect2(c - half, half * 2.0)


## (the room `pair_box` leaves past each sun's disc, and all round it: plane px)
const PAIR_SUN_PAD := 30.0
const PAIR_PAD := 30.0


## A sun's drawn radius on screen (game px) at zoom z: the floor the map eases
## it up to (`SystemView._star_k_raw`, every style).
static func sun_drawn(r: float, z: float) -> float:
	return sqrt(pow(r * z, 2.0) + SUN_FLOOR * SUN_FLOOR)


## A planet's drawn radius on screen (game px) at zoom z (`SystemView._draw_r_raw`).
static func world_drawn(b: Body, z: float) -> float:
	return maxf(maxf(b.r, WORLD_MIN_R) * z, WORLD_FLOOR)


## One in three, off its own stream so nothing else a system rolls moves (Jon, Nov 1).
static func is_close(n: MapGen.MapNode) -> bool:
	var force := _close_force()
	if force != 0:
		return force > 0
	return Rng.derive(&"binary_kind", n.index).randf() < CLOSE_SHARE


## Harness switch: `-- twin=close` or `twin=wide`; 1 close, -1 wide, 0 follows the command line.
static var close_force := 0


static func _close_force() -> int:
	if close_force != 0:
		return close_force
	for a in OS.get_cmdline_user_args():
		if a == "twin=close":
			return 1
		if a == "twin=wide":
			return -1
	return 0


static func star_kind(n: MapGen.MapNode) -> StarKind:
	if n.type == MapGen.NodeType.CORE:
		return StarKind.CORE
	if n.type == MapGen.NodeType.PULSAR:
		return StarKind.PULSAR
	match n.star:
		MapGen.Star.RED:
			return StarKind.RED
		MapGen.Star.BLUE:
			return StarKind.BLUE
	return StarKind.ORDINARY


## The layout of node `n`. Cheap enough to call whenever it is wanted: a few
## dozen draws, no allocation worth caching.
static func of(n: MapGen.MapNode) -> SystemLayout:
	OptionTable.ensure(n)
	var R := Rng.derive(&"system", n.index)
	var L := SystemLayout.new()
	L.star = star_kind(n)
	L.star_r = STAR_R[L.star]
	L.star_mass = STAR_MASS[L.star]
	# TWO SUNS where the node has them, and only where it may (`MapGen.twin_ok`)
	L.twin = n.twin and MapGen.twin_ok(n)
	# and which kind of binary (`is_close`)
	L.close = L.twin and is_close(n)

	# what each option wants to sit on
	var want: Array = []
	# An event whose text has the giant in the sky sits on the giant, a red-star glare on the star.
	var on_giant: Array[int] = []
	var giant_here := n.gas_giant and L.star != StarKind.PULSAR
	var hot_star := L.star == StarKind.RED or L.star == StarKind.BLUE
	# A SIGNED JOB'S EVENT (`OptionTable.is_job`) is laid out after everything
	# else, past the last orbit, so posting it moves nothing already there
	var jobs: Array[int] = []
	for i in n.options.size():
		if OptionTable.is_job(n.options[i]):
			jobs.append(i)
			continue
		var site := StringName(OptionTable.by_id(n.options[i]).get("site", &""))
		if site == &"giant" and giant_here and on_giant.is_empty():
			on_giant.append(i)
			continue
		if site == &"star" and hot_star and L.star_beacons.is_empty():
			var sb := Beacon.new()
			sb.opt = i
			L.star_beacons.append(sb)
			continue
		var tags: Array = OptionTable.by_id(n.options[i]).get("tags", [])
		var k := &"planet"
		if tags.has(&"fight") and not tags.has(&"salvage"):
			k = &"contact"
		elif tags.has(&"salvage") and tags.has(&"hazard"):
			k = &"belt"
		elif tags.has(&"salvage"):
			k = &"derelict" if R.randf() < 0.5 else &"belt"
		elif tags.has(&"hazard"):
			k = &"belt"
		want.append([i, k])

	# Few bodies are fine (Jon): options share a world half the time, the planet only if none.
	var order: Array = []
	if n.type == MapGen.NodeType.STATION:
		order.append({"kind": &"station", "r": 4.0})
	for w in want:
		if w[1] == &"planet":
			order.append({"kind": &"planet", "opt": w[0]})
		else:
			order.append({"kind": w[1], "opt": w[0], "r": 3.0 if w[1] == &"derelict" else 0.0})
	if not order.any(func(o): return o.kind == &"planet"):
		order.insert(0, {"kind": &"planet"})
	# A world round each sun, always: the flight between them is why a twin exists.
	# Close pairs get it too: the sheet's numbers were measured with it (43 vs 35 of 55).
	# Why: docs/why/SystemLayout.md#twin-worlds
	if L.twin and order.filter(func(o): return o.kind == &"planet").size() < 2:
		for k in order.size():
			if order[k].kind == &"planet":
				order.insert(k + 1, {"kind": &"planet"})
				break
	if n.gas_giant and L.star != StarKind.PULSAR:
		order.insert(mini(order.size(), 2 + int(R.randf() * 2.0)), {"kind": &"giant", "also": on_giant})
	var has_belt := order.any(func(o): return o.kind == &"belt")
	if not has_belt:
		var roll := R.randf()
		if roll < 0.33 or L.star == StarKind.CORE or L.star == StarKind.PULSAR:
			order.insert(1 + int(R.randf() * float(order.size() - 1)), {"kind": &"belt"})

	# one belt holds every option that wanted a belt
	var belt: Body = null
	for o in order:
		if o.kind == &"belt" and belt != null:
			if o.has("opt"):
				var bb := Beacon.new()
				bb.opt = o.opt
				belt.beacons.append(bb)
			continue
		var b := Body.new()
		b.kind = o.kind
		b.r = float(o.get("r", 0.0))
		if o.has("opt"):
			var bo := Beacon.new()
			bo.opt = o.opt
			b.beacons.append(bo)
		for extra in o.get("also", []):
			var be := Beacon.new()
			be.opt = int(extra)
			b.beacons.append(be)
		if b.kind == &"belt":
			belt = b
		L.bodies.append(b)
	if L.star == StarKind.CORE:
		var cb := Body.new()
		cb.kind = &"contact"
		var bcore := Beacon.new()
		bcore.core = true
		cb.beacons.append(bcore)
		L.bodies.append(cb)
	if n.type == MapGen.NodeType.STATION:
		for b in L.bodies:
			if b.kind == &"station":
				var bd := Beacon.new()
				bd.dock = true
				b.beacons.append(bd)
	if L.twin:
		if L.close:
			_close(L, n, R, jobs)
		else:
			_twin(L, n, R, jobs)
		_weigh_giant(L, n)
		spin_pair(L)
		return L

	# where each body falls, out from the star: which pool its world comes from
	for i in L.bodies.size():
		var f := 0.0 if L.bodies.size() == 1 else float(i) / float(L.bodies.size() - 1)
		L.bodies[i].zone = 0 if f < 0.34 else (1 if f < 0.7 else 2)
		L.bodies[i].index = i

	# what each world is
	_worlds(L, n, R)
	# Orbits at least as far apart as their bodies are wide: even spacing overlapped by 24 px.
	# First orbit clear of the star at the map's slant (Jon), then spaced by ratio.
	# Why: docs/why/SystemLayout.md#orbit-spacing
	var lo := L.star_r + (62.0 if L.star == StarKind.RED else (84.0 if L.star == StarKind.CORE else 46.0))
	lo = maxf(lo, (L.star_r + CLEAR) / SLANT)
	# First orbit scaled to the wider system (Jon): at 900 it sat at a ninth, now a quarter.
	lo = maxf(lo, HI * (0.32 if L.star == StarKind.RED or L.star == StarKind.CORE else 0.27))
	var star_ring := L.star_ring_of(-1)
	var sysname := MapGen.star_name(n)
	var short := " ".join(sysname.split(" ").slice(0, 2))
	var last := -INF
	var last_reach := 0.0
	for i in L.bodies.size():
		var b := L.bodies[i]
		var f := (float(i) + 0.5 + (R.randf() - 0.5) * 0.7) / float(L.bodies.size())
		var want_at := lo * pow(HI / lo, f)
		var reach := reach_of(b)
		if i > 0:
			want_at = maxf(want_at, last + last_reach + reach + GAP)
		if b.world != &"":
			want_at = maxf(want_at, star_ring + soi_of(b) + RING_GAP)
		b.orbit = want_at
		b.period = kepler_s() * pow(b.orbit / 100.0, 1.5) * (0.95 + R.randf() * 0.1)
		b.phase = R.randf() * TAU
		b.name = "%s %s" % [short, ROMAN[mini(i, ROMAN.size() - 1)]]
		last = b.orbit
		last_reach = reach
	L.edge = maxf(HI, last + last_reach) + 30.0
	L.fit_zoom = open_zoom(L.edge)
	# Job targets are added last on their own stream, so worlds seen before signing do not move.
	for k in jobs.size():
		var jr := Rng.derive(&"job_place", n.index * 8 + k)
		var jb := _job_body(L, n, jobs[k], jr)
		var at := maxf(HI, last + last_reach) + reach_of(jb) + GAP + 24.0
		if jb.world != &"":
			at += soi_of(jb)
		jb.orbit = at
		jb.period = kepler_s() * pow(jb.orbit / 100.0, 1.5) * (0.95 + jr.randf() * 0.1)
		jb.phase = jr.randf() * TAU
		jb.name = "%s %s" % [short, ROMAN[mini(jb.index, ROMAN.size() - 1)]]
		L.bodies.append(jb)
		last = jb.orbit
		last_reach = reach_of(jb) + (soi_of(jb) if jb.world != &"" else 0.0)
		L.edge = jb.orbit + last_reach + 30.0
	# THE HELLBENDER'S OWN PLACE, past every orbit and last in the list, so
	# nothing else moves when it comes or goes
	if hellbender_here(n):
		var hb := _hellbender_body(L, n)
		hb.orbit = maxf(HI, last + last_reach) + reach_of(hb) + GAP + 24.0
		hb.period = kepler_s() * pow(hb.orbit / 100.0, 1.5)
		hb.phase = float(Rng.derive(&"hellbender_place", n.index).randf()) * TAU
		hb.name = "%s %s" % [short, ROMAN[mini(hb.index, ROMAN.size() - 1)]]
		L.bodies.append(hb)
		L.edge = hb.orbit + reach_of(hb) + 30.0
	# EACH WORLD'S RING, sized by how much it weighs (giants biggest, small rocks
	# least) and spread for the wider system; nothing else has one
	for b in L.bodies:
		if b.world != &"":
			b.soi = soi_of(b)
	_weigh_giant(L, n)
	return L


## Zone is set first: by index round one star, by distance from the light round two.
static func _worlds(L: SystemLayout, n: MapGen.MapNode, R: RandomNumberGenerator) -> void:
	for b in L.bodies:
		b.seed = n.index * 31 + b.index * 7 + 1
		if b.kind == &"planet":
			var pool: Array = POOLS[b.zone]
			var w: StringName = pool[int(R.randf() * pool.size())]
			if b.zone == 1 and (n.development == MapGen.Development.CITY or n.development == MapGen.Development.CAPITAL) and R.randf() < 0.6:
				w = &"megacity" if n.development == MapGen.Development.CAPITAL and R.randf() < 0.5 else &"city"
			# now and then, a world broken to pieces
			if R.randf() < 0.025:
				w = &"shattered"
			if L.star == StarKind.CORE:
				w = CORE_WORLDS[int(R.randf() * CORE_WORLDS.size())]
			if L.star == StarKind.PULSAR:
				w = PULSAR_WORLDS[int(R.randf() * PULSAR_WORLDS.size())]
				b.scorched = true
			b.world = w
			# a broken world is drawn bigger, so its pieces read
			if w == &"shattered":
				b.r = 10.0 + R.randf() * 2.0
			elif b.scorched:
				b.r = 3.5 + R.randf() * 2.5
			else:
				b.r = 5.0 + R.randf() * 4.0 + (1.5 if b.zone == 1 else 0.0)
		elif b.kind == &"giant":
			if b.zone == 0:
				b.world = HOT_GIANTS[int(R.randf() * HOT_GIANTS.size())]
			else:
				b.world = &"banded" if R.randf() < 0.5 else GIANTS[int(R.randf() * GIANTS.size())]
			b.r = 15.0 + R.randf() * 4.0
		elif b.kind == &"belt":
			b.comp = "RUBBLE, GLAZED BY THE BEAM" if L.star == StarKind.PULSAR else BELT_KINDS[int(R.randf() * BELT_KINDS.size())]
		match b.kind:
			&"giant":
				b.mass = 24.0
				b.well_w = 34.0
			&"planet":
				b.mass = 3.0 + b.r * 0.9
				b.well_w = 14.0 + b.r * 1.6
			&"station":
				b.mass = 1.2
				b.well_w = 9.0
			&"derelict":
				b.mass = 0.8
				b.well_w = 8.0


## A signed job's place, before it is put on an orbit, drawn off its own stream
## `jr`; the caller goes on to draw its period and phase from it.
static func _job_body(L: SystemLayout, n: MapGen.MapNode, i: int, jr: RandomNumberGenerator) -> Body:
	var jb := Body.new()
	var tags: Array = OptionTable.by_id(n.options[i]).get("tags", [])
	jb.kind = &"contact" if tags.has(&"fight") else &"planet"
	var bj := Beacon.new()
	bj.opt = i
	jb.beacons.append(bj)
	jb.index = L.bodies.size()
	jb.zone = 2
	jb.seed = n.index * 31 + jb.index * 7 + 1
	if jb.kind == &"planet":
		if L.star == StarKind.PULSAR:
			jb.world = PULSAR_WORLDS[int(jr.randf() * PULSAR_WORLDS.size())]
			jb.scorched = true
			jb.r = 3.5 + jr.randf() * 2.5
		else:
			var pool: Array = POOLS[2]
			jb.world = pool[int(jr.randf() * pool.size())]
			jb.r = 5.0 + jr.randf() * 3.0
		jb.mass = 3.0 + jb.r * 0.9
		jb.well_w = 14.0 + jb.r * 1.6
	return jb


## The Hellbender's place, before it is put on an orbit.
static func _hellbender_body(L: SystemLayout, n: MapGen.MapNode) -> Body:
	var hb := Body.new()
	hb.kind = &"contact"
	var bh := Beacon.new()
	bh.hellbender = true
	hb.beacons.append(bh)
	hb.index = L.bodies.size()
	hb.zone = 2
	hb.seed = n.index * 31 + hb.index * 7 + 1
	return hb


## Weight rolled on its own stream and kept off `mass` and `soi`, so no orbit moves.
static func _weigh_giant(L: SystemLayout, n: MapGen.MapNode) -> void:
	for b in L.bodies:
		if b.kind == &"giant":
			b.gm_frac = lerpf(GIANT_MIN, GIANT_MAX, Rng.derive(&"giant_mass", n.index).randf())
			b.gm = b.gm_frac * GM_SHIP


## Four times Kepler (ruling 23, Jon, Nov 1): at Kepler nobody would see the pair move in a visit.
## Worlds round one sun speed up too to keep steady laps. Worlds round both and map time do not.
## Why: docs/why/SystemLayout.md#pair-speed
const PAIR_K := 4.0
## (a harness's switch, `-- pair=K`: K times Kepler, 0 holding the pair still
## as before ruling 23; -1 means PAIR_K, or the command line's)
static var pair_k := -1.0

## THE WORLDS' PACE (Jon, Nov 4-5, "3D"): every body's period and the pair's turn go WORLD_PACE times
## the old Kepler rate. Not the map's clock, comets or the ship's parked orbit. A game constant
## every peer must share (`NetSession.PROTOCOL` 17).
## Why: docs/why/SystemLayout.md#world-pace
const WORLD_PACE := 4.0
## (a harness's switch, `-- worldpace=K`; -1 means WORLD_PACE, or the command
## line's)
static var world_k := -1.0


## The worlds' pace: `world_k` if a harness set it, else the command line's
## `worldpace=K`, else WORLD_PACE.
static func world_pace() -> float:
	if world_k > 0.0:
		return world_k
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("worldpace="):
			world_k = maxf(float((a as String).substr(10)), 0.01)
			return world_k
	world_k = WORLD_PACE
	return world_k


## SECONDS A LAP AT 100 px round the whole mass (Kepler's law sets the rest):
## 800 at a pace of 1, as the game always had it, over the worlds' pace.
static func kepler_s() -> float:
	return 800.0 / world_pace()


## Not DisplaySettings' reduced motion: the pair's angle feeds flights, saves and co-op.
static func pair_speed() -> float:
	if pair_k >= 0.0:
		return pair_k
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("pair="):
			pair_k = maxf(float((a as String).substr(5)), 0.0)
			return pair_k
	pair_k = PAIR_K
	return pair_k


## The pair turns as one rigid thing, so the t = 0 distances, ladders and rings hold at every t.
## Laid last, once the layout is done.
## Why: docs/why/SystemLayout.md#pair-turning
static func spin_pair(L: SystemLayout) -> void:
	if not L.twin or L.sep <= 0.0:
		return
	# (the pair's line and shares, turning or not: `pair_angle`, `_pair_r`)
	L.pair_ph = atan2(L.star2_at0.y, L.star2_at0.x)
	L.pair_ra = L.bary.length()
	var k := pair_speed()
	if k <= 0.0:
		return
	L.pair_n = TAU / (kepler_s() * pow(L.sep / 100.0, 1.5)) * k
	for b in L.bodies:
		if not is_star(b.host_id):
			continue
		b.hc = L.bary
		b.hn = L.pair_n
		b.hph = L.pair_ph
		b.hr = L._pair_r(b.host_id)
		# (past Kepler the world goes as much faster as the pair: x1 and the
		# still pair leave it its own Kepler period)
		if k > 1.0:
			b.period /= k


## Fitted to the opening zoom, and solved with the edge as stars move apart to fit worlds.
## Fitting to jobs or the Hellbender cannot converge (slope 0.82), so the keep-out stays fixed.
## Why: docs/why/SystemLayout.md#wide-pair
static func _twin(L: SystemLayout, n: MapGen.MapNode, R: RandomNumberGenerator, jobs: Array[int]) -> void:
	var tw := Rng.derive(&"twin", n.index)
	tw.randf()
	L.star_share = lerpf(TWIN_SHARE_LO, TWIN_SHARE_HI, tw.randf())
	var sep0 := lerpf(TWIN_SEP_LO, TWIN_SEP_HI, tw.randf())
	var theta := (0.0 if tw.randf() < 0.5 else PI) + (tw.randf() * 2.0 - 1.0) * TWIN_TURN
	L.star2 = StarKind.ORDINARY
	L.star2_r = STAR_R[StarKind.ORDINARY] * pow((1.0 - L.star_share) / L.star_share, 0.8)
	var N := L.bodies.size()
	for i in N:
		L.bodies[i].index = i
	var jit := PackedFloat64Array()
	var pj := PackedFloat64Array()
	var ph := PackedFloat64Array()
	for i in N:
		jit.append(R.randf())
		pj.append(R.randf())
		ph.append(R.randf())
	# which world goes round which star: the first two planets, A's then B's
	var sa := -1
	var sb := -1
	var outer: Array[int] = []
	for i in N:
		if L.bodies[i].kind == &"planet" and sa < 0:
			sa = i
		elif L.bodies[i].kind == &"planet" and sb < 0:
			sb = i
		else:
			outer.append(i)
	var lim_a := s_limit(1.0 - L.star_share)
	var lim_b := s_limit(L.star_share)
	# Separation is bisected: stepping out closed only 7 to 9% of the gap and left rings misfit.
	# Why: docs/why/SystemLayout.md#wide-pair
	var sep := sep0
	if not _twin_fits(L, sep, lim_a, lim_b, outer, jit):
		var lo := sep0
		var hi := sep0 * 2.0
		# (at the zoom's 0.1 floor a world needs at most about 190 px from its
		# sun, which any pair 900 px apart holds, so this ends by 1,520)
		for _k in 4:
			if _twin_fits(L, hi, lim_a, lim_b, outer, jit):
				break
			lo = hi
			hi *= 2.0
		for _k in 48:
			var mid := 0.5 * (lo + hi)
			if _twin_fits(L, mid, lim_a, lim_b, outer, jit):
				hi = mid
			else:
				lo = mid
		sep = hi
	var fit := _twin_fit(L, sep, lim_a, lim_b, outer, jit)
	var z := fit[0]
	var lad_a := _twin_ladder(L.star_r, z)
	var lad_b := _twin_ladder(L.star2_r, z)
	var need_a := fit[1]
	var need_b := fit[2]
	L.fit_zoom = z
	L.sep = sep
	L.star2_at0 = Vector2(cos(theta), sin(theta)) * sep
	L.bary = L.star2_at0 * (1.0 - L.star_share)
	L._keep = {-1: lad_a[0], STAR_B: lad_b[0]}
	L._rail = {-1: lad_a[1], STAR_B: lad_b[1]}
	L._ring = {-1: lad_a[2], STAR_B: lad_b[2]}
	# One star each, in the steady zone it rolled, or as far out as its ring and disc need.
	var wa := L.bodies[sa]
	wa.host0 = Vector2.ZERO
	wa.host_id = -1
	wa.orbit = minf(maxf(lerpf(S_LO, S_HI, jit[sa]) * lim_a * sep, need_a), S_HI * lim_a * sep)
	var wb := L.bodies[sb]
	wb.host0 = L.star2_at0
	wb.host_id = STAR_B
	wb.orbit = minf(maxf(lerpf(S_LO, S_HI, jit[sb]) * lim_b * sep, need_b), S_HI * lim_b * sep)
	# round both
	var po := _p_orbits(L, sep, outer, jit)
	for k in outer.size():
		var b := L.bodies[outer[k]]
		b.host0 = L.bary
		b.host_id = -9
		b.orbit = po[k]
	# Kepler round what it circles: a world round one star feels only its share of the mass.
	for i in N:
		var b := L.bodies[i]
		var m := 1.0 if b.host_id == -9 else (L.star_share if b.host_id == -1 else 1.0 - L.star_share)
		b.period = kepler_s() * pow(b.orbit / 100.0, 1.5) / sqrt(m) * (0.95 + pj[i] * 0.1)
		b.phase = ph[i] * TAU
	for b in L.bodies:
		b.zone = L.zone_of(b)
	_worlds(L, n, R)
	# NAMED OUT FROM THE SUNS: A's world first, then B's, then those round both
	# from the inside out (theirs by index is theirs by orbit)
	var short := " ".join(MapGen.star_name(n).split(" ").slice(0, 2))
	var rank: Array[int] = [sa, sb]
	rank.append_array(outer)
	for k in rank.size():
		L.bodies[rank[k]].name = "%s %s" % [short, ROMAN[mini(k, ROMAN.size() - 1)]]
	_past_the_edge(L, n, jobs, short)


## Edge of a binary: by each body's reach from its own centre, never under `least`.
static func _past_the_edge(L: SystemLayout, n: MapGen.MapNode, jobs: Array[int], short: String, least := 0.0) -> void:
	var far := 0.0
	var ext := 0.0
	# Measured from star A's origin: the edge holds at every angle of the turning pair.
	for b in L.bodies:
		far = maxf(far, b.host0.length() + b.orbit + reach_of(b))
		ext = maxf(ext, b.host0.distance_to(L.bary) + b.orbit + reach_of(b))
	L.edge = maxf(maxf(HI, far) + 30.0, least)
	for k in jobs.size():
		var jr := Rng.derive(&"job_place", n.index * 8 + k)
		var jb := _job_body(L, n, jobs[k], jr)
		var at := maxf(HI, ext) + reach_of(jb) + GAP + 24.0
		if jb.world != &"":
			at += soi_of(jb)
		jb.orbit = at
		jb.host0 = L.bary
		jb.host_id = -9
		jb.period = kepler_s() * pow(jb.orbit / 100.0, 1.5) * (0.95 + jr.randf() * 0.1)
		jb.phase = jr.randf() * TAU
		jb.name = "%s %s" % [short, ROMAN[mini(jb.index, ROMAN.size() - 1)]]
		L.bodies.append(jb)
		ext = jb.orbit + reach_of(jb) + (soi_of(jb) if jb.world != &"" else 0.0)
		L.edge = maxf(L.bary.length() + ext + 30.0, least)
	if hellbender_here(n):
		var hb := _hellbender_body(L, n)
		hb.orbit = maxf(HI, ext) + reach_of(hb) + GAP + 24.0
		hb.host0 = L.bary
		hb.host_id = -9
		hb.period = kepler_s() * pow(hb.orbit / 100.0, 1.5)
		hb.phase = float(Rng.derive(&"hellbender_place", n.index).randf()) * TAU
		hb.name = "%s %s" % [short, ROMAN[mini(hb.index, ROMAN.size() - 1)]]
		L.bodies.append(hb)
		L.edge = maxf(L.bary.length() + hb.orbit + reach_of(hb) + 30.0, least)
	for b in L.bodies:
		if b.world != &"":
			b.soi = S_RING if is_star(b.host_id) else soi_of(b)
	# Room to arrive counts the jobs and Hellbender too, or a jump landed inside a world.
	# Seen at seed 1999 THETA ABYSSAL MINOR: edge at 322 px where the clear circle is 1000.
	# Why: docs/why/SystemLayout.md#close-pair
	if least > 0.0:
		var arrive := 0.0
		for b in L.bodies:
			arrive = maxf(arrive, b.orbit + arrive_reach(b))
		L.edge = maxf(L.edge, L.bary.length() + arrive + ARRIVE_IN + GAP)


## Every body goes round both: round one sun the steady orbits end inside its close-orbit ring.
## Packed 440 to 900 px, a ring holds a neighbour twice as often. Bodies never meet.
## Why: docs/why/SystemLayout.md#close-pair
static func _close(L: SystemLayout, n: MapGen.MapNode, R: RandomNumberGenerator, jobs: Array[int]) -> void:
	var tw := Rng.derive(&"twin", n.index)
	tw.randf()
	L.star_share = lerpf(TWIN_SHARE_LO, TWIN_SHARE_HI, tw.randf())
	var sep := lerpf(CLOSE_SEP_LO, CLOSE_SEP_HI, tw.randf())
	var theta := (0.0 if tw.randf() < 0.5 else PI) + (tw.randf() * 2.0 - 1.0) * TWIN_TURN
	L.star2 = StarKind.ORDINARY
	L.star2_r = STAR_R[StarKind.ORDINARY] * pow((1.0 - L.star_share) / L.star_share, 0.8)
	L.sep = sep
	L.star2_at0 = Vector2(cos(theta), sin(theta)) * sep
	L.bary = L.star2_at0 * (1.0 - L.star_share)
	var N := L.bodies.size()
	for i in N:
		L.bodies[i].index = i
	var jit := PackedFloat64Array()
	var pj := PackedFloat64Array()
	var ph := PackedFloat64Array()
	for i in N:
		jit.append(R.randf())
		pj.append(R.randf())
		ph.append(R.randf())
	# the suns' close-orbit rings as seen from the balance point, at their widest
	# (the ladder at the zoom's floor: the map is fitted after the orbits are)
	var rings := 0.0
	for p in L.stars():
		rings = maxf(rings, L.star_pos(p, 0.0).distance_to(L.bary) + _twin_ladder(L.star_radius(p), ZOOM_FLOOR)[2])
	var lo := maxf(p_limit(1.0 - L.star_share) * P_MARGIN * sep, HI * 0.27)
	var last := -INF
	var last_reach := 0.0
	var ext_most := 0.0
	for i in N:
		var b := L.bodies[i]
		var f := (float(i) + 0.5 + (jit[i] - 0.5) * 0.7) / float(N)
		var want := maxf(lo, lo * pow(HI / lo, f))
		var reach := _reach_most(b)
		if i > 0:
			want = maxf(want, last + last_reach + reach + GAP)
		if b.kind == &"planet" or b.kind == &"giant":
			want = maxf(want, rings + _soi_most(b) + RING_GAP)
		b.host0 = L.bary
		b.host_id = -9
		b.orbit = want
		b.period = kepler_s() * pow(b.orbit / 100.0, 1.5) * (0.95 + pj[i] * 0.1)
		b.phase = ph[i] * TAU
		last = want
		last_reach = reach
		ext_most = maxf(ext_most, want + reach)
	for b in L.bodies:
		b.zone = L.zone_of(b)
	_worlds(L, n, R)
	# Room past the worlds for a ship to arrive: 53 of 56 close pairs had no clear circle.
	# Costs a median 5% opening zoom, 12% at most (built stills, Nov 2).
	# Why: docs/why/SystemLayout.md#close-pair
	var arrive := 0.0
	for b in L.bodies:
		if b.world != &"":
			b.soi = soi_of(b)
		arrive = maxf(arrive, b.orbit + arrive_reach(b))
	var least_edge := L.bary.length() + arrive + ARRIVE_IN + GAP
	# FITTED TO THE MAP with every world as big as it can be, as a wide pair is
	# (`_twin_edge_most`), and that room: the map opens there or nearer
	var z := open_zoom(maxf(maxf(HI, L.bary.length() + ext_most) + 30.0, least_edge))
	var lad_a := _twin_ladder(L.star_r, z)
	var lad_b := _twin_ladder(L.star2_r, z)
	L.fit_zoom = z
	L._keep = {-1: lad_a[0], STAR_B: lad_b[0]}
	L._rail = {-1: lad_a[1], STAR_B: lad_b[1]}
	L._ring = {-1: lad_a[2], STAR_B: lad_b[2]}
	# named out from the suns, which round both alone is by index
	var short := " ".join(MapGen.star_name(n).split(" ").slice(0, 2))
	for i in N:
		L.bodies[i].name = "%s %s" % [short, ROMAN[mini(i, ROMAN.size() - 1)]]
	_past_the_edge(L, n, jobs, short, least_edge)


## How far an arrival circle keeps from body b's orbit (`ShipFlight.arrival_r`), plus ARRIVE_PAD.
static func arrive_reach(b: Body) -> float:
	if b.world != &"":
		return b.soi * ARRIVE_RING_K + ARRIVE_PAD
	if b.kind == &"belt" or b.kind == &"station" or b.kind == &"derelict" or b.kind == &"contact":
		return ALONGSIDE / SLANT + ARRIVE_PAD
	return 0.0


## `arrive_reach`'s numbers: ALONGSIDE is `ShipFlight.KEEP_R`, ARRIVE_IN is the circle's inset.
const ARRIVE_RING_K := 1.3
const ARRIVE_PAD := 10.0
const ALONGSIDE := 22.0
const ARRIVE_IN := 12.0


## The largest ring a world can have before it is rolled (`soi_of`): a planet as
## the largest broken one, a giant as every giant.
static func _soi_most(b: Body) -> float:
	var most := Body.new()
	most.mass = 24.0 if b.kind == &"giant" else 3.0 + S_WORLD_MOST * 0.9
	return soi_of(most)


## Bodies are kept apart, not their rings: a giant's ring would cost opening zoom 0.229 to 0.145.
## Why: docs/why/SystemLayout.md#orbits-round-both
static func _p_orbits(L: SystemLayout, sep: float, outer: Array[int], jit: PackedFloat64Array) -> PackedFloat64Array:
	var lo := p_limit(1.0 - L.star_share) * P_MARGIN * sep
	var hi := lo * P_SPREAD
	var out := PackedFloat64Array()
	var last := -INF
	var last_reach := 0.0
	for k in outer.size():
		var b := L.bodies[outer[k]]
		var f := (float(k) + 0.5 + (jit[outer[k]] - 0.5) * 0.7) / float(outer.size())
		var want := maxf(lo, lo * pow(hi / lo, f))
		var reach := _reach_most(b)
		if k > 0:
			want = maxf(want, last + last_reach + reach + GAP)
		out.append(want)
		last = want
		last_reach = reach
	return out


## The most a body can reach either side of its orbit before its world is rolled:
## a planet as a broken one, a giant as the biggest.
static func _reach_most(b: Body) -> float:
	match b.kind:
		&"planet":
			return S_WORLD_MOST
		&"giant":
			return 19.0 * 2.2
	return reach_of(b)


## Leaves out the Hellbender and signed jobs: they come and go and must move nothing.
## Why: docs/why/SystemLayout.md#wide-pair
static func _twin_edge_most(L: SystemLayout, sep: float, lim_a: float, lim_b: float, outer: Array[int], jit: PackedFloat64Array) -> float:
	var bary_r := (1.0 - L.star_share) * sep
	var ext := maxf(bary_r + S_HI * lim_a * sep, L.star_share * sep + S_HI * lim_b * sep) + S_WORLD_MOST
	var po := _p_orbits(L, sep, outer, jit)
	for k in outer.size():
		ext = maxf(ext, po[k] + _reach_most(L.bodies[outer[k]]))
	return maxf(HI, bary_r + ext) + 30.0


## Keep-out, close orbit and ring at zoom z. 64-bit: a Vector3's 32-bit parts rounded the keep-out.
static func _twin_ladder(r: float, z: float) -> PackedFloat64Array:
	var keep := maxf(r + TWIN_KEEP, sun_drawn(r, z) / z + RING_OUT)
	return PackedFloat64Array([keep, keep + TWIN_RIDE, keep + TWIN_RIDE + TWIN_TAKE])


## Least orbit for a world: its ring clear of the star's, its disc clear of the drawn sun.
static func _s_need(r: float, z: float) -> float:
	return maxf(_twin_ladder(r, z)[2] + RING_CLEAR + S_RING, _side_need(r, z))


## Checked at z and every nearer zoom: the held sun steps up 2 px and can take back the gap.
## Only the first step matters, later ones come too far apart.
## Why: docs/why/SystemLayout.md#twin-side-gap
static func _side_need(r: float, z: float) -> float:
	var raw := sun_drawn(r, z)
	var worst := (held_most(raw, SUN_LEAST) + _disc_most(z) + SIDE_GAP) / z
	var next := floorf((raw + HOLD_PX) / 2.0) * 2.0 + 2.0
	var raw_at := next - HOLD_PX
	if raw_at > SUN_FLOOR:
		var z2 := sqrt(raw_at * raw_at - SUN_FLOOR * SUN_FLOOR) / r
		worst = maxf(worst, (next + _disc_most(z2) + SIDE_GAP) / z2)
	return worst


## The largest disc a world round one star of a pair is drawn at, zoom z.
static func _disc_most(z: float) -> float:
	var w := maxf(S_WORLD_MOST * z, WORLD_FLOOR)
	return held_most(w, minf(WORLD_FLOOR, w))


## What a pair `sep` apart is fitted to: [its zoom, the orbit star A's world
## needs, star B's].
static func _twin_fit(L: SystemLayout, sep: float, lim_a: float, lim_b: float, outer: Array[int], jit: PackedFloat64Array) -> PackedFloat64Array:
	var z := open_zoom(_twin_edge_most(L, sep, lim_a, lim_b, outer, jit))
	return PackedFloat64Array([z, _s_need(L.star_r, z), _s_need(L.star2_r, z)])


## Whether both worlds fit inside their steady zones with the pair `sep` apart.
static func _twin_fits(L: SystemLayout, sep: float, lim_a: float, lim_b: float, outer: Array[int], jit: PackedFloat64Array) -> bool:
	var fit := _twin_fit(L, sep, lim_a, lim_b, outer, jit)
	return fit[1] <= S_HI * lim_a * sep and fit[2] <= S_HI * lim_b * sep


## Distance from a lone sun giving the same light, averaged round the orbit. B counts by area.
func light_distance(b: Body) -> float:
	var flux := 0.0
	for p in stars():
		# (at t 0: the pair turns rigidly, every world round one sun with its
		# sun, so the distance from each sun to the centre is the same at every t)
		var c := star_pos(p, 0.0).distance_to(b.host0)
		var lum := pow(star_radius(p) / STAR_R[StarKind.ORDINARY], 2.0)
		flux += lum / maxf(absf(c * c - b.orbit * b.orbit), 1.0)
	return 1.0 / sqrt(flux)


## A twin's zone for a body, by its light: near, middle or far (one star's go by index).
func zone_of(b: Body) -> int:
	var d := light_distance(b)
	return 0 if d < ZONE_NEAR else (1 if d < ZONE_FAR else 2)


## A world's ring, by how much it weighs (giants biggest, small rocks least).
static func soi_of(b: Body) -> float:
	return (24.0 + b.mass * 2.4) * 1.6


## The least space between a world's ring and the star's close-orbit ring.
const RING_GAP := 24.0


## The map's slant (`SystemView.TILT`): an orbit's near side is this much of its
## radius below the star on screen.
const SLANT := 0.38
## How far a world's centre keeps from the star's edge when it passes in front.
const CLEAR := 22.0


## The clear space neighbouring orbits must leave between their bodies.
const GAP := 4.0


## How far a body reaches either side of its orbit: a giant's rings go out to
## 2.2 of its radius, a belt's rocks about 16 px, a contact's marker 4.
static func reach_of(b: Body) -> float:
	match b.kind:
		&"giant":
			return b.r * 2.2
		&"belt":
			return 16.0
		&"contact":
			return 4.0
	return maxf(b.r, 4.0)


## How deep the fabric sinks at a point on the plane, under the star and every
## body at their places `pos` (one per body, from `Body.pos`).
func sink(x: float, z: float, pos: Array[Vector2]) -> float:
	var r2 := x * x + z * z
	var D := star_mass * 0.8
	var w := 46.0 + star_r * 1.4
	var d := D * w * w / (r2 + w * w)
	for i in bodies.size():
		var b := bodies[i]
		if b.mass <= 0.0:
			continue
		var dx := x - pos[i].x
		var dz := z - pos[i].y
		d += b.mass * 0.9 * b.well_w * b.well_w / (dx * dx + dz * dz + b.well_w * b.well_w)
	return d


## Whether the Hellbender has a place in this system: anchored here, or its
## wreck lying here (where it died stays a place you can fly back to).
static func hellbender_here(n: MapGen.MapNode) -> bool:
	if Run.hellbender_alive() and Run.hellbender_at == n.index:
		return true
	for raw in n.jetsam:
		if (raw as MapGen.Jetsam).art == &"hellbender":
			return true
	return false


## The Hellbender's place in this layout, or -2 if it has none.
func hellbender_place() -> int:
	for bi in bodies.size():
		for bc in bodies[bi].beacons:
			if bc.hellbender:
				return bi
	return -2


## The core custodian's place in this layout, or -2 if it has none.
func core_place() -> int:
	for bi in bodies.size():
		for bc in bodies[bi].beacons:
			if bc.core:
				return bi
	return -2


## The station's place in this layout (the body its DOCK is on), or -2 if it
## has none: where the ship has to be to dock (`Router.at_station`).
func dock_place() -> int:
	for bi in bodies.size():
		for bc in bodies[bi].beacons:
			if bc.dock:
				return bi
	return -2


## Binary bodies are named out from the suns, not in make order (seed 7 read III, IV, I, V, II, VI).
## Ordered by numeral, ties by index. One-sun systems are unchanged.
## Why: docs/why/SystemLayout.md#body-names
func name_order() -> Array[int]:
	var num := {}
	for b in bodies:
		var k := ROMAN.find(b.name.get_slice(" ", b.name.get_slice_count(" ") - 1))
		num[b.index] = k if k >= 0 else ROMAN.size()
	var out: Array[int] = []
	for b in bodies:
		out.append(b.index)
	out.sort_custom(func(a: int, c: int) -> bool:
		return int(num[a]) < int(num[c]) if int(num[a]) != int(num[c]) else a < c)
	return out


## The body an option sits on, or null (also for one on the star: `place_of`).
func body_of_option(i: int) -> Body:
	for b in bodies:
		for bc in b.beacons:
			if bc.opt == i:
				return b
	return null


## Where option i sits: a body's index, -1 the star, -2 nowhere.
func place_of(i: int) -> int:
	for bi in bodies.size():
		for bc in bodies[bi].beacons:
			if bc.opt == i:
				return bi
	for bc in star_beacons:
		if bc.opt == i:
			return -1
	return -2


## The beacons at place `body` (-1 the star's own events).
func beacons_at(body: int) -> Array[Beacon]:
	if body == -1:
		return star_beacons
	if body < 0 or body >= bodies.size():
		return []
	return bodies[body].beacons
