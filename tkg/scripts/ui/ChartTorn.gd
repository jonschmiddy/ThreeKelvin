class_name ChartTorn
extends RefCounted

## TORN AWAY, direction B (proto/dwarf-b): the stream. The hardest galaxies, the
## two dwarfs (GalaxyGen kinds 14 and 15), are being eaten by a giant neighbour.
## ONE stream of the dwarf's stars (Jon, Nov 7: "a single stream of the galaxy
## being pulled, rather than two") trails out of it along its orbit round the giant
## and, as the dwarf is stripped, grows into a loop of stars wrapped round the giant
## (Jon's Nov 8 reference, a minor merger in three panels: a trail along the orbit,
## then a loop round the big galaxy, then only the faint loop left).
##
## THE DWARF IS DRAWN BIG (Jon, Nov 8, "SIZE: bigger", and "I basically want the
## dwarf to be drawn large, and then get smaller and smaller as it's stripped away
## to nothing"): its body reaches past its outermost ring (`cover`), whether TORN
## AWAY is on or not, so every system sits on it. Its core keeps its real size; the
## body round it is a faint envelope (`ball_v`, read by every style's ball), its
## light, clumps and stars read at the new size, never a picture scaled up.
##
## The rings fall away from the outside in (`lost`, rings gone so far, to
## `max_lost`). With each ring lost the dwarf is REDRAWN, never shrunk (Jon, Nov 8:
## "it's almost like the image of the galaxy is shrinking rather than a true
## redraw"): REDRAW A, STRIPPED. Its core, body, glow and stars keep their size and
## place; past its edge (`edge`, at the rings' own radii, `ring_r`) they are gone,
## the edge torn (ragged on the galaxy's own noise, never inside the outermost ring
## still standing, drawn out toward the stream, its last band broken into clumps that
## feed the stream's start). The systems on the lost rings are off the chart (`gone`,
## `StarchartScreen._drop_torn`). No ring is marked (Jon: "I don't want the red ring
## to be in the game").
##
## THE END (an open game question, one switch: `ending`): today the last four rings
## never fall. F (the default, the rules unchanged): rings 0-9 can fall, and the
## picture is stripped to nothing as ring 9 goes; the four inner rings' systems are
## left where they stand, loose stars in the stream. N: all 14 rings can fall, and
## the dwarf is eaten whole.
##
## Drawn by every style's place pass (`chart_torn_core.gdshaderinc`, and PAINTED's
## `chart_torn.gdshaderinc`) from these uniforms. Off unless the run sets it
## (`active`), so no dwarf run changes but for its size until TORN AWAY is built.
##
## Proto: `lost` is set by hand (`sheet=ChartLook torn=N`); the mechanic that
## drives it is being designed elsewhere.

## On for this run (TORN AWAY sets it; `sheet=ChartLook torn=N` here).
static var active := false
## Rings lost so far, 0 .. `max_lost` (a float, so a film can sweep it).
static var lost := 0.0
## -1: on for the dwarfs while `active`. 0 / 1 force it off / on for any kind (a bench's).
static var force := -1
## How the decay ends (`tornend=N|F`): &"F" the rules as they are (the last four rings
## hold, the picture goes to nothing over them), &"N" every ring falls.
static var ending := &"F"
## The dwarfs drawn big (`dwarfbig=0` draws them as before, for a before/after).
static var big := true

## Back to off, as a new run starts (statics outlive a run: the mechanic,
## when it is built, calls this where a run begins).
static func reset() -> void:
	active = false
	lost = 0.0
	force = -1


## The rings a galaxy has (the core is not one).
const RINGS := MapGen.LAYERS - 1
## Ending F follows the rings' own edges to here, then closes over the rings left
## to fall (`edge_at`).
const F_FOLLOW := 6

