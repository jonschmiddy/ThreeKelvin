class_name SystemLayout
extends RefCounted

## WHAT IS IN A SYSTEM, AND WHERE: its star, the bodies going round it, and
## which body each of the system's options sits on.
##
## DERIVED, NEVER SAVED. Everything here comes from `Rng.derive(&"system",
## n.index)` and the node's own facts, so the same system lays out the same way
## every time it is asked, on every machine, with nothing in the save -- the way
## `_roll_foes` needs no save. The option list, the claim ids (`OPTION_SITE + i`)
## and the results are untouched: this only says where on the map each option is
## drawn.
##
## Ported from the approved system-map mockup (`layout()` in the scratchpad's
## `sysmap/template.html`), rule for rule:
##
## - one body for every option, chosen by its tags: a fight with nothing to
##   salvage is a CONTACT in open space; salvage and hazard together, or hazard
##   alone, is a BELT (one belt holds all of them); salvage alone is a DERELICT
##   or a belt; anything else -- a contract, a signal, fauna -- is a PLANET;
## - a gas giant if and only if the node has one (never round a pulsar);
## - a station's station as a body of its own, with DOCK on it;
## - about a third of the systems with no belt get one anyway, as scenery, and
##   a pulsar or the core always does;
## - ONE EVENT TO A WORLD (Jon, Oct 15: "A planet should only hold one event.
##   That should be a rule."): every option that wants a planet gets its own,
##   and the giant and the star each hold one at most -- a second that wanted
##   them takes its place by its tags. A place is where a fight leaves its
##   wrecks (`Jetsam.site`), so one event to a place is one fight's wrecks to a
##   place. A belt still holds every option that wanted a belt;
## - no padding: one body is always there, and a system has as many more as
##   its options, its giant, its station and its belt make -- one, two or three
##   is normal (Jon: "I like the diversity and scarcity");
## - the core's custodian as a contact on the outermost orbit;
## - the Hellbender, while it is anchored here or its wreck lies here, as a
##   contact of its own past every orbit, added last so no other body moves
##   (Jon, Oct 15: the system's contact at a place of its own, so you fly there
##   to fight it and its wrecks are its own);
## - at about one ordinary system in four, TWO SUNS (ruling 20), of two kinds
##   (Jon, Nov 1, "Binary kinds: close:B share:A"): two in three a WIDE PAIR, a
##   world round each sun and everything else round both (`_twin`); one in
##   three a CLOSE PAIR, every body round both (`_close`).
##
## Orbits are spread from just outside the star (further out round a red giant
## and the black hole) to `HI`; periods follow Kepler, the square of the period
## going as the cube of the orbit, so the inner bodies go round faster.

## THREE TIMES THE OLD SPREAD (Jon: "can the solar system also be a bit more
## zoomed out? with further away orbits?" -- "even 3x would be good"), so there is
## room to fly between worlds. The first orbit still sits just clear of the star;
## the rest are spaced by ratio out to here. The map opens zoomed out to fit it.
const HI := 900.0
const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

## The star's look: a sun, a red hypergiant, a blue hypergiant, a pulsar, the
## core's black hole.
enum StarKind { ORDINARY, RED, BLUE, PULSAR, CORE }

## The star's drawn radius, and how deep its well sinks the fabric under it.
const STAR_R := {StarKind.ORDINARY: 16.0, StarKind.RED: 48.0, StarKind.BLUE: 24.0, StarKind.PULSAR: 3.0, StarKind.CORE: 16.0}
const STAR_MASS := {StarKind.ORDINARY: 46.0, StarKind.RED: 62.0, StarKind.BLUE: 56.0, StarKind.PULSAR: 66.0, StarKind.CORE: 110.0}

## THE PULL A SHIP FEELS, on map time (Phase 13, ruled Oct 29 "clock:map", and
## ruling 20, Oct 30): a system's whole star mass pulls a ship with this GM
## (px^3/s^2), whatever its kind. It is KAPPA times the Kepler GM that turns the
## worlds (GM_KEPLER: a world 100 px out laps in 800 s), because on map time a
## ship flies about a hundred times faster than the worlds move. A ship riding
## 170 px out at RAIL_V 35 px/s is on a circular orbit under it. Only autopilot
## flights feel it; flying by hand has no gravity (Jon, Oct 3).
const GM_KEPLER := 61.685
const KAPPA := 3376.0
const GM_SHIP := 208250.0
## A GIANT'S WEIGHT against its star (ruling 20: "1/4 - 1/10 ... purely because
## it's more fun"), rolled per giant; every autopilot flight feels it.
const GIANT_MIN := 0.10
const GIANT_MAX := 0.25
## STAR B'S PLACE. A place in a system is an int: a body's index (0 or more),
## -1 star A (the star, its close orbit), STAR_B star B. -2 is "nowhere", -3
## the edge as arrived, -9 open space, -10 a co-op arrival, -99 SITE_ANY, so
## star B takes -4, which nothing used. Test with `is_star` / `is_place`, never
## `>= -1` or `< 0`.
const STAR_B := -4

