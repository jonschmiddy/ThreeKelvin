class_name ChartTorn
extends RefCounted

## TORN AWAY, direction B (proto/dwarf-b): the stream. The hardest galaxies, the
## two dwarfs (GalaxyGen kinds 14 and 15), are being eaten by a giant neighbour,
## seen far off and steeply tilted up the chart. ONE stream of the dwarf's stars
## (Jon, Nov 7: "a single stream of the galaxy being pulled, rather than two")
## runs out of the dwarf toward the giant and spirals into the giant's middle.
##
## The rings fall away from the outside in (`lost`, rings gone so far; the last
## four hold, so `MAX_LOST`). The dwarf starts as it always is drawn and LOSES
## its outside with each ring lost, REDRAWN, never shrunk (Jon, Nov 8: "it's
## almost like the image of the galaxy is shrinking rather than a true redraw"):
## REDRAW A, STRIPPED. Its core, body, glow and stars keep their real size and
## place; past its drawn edge (`drawn_edge`) they are gone, the edge torn (ragged on the galaxy's own noise, drawn
## out toward the stream, `LOBE`, its last band broken into clumps that feed the
## stream's start) and the light fading over a short band inside it. The drawn
## edge is the rings' (`edge()`, halfway between the last ring lost and the
## outermost left) taken into the dwarf's drawn light (`R_DRAWN`): a dwarf's
## light and its thick stars end at about a fifth of its rings' reach (0.21 gu of
## 0.95), so its own rings, cut where they lie, never reach its body: ten rings
## gone left the picture as it was. The stars past the rings' edge go with
## their rings; those thick about the body past the drawn edge thin out to the
## sky's own few. The systems on the lost rings are off the chart (`gone`, `StarchartScreen._drop_torn`). The stream
## grows wider and brighter as more of the dwarf goes into it. No ring is marked
## (Jon: "I don't want the red ring to be in the game").
##
## Drawn by the painted chart's place pass (`chart_torn.gdshaderinc`) from these
## uniforms. Off unless the run sets it (`active`), so no dwarf run changes
## until TORN AWAY is built; SIMPLIFIED and RADIANT draw the dwarf as before
## (only the lost rings' systems leave the chart there).
##
## Proto: `lost` is set by hand (`sheet=ChartLook torn=N`); the mechanic that
## drives it is being designed elsewhere.

## On for this run (TORN AWAY sets it; `sheet=ChartLook torn=N` here).
static var active := false
## Rings lost so far, 0 .. MAX_LOST (a float, so a film can sweep it).
static var lost := 0.0
## -1: on for the dwarfs while `active`. 0 / 1 force it off / on for any kind (a bench's).
static var force := -1

## Back to off, as a new run starts (statics outlive a run: the mechanic,
## when it is built, calls this where a run begins).
static func reset() -> void:
	active = false
	lost = 0.0
	force = -1


## At most this many rings fall: the last four (and the core) hold.
const MAX_LOST := MapGen.LAYERS - 5

## The giant, in the dwarf's plane (gu) and height above it (gu): up the screen,
## to the left of the core, far enough that its line lies above the rim.
const GIANT := Vector3(-0.35, -1.3, 0.4)
## The dwarf's orbit round it, tilted out of the chart's plane.
const INC := 0.61
## The stream spirals in to the giant over this much of a turn.
const SPAN := PI * 1.3
## Its points (the shader's TORN_N).
const N := 48
## The giant on the screen: half its length (gu, wider than the dwarf's whole
## disc: it is the bigger galaxy) and its tilt.
const GIANT_LEN := 1.2
const GIANT_ANG := -0.21
## How far the torn edge is drawn out toward the stream by the end, a share of
## the edge (the tidal side: the shader's `tornShape`, the stars' cut).
const LOBE := 0.35
## How far the dwarf's light reads on the screen, in its ball's own radii
## (`ballS`'s s), by kind: a blue compact dwarf's bright young glow reaches well
## past its ball, a dwarf spheroidal's faint old light only part way. The stream
## is drawn out of the body inside this (`lit_along`): measured off the painted
## chart at every ring lost (v6/measure.py), where the light leaves the sky.
const LIT_S := {14: 1.8, 15: 0.58}
## Where the dwarf's drawn light and its thick stars end at the opening, by kind
## (gu, the ball's own frame, round on the screen): measured off the painted chart
## with TORN AWAY off (v7/prof.py: the share of lit pixels falls to the sky's).
const R_DRAWN := {14: 0.21, 15: 0.18}


static func on() -> bool:
	if force >= 0:
		return force == 1
	return active and (Run.galaxy_kind == 14 or Run.galaxy_kind == 15)