## The giant, on the screen (gu at zoom 1 about the dwarf's core, the core's own
## frame, `vb`): up and to the left, its middle in the opening view's upper left
## corner, clear of the dwarf's body, the rings' systems and the HUD's goal line, its
## disc running on behind the dwarf (drawn over the sky only). Fixed on the screen (the
## dwarf turns under it: it is stripped evenly all round, so nothing is lost by it),
## so it never comes over the dwarf's core.
const GIANT_S := Vector2(-1.02, -0.56)
## The giant on the screen: half its length (gu, wider than the dwarf's whole
## body: it is the bigger galaxy) and its tilt.
const GIANT_LEN := 0.95
const GIANT_ANG := -0.32
## The dwarf's orbit round it, on the screen: an ellipse about the giant along its
## tilt, this much as tall across as along (a loop seen a little from above), through
## the dwarf's core.
const LOOP_Q := 0.72
## The stream trails along that orbit this far round (radians) at the start, and
## the whole way round by the end (`span`), so it closes into a loop.
const SPAN0 := PI * 0.2
const SPAN1 := TAU * 0.985
## Its points (the shader's TORN_N).
const N := 48
## How far the torn edge is drawn out toward the stream by the end, a share of the
## edge (the tidal side: the shader's `tornShape`, the stars' cut), and at most (gu).
const LOBE := 0.35
const LOBE_MAX := 0.12
## The big dwarf's reach past its outermost ring's edge (`cover`), and where its lit
## body ends inside that (the stream is drawn out of the body from inside it,
## `lit_along`): measured off the painted chart, where the light leaves the sky.
const COVER_K := 1.1
const LIT_K := 0.9
## The dwarf before the big body (`dwarfbig=0`): where its light ended, in its
## ball's own radii (`ballS`'s s), by kind.
const LIT_S := {14: 1.8, 15: 0.58}


static func on() -> bool:
	if force >= 0:
		return force == 1
	return active and dwarf(Run.galaxy_kind)


## The two dwarfs, the galaxies TORN AWAY is for.
static func dwarf(kind: int) -> bool:
	var nm := GalaxyGen.type_name(kind)
	return nm == "Blue Compact Dwarf" or nm == "Dwarf Spheroidal"


## Whether this galaxy's dwarf is drawn big (`cover`).
static func big_on(kind: int = -1) -> bool:
	return big and dwarf(Run.galaxy_kind if kind < 0 else kind)


## How many rings can fall (`ending`).
static func max_lost() -> int:
	return RINGS if ending == &"N" else MapGen.LAYERS - 5


## Whether a system's ring has gone to the giant.
static func gone(n: MapGen.MapNode) -> bool:
	return on() and n.type != MapGen.NodeType.CORE and n.layer < int(floor(minf(lost, float(max_lost())) + 1e-4))


# ------------------------------------------------------------------ the rings' own radii

static var _rr_key := ""
static var _rr := PackedFloat32Array()
static var _ro := PackedFloat32Array()
## How far past the farthest system still standing the edge stays at least (gu): its
## mark stands on the picture (the shader's TORN_MARGIN floor is this, on its ring).
const STAND := 0.02


## Ring l's radius in the galaxy's own plane (gu): the median of its systems'
## (`MapNode.gal`, unsquashed as `hop_distance` measures), so the galaxy's reach,
## its rings' spread and a test's stretch are all in it; the rings' schedule where
## the map has none on it.
static func ring_r(l: int) -> float:
	_rings()
	return _rr[l] if l >= 0 and l < _rr.size() else 0.0


static func _rings() -> void:
	var first := Vector2.ZERO
	if Run.map.size() > 1:
		first = (Run.map[1] as MapGen.MapNode).gal
	var key := "%d:%d:%d:%s:%s" % [Run.galaxy_seed, Run.galaxy_kind, Run.map.size(), first, Run.galaxy.get("reach", 1.0)]
	if key == _rr_key and _rr.size() == RINGS:
		return
	_rr_key = key
	var sq := maxf(float(Run.galaxy.get("squash", 0.85)), 0.05)
	var by: Array = []
	for l in RINGS:
		by.append([])
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.CORE or n.layer < 0 or n.layer >= RINGS:
			continue
		(by[n.layer] as Array).append(Vector2(n.gal.x, n.gal.y / sq).length())
	var reach := float(Run.galaxy.get("reach", 1.0)) * MapGen.test_stretch
	_rr.resize(RINGS)
	_ro.resize(RINGS)
	for l in RINGS:
		var a: Array = by[l]
		if a.is_empty():
			_rr[l] = MapGen.ring_radius(l) * reach
			_ro[l] = _rr[l]
		else:
			a.sort()
			_rr[l] = float(a[a.size() / 2])
			_ro[l] = float(a[a.size() - 1])
	# (the farthest of each ring and every ring inside it: a system the map's layout
	# pushed out past its ring -- 0.82 gu on a rim of 0.70 -- still stands on the picture)
	for l in range(RINGS - 2, -1, -1):
		_ro[l] = maxf(_ro[l], _ro[l + 1])