## TWO SUNS: THE NUMBERS (ruling 20, Oct 30; `of` lays them out, `_twin`).
## Star A's share of the pair's mass, rolled. The build asked 0.52 to 0.65. The
## higher the share, the smaller star B's steady zone (0.255 of the separation
## at 0.55, 0.243 at 0.58, 0.236 at 0.60, 0.217 at 0.65), and its world has to
## stand clear of B's drawn sun at the opening zoom, which spreading the pair
## lowers in turn: near 0.60 the two almost keep pace, and a pair runs away.
## Measured in a model of this fit on the 1,633 twins of eight seeds (layout
## review, Oct 30): capped at 0.60, 5% of pairs went past 380 px, the widest to
## 564 px and an opening zoom of 0.158; at 0.59, 1% and 435 px; at 0.58, none
## past 380 and the least zoom 0.229.
const TWIN_SHARE_LO := 0.52
const TWIN_SHARE_HI := 0.58
## How far apart the two stars are, rolled (px). A pair whose worlds would not
## fit is moved further apart until they do (`_twin`): about a third of them in
## a model of the fit, and none past 380 in 24 seeds' 5,014 twins (Oct 30).
const TWIN_SEP_LO := 320.0
const TWIN_SEP_HI := 380.0
## THE CLOSE PAIR (Jon, Nov 1, "Binary kinds: close:B share:A", from the
## binary-kinds sheet): one binary in three, rolled off a stream of its own
## (`is_close`), so a wide pair keeps every draw it makes today. Its suns are
## rolled 150 to 170 px apart (the sheet's B), off the "twin" stream's
## separation draw, and every body goes round both (`_close`). At B, on the 55
## binaries of seed 7: the two suns 19 to 33 game px apart edge to edge at the
## opening zoom (A's 90 to 110 touched and read as one sun); a hot world first
## in all but 2; 43 of 55 with a world in the middle band (C's 230 to 250 had
## no hot world at all); each sun's close orbit as a wide pair's. Over
## SystemTest's 343 close pairs the two keep-outs stay 70 px apart or more, a
## sun's close orbit 68 px off the other's keep-out, the capture rings 62 apart.
const CLOSE_SHARE := 1.0 / 3.0
const CLOSE_SEP_LO := 150.0
const CLOSE_SEP_HI := 170.0
## (`open_zoom`'s floor: every ring a close pair's ladder can have is at most its
## size here, `_close`)
const ZOOM_FLOOR := 0.1
## Star B is never more than this (radians, 40 degrees) off the map's level line
## from star A: seen at the map's slant a pair one above the other stands 0.38 of
## its distance apart, and two suns that close on screen read as one. At 40
## degrees they stand 0.80 of it apart.
const TWIN_TURN := 0.6981317
## THE FARTHEST STEADY ORBIT ROUND ONE STAR OF A PAIR (Holman and Wiegert 1999,
## circular orbits): a = (HW_0 - HW_MU mu) x separation, mu the OTHER star's
## share. 0.293 round A and 0.255 round B at a 0.55 share.
const HW_0 := 0.464
const HW_MU := 0.380
## Where in that zone a world round one star goes: 0.70 to 0.90 of the limit.
const S_LO := 0.70
const S_HI := 0.90
## THE NEAREST STEADY ORBIT ROUND BOTH, as a share of the separation from the
## balance point (`p_limit`): Holman and Wiegert's circumbinary limit for
## circular orbits, HW_P0 + HW_P1 mu - HW_P2 mu^2 with mu star B's share, and
## never under the build's 2.423. The formula peaks at 2.434 at mu 0.40 (star A
## at 0.60) and is 2.405 at mu 0.48, so 2.423 alone sat inside it for star A
## above about 0.555 (layout review, Oct 30). The first world round both goes a
## few percent past it.
const P_LIMIT := 2.423
const HW_P0 := 1.60
const HW_P1 := 4.12
const HW_P2 := 5.09
const P_MARGIN := 1.03
## The worlds round both are spread by ratio over this much of their first
## orbit, as a one-star system's are over lo to HI (3.7 times): kept close,
## because every pixel out shrinks the whole map at its opening zoom.
const P_SPREAD := 1.25
## A WORLD'S RING ROUND ONE STAR OF A PAIR (px). A one-star world's is 62 to 91
## (`soi_of`), and the steady zone round a star is 70 to 105 px: the prototype's
## 38.4 did not fit inside it. 20 holds the ship 17.6 px out (`ORBIT_K`), clear
## of the largest world drawn (12, a broken one).
const S_RING := 20.0
## EACH TWIN STAR'S KEEP-OUT, CLOSE ORBIT AND RING (`_twin_ladder`), in plane
## px from its centre, all fitted to the zoom the layout is fitted to
## (`fit_zoom`), where the sun is drawn widest on the plane it ever is with no
## job or Hellbender out (the map never zooms out past its opening zoom):
## - keep-clear (`keep_clear_of`): RING_OUT outside the drawn sun, the
##   autopilot's keep-out round a sun (the drawn sun + 6, ruling 20's build),
##   and never under TWIN_KEEP past its surface. One source: the planner's
##   keep-out (the larger of this and the drawn sun + 6) is exactly this, so
##   long as it measures the sun at `fit_zoom` and not at the zoom the map
##   opens at, which a job or the Hellbender lowers.
## - the close orbit a ship rides (`star_rail_of`): TWIN_RIDE outside that, so a
##   ship parked there starts every flight outside the keep-out.
## - the ring a ship is taken onto it inside (`star_ring_of`): TWIN_TAKE past it.
## One star keeps 48, 60 and 95 (r + 32, + 44, + 79), made for a 243 px first
## orbit; a twin's world is 65 to 110 px out, so the three sit 2 px apart. The
## first fit (r + 10, r + 14 and the drawn sun + 6) left the close orbit inside
## the drawn sun at every twin's opening zoom and the ring on the keep-out
## itself, so nothing ridable was outside it (layout review, Oct 30). These 4 px
## cost a median opening zoom of 0.254 against 0.256, in a model of the fit.
const TWIN_KEEP := 10.0
const RING_OUT := 6.0
const TWIN_RIDE := 2.0
const TWIN_TAKE := 2.0
## How far a world's ring keeps from its star's close-orbit ring (px).
const RING_CLEAR := 8.0
## AT THE OPENING ZOOM a world round one star stands this far (game px) clear of
## its sun's drawn disc beside it, as drawn: SystemView holds both in 2 px
## blocks (`held_most`), so a world at its 5 px floor is drawn at 6 and a sun
## up to HOLD_PX over its true size. The first fit counted 4 game px of the
## true sizes, which drawn came to 2.75 (layout review, Oct 30). (At its near
## point, in front of the sun, it cannot: see `_twin`.)
const SIDE_GAP := 3.0
## `SystemView.HOLD_PX`: a held size moves to the nearest block only once the
## true size is this far from it; and the sun's least held radius.
const HOLD_PX := 1.4
const SUN_LEAST := 2.0
## The map's drawing, which the twins' numbers are fitted to: the sun's floor of
## screen radius (`SystemView.STAR_FLOOR`), a world's least drawn radius on the
## plane and on screen (`SystemView.min_r`, `MIN_SCREEN_R`), the largest world
## drawn round one star of a pair (a broken one's r), and the frame the opening
## zoom is fitted to before the screen is laid out (`SystemMapScreen._fit_zoom`).
const SUN_FLOOR := 10.0
const WORLD_MIN_R := 10.0
const WORLD_FLOOR := 5.0
const S_WORLD_MOST := 12.0
const FIT_FRAME := Vector2(655.0, 420.0)
## ZONES BY DISTANCE FROM THE LIGHT, in a twin (a one-star system's go by index,
## as they always have): a body's light, as the distance from a lone sun that
## would give it as much, under 380 px is near and under 600 the middle. Those
## are where a one-star system's index rule puts them (its orbits 243 to 900 px
## by ratio, a third and seven tenths of the way out). A star's light goes as its
## drawn area: star A as a lone sun's, star B as (r_B / 16)^2 of it.
const ZONE_NEAR := 380.0
const ZONE_FAR := 600.0

