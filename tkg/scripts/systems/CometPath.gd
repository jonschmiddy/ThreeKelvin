class_name CometPath
extends RefCounted

## A comet you can see coming (Phase 13, Jon picked C, "wait on its path", Nov 9).
## One pass per visit on the system's own map clock, drawn off its own stream.
## Why: docs/why/CometPath.md#one-pass

## It comes in from the edge this long after the system's map first opens (s, map time).
const IN_LO := 5.0
const IN_HI := 15.0
## The pass, edge to edge: the weather comet's own, whose speed Jon called perfect (Nov 5).
const PASS_LO := 60.0
const PASS_HI := 80.0
## Perihelion against the innermost orbit, as the weather comet's.
const Q_LO := 0.6
const Q_HI := 1.2

## Nearest the star (plane px, from star A).
var q := 0.0
## Which way perihelion points (rad).
var w := 0.0
## Barker's time scale, and the age it is nearest the star.
var K := 1.0
var tp := 0.0
## The map time it comes in at, and how long it takes to cross.
var t_in := 0.0
var T := 1.0
var name := ""
## Its readings, sited on it (`OptionTable` site &"comet"); empty until Phase 13's events.
var beacons: Array = []


## THE PATH, a parabola about the star (Barker's equation) at `age` seconds into the pass,
## from star A. The weather comet's `comet_pos` is this.
static func barker(eq: float, ew: float, eK: float, etp: float, age: float) -> Vector2:
	var B := 3.0 * (age - etp) / eK
	var y := pow(B + sqrt(B * B + 1.0), 1.0 / 3.0)
	var D := y - 1.0 / y
	var r := eq * (1.0 + D * D)
	var a := 2.0 * atan(D) + ew
	return Vector2(cos(a), sin(a)) * r


## Seconds into the pass at map time t: below 0 it is still coming, past T it has gone.
func age(t: float) -> float:
	return t - t_in


## Whether it is in the system at map time t.
func here(t: float) -> bool:
	var a := age(t)
	return a >= 0.0 and a <= T


## Whether it has passed for good at map time t: it never comes back.
func gone(t: float) -> bool:
	return age(t) > T


## From star A, `a` seconds into the pass.
func rel(a: float) -> Vector2:
	return barker(q, w, K, tp, a)


## On the plane at map time t: round star A where the pair has it then.
func pos(L: SystemLayout, t: float) -> Vector2:
	return L.star_pos(-1, t) + rel(age(t))


## How fast it moves at map time t (plane px/s).
func vel(L: SystemLayout, t: float) -> Vector2:
	const H := 0.01
	return (pos(L, t + H) - pos(L, t - H)) / (2.0 * H)


## What it is, in the panel's and the tip's words.
const KIND := "COMET · ICE AND DUST"


## Where it is in its pass, in plain words with the time to the next thing.
func status(t: float) -> String:
	var a := age(t)
	if a < 0.0:
		return "COMES IN %s" % clock(-a)
	if a < tp:
		return "NEAREST THE STAR IN %s" % clock(tp - a)
	if a <= T:
		return "GONE IN %s" % clock(T - a)
	return "GONE FOR GOOD"


## Seconds as M:SS, rounded up so it never reads 0:00 early.
static func clock(s: float) -> String:
	var n := int(ceil(maxf(s, 0.0)))
	return "%d:%02d" % [n / 60, n % 60]


## The drawing's event: the weather comet's own fields, so one drawing serves both.
func ev() -> Dictionary[String, Variant]:
	return {"q": q, "w": w, "K": K, "tp": tp, "end": T, "mode": &"comet", "age": -1.0, "real": true, "a_min": A_MIN}


## Its brightness at least this far out (the drawing's A, 0 to 1): it must read as a thing to click.
const A_MIN := 0.5


## Whether system n has a comet: one of its options is sited on one (Phase 13's readings),
## or a harness asked for one (`cometpass`). Never at the core, a pulsar or a station.
static func wanted(n: MapGen.MapNode, kind: SystemLayout.StarKind) -> bool:
	if kind == SystemLayout.StarKind.CORE or kind == SystemLayout.StarKind.PULSAR:
		return false
	if n.type == MapGen.NodeType.STATION:
		return false
	for id in n.options:
		if StringName(OptionTable.by_id(id).get("site", &"")) == &"comet":
			return true
	return forced()


static var _force := -1

## A harness's `cometpass`: a comet in every system that may have one.
static func forced() -> bool:
	if _force < 0:
		_force = 1 if "cometpass" in OS.get_cmdline_user_args() else 0
	return _force == 1