## Whether a system's ring has gone to the giant.
static func gone(n: MapGen.MapNode) -> bool:
	return on() and n.type != MapGen.NodeType.CORE and n.layer < int(floor(lost + 1e-4))


## The drawn edge with `l` whole rings lost (gu, the rings' radius): halfway
## between the last ring lost and the outermost left; with none lost, the same
## half gap past the rim.
static func _edge_at(l: int) -> float:
	if l <= 0:
		return MapGen.ring_radius(0) + 0.5 * (MapGen.ring_radius(0) - MapGen.ring_radius(1))
	return 0.5 * (MapGen.ring_radius(l - 1) + MapGen.ring_radius(l))


## The drawn edge now, eased between rings so a film can sweep `lost`.
static func edge() -> float:
	var l := clampf(lost, 0.0, float(MAX_LOST))
	var i := int(floor(l))
	return lerpf(_edge_at(i), _edge_at(mini(i + 1, MAX_LOST)), l - float(i))


## The dwarf is never drawn smaller now (a redraw, not a shrink): 1, kept for
## the bench's log.
static func scale() -> float:
	return 1.0


## The dwarf's drawn edge (gu, the ball's own frame): its drawn reach as a share
## of its rings' (`edge()` over the rim's), so it goes ring by ring as the rings
## do, eased between them as `edge()` is. Nothing inside it moves.
static func drawn_edge() -> float:
	return float(R_DRAWN.get(Run.galaxy_kind, 0.2)) * edge() / _edge_at(0)


## How far the torn edge is drawn out toward the stream (a share of the edge):
## none with no ring lost, `LOBE` by the end.
static func lobe() -> float:
	return LOBE * progress()


## The ball's own frame (gu, round on the screen as its light is drawn, `ballS`)
## of a point of the stream's polyline.
static func _ball_pt(p: Vector4, bsq: float) -> Vector2:
	return Vector2(p.x, p.y / bsq) / ChartSky.K0


static func _bsq() -> float:
	var ball := ChartSky.ball_of(Run.galaxy_kind, Run.galaxy)
	return ChartPainted.ball_squash(Run.galaxy_kind, ball)


## Where the dwarf's lit body ends along the stream, as its length along (gu on
## the screen): the stream is drawn out of the body from inside this (the shader's
## `tornStream`), so it reads as the dwarf's own light pulled off, never starting
## out in the empty sky past it (Jon, Nov 8, "Why is there a gap between the stream
## in the galaxy"). The body is drawn at its real size now, so this is where its
## light ends (`LIT_S`), or the torn edge where that has come inside it, as it
## does from the first ring.
static func lit_along(_phi: float, pts: PackedVector4Array) -> float:
	var ball := ChartSky.ball_of(Run.galaxy_kind, Run.galaxy)
	var rb := ball.x * ChartPainted.ball_form(Run.galaxy_kind).x
	var bsq := _bsq()
	var lit := rb * float(LIT_S.get(Run.galaxy_kind, 1.0))
	if lost > 1e-4:
		lit = minf(lit, drawn_edge() * (1.0 + lobe()))
	var prev_r := 0.0
	for i in pts.size():
		var r := _ball_pt(pts[i], bsq).length()
		if r >= lit and i > 0:
			var f := clampf((lit - prev_r) / maxf(r - prev_r, 1e-6), 0.0, 1.0)
			return lerpf(pts[i - 1].z, pts[i].z, f)
		prev_r = r
	return pts[pts.size() - 1].z


## Which way the stream leaves the dwarf where it crosses the torn edge: in the
## ball's own frame on the screen (xy: the body's light and its thick stars,
## at the drawn edge) and in the galaxy's plane, its squash on y as the rings'
## (zw: the stars' cut at the rings' edge). The edge is drawn out that way, the
## tidal side.
static func stream_dir(pts: PackedVector4Array) -> Vector4:
	var e := drawn_edge()
	var bsq := _bsq()
	var db := Vector2(1, 0)
	for i in range(1, pts.size()):
		var b := _ball_pt(pts[i], bsq)
		db = b.normalized()
		if b.length() >= e:
			break
	var sq := float(Run.galaxy.get("squash", 0.85))
	var dp := Vector2(1, 0)
	for i in range(1, N):
		var q := ribbon3(float(i) / float(N - 1))
		dp = Vector2(q.x, q.y * sq).normalized()
		if q.length() >= edge():
			break
	return Vector4(db.x, db.y, dp.x, dp.y)


## How far the run is into the decay, 0 .. 1.
static func progress() -> float:
	return clampf(lost / float(MAX_LOST), 0.0, 1.0)