## EVERY WORLD IN THE MIX, by how far out it is: the scorched and burning close
## in, the living in the middle, the frozen far out. The names are the planet
## painter's.
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
	## THE CENTRE OF ITS CIRCLE on the plane (x, z): star A at the origin in a
	## one-star system and for a world round star A; star B's place for a world
	## round star B; the pair's balance point for a world round both (P-type).
	## The stars hold still (ruling 20's build: the pair turns once an hour on
	## map time, and each visit starts the map's clock again), so this is fixed.
	var host: Vector2 = Vector2.ZERO
	## Which: -1 star A, STAR_B star B, -9 both (round the balance point).
	var host_id: int = -1
	## The pull a ship feels from it (px^3/s^2): a giant's, `gm_frac` of the
	## stars' whole GM_SHIP; 0 for every other body (worlds pull nothing).
	var gm: float = 0.0
	## A giant's weight against its star or stars (GIANT_MIN to GIANT_MAX); 0
	## for every other body. The fabric's dent (`mass`) and the capture ring
	## (`soi`) do not follow it.
	var gm_frac: float = 0.0

	## Where it is at time `t`, on the plane: x across, z toward the viewer.
	## Its footprint on the plane: where it is at time t, x across, z toward the viewer.
	func pos(t: float) -> Vector2:
		var p := point3(t)
		return Vector2(p.x, p.z)

	## Where it is at time t, as the flight's (x, 0, z): every world is on the
	## plane (Jon: "we can get rid of planets with tilted orbits, it doesn't
	## work on a flat plane for this game").
	func point3(t: float) -> Vector3:
		return orbit_point(phase + t / period * TAU)

	func orbit_point(a: float) -> Vector3:
		return Vector3(host.x + cos(a) * orbit, 0.0, host.y + sin(a) * orbit)


var star: StarKind = StarKind.ORDINARY
var star_r: float = 16.0
var star_mass: float = 46.0
var bodies: Array[Body] = []
## The events on the star itself (an option whose `site` is the star, at a red
## or blue star): open from a close orbit of it, body -1 everywhere a place is
## asked for.
var star_beacons: Array[Beacon] = []
## How far out the outermost orbit reaches, plus a margin: from star A, round
## whatever centre each body circles.
var edge: float = HI + 30.0
## THE ZOOM THE LAYOUT IS FITTED TO: the opening zoom (`open_zoom`) of the
## system with no signed job and no Hellbender out past its edge, which come and
## go and must move nothing. The map opens there or nearer, and only further out
## while one of them is posted. A twin's star rings are fitted to it, and the
## autopilot's keep-out round a sun should be measured at it too, so the
## keep-out is the layout's and not moved by a job (`keep_clear_of`).
var fit_zoom: float = 0.0

## TWO STARS (ruling 20, Oct 30). Star A is `star`, at the origin as the one
## star always was; star B holds still at `star2_at`. Off (`twin` false) every
## field here keeps its one-star value and nothing changes.
var twin: bool = false
var star2: StarKind = StarKind.ORDINARY
var star2_r: float = 0.0
var star2_at: Vector2 = Vector2.ZERO
## Star A's share of the stars' mass (1 alone); star B has the rest.
var star_share: float = 1.0
## The pair's balance point, which worlds round both stars circle.
var bary: Vector2 = Vector2.ZERO
## The stars' distance apart (0 alone).
var sep: float = 0.0
## A CLOSE PAIR (`is_close`, `_close`): every body round both suns, none round
## one. False alone and in a wide pair, whose worlds round one sun are its
## first two planets.
var close: bool = false
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