## The farthest system on ring l or any ring inside it (gu, the plane).
static func ring_out(l: int) -> float:
	_rings()
	return _ro[l] if l >= 0 and l < _ro.size() else 0.0


## The rings' edge with `l` whole rings lost (gu, the plane): halfway between the
## last ring lost and the outermost left (their medians); with none lost, the same
## half gap past the rim; with every ring lost, nothing. Never inside the farthest
## system still standing (`ring_out`, by STAND).
static func real_edge(l: int) -> float:
	if l >= RINGS:
		return 0.0
	var e := ring_r(0) + 0.5 * (ring_r(0) - ring_r(1)) if l <= 0 else 0.5 * (ring_r(l - 1) + ring_r(l))
	return maxf(e, ring_out(maxi(l, 0)) + STAND)


## The big dwarf's reach (gu, the ball's own frame: along the screen's width, the
## plane's): past its outermost ring, so its light covers every system.
static func cover() -> float:
	return maxf(COVER_K * (ring_r(0) + 0.5 * (ring_r(0) - ring_r(1))), ring_out(0) + 2.0 * STAND)


## The picture's edge with `l` whole rings lost (gu): the rings' own (`real_edge`).
## Ending N follows them to nothing; ending F follows them to `F_FOLLOW`, then closes
## evenly to nothing as its last ring falls (the inner four rings' systems stand
## past it then, loose in the stream).
static func edge_at(l: int) -> float:
	var ml := max_lost()
	if l >= ml:
		return 0.0
	if ending == &"N" or l <= F_FOLLOW:
		return real_edge(l)
	return real_edge(F_FOLLOW) * float(ml - l) / float(ml - F_FOLLOW)


## The edge now, eased between rings so a film can sweep `lost`.
static func edge() -> float:
	var l := clampf(lost, 0.0, float(max_lost()))
	var i := int(floor(l))
	return lerpf(edge_at(i), edge_at(mini(i + 1, max_lost())), l - float(i))


## The farthest system still standing (gu, the plane), the torn edge's floor: none
## (0) once the picture has gone inside it (ending F's last rings).
static func live_r() -> float:
	var l := int(floor(clampf(lost, 0.0, float(max_lost())) + 1e-4))
	if l >= RINGS:
		return 0.0
	var r := ring_out(l)
	return r if r < edge() else 0.0


## The dwarf is never drawn smaller (a redraw, not a shrink): 1, kept for the bench's log.
static func scale() -> float:
	return 1.0


## How far the torn edge is drawn out toward the stream (a share of the edge):
## none with no ring lost, `LOBE` by the end.
static func lobe() -> float:
	return LOBE * progress()


## How far the run is into the decay, 0 .. 1.
static func progress() -> float:
	return clampf(lost / float(max_lost()), 0.0, 1.0)


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
## in the galaxy"). The big body's lit reach (`LIT_K` of `cover`), or the torn edge
## where that has come inside it, as it does from the first ring.
static func lit_along(_phi: float, pts: PackedVector4Array) -> float:
	var lit := lit_r()
	var bsq := _bsq()
	var prev_r := 0.0
	for i in pts.size():
		var r := _ball_pt(pts[i], bsq).length()
		if r >= lit and i > 0:
			var f := clampf((lit - prev_r) / maxf(r - prev_r, 1e-6), 0.0, 1.0)
			return lerpf(pts[i - 1].z, pts[i].z, f)
		prev_r = r
	return pts[pts.size() - 1].z


