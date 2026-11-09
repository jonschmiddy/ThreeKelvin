class_name ChartTorn
extends RefCounted

## TORN AWAY (the two dwarfs eaten by a giant): one tapered stream, the dwarf drawn big
## and stripped ring by ring, its clouds torn with it. Off unless `active`.
## Why: docs/why/ChartTorn.md#torn-away

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

## THE HOOK (Jon, Nov 8, "THIS IS EXACTLY RIGHT!!!"): the approved mockup's geometry, in
## its own pixels about the dwarf's core, drawn at `HOOK_PX` opening px each.
## Why: docs/why/ChartTorn.md#the-hook
const HOOK_PX := 1.5
## The opening's zoom (`MapChart.ZOOM_MIN`, as a harness's z): opening px per view px.
const Z_OPEN := 0.42
## The giant's middle at 0 lost, and how far it closes in by `HOOK_LOST` (mockup px).
const GIANT_M := Vector2(-177.0, -88.0)
const GIANT_IN := Vector2(42.0, 26.0)
## Its half length and half breadth on the screen (mockup px; it grows by GIANT_GROW),
## and its tilt (rad, its right end up).
const GIANT_RX := 62.0
const GIANT_RY := 30.0
const GIANT_GROW := 0.3
const GIANT_ANG := -0.25
## The rings lost by which the giant is in closest and the stream's share is whole.
const HOOK_LOST := 10.0
## The stream's bend: from the root, its first control point this far on (down and left),
## its second this far below the core and this far left of the giant; into the giant's
## underside here, off its middle (mockup px, times the giant's growth).
const HOOK_C1 := Vector2(-68.0, 48.0)
const HOOK_C2Y := 64.0
const HOOK_C2X := -78.0
const HOOK_IN := Vector2(-43.0, 22.0)
## The stream's root half width (mockup px at 0 lost, narrowing as the dwarf is
## stripped) and the least it narrows to before its tip (`tornW`).
const HOOK_W0 := 22.0
const HOOK_WMIN := 1.5
## How far the turn (the hook's third point) slides toward the giant's share: 0 holds it
## with the dwarf, so a pan bends only the climb.
const HOOK_BEND := 0.0
## PARALLAX: the share of a pan the giant moves with, at 0 lost and at `HOOK_LOST`.
const PAR_FAR := 0.4
const PAR_NEAR := 0.8
## THE OPENING (TORN AWAY on): the dwarf's core this far right and down of the chart's
## middle (gu at zoom 1), so the giant stands whole in the upper left.
const OPEN_SHIFT := Vector2(0.25, 0.135)
## The stream's points (the shader's TORN_N).
const N := 48
## THE BIG DWARF FAINTER UNDER THE GIANT: with TORN AWAY on, its envelope's light is
## this share of a normal run's (`ball_v`), so the giant reads as the bigger, brighter
## galaxy doing the eating; its size is unchanged.
const ENV_TORN := 0.7
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
## the screen): kept for the bench's log. The shader rises the stream out of the
## body by the lit reach itself (`lit_r`, in the ball's own frame, all round the
## stream's root: the tail hugs the body's sides, never starting out in the empty
## sky past it; Jon, Nov 8, "Why is there a gap between the stream in the galaxy").
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


# ------------------------------------------------------------------ the hook

## Mockup px to gu on the screen (zoom 1, about the dwarf's core).
static func _m(v: Variant) -> Variant:
	return v * HOOK_PX / (ChartSky.K0 * Z_OPEN)


## How far in the decay the hook is, 0 .. 1 (rings lost over `HOOK_LOST`).
static func share() -> float:
	return clampf(lost / HOOK_LOST, 0.0, 1.0)


## How far round the stream has come (a share of its path): well on its way with none
## lost, all the way in from about 3.
static func reach() -> float:
	return minf(1.0, 0.62 + share() * 1.3)


## The giant's growth (its size against the opening's).
static func giant_s() -> float:
	return 1.0 + GIANT_GROW * share()


## How much of a pan the giant moves with: further off than the chart's plane, nearer
## as it closes in.
static func par() -> float:
	return lerpf(PAR_FAR, PAR_NEAR, share())


## The giant's middle, still (gu on the screen about the dwarf's core): closer as it feeds.
static func giant_at() -> Vector2:
	return _m(GIANT_M + GIANT_IN * share())


## Its half length (gu on the screen).
static func giant_len() -> float:
	return _m(GIANT_RX) * giant_s()


## The chart's pan at the opening (px, the core off the chart's middle) at zoom `ze`
## (px a view px): the dwarf down and to the right, the giant whole above it to the
## left; none with TORN AWAY off.
static func open_pan(ze: float) -> Vector2:
	return OPEN_SHIFT * ChartSky.K0 * ze if on() else Vector2.ZERO


## The view's pan away from the opening (gu at zoom 1, the view's centre against the
## opening's), set every frame by the place pass (`push`).
static var view_off := Vector2.ZERO
## A block (gu at zoom 1) at the zoom drawn now.
static var view_blk := 0.0