## A STAR'S NAME (ruling 20, Oct 30): the system's own name for its one star,
## as the map always named it, and "<system> A" and "<system> B" for the two of
## a pair, wherever a star is named (the map's words and tip, the panel, LOCAL's
## event line). Added by the sites build; it lays out nothing.
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


## Where star p is on the plane (x, z).
func star_pos(p: int) -> Vector2:
	return star2_at if p == STAR_B else Vector2.ZERO


func star_radius(p: int) -> float:
	return star2_r if p == STAR_B else star_r


func star_kind_of(p: int) -> StarKind:
	return star2 if p == STAR_B else star


## The pull a ship feels from star p (px^3/s^2).
func star_gm(p: int) -> float:
	return GM_SHIP * ((1.0 - star_share) if p == STAR_B else star_share)


## STAR p'S CLOSE ORBIT, the rail (the black hole's lens reaches far past its
## disc, so its close orbit sits outside it), and the ring a ship is taken onto
## it inside. One star: today's numbers, star_r + 44 and + 79, and `ShipFlight`
## rides 8 inside the ring. In a twin (`_twin_ladder`) the rail IS the orbit to
## ride, 2 px outside the keep-out, and the ring 2 px past it: ring - 8 there is
## inside the keep-out, and rail-derived radii such as ShipFlight's bumper
## (rail + 25) land past the ring.
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


## How far a flight keeps from star p's centre. One star: star_r + 32. In a
## twin: the drawn sun at `fit_zoom` plus RING_OUT, so it is the autopilot's
## keep-out itself (`_twin_ladder`).
func keep_clear_of(p: int = -1) -> float:
	if _keep.has(p):
		return _keep[p]
	return star_radius(p) + 32.0


## The farthest steady orbit round one star of a pair, as a share of the
## separation; `mu` is the OTHER star's share (Holman and Wiegert 1999).
static func s_limit(mu: float) -> float:
	return HW_0 - HW_MU * mu


## The nearest steady orbit round both stars of a pair, as a share of the
## separation from the balance point; `mu` is star B's share (Holman and
## Wiegert 1999, circular orbits), never under P_LIMIT.
static func p_limit(mu: float) -> float:
	return maxf(P_LIMIT, HW_P0 + HW_P1 * mu - HW_P2 * mu * mu)


## The most a size of `raw` game px can be drawn at once SystemView holds it in
## 2 px blocks (`SystemView._held`): the nearest block, or one up to HOLD_PX
## above it still held from a nearer zoom, and never under `least`.
static func held_most(raw: float, least: float) -> float:
	return maxf(maxf(roundf(raw / 2.0) * 2.0, floorf((raw + HOLD_PX) / 2.0) * 2.0), ceilf(least / 2.0) * 2.0)


## THE ZOOM A SYSTEM OPENS AT for its edge: `SystemMapScreen._fit_zoom`, with
## the frame it is fitted to before the screen is laid out. A wide pair opens
## nearer, on its own part (`pair_box`), and is wheeled out to this.
static func open_zoom(edge: float) -> float:
	return clampf(minf(FIT_FRAME.x / (2.0 * (edge + 20.0)), FIT_FRAME.y / (2.0 * (edge + 20.0) * SLANT + 60.0)), ZOOM_FLOOR, 1.0)


## THE PAIR'S OWN PART OF A WIDE BINARY (Jon, Nov 1, "gap:A"), which its map
## opens framed on (`SystemMapScreen.open_view`): the two suns and the worlds
## that circle one of them, each world by its whole orbit and reach. Fitted to
## the whole system, a wide pair's world round one sun was drawn as little as
## 5 px from its sun's disc (seed 7, the binary-gap prototype); framed on the
## pair, 28 to 45 px (the wide pairs of seeds 7, 4242 and 1999). On the
## plane (x across, y deep), star A at the origin: centred on the middle of the
## suns' discs and those orbits, and reaching from there PAIR_SUN_PAD past each
## sun's disc and past every such orbit, and PAIR_PAD more all round. Empty for one sun and for a close pair, which
## nothing circles one sun of: they open on their whole system as they did.
func pair_box() -> Rect2:
	if not twin or close:
		return Rect2()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in stars():
		lo = lo.min(star_pos(p) - Vector2.ONE * star_radius(p))
		hi = hi.max(star_pos(p) + Vector2.ONE * star_radius(p))
	for b in bodies:
		if is_star(b.host_id):
			var rr := b.orbit + reach_of(b)
			lo = lo.min(b.host - Vector2.ONE * rr)
			hi = hi.max(b.host + Vector2.ONE * rr)
	var c := (lo + hi) * 0.5
	var half := Vector2.ZERO
	for p in stars():
		half = half.max((star_pos(p) - c).abs() + Vector2.ONE * (star_radius(p) + PAIR_SUN_PAD))
	for b in bodies:
		if is_star(b.host_id):
			half = half.max((b.host - c).abs() + Vector2.ONE * (b.orbit + reach_of(b)))
	half += Vector2.ONE * PAIR_PAD
	return Rect2(c - half, half * 2.0)


## (the room `pair_box` leaves past each sun's disc, and all round it: plane px)
const PAIR_SUN_PAD := 30.0
const PAIR_PAD := 30.0


## A sun's drawn radius on screen (game px) at zoom z: the floor the map eases
## it up to (`SystemView._star_k_raw`, every style but LEGACY).
static func sun_drawn(r: float, z: float) -> float:
	return sqrt(pow(r * z, 2.0) + SUN_FLOOR * SUN_FLOOR)


