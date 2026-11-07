class_name ChartTorn
extends RefCounted

## TORN AWAY, direction B (proto/dwarf-b): the stream. The hardest galaxies, the
## two dwarfs (GalaxyGen kinds 14 and 15), are being eaten by a giant neighbour.
## Like the Sagittarius Dwarf round the Milky Way, the dwarf has already been
## unwound into a ribbon of stars that loops across the whole chart and off to the
## giant, seen far off and edge-on: a burning line split by its dust, a hot core.
## What is left of the dwarf is a knot on the ribbon, stretched toward the giant.
##
## The rings fall away from the outside in (`lost`, rings gone so far): the next
## ring to go (`MapGen.ring_radius(lost)`) frays red, its stars pulled off at the
## two tips that point at the giant and away from it, into the two tails; past it
## the dark is the old shear, swept out into the ribbon. The ribbon grows brighter
## and wider as more of the dwarf goes into it.
##
## Drawn by the painted chart's place pass (`chart_torn.gdshaderinc`) from these
## uniforms; every other kind has `u_torn.x` 0 and draws exactly as before.
##
## Proto: `lost` is set by hand (`sheet=ChartLook torn=N`); the mechanic that
## drives it is being designed elsewhere.

## Rings lost so far, 0 .. MapGen.LAYERS - 2 (a float, so a film can sweep it).
static var lost := 0.0
## -1: on for the dwarfs only. 0 / 1 force it off / on for any kind (a bench's).
static var force := -1

## The giant, in the dwarf's plane (gu) and height above it (gu): up the screen,
## to the left of the core, far enough that its line lies above the rim.
const GIANT := Vector3(-0.35, -1.3, 0.25)
## The dwarf's orbit round it, tilted out of the chart's plane.
const INC := 0.61
## The leading arm spirals in to the giant over this much of a turn; the trailing
## arm is flung out to 1.7 of the orbit's radius over 2.4 half-turns (so it loops
## round the chart and crosses it again: last orbit's wrap).
const LEAD_SPAN := PI * 1.15
const TRAIL_SPAN := PI * 2.4
const TRAIL_R := 1.7
const N_LEAD := 24
const N_TRAIL := 40
## The edge-on giant on the screen: half its length (gu) and its tilt.
const GIANT_LEN := 0.55
const GIANT_ANG := -0.21


static func on() -> bool:
	if force >= 0:
		return force == 1
	return Run.galaxy_kind == 14 or Run.galaxy_kind == 15


## The tidal radius: where the next ring to go lies (gu, the rings' own radius),
## eased between rings so a film can sweep `lost`.
static func tidal_r() -> float:
	var top := MapGen.LAYERS - 2
	var l := clampf(lost, 0.0, float(top))
	var a := MapGen.ring_radius(int(floor(l)))
	var b := MapGen.ring_radius(mini(int(floor(l)) + 1, top))
	return lerpf(a, b, l - floor(l))


## How far the run is into the decay, 0 .. 1.
static func progress() -> float:
	return clampf(lost / float(MapGen.LAYERS - 2), 0.0, 1.0)


static func _v3(p: Vector3, phi: float) -> Vector2:
	var c := cos(phi)
	var s := sin(phi)
	return Vector2(p.x * c + p.y * s, (p.y * c - p.x * s) * ChartSky.TILT - p.z * 0.92499) * ChartSky.K0


## The ribbon as a polyline in view px (zoom 1, about the core): x, y, the signed
## length along it from the dwarf (gu on the screen; + the leading arm), and its
## age (0 at the dwarf, 1 at its far end). Leading arm first, then the trailing.
static func ribbon(phi: float) -> PackedVector4Array:
	var out := PackedVector4Array()
	var e1 := (-GIANT).normalized()
	var pp := Vector3(-e1.y, e1.x, 0.0).normalized()
	var e2 := pp * cos(INC) + Vector3(0, 0, 1) * sin(INC)
	var r0 := GIANT.length()
	var rt := tidal_r()
	var sq := float(Run.galaxy.get("squash", 0.85))
	# (the tips the arms leave by: on the line to the giant, at the tidal radius, in
	# the plane as the rings lie in it)
	var ax := Vector3(e1.x, e1.y, 0.0).normalized()
	for arm in 2:
		var n := N_LEAD if arm == 0 else N_TRAIL
		var acc := 0.0
		var prev := Vector2.ZERO
		for i in n:
			var f := float(i) / float(n - 1)
			var th: float
			var r: float
			if arm == 0:
				th = f * LEAD_SPAN
				r = r0 * pow(1.0 - f, 1.25)
			else:
				th = -f * TRAIL_SPAN
				r = r0 * (1.0 + (TRAIL_R - 1.0) * pow(f, 0.8))
			var q := GIANT + (e1 * cos(th) + e2 * sin(th)) * r
			# leave by the tip: toward the giant (leading), away from it (trailing)
			var tip := ax * rt * (1.0 if arm == 1 else -1.0)
			tip.y /= sq
			q += tip * exp(-f / 0.06)
			var vv := _v3(q, phi)
			if i > 0:
				acc += (vv - prev).length() / ChartSky.K0
			prev = vv
			out.append(Vector4(vv.x, vv.y, acc if arm == 0 else -acc, f))
	return out


## Every frame, on the painted place pass.
static var _pushed := Vector4(-1, -1, -1, -1)
static var _mp_id := 0


static func push(mp: ShaderMaterial, phi: float) -> void:
	# (a new place pass has none of it yet)
	if mp.get_instance_id() != _mp_id:
		_mp_id = mp.get_instance_id()
		_pushed = Vector4(-1, -1, -1, -1)
	if not on():
		if _pushed.x != 0.0:
			mp.set_shader_parameter("u_torn", Vector4.ZERO)
			_pushed = Vector4.ZERO
		return
	# (only when something moved: the turn is slow, the rings fall seldom)
	var key := Vector4(1.0, snappedf(phi, 1e-5), lost, float(Run.galaxy_kind))
	if key == _pushed:
		return
	_pushed = key
	var gv := _v3(GIANT, phi)
	# (the line to the giant, in the plane: the shader turns it as it needs)
	var e1 := Vector2(-GIANT.x, -GIANT.y).normalized()
	mp.set_shader_parameter("u_torn", Vector4(1.0, tidal_r(), progress(), float(Run.galaxy.get("squash", 0.85))))
	mp.set_shader_parameter("u_tornG", Vector4(gv.x, gv.y, GIANT_ANG, GIANT_LEN))
	mp.set_shader_parameter("u_tornA", Vector4(e1.x, e1.y, MapGen.ring_radius(mini(int(floor(lost)) + 1, MapGen.LAYERS - 2)), lost))
	mp.set_shader_parameter("u_tornP", ribbon(phi))
