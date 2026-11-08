class_name ChartTorn
extends RefCounted

## TORN AWAY, direction B (proto/dwarf-b): the stream. The hardest galaxies, the
## two dwarfs (GalaxyGen kinds 14 and 15), are being eaten by a giant neighbour,
## seen far off and steeply tilted up the chart. ONE stream of the dwarf's stars
## (Jon, Nov 7: "a single stream of the galaxy being pulled, rather than two")
## runs out of the dwarf toward the giant and spirals into the giant's middle.
##
## The rings fall away from the outside in (`lost`, rings gone so far; the last
## four hold, so `MAX_LOST`). The dwarf starts as it always is drawn and is
## DRAWN SMALLER with each ring lost (Jon: "the galaxy should start normal size
## ... and should be drawn smaller and smaller"): its whole picture scaled about
## its core by `scale()`, so its rim lands on `edge()`, halfway between the last
## ring lost and the outermost ring left, and cut there; the systems on the lost
## rings are off the chart (`gone`, `StarchartScreen._drop_torn`). The stream
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
## How far the dwarf is drawn out toward the giant by the end (the shader's
## `tornBody`; that side only).
const STRETCH := 0.3
## The dwarf's light fades out inside its drawn edge: the stream starts this far
## in (a share of the edge), so it comes out of the visible body.
const RIM_IN := 0.65


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


## Whole rings gone: the drawn picture's step. While a ring is going (`lost`
## between whole numbers) the picture holds at the last whole ring and the cut
## eats the falling one; it settles to the next scale once, when the ring has
## gone. (A picture resampled at an eased scale boils: every block's pattern
## reshuffled each frame of a fall.)
static func whole() -> int:
	return clampi(int(floor(lost + 1e-4)), 0, MAX_LOST)


## How much smaller the dwarf's picture is drawn than it always is (1 with none
## lost), a whole ring at a time.
static func scale() -> float:
	return _edge_at(whole()) / _edge_at(0)


## The same, eased with `lost` (the stream's width, the share of stars kept).
static func scale_eased() -> float:
	return edge() / _edge_at(0)


## The picture's stretch toward the giant, a whole ring at a time.
static func stretch() -> float:
	return STRETCH * float(whole()) / float(MAX_LOST)


## Where the stream crosses the dwarf's drawn rim, as its length along (gu on
## the screen): the stream is drawn from there, never over the dwarf's body or
## its core. Each of its points taken back to the plane (as the body's cut
## reads the screen) and measured as `tornCut` does, eased with `lost`.
static func rim_along(phi: float, pts: PackedVector4Array) -> float:
	var c := cos(phi)
	var s := sin(phi)
	var sq := float(Run.galaxy.get("squash", 0.85))
	var ax := axis()
	var st := STRETCH * progress()
	var e := edge() * RIM_IN
	var prev_re := 0.0
	for i in pts.size():
		var u := pts[i].x / ChartSky.K0
		var w := pts[i].y / (ChartSky.K0 * ChartSky.TILT)
		var gal := Vector2(u * c - w * s, (u * s + w * c) * sq)
		var al := gal.dot(ax)
		var pe := gal.dot(Vector2(-ax.y, ax.x))
		var re := Vector2(al / (1.0 + st) if al > 0.0 else al, pe).length()
		if re >= e and i > 0:
			var f := clampf((e - prev_re) / maxf(re - prev_re, 1e-6), 0.0, 1.0)
			return lerpf(pts[i - 1].z, pts[i].z, f)
		prev_re = re
	return pts[pts.size() - 1].z


## How far the run is into the decay, 0 .. 1.
static func progress() -> float:
	return clampf(lost / float(MAX_LOST), 0.0, 1.0)


## The line to the giant, in the galaxy's plane (unit).
static func axis() -> Vector2:
	return Vector2(-GIANT.x, -GIANT.y).normalized()


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
	var e1 := (-GIANT).normalized()
	var pp := Vector3(-e1.y, e1.x, 0.0).normalized()
	var e2 := pp * cos(INC) + Vector3(0, 0, 1) * sin(INC)
	var r0 := GIANT.length()
	var acc := 0.0
	var prev := Vector2.ZERO
	for i in N:
		var f := float(i) / float(N - 1)
		var th := f * SPAN
		var r := r0 * pow(1.0 - f, 1.25)
		var q := GIANT + (e1 * cos(th) + e2 * sin(th)) * r
		var vv := _v3(q, phi)
		if i > 0:
			acc += (vv - prev).length() / ChartSky.K0
		prev = vv
		out.append(Vector4(vv.x, vv.y, acc, f))
	return out


## Every frame, on the painted place pass.
static var _pushed := Vector4(-1, -1, -1, -1)
static var _mp_id := 0


## (`ms`: the chart's own stars, `chart_b_stars`'s material: scaled, thinned and
## cut with the dwarf, set every frame, and set back to none when it is off)
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
			ms.set_shader_parameter("torn", Vector4(1.0, 0.0, 1.0, 0.0))
			ms.set_shader_parameter("torn2", Vector4(0.0, 1.0, 0.0, 1.0))
		return
	var sq := float(Run.galaxy.get("squash", 0.85))
	if ms != null:
		var a := axis()
		var se := scale_eased()
		ms.set_shader_parameter("torn", Vector4(scale(), stretch(), a.x, a.y))
		ms.set_shader_parameter("torn2", Vector4(edge(), sq, clampf(lost, 0.0, 1.0), se * se))
	# (only when something moved: the turn is slow, the rings fall seldom)
	var key := Vector4(1.0, snappedf(phi, 1e-5), lost, float(Run.galaxy_kind))
	if key == _pushed:
		return
	_pushed = key
	var gv := _v3(GIANT, phi)
	# (the line to the giant, in the plane: the shader turns it as it needs)
	var e1 := axis()
	mp.set_shader_parameter("u_torn", Vector4(1.0, edge(), progress(), sq))
	mp.set_shader_parameter("u_tornG", Vector4(gv.x, gv.y, GIANT_ANG, GIANT_LEN))
	mp.set_shader_parameter("u_tornA", Vector4(e1.x, e1.y, scale(), clampf(lost, 0.0, float(MAX_LOST))))
	var pts := ribbon(phi)
	mp.set_shader_parameter("u_tornB", Vector4(stretch(), clampf(lost, 0.0, 1.0), rim_along(phi, pts), scale_eased()))
	mp.set_shader_parameter("u_tornP", pts)