## A planet's drawn radius on screen (game px) at zoom z (`SystemView._draw_r_raw`).
static func world_drawn(b: Body, z: float) -> float:
	return maxf(maxf(b.r, WORLD_MIN_R) * z, WORLD_FLOOR)


## WHETHER A BINARY IS A CLOSE PAIR (Jon, Nov 1, "share:A": one in three), off
## its own stream, `Rng.derive(&"binary_kind", index)`, so nothing else a system
## rolls moves: a wide pair is drawn as it always was. Only asked of a system
## with two suns.
static func is_close(n: MapGen.MapNode) -> bool:
	var force := _close_force()
	if force != 0:
		return force > 0
	return Rng.derive(&"binary_kind", n.index).randf() < CLOSE_SHARE


## (a harness's switch, as `MapGen.twin_force` is: `-- twin=close` makes every
## binary a close pair and `twin=wide` every one wide, each with every system
## that may have two suns given them; a harness can set it itself, 1 close, -1
## wide, 0 as the command line says)
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
	# WHERE THE TEXT SAYS IT IS (an option's `site`, `OptionTable`): an event
	# whose text has the giant filling the sky sits on the giant, one in a red
	# or blue star's glare on the star itself -- not on a belt LOCAL draws as
	# rocks. Only where the system has that giant or that star; otherwise it
	# takes its place by its tags, as every other option does.
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

	# the order out from the star. FEW BODIES ARE FINE (Jon: "1, 2, or 3 is fine.
	# I like the diversity and scarcity"; "sometimes two planets or three planets
	# is fine, too"): options that want a world share one about half the time,
	# so one planet can hold two or three encounters, and the planet that is
	# always there is only added when no option brought one
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
	# A WORLD ROUND EACH SUN, always (ruling 20: the flight from one to the
	# other is why a twin is there): its first two planets go round its two
	# stars, so where the options bring one a bare second goes in beside it.
	# A CLOSE PAIR GETS IT TOO, round both: the binary-kinds sheet's numbers that
	# Jon picked on were measured with it (43 of seed 7's 55 with a world in the
	# middle band; 35 without it), and it keeps R's draws as a wide pair's
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
		return L

	# where each body falls, out from the star: which pool its world comes from
	for i in L.bodies.size():
		var f := 0.0 if L.bodies.size() == 1 else float(i) / float(L.bodies.size() - 1)
		L.bodies[i].zone = 0 if f < 0.34 else (1 if f < 0.7 else 2)
		L.bodies[i].index = i

	# what each world is
	_worlds(L, n, R)
	# ORBITS, spread out from clear of the star, each at least as far from the
	# last as the two bodies on them are wide. The mockup spread them evenly and
	# sized the bodies afterwards, so a ringed giant beside a large world could
	# overlap it -- by 24 px at worst, measured by `-- systemtest`.
	# The first orbit is far enough out that a world at the front of it, seen at
	# the map's slant, sits clear of the star's disc (Jon: "the first planet of a
	# system is always SUPER CLOSE to the sun"). Each body then takes its own
	# slot between there and `HI`, spaced by ratio as real systems are, and
	# lands anywhere in it, so the first is not always on the inner edge.
	var lo := L.star_r + (62.0 if L.star == StarKind.RED else (84.0 if L.star == StarKind.CORE else 46.0))
	lo = maxf(lo, (L.star_r + CLEAR) / SLANT)
	# OUT IN PROPORTION TO THE WIDER SYSTEM (Jon: "planets don't have to be so
	# hella close to their star"): the first orbit was set when the system
	# reached 300; at 900 it sat at a ninth of it. Now a quarter and more (more
	# again round a red giant or the core), and every world's ring kept clear of
	# the star's close-orbit ring
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
		b.period = 800.0 * pow(b.orbit / 100.0, 1.5) * (0.95 + R.randf() * 0.1)
		b.phase = R.randf() * TAU
		b.name = "%s %s" % [short, ROMAN[mini(i, ROMAN.size() - 1)]]
		last = b.orbit
		last_reach = reach
	L.edge = maxf(HI, last + last_reach) + 30.0
	L.fit_zoom = open_zoom(L.edge)
	# A SIGNED CONTRACT'S WORK, each on a place of its own past every orbit
	# (`Contracts.post_goal`): a hunt's target is a contact, a fetch's pickup a
	# world. Drawn off its own stream and added after the system's own bodies,
	# like the Hellbender below, so the worlds you saw before you signed are
	# the worlds you see after.
	for k in jobs.size():
		var jr := Rng.derive(&"job_place", n.index * 8 + k)
		var jb := _job_body(L, n, jobs[k], jr)
		var at := maxf(HI, last + last_reach) + reach_of(jb) + GAP + 24.0
		if jb.world != &"":
			at += soi_of(jb)
		jb.orbit = at
		jb.period = 800.0 * pow(jb.orbit / 100.0, 1.5) * (0.95 + jr.randf() * 0.1)
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
		hb.period = 800.0 * pow(hb.orbit / 100.0, 1.5)
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


## WHAT EACH WORLD IS: its painter's world and size by its zone, and the dent it
## makes in the fabric. Its zone is set first, by index round one star, by
## distance from the light round two (`_twin`).
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


## A GIANT'S WEIGHT (ruling 20: "1/4 - 1/10 ... purely because it's more fun"),
## in every system with one, one sun or two: rolled off a stream of its own, so
## nothing else a layout rolls moves, and kept off `mass` and `soi`, so no orbit
## moves either.
static func _weigh_giant(L: SystemLayout, n: MapGen.MapNode) -> void:
	for b in L.bodies:
		if b.kind == &"giant":
			b.gm_frac = lerpf(GIANT_MIN, GIANT_MAX, Rng.derive(&"giant_mass", n.index).randf())
			b.gm = b.gm_frac * GM_SHIP