## Laid out after everything else, off its own stream, so no world moves for it.
## Why: docs/why/CometPath.md#own-stream
static func build(L: SystemLayout, n: MapGen.MapNode) -> CometPath:
	var R := Rng.derive(&"comet", n.index)
	var c := CometPath.new()
	var inner := INF
	# (round A, or round both of a close pair, so it passes outside the pair)
	for b in L.bodies:
		if b.kind != &"belt" and (b.host_id == -1 or L.close):
			inner = minf(inner, b.orbit)
	if inner == INF:
		inner = L.star_r * 6.0
	c.T = R.randf_range(PASS_LO, PASS_HI)
	c.tp = c.T / 2.0
	c.t_in = R.randf_range(IN_LO, IN_HI)
	# Never through a sun's keep-out: drawn again off the same stream until clear.
	# Why: docs/why/CometPath.md#clear-of-the-suns
	for _try in TRIES:
		c.q = maxf(inner * R.randf_range(Q_LO, Q_HI), L.keep_clear_of(-1) + CLEAR)
		var De := sqrt(maxf(L.edge / c.q - 1.0, 0.1))
		c.K = c.T / (De + De * De * De / 3.0)
		c.w = R.randf() * TAU
		if c.clear_of_suns(L) >= CLEAR:
			break
	var sysname := MapGen.star_name(n)
	c.name = "%s COMET" % " ".join(sysname.split(" ").slice(0, 2))
	return c


## How many times a path through a sun is drawn again.
const TRIES := 8
## How far outside every sun's keep-out the path stays (plane px).
const CLEAR := 12.0
## The path is checked at this many points of the pass.
const CHECKS := 160


## The path's nearest approach outside any sun's keep-out over the pass (plane px; below 0 inside).
func clear_of_suns(L: SystemLayout) -> float:
	var least := INF
	for k in CHECKS + 1:
		var a := T * float(k) / float(CHECKS)
		var p := pos(L, t_in + a)
		for s: int in L.stars():
			least = minf(least, p.distance_to(L.star_pos(s, t_in + a)) - L.keep_clear_of(s))
	return least


# ---------------------------------------------------------------- the catch (Jon's C)
## THE THREE SPOTS on its path, as fractions of the way from coming in to nearest the star:
## far, near, and at the star. Why: docs/why/CometPath.md#the-spots
const SPOT_AGE: Array[float] = [0.45, 0.75, 1.0]
const SPOT_NAMES: Array[String] = ["FAR", "NEAR", "AT THE STAR"]
## A reading's pay against the careful one, at each spot (ECONOMY: 1x, 2x, 2.5x), in halves.
const SPOT_PAY_HALVES: Array[int] = [2, 4, 5]
## What each spot costs: hull at the near two, heat at the star.
const SPOT_HULL: Array[int] = [0, 2, 3]
const SPOT_HEAT: Array[int] = [0, 0, 8]


## The age it reaches spot k (s into the pass).
func spot_age(k: int) -> float:
	return tp * SPOT_AGE[k]


## The map time it reaches spot k.
func spot_t(k: int) -> float:
	return t_in + spot_age(k)


## Spot k on the plane: where the comet will be when it gets there (star A where it is then).
func spot_at(L: SystemLayout, k: int) -> Vector2:
	return pos(L, spot_t(k))


## Seconds until it reaches spot k at map time t (below 0: it has gone by).
func spot_in(k: int, t: float) -> float:
	return spot_t(k) - t


## The spot the ship met the comet at in system n (the reading's spot), or -1. Kept on the node
## for the visit: never saved, as the reading is taken in the same LOCAL.
static func caught_at(n: MapGen.MapNode) -> int:
	return int(n.get_meta(&"comet_spot", -1)) if n != null else -1


static func set_caught(n: MapGen.MapNode, k: int) -> void:
	n.set_meta(&"comet_spot", k)


## Where the reading is taken now: this system's caught spot (FAR when none, as a harness has it).
static func spot_here() -> int:
	var k := caught_at(Run.node_at() if not Run.map.is_empty() else null)
	return clampi(k, 0, 2)


## A comet reading's DATA at the spot here: the careful reading times 1, 2 or 2.5.
static func pay_here() -> int:
	return int(round(float(OptionTable.reading(1)) * float(SPOT_PAY_HALVES[spot_here()]) / 2.0))


## The spot's toll on the ship (hull at the near two, heat at the star), and its words.
static func toll_here(why: String) -> void:
	var k := spot_here()
	if SPOT_HULL[k] > 0:
		Run.take_hull_damage(OptionTable.toll(SPOT_HULL[k]), why)
	if SPOT_HEAT[k] > 0:
		Run.heat += SPOT_HEAT[k]


## One of three lines by the spot here: far, near, at the star.
static func by_spot(lines: Array) -> String:
	return lines[spot_here()]