## The line to the giant, in the galaxy's plane (unit).
static func axis() -> Vector2:
	return Vector2(-GIANT.x, -GIANT.y).normalized()


## The stream at age f (0 at the dwarf's core, 1 in the giant's middle), in the
## dwarf's plane (gu) and height above it.
static func ribbon3(f: float) -> Vector3:
	var e1 := (-GIANT).normalized()
	var pp := Vector3(-e1.y, e1.x, 0.0).normalized()
	var e2 := pp * cos(INC) + Vector3(0, 0, 1) * sin(INC)
	var th := f * SPAN
	return GIANT + (e1 * cos(th) + e2 * sin(th)) * GIANT.length() * pow(1.0 - f, 1.25)


static func _v3(p: Vector3, phi: float) -> Vector2:
	var c := cos(phi)
	var s := sin(phi)
	return Vector2(p.x * c + p.y * s, (p.y * c - p.x * s) * ChartSky.TILT - p.z * 0.92499) * ChartSky.K0


## The stream as a polyline in view px (zoom 1, about the core): x, y, its
## length along from the dwarf (gu on the screen), and its age (0 at the dwarf's
## core, 1 in the giant's middle). It leaves the dwarf toward the giant and
## spirals in, out of the chart's plane up to the giant's.
static func ribbon(phi: float) -> PackedVector4Array:
	var out := PackedVector4Array()
	var acc := 0.0
	var prev := Vector2.ZERO
	for i in N:
		var f := float(i) / float(N - 1)
		var q := ribbon3(f)
		var vv := _v3(q, phi)
		if i > 0:
			acc += (vv - prev).length() / ChartSky.K0
		prev = vv
		out.append(Vector4(vv.x, vv.y, acc, f))
	return out


## Every frame, on the painted place pass.
static var _pushed := Vector4(-1, -1, -1, -1)
static var _mp_id := 0
## The turn it was last drawn at (a bench's log reads the stream with it).
static var last_phi := 0.0


## Which way the stream leaves the dwarf, as last pushed (`stream_dir`).
static var _dir := Vector4(1, 0, 1, 0)


## (`ms`: the chart's own stars, `chart_b_stars`'s material: cut with the dwarf at
## its torn edge, set every frame, and set back to none when it is off)
static func push(mp: ShaderMaterial, ms: ShaderMaterial, phi: float) -> void:
	# (a new place pass has none of it yet)
	if mp.get_instance_id() != _mp_id:
		_mp_id = mp.get_instance_id()
		_pushed = Vector4(-1, -1, -1, -1)
	if not on():
		if _pushed.x != 0.0:
			mp.set_shader_parameter("u_torn", Vector4.ZERO)
			_pushed = Vector4.ZERO
		if ms != null:
			ms.set_shader_parameter("torn", Vector4.ZERO)
		return
	last_phi = phi
	var sq := float(Run.galaxy.get("squash", 0.85))
	# (only when something moved: the turn is slow, the rings fall seldom)
	var key := Vector4(1.0, snappedf(phi, 1e-5), lost, float(Run.galaxy_kind))
	if key != _pushed:
		_pushed = key
		var gv := _v3(GIANT, phi)
		# (the line to the giant, in the plane: the shader turns it as it needs)
		var e1 := axis()
		var pts := ribbon(phi)
		_dir = stream_dir(pts)
		mp.set_shader_parameter("u_torn", Vector4(1.0, drawn_edge(), progress(), sq))
		mp.set_shader_parameter("u_tornG", Vector4(gv.x, gv.y, GIANT_ANG, GIANT_LEN))
		mp.set_shader_parameter("u_tornA", Vector4(e1.x, e1.y, 1.0, clampf(lost, 0.0, float(MAX_LOST))))
		# (the stream's head as wide as the dwarf is drawn: narrower as it is stripped)
		mp.set_shader_parameter("u_tornB", Vector4(0.0, clampf(lost, 0.0, 1.0), lit_along(phi, pts), edge() / _edge_at(0)))
		mp.set_shader_parameter("u_tornC", Vector4(_dir.x, _dir.y, lobe(), 0.0))
		mp.set_shader_parameter("u_tornP", pts)
	if ms != null:
		ms.set_shader_parameter("torn", Vector4(1.0, edge(), sq, clampf(lost, 0.0, 1.0)))
		ms.set_shader_parameter("torn2", Vector4(_dir.z, _dir.w, lobe(), drawn_edge()))
		ms.set_shader_parameter("torn3", Vector4(_dir.x, _dir.y, _bsq(), float(R_DRAWN.get(Run.galaxy_kind, 0.2))))