## A WIDE PAIR, two binaries in three (ruling 20, Oct 30: "Prototype: twin:A";
## the close pair is `_close`). Star A stays at the origin;
## star B holds still `sep` from it at `star2_at`, a little smaller. The first two
## planets go round one star each (S-type), inside the farthest steady orbit round
## it, at 0.70 to 0.90 of it. Everything else -- the giant, the belt, any further
## world, a contact, a signed job, the Hellbender -- goes round both (P-type),
## past the nearest steady orbit round the pair, circling the balance point. So
## index order is not radial order here: there are three centres.
##
## FITTED TO THE MAP AT ITS OPENING ZOOM (`fit_zoom`). A world round one star is
## 65 to 110 px from it and the whole system 1,000 to 1,400 px across the frame's
## half, so the map opens at about a quarter zoom, where a sun is drawn at its 10
## px floor (40 plane px, against its own 16) and a world at 5. So each star's
## keep-out sits RING_OUT outside its drawn sun, its close orbit and ring just
## past that (`_twin_ladder`), each world's ring RING_CLEAR outside the star's,
## and each world stands SIDE_GAP clear of its sun's disc beside it as drawn.
## Where a pair's worlds would not fit, the stars move further apart; that moves
## the edge and so the opening zoom, so the two are solved together
## (`_twin_edge_most`, `_twin_fit`).
## A SIGNED JOB OR THE HELLBENDER out past the edge opens the map further out
## than `fit_zoom` while it is there, and the suns are drawn wider on the plane
## than the rings were fitted to: by up to about 10 px with a fetch's world out
## (systemtest measures it). Fitting to that instead cannot be done: the fit is
## a fixed point (the worlds need about 19 / zoom px from their sun, and the zoom
## falls as the pair spreads) whose slope is about 0.82, so the 271 px that a
## fetch, a hunt and the Hellbender can add came back about five times over, and
## in a model of 1,633 twins 98% of pairs went past 380 px apart and the median
## opening zoom fell from 0.26 to 0.13 (layout review, Oct 30). So the keep-out
## stays the layout's (`keep_clear_of`), and nothing moves when they come.
## IN FRONT OF ITS SUN, at its orbit's near point, a world round one star cannot
## clear the drawn disc at the opening zoom, for any numbers: it is a z SLANT
## below the sun there, and with anything round both the edge is at least 2.8
## times the separation while a is at most 0.30 of it, so that is at most 13
## game px against the sun's 10 and the world's 5. It passes over the sun's lower
## edge (systemtest measures it: 5.6 to 10 game px of overlap as drawn in 2 px
## blocks, 4 to 8 of the true sizes) and clears it from a zoom of about 0.6.
##
## Draws: the "twin" stream for the pair (its first draw is MapGen's, whether
## there are two suns at all), then R in a twin's own order -- the orbits' three
## draws a body first, since where a body is decides its zone, then its world.
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
	# THE SEPARATION, as rolled or as far apart as the worlds round each star
	# need: never shrunk, and moving it out moves the opening zoom (smaller, so
	# a sun's floor is wider on the plane). Near the answer each step of going
	# out by what the worlds need closes only 7 to 9% of the distance left, and
	# the first fit's 32 such steps ran out short in about half the spread pairs,
	# its rings fitted to the step before (layout review, Oct 30). So it is
	# bisected: from a separation that fits, halved toward the rolled one 48
	# times, and everything below is fitted to the one it ends on.
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
	L.star2_at = Vector2(cos(theta), sin(theta)) * sep
	L.bary = L.star2_at * (1.0 - L.star_share)
	L._keep = {-1: lad_a[0], STAR_B: lad_b[0]}
	L._rail = {-1: lad_a[1], STAR_B: lad_b[1]}
	L._ring = {-1: lad_a[2], STAR_B: lad_b[2]}
	# round one star each, where in the steady zone it rolled, or as far out as
	# its ring and its drawn disc need (the separation was found so that is
	# inside the steady limit, which is the rule)
	var wa := L.bodies[sa]
	wa.host = Vector2.ZERO
	wa.host_id = -1
	wa.orbit = minf(maxf(lerpf(S_LO, S_HI, jit[sa]) * lim_a * sep, need_a), S_HI * lim_a * sep)
	var wb := L.bodies[sb]
	wb.host = L.star2_at
	wb.host_id = STAR_B
	wb.orbit = minf(maxf(lerpf(S_LO, S_HI, jit[sb]) * lim_b * sep, need_b), S_HI * lim_b * sep)
	# round both
	var po := _p_orbits(L, sep, outer, jit)
	for k in outer.size():
		var b := L.bodies[outer[k]]
		b.host = L.bary
		b.host_id = -9
		b.orbit = po[k]
	# KEPLER ROUND WHAT IT CIRCLES: a world round one star goes round as its
	# share of the mass pulls it, slower (the period formula has the whole mass
	# as 1); a world round both, as round a lone star
	for i in N:
		var b := L.bodies[i]
		var m := 1.0 if b.host_id == -9 else (L.star_share if b.host_id == -1 else 1.0 - L.star_share)
		b.period = 800.0 * pow(b.orbit / 100.0, 1.5) / sqrt(m) * (0.95 + pj[i] * 0.1)
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