## The lit body's reach now (gu, the ball's own frame).
static func lit_r() -> float:
	var lit: float
	if big_on():
		lit = LIT_K * cover()
	else:
		var ball := ChartSky.ball_of(Run.galaxy_kind, Run.galaxy)
		lit = ball.x * ChartPainted.ball_form(Run.galaxy_kind).x * float(LIT_S.get(Run.galaxy_kind, 1.0))
	if lost > 1e-4:
		lit = minf(lit, edge() + minf(edge() * lobe(), LOBE_MAX))
	return lit


## Which way the stream leaves the dwarf where it crosses the torn edge: in the
## ball's own frame on the screen (xy: the body's light), and in the galaxy's plane at
## this turn (zw: the stars' cut, which turn with the galaxy under the fixed stream).
## The edge is drawn out that way, the tidal side.
static func stream_dir(pts: PackedVector4Array, phi: float) -> Vector4:
	var e := maxf(edge(), 0.02)
	var bsq := _bsq()
	var db := Vector2(-1, 0)
	for i in range(1, pts.size()):
		var b := _ball_pt(pts[i], bsq)
		db = b.normalized()
		if b.length() >= e:
			break
	# (the screen's way back into the plane: the chart's projection turned back)
	var sx := db.x
	var sy := db.y * bsq / ChartSky.TILT
	var c := cos(phi)
	var s := sin(phi)
	var dp := Vector2(sx * c - sy * s, sx * s + sy * c).normalized()
	return Vector4(db.x, db.y, dp.x, dp.y)


# ------------------------------------------------------------------ the orbit

## The giant's frame on the screen: its axis along.
static func _gax() -> Vector2:
	return Vector2(cos(GIANT_ANG), sin(GIANT_ANG))


## The orbit's size along the giant (gu): the ellipse about the giant, LOOP_Q as tall
## across, through the dwarf's core; and the angle on it the dwarf stands at.
static func _orbit() -> Vector2:
	var ax := _gax()
	var d := -GIANT_S
	var along := d.x * ax.x + d.y * ax.y
	var across := -d.x * ax.y + d.y * ax.x
	var a := sqrt(along * along + (across / LOOP_Q) * (across / LOOP_Q))
	return Vector2(a, atan2(across / LOOP_Q / a, along / a))


## A point of the orbit at angle th (gu on the screen about the dwarf's core).
static func _orbit_at(th: float) -> Vector2:
	var o := _orbit()
	var ax := _gax()
	var al := o.x * cos(th)
	var ac := o.x * LOOP_Q * sin(th)
	return GIANT_S + ax * al + Vector2(-ax.y, ax.x) * ac


## Which way round the stream trails (+1 or -1): leftward from the dwarf, under the
## giant and up its far side.
static func _trail_sign() -> float:
	var th0 := _orbit().y
	return 1.0 if _orbit_at(th0 + 0.05).x < _orbit_at(th0 - 0.05).x else -1.0


## How far round the orbit the stream reaches now (radians): a short trail at the
## start, the whole way round by the end.
static func span() -> float:
	return lerpf(SPAN0, SPAN1, smoothstep(0.0, 1.0, progress()))


## The stream as a polyline in view px (zoom 1, the core's own frame): x, y, its
## length along from the dwarf (gu on the screen), and its age (0 at the dwarf's
## core, 1 at the stream's far end, round the orbit). Fixed on the screen: `phi` is
## kept for the bench's log.
static func ribbon(_phi: float = 0.0) -> PackedVector4Array:
	var out := PackedVector4Array()
	var acc := 0.0
	var prev := Vector2.ZERO
	var th0 := _orbit().y
	var sg := _trail_sign()
	var sp := span()
	for i in N:
		var f := float(i) / float(N - 1)
		var q := _orbit_at(th0 + sg * f * sp)
		if i == 0:
			q = Vector2.ZERO
		var vv := q * ChartSky.K0
		if i > 0:
			acc += (vv - prev).length() / ChartSky.K0
		prev = vv
		out.append(Vector4(vv.x, vv.y, acc, f))
	return out