## How far a layer that moves `k` of a pan has slid against the chart (gu at zoom 1):
## in whole blocks, rigid, never a crawl.
static func slide(k: float) -> Vector2:
	var s := (1.0 - k) * view_off
	if view_blk <= 0.0:
		return s
	return (s / view_blk).round() * view_blk


## The dwarf's lit body on the screen now (gu, its half width and half height).
static func _body() -> Vector2:
	var lit := lit_r() if lost <= 1e-4 or edge() > 0.0 else 0.0
	return Vector2(lit, lit * _bsq())


## The stream's root: the dwarf's left side (gu on the screen about its core).
static func root_at() -> Vector2:
	var b := _body()
	return Vector2(-0.85 * b.x, 0.15 * b.y)


## The hook's four control points (gu on the screen about the dwarf's core), as drawn
## now: the root, the sweep and the turn held with the dwarf (1:1), only the end in the
## giant's underside slid with the giant, so a pan bends just the climb (Jon, Nov 8).
static func hook() -> PackedVector2Array:
	var g := giant_at()
	var s := giant_s()
	var b0 := Vector2(LIT_K * cover(), LIT_K * cover() * _bsq()) if big_on() else _body()
	var c1: Vector2 = Vector2(-0.85 * b0.x, 0.15 * b0.y) + _m(HOOK_C1)
	var c2 := Vector2(g.x + _m(HOOK_C2X * s), maxf(_m(HOOK_C2Y), c1.y + _m(9.0)))
	var c3: Vector2 = g + _m(HOOK_IN * s)
	var p := par()
	return PackedVector2Array([root_at(), c1, c2 + slide(1.0 - HOOK_BEND * (1.0 - p)), c3 + slide(p)])