## THE EDGE OF A BINARY, and the jobs and the Hellbender past it, round both
## suns: by how far each body reaches from its own centre, not the last one's
## orbit. Then each world's ring (S_RING round one sun of a wide pair).
static func _past_the_edge(L: SystemLayout, n: MapGen.MapNode, jobs: Array[int], short: String) -> void:
	var far := 0.0
	var ext := 0.0
	for b in L.bodies:
		far = maxf(far, b.host.length() + b.orbit + reach_of(b))
		ext = maxf(ext, b.host.distance_to(L.bary) + b.orbit + reach_of(b))
	L.edge = maxf(HI, far) + 30.0
	for k in jobs.size():
		var jr := Rng.derive(&"job_place", n.index * 8 + k)
		var jb := _job_body(L, n, jobs[k], jr)
		var at := maxf(HI, ext) + reach_of(jb) + GAP + 24.0
		if jb.world != &"":
			at += soi_of(jb)
		jb.orbit = at
		jb.host = L.bary
		jb.host_id = -9
		jb.period = 800.0 * pow(jb.orbit / 100.0, 1.5) * (0.95 + jr.randf() * 0.1)
		jb.phase = jr.randf() * TAU
		jb.name = "%s %s" % [short, ROMAN[mini(jb.index, ROMAN.size() - 1)]]
		L.bodies.append(jb)
		ext = jb.orbit + reach_of(jb) + (soi_of(jb) if jb.world != &"" else 0.0)
		L.edge = L.bary.length() + ext + 30.0
	if hellbender_here(n):
		var hb := _hellbender_body(L, n)
		hb.orbit = maxf(HI, ext) + reach_of(hb) + GAP + 24.0
		hb.host = L.bary
		hb.host_id = -9
		hb.period = 800.0 * pow(hb.orbit / 100.0, 1.5)
		hb.phase = float(Rng.derive(&"hellbender_place", n.index).randf()) * TAU
		hb.name = "%s %s" % [short, ROMAN[mini(hb.index, ROMAN.size() - 1)]]
		L.bodies.append(hb)
		L.edge = L.bary.length() + hb.orbit + reach_of(hb) + 30.0
	for b in L.bodies:
		if b.world != &"":
			b.soi = S_RING if is_star(b.host_id) else soi_of(b)


## A CLOSE PAIR (Jon, Nov 1, "Binary kinds: close:B"). Star A stays at the
## origin and star B holds still `sep` from it, 150 to 170 px (`CLOSE_SEP_LO`),
## a little smaller, as in a wide pair. Every body goes round both (P-type),
## circling the balance point past the nearest steady orbit round the pair, and
## none round one sun: round one, the steady orbits end 43 to 51 px out, inside
## its close orbit's ring. The real close pairs Kepler-16 and Kepler-47 have
## this shape, planets round both suns.
##
## LAID OUT AS ROUND ONE SUN (`of`'s rules): by ratio from that first steady
## orbit (`p_limit`, P_MARGIN past it; never nearer than a one-sun system's
## first, which it always is past) out to HI, each body at least as far from the
## last as the two could be wide (`_reach_most`: their worlds are rolled after,
## by their light), and each world's ring RING_GAP clear of both suns' close-
## orbit rings. Zones by light (`zone_of`), as a wide pair's: the middle band is
## about 490 to 830 px out, so the first body is hot in all but 2 of seed 7's 55
## close pairs and 43 of them have a planet in the middle band, where a city, a
## green world or an ocean can be. THE COST (the sheet's): the bodies are packed
## between about 440 and 900 px, not 243 to 900, so a world's ring holds a
## neighbour about twice as often as round one sun; the bodies never meet.
##
## Each sun keeps its keep-out, close orbit and ring, a wide pair's ladder
## (`_twin_ladder`) at the zoom this layout is fitted to (`fit_zoom`): at 150 px
## apart the two keep-outs, and each sun's close orbit and the other's keep-out,
## are 68 px or more apart.
##
## Draws: `_twin`'s, in its order: the "twin" stream's share, separation, side
## and turn; R's three a body (where in its slot, its period's jitter, its
## phase); then its world.
static func _close(L: SystemLayout, n: MapGen.MapNode, R: RandomNumberGenerator, jobs: Array[int]) -> void:
	var tw := Rng.derive(&"twin", n.index)
	tw.randf()
	L.star_share = lerpf(TWIN_SHARE_LO, TWIN_SHARE_HI, tw.randf())
	var sep := lerpf(CLOSE_SEP_LO, CLOSE_SEP_HI, tw.randf())
	var theta := (0.0 if tw.randf() < 0.5 else PI) + (tw.randf() * 2.0 - 1.0) * TWIN_TURN
	L.star2 = StarKind.ORDINARY
	L.star2_r = STAR_R[StarKind.ORDINARY] * pow((1.0 - L.star_share) / L.star_share, 0.8)
	L.sep = sep
	L.star2_at = Vector2(cos(theta), sin(theta)) * sep
	L.bary = L.star2_at * (1.0 - L.star_share)
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
		rings = maxf(rings, L.star_pos(p).distance_to(L.bary) + _twin_ladder(L.star_radius(p), ZOOM_FLOOR)[2])
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
		b.host = L.bary
		b.host_id = -9
		b.orbit = want
		b.period = 800.0 * pow(b.orbit / 100.0, 1.5) * (0.95 + pj[i] * 0.1)
		b.phase = ph[i] * TAU
		last = want
		last_reach = reach
		ext_most = maxf(ext_most, want + reach)
	# FITTED TO THE MAP with every world as big as it can be, as a wide pair is
	# (`_twin_edge_most`): the map opens there or nearer
	var z := open_zoom(maxf(HI, L.bary.length() + ext_most) + 30.0)
	var lad_a := _twin_ladder(L.star_r, z)
	var lad_b := _twin_ladder(L.star2_r, z)
	L.fit_zoom = z
	L._keep = {-1: lad_a[0], STAR_B: lad_b[0]}
	L._rail = {-1: lad_a[1], STAR_B: lad_b[1]}
	L._ring = {-1: lad_a[2], STAR_B: lad_b[2]}
	for b in L.bodies:
		b.zone = L.zone_of(b)
	_worlds(L, n, R)
	# named out from the suns, which round both alone is by index
	var short := " ".join(MapGen.star_name(n).split(" ").slice(0, 2))
	for i in N:
		L.bodies[i].name = "%s %s" % [short, ROMAN[mini(i, ROMAN.size() - 1)]]
	_past_the_edge(L, n, jobs, short)