# ------------------------------------------------------------------ to the shaders

## Every frame, on the place pass.
static var _pushed := Vector4(-1, -1, -1, -1)
static var _mp_id := 0
## The turn it was last drawn at (a bench's log reads the stream with it).
static var last_phi := 0.0


## Which way the stream leaves the dwarf, as last pushed (`stream_dir`).
static var _dir := Vector4(-1, 0, 1, 0)


## (`ms`: the chart's own stars' material, PAINTED's `chart_b_stars`: cut with the
## dwarf at its torn edge, set every frame, and set back to none when it is off; null
## in the styles that cut their stars in the place pass)
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
	var bsq := _bsq()
	# (only when something moved: the turn is slow, the rings fall seldom)
	var key := Vector4(1.0, snappedf(phi, 1e-5), lost, float(Run.galaxy_kind) + (0.5 if ending == &"N" else 0.0))
	if key != _pushed:
		_pushed = key
		var pts := ribbon(phi)
		_dir = stream_dir(pts, phi)
		var e0 := edge_at(0)
		mp.set_shader_parameter("u_torn", Vector4(1.0, edge(), progress(), sq))
		mp.set_shader_parameter("u_tornG", Vector4(GIANT_S.x * ChartSky.K0, GIANT_S.y * ChartSky.K0, GIANT_ANG, GIANT_LEN))
		mp.set_shader_parameter("u_tornA", Vector4(0.0, 0.0, 1.0, clampf(lost, 0.0, float(max_lost()))))
		# (the rings' own flatness in the ball's frame, for the edge's floor; the cut's
		# strength; where the lit body ends along the stream; the stream's head as wide
		# as the dwarf is drawn: narrower as it is stripped)
		mp.set_shader_parameter("u_tornB", Vector4(ChartSky.TILT / bsq, clampf(lost, 0.0, 1.0), lit_along(phi, pts), edge() / maxf(e0, 1e-4)))
		mp.set_shader_parameter("u_tornC", Vector4(_dir.x, _dir.y, lobe(), live_r()))
		mp.set_shader_parameter("u_tornP", pts)
		# (the stars cut in the place pass, SIMPLIFIED's and RADIANT's: in the plane, as
		# PAINTED's sparkles are)
		mp.set_shader_parameter("u_tornS", Vector4(_dir.z, _dir.w, LOBE_MAX, 0.0))
	if ms != null:
		ms.set_shader_parameter("torn", Vector4(1.0, edge(), sq, clampf(lost, 0.0, 1.0)))
		ms.set_shader_parameter("torn2", Vector4(_dir.z, _dir.w, lobe(), LOBE_MAX))
		ms.set_shader_parameter("torn3", Vector4(_dir.x, _dir.y, bsq, live_r()))


# ------------------------------------------------------------------ the big body

## The big dwarf's body, every style's (`u_ballV`): its reach (gu, the ball's own
## frame), its envelope's level against the body's middle, the power that envelope's
## light falls by, on. Off for every other galaxy (and with `dwarfbig=0`).
static func ball_v(level: float, power: float) -> Vector4:
	if not big_on():
		return Vector4(1.0, 0.0, 1.0, 0.0)
	return Vector4(cover(), level, power, 1.0)


## The chart's own star field for a big dwarf (`MapChart._build_field`, on a worker
## too: it reads only the galaxy it is handed): the reach its thick stars spread to
## (a share of r_max, the plane's gu), so they lie over the big body as its light
## does; 0 for any other galaxy, or with `dwarfbig=0`.
static func field_reach(g: Dictionary) -> float:
	if not big:
		return 0.0
	var nm := String(g.get("name", ""))
	if nm != "Blue Compact Dwarf" and nm != "Dwarf Spheroidal":
		return 0.0
	# (the rim's ring stands at about 0.95 of the reach, its edge a half gap past it)
	return LIT_K * COVER_K * 0.95 * float(g.get("reach", 1.0))