static func _bez(c: PackedVector2Array, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * c[0] + 3.0 * u * u * t * c[1] + 3.0 * u * t * t * c[2] + t * t * t * c[3]


## The stream as a polyline in view px (zoom 1, the core's own frame): x, y, its
## length along from the root (gu on the screen), and its age (0 at the root, 1 in
## the giant; drawn only to `reach`). `phi` is kept for the bench's log.
static func ribbon(_phi: float = 0.0) -> PackedVector4Array:
	var c := hook()
	var r := reach()
	var out := PackedVector4Array()
	var acc := 0.0
	var prev := Vector2.ZERO
	for i in N:
		var f := r * float(i) / float(N - 1)
		var vv := _bez(c, f) * ChartSky.K0
		if i > 0:
			acc += (vv - prev).length() / ChartSky.K0
		prev = vv
		out.append(Vector4(vv.x, vv.y, acc, f))
	return out


## The stream's root half width (gu on the screen): the mockup's band, as wide as the
## dwarf there, narrowing as it is stripped (the mockup's dwarf, 46 px less 3.4 a ring).
static func root_w() -> float:
	return _m(HOOK_W0) * (46.0 - 3.4 * share() * HOOK_LOST) / 46.0


# ------------------------------------------------------------------ the dwarf's clouds

## How far a named cloud is torn and which way it is drawn out: [tear, way].
## All zero (whole) off TORN AWAY and for a cloud outside the dwarf.
## Why: docs/why/ChartTorn.md#cloud-tear
const CLOUD_FLAT := 0.46341
static func cloud_tear(xy: Vector2, reach: float, phi: float) -> Array:
	if not on() or not big_on():
		return [Vector4.ZERO, Vector4.ZERO]
	var rc := xy.length()
	if rc - 0.5 * reach > cover():
		return [Vector4.ZERO, Vector4.ZERO]
	var e := edge()
	# (eaten as the torn edge comes in past it: none while the edge is out past its far
	# side, all of it once the edge is in past its middle by its size)
	var span := 2.0 * reach + 0.08
	var eat := clampf((rc + reach - e) / span, 0.0, 1.0)
	eat = eat * eat * (3.0 - 2.0 * eat)
	# (and by the end every one of the dwarf's: nothing of them left whole)
	eat = maxf(eat, smoothstep(0.8, 1.0, progress()))
	if e <= 0.0 and lost > 1e-4:
		eat = 1.0
	var p := progress()
	var tear := Vector4(smoothstep(0.45, 1.0, eat), 4.0 * eat, 1.5 * eat * (reach + 0.04), 0.35 * minf(p * 4.0, 1.0) * (1.0 - eat))
	# the way it is drawn out, on the screen: sideways out from the core, as the mockup
	# smears them, a little up. Toward the stream's bend it dragged a cloud across the core
	# in a bar, and down the screen RADIANT's rays through it flickered (240 flips a second)
	var v := ChartSky._to_view(xy, phi) / ChartSky.K0
	var ds := Vector2(-1.0 if v.x <= 0.0 else 1.0, -0.3)
	var wr := Vector2(ds.x, ds.y / CLOUD_FLAT).normalized()
	# (back into the plane: the chart's projection turned back)
	var w := Vector2(ds.x, ds.y / ChartSky.TILT)
	var c := cos(phi)
	var sn := sin(phi)
	var wp := Vector2(w.x * c - w.y * sn, w.x * sn + w.y * c).normalized()
	return [tear, Vector4(wr.x, wr.y, wp.x, wp.y)]


## A point q of a cloud as drawn whole (its round frame on the screen, gu about its
## middle) to where it shows torn (the shader's `tornClFwd`): its own stars go with it.
static func cloud_fwd(tear: Vector4, way: Vector2, q: Vector2) -> Vector2:
	if tear.y <= 1e-4 and tear.w <= 1e-4 and tear.z <= 1e-4:
		return q
	var n := Vector2(-way.y, way.x)
	var a := q.dot(way)
	var b := q.dot(n) / (1.0 + 0.35 * tear.y)
	a *= (1.0 + tear.y) if a > 0.0 else (1.0 + 0.3 * tear.y)
	a += tear.z + tear.w * b
	return way * a + n * b


## Every cloud's tear for a place pass, in the order it holds them (`xys`, `reaches`):
## {u_tornCl, u_tornClD}, padded to n.
static func cloud_arrays(xys: Array, reaches: Array, phi: float, n: int) -> Dictionary:
	var a := PackedVector4Array()
	var b := PackedVector4Array()
	for i in mini(xys.size(), n):
		var t := cloud_tear(xys[i], float(reaches[i]), phi)
		a.append(t[0])
		b.append(t[1])
	a.resize(n)
	b.resize(n)
	return {"u_tornCl": a, "u_tornClD": b}


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
## in the styles that cut their stars in the place pass. `pan` the chart's pan (px) and
## `z` its zoom (px a view px), for the giant's parallax; z 0 for none)
static func push(mp: ShaderMaterial, ms: ShaderMaterial, phi: float, pan := Vector2.ZERO, z := 0.0) -> void:
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
	# (the view's centre against the opening's, gu at zoom 1: the parallax's pan)
	if z > 0.0:
		view_off = -pan / (z * ChartSky.K0) + OPEN_SHIFT
		view_blk = 2.0 / (z * ChartSky.K0)
	else:
		view_off = Vector2.ZERO
		view_blk = 0.0
	var sq := float(Run.galaxy.get("squash", 0.85))
	var bsq := _bsq()
	# (only when something moved: the turn is slow, the rings fall seldom, and the
	# parallax steps a block at a time)
	var gsl := slide(par())
	var key := Vector4(1.0, snappedf(phi, 1e-5), lost + 17.0 * gsl.x + 131.0 * gsl.y + 0.37 * view_blk, float(Run.galaxy_kind) + (0.5 if ending == &"N" else 0.0))
	if key != _pushed:
		_pushed = key
		var pts := ribbon(phi)
		_dir = stream_dir(pts, phi)
		var e0 := edge_at(0)
		var g := (giant_at() + gsl) * ChartSky.K0
		mp.set_shader_parameter("u_torn", Vector4(1.0, edge(), progress(), sq))
		mp.set_shader_parameter("u_tornG", Vector4(g.x, g.y, GIANT_ANG, giant_len()))
		# (the stream's root half width, as wide as the dwarf: narrower as it is stripped;
		# the length drawn, gu on the screen; how far round it has come)
		mp.set_shader_parameter("u_tornA", Vector4(root_w(), pts[pts.size() - 1].z, reach(), clampf(lost, 0.0, float(max_lost()))))
		# (the least half width before its tip, and the giant's breadth against its length)
		# (and the giant's slide in whole blocks, x here and y in u_tornS.w: PAINTED's
		# patterns ride with it, so it slides rigid)
		var gb := (gsl / view_blk).round() if view_blk > 0.0 else Vector2.ZERO
		mp.set_shader_parameter("u_tornH", Vector4(_m(HOOK_WMIN), GIANT_RY / GIANT_RX, share(), gb.x))
		# (the rings' own flatness in the ball's frame, for the edge's floor; the cut's
		# strength; where the lit body ends, in the ball's own frame, the stream rising out
		# of it; the dwarf's edge against its whole)
		mp.set_shader_parameter("u_tornB", Vector4(ChartSky.TILT / bsq, clampf(lost, 0.0, 1.0), lit_r(), edge() / maxf(e0, 1e-4)))
		mp.set_shader_parameter("u_tornC", Vector4(_dir.x, _dir.y, lobe(), live_r()))
		mp.set_shader_parameter("u_tornP", pts)
		# (the stars cut in the place pass, SIMPLIFIED's and RADIANT's: in the plane, as
		# PAINTED's sparkles are)
		mp.set_shader_parameter("u_tornS", Vector4(_dir.z, _dir.w, LOBE_MAX, gb.y))
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
	return Vector4(cover(), level * (ENV_TORN if on() else 1.0), power, 1.0)


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