## The largest ring a world can have before it is rolled (`soi_of`): a planet as
## the largest broken one, a giant as every giant.
static func _soi_most(b: Body) -> float:
	var most := Body.new()
	most.mass = 24.0 if b.kind == &"giant" else 3.0 + S_WORLD_MOST * 0.9
	return soi_of(most)


## The orbits round both stars, in index order: spread by ratio from just past
## the nearest steady one, each at least as far from the last as the two bodies
## could be wide (`_reach_most`: the spacing is fixed before the worlds are
## rolled, so it cannot depend on them). As round one sun, the bodies are kept
## apart, not their rings: a giant's 131 px ring holds its neighbours round both
## far more often than round one sun, where the orbits spread 3.7 times from the
## first (systemtest prints how often). Keeping every body out of the giant's
## ring cost, in a model of 1,633 twins, the least opening zoom 0.229 to 0.145
## and pushed 9% of pairs past 380 px apart (layout review, Oct 30).
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


## How far out a twin reaches from star A at the most, for separation `sep`,
## with every world as big as it can be: its opening zoom can then only be this
## or nearer, and nearer only clears the suns more. Not the Hellbender's place
## or a signed job's: they come and go, and must move nothing when they do
## (systemtest, contracttest), and room kept for them always cannot be had (see
## `_twin`), so while one is out past the edge the map opens further out than
## the layout's `fit_zoom` and the suns are drawn wider than it.
static func _twin_edge_most(L: SystemLayout, sep: float, lim_a: float, lim_b: float, outer: Array[int], jit: PackedFloat64Array) -> float:
	var bary_r := (1.0 - L.star_share) * sep
	var ext := maxf(bary_r + S_HI * lim_a * sep, L.star_share * sep + S_HI * lim_b * sep) + S_WORLD_MOST
	var po := _p_orbits(L, sep, outer, jit)
	for k in outer.size():
		ext = maxf(ext, po[k] + _reach_most(L.bodies[outer[k]]))
	return maxf(HI, bary_r + ext) + 30.0


## A twin star's keep-out, close orbit and ring at zoom z: RING_OUT outside its
## drawn sun and at least TWIN_KEEP past its surface, then TWIN_RIDE and
## TWIN_TAKE further out. (64-bit: a Vector3's 32-bit parts rounded the keep-out
## under the drawn sun + 6 it is measured against.)
static func _twin_ladder(r: float, z: float) -> PackedFloat64Array:
	var keep := maxf(r + TWIN_KEEP, sun_drawn(r, z) / z + RING_OUT)
	return PackedFloat64Array([keep, keep + TWIN_RIDE, keep + TWIN_RIDE + TWIN_TAKE])


## The least orbit a world round a star of radius r needs at zoom z: its ring
## clear of the star's, and its disc clear of the drawn sun beside it
## (`_side_need`).
static func _s_need(r: float, z: float) -> float:
	return maxf(_twin_ladder(r, z)[2] + RING_CLEAR + S_RING, _side_need(r, z))


## The least orbit that keeps a world SIDE_GAP clear of its sun beside it, both
## at the most SystemView draws them (`held_most`), at zoom z AND at every
## nearer zoom, since the map can open nearer than the layout was fitted to.
## The world's distance grows with the zoom but the held sun steps up 2 px at
## a time: just past z its next step can take back what the zoom gave (fitted at
## a sun of 10.58 game px, held at 10, a twin opened at a sun past 10.6, held at
## 12, and its world stood 1.8 game px off). Past that step the next ones come
## too far apart to matter (`_side_need` takes the first only: a sun of r 16
## steps again at 0.48 zoom, needing half the orbit).
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


## HOW FAR FROM THE LIGHT a body is: the distance from a lone sun that would
## give it the light it gets here, averaged round its orbit (round a circle of
## radius a, 1/d^2 from a star c from its centre averages 1/|c^2 - a^2|). Star A
## is as bright as a lone sun, star B as its drawn area of one. One star: the
## orbit.
func light_distance(b: Body) -> float:
	var flux := 0.0
	for p in stars():
		var c := star_pos(p).distance_to(b.host)
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


## THE BODIES IN THE ORDER OF THEIR NAMES (I, II, III ...): the panel's
## SATELLITES list (Jon, Nov 1, "list:C"). Round one sun every body is named by
## its index (`ROMAN[i]`), so this is the order they were made in and nothing
## there moves. In a binary they are named out from the suns (star A's world,
## star B's world, then those round both, `_twin`), not in the order they were
## made: SIGMA KESTREL PRIME on seed 7 read III, IV, I, V, II, VI. By the numeral
## each name ends in; a tie (past X, which `ROMAN` stops at) by index.
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
