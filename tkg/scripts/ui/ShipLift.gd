class_name ShipLift
extends RefCounted

## THE HEAVY LIFT (Jon's L1, Nov 12): a hull leaving its stands, or setting down on
## them, on its belly jets; one piece for the front door's LAUNCH and the deck's undock
## and landing. The host moves time on (`lift_at`, `land_at`); this poses the hull and
## all that answers it: stands, jets, smoke, light, lamps, a shiver, the crew.
## Why: docs/why/ShipLift.md#heavy-lift

## The lift, s from its start: the jets spool up, the hull rises with a sag, the
## main engines light, and it burns off; then the hall clears behind it.
const SPOOL_S := 0.45
const RISE_S := 1.7
const SAG_S := 0.35
## THE MAINS LIGHT here and nowhere sooner: the flame, the sideways burn and its
## sound (`lateral`) all start on this one beat (Jon, Nov 12: "shouldn't visually turn
## on until the thrusters sound turns on"); through the rise only the jets are lit.
const MAINS_ON := 2.05
## The burn off the picture, s, gathering speed from near still the whole way (Jon's
## E2, Nov 12: 1.05 s was "WAY too fast").
const BURN_S := 3.15
## The front door holds the hall this long after the hull is off the picture.
const HOLD_S := 0.8
## Past the picture's right edge by this much, its flame and glow off it too.
const EXIT_CLEAR := 190.0
const PLUME_AT := 0.15
const SINK_FROM := 0.7
const SINK_S := 0.8
## How far the stands sink (front row px) and the rise (front row px, by weight).
const SINK_PX := 52.0
const RISE_PX := {HullData.Weight.LIGHT: 50.0, HullData.Weight.MEDIUM: 46.0, HullData.Weight.HEAVY: 72.0}
## The landing, s from its start (Jon, Nov 12: "come in higher, hover over the
## stands, and then slowly descend"): in high on the mains, slowing to a hover over
## the stands, holding on the jets with a bob, a slow descent, the stands take it.
const LAND_FLY_S := 2.6
const LAND_HOVER_S := 0.8
const LAND_DOWN_S := 1.6
const LAND_SETTLE_S := 0.25
const LAND_S := LAND_FLY_S + LAND_HOVER_S + LAND_DOWN_S + LAND_SETTLE_S
const LAND_JETS_AT := 1.8
const LAND_PLUME_AT := 2.1

## The main engines pushing the hull sideways start (`on`) and stop, and how fast
## it is going across (px/s, signed): for the thruster layer under the lift's sound.
signal lateral(on: bool, speed: float)

## THE TAKEOFF HEARD (Jon's LC2 with the LTC layer, Nov 12): the take from the jets
## (`PLUME_AT`), its own fade carrying it out; the ship's own thrust loop and departure
## burn at `Audio.SHIP_DB` from `MAINS_ON`, the loop faded over `LOOP_OUT_S` at the exit.
## Why: docs/why/ShipLift.md#heard
const LIFT_TAKE := &"ship_liftoff"
const LOOP_OUT_S := 0.3
## The landing's take (the engines bearing it down), from the belly jets lighting
## (`LAND_JETS_AT`): one of four at random each landing (Jon's "ALL": DA3, DB3, DC2,
## DC4 as `ship_landing`, `_2`, `_3`, `_4`, `Audio.play`'s round robin).
const LAND_TAKE := &"ship_landing"

## The hull and its place at rest, in its parent.
var view: ShipView
var rest := Vector2.ZERO
## Where the layers go (jets under the hull, smoke and light over), in whose pixels.
var host: Control
## The floor row the stands stand on, in the host's pixels; px it rises; +1 right.
var floor_y := 0.0
var rise := 46.0
var dir := 1.0
## How far it must go to be off the picture, and how far out it starts a landing.
var exit_px := 300.0
var in_px := 300.0
## How high over its stands it comes in and hovers (host px), under the hall's lamps.
var approach_px := 70.0
## The highest the hull's top may climb as it leaves (host px): under the hall's lamps.
var ceiling_y := 40.0
## Size against the front door's front row (the deck's hulls stand smaller).
var k := 1.0
## The yard's crew, optional.
var life: YardLife = null
## Hooks the host fills: `sink(rows)` sinks the stands, `moved(off)` follows the hull.
var sink: Callable = Callable()
var moved: Callable = Callable()
## False when `moved` carries the hull itself (the front door moves its berth).
var move_view := true
## The host's shake (whole px) is applied to this control, from its place at rest.
var shake_node: Control = null
var shake_rest := Vector2.ZERO
## Or the hull alone shivers (the deck, whose camera holds still).
var shiver_hull := false
## The smoke's size against the hull's (the deck's low hulls drowned in a full cloud).
var plume_k := 1.0


## Off the picture by here, and the front door's whole lift.
static func exit_s() -> float:
	return MAINS_ON + BURN_S


static func front_s() -> float:
	return exit_s() + HOLD_S



var plume: LiftPlume
var _glow: ColorRect
var _gmat: ShaderMaterial
var _jets: Control
var _off := Vector2.ZERO
var _dt := 0.0
var _prev_x := NAN
var _lat_on := false
var _lat_want := false
var _lifting := false
var _touched := false
## The stands' tops at rest (host px), where steam also rises.
var vents: Array[Vector2] = []
## The hall's ceiling lamps over it (x, reach), for the light on the steam's tops.
var lamps: Array[Vector2] = []


## The ceiling lamps of `light`'s hall as (x, reach), and their copies on a hall run on past its edge.
static func lamps_of(light: YardLight, width: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if light == null:
		return out
	for i in light.ceil_idx:
		var b: Array = (light.lights[int(i)] as Dictionary).get("box", [])
		if b.size() < 4:
			continue
		var x := (float(b[0]) + float(b[2])) * 0.5
		var reach := maxf(30.0, (float(b[2]) - float(b[0])) * 0.45)
		out.append(Vector2(x, reach))
		if x + float(YardScene.W) < width:
			out.append(Vector2(x + float(YardScene.W), reach))
	return out
## The process frames the landing's belly jets lit and its take started (-1: not yet).
var jets_frame := -1
var take_frame := -1
var _heard_take := false
var _loop_out := -1.0
## How fast the hull is going across this frame (px/s, signed).
var lateral_speed := 0.0
var _shiver := Vector2.ZERO
var _t := 0.0
var _jets_k := 0.0
var _lights: Array = []
var _extra: Array = []
var _origin := Vector2.ZERO
var _ink := Rect2()
var _walk := ""
var _engines := -2
## The belly at rest, column by column (host px: x, its lowest inked row + 1).
var _profile: Array[Vector2] = []
## The jets at rest: (x, belly row, weight); the smoke comes from under them.
var _jet_pts: Array[Vector3] = []


## Lay the layers into the host: the jets just under the hull's own layer (index
## `under`), the smoke and its light over everything at `over` (-1: on top).
func setup(v: ShipView, h: Control, under: int, over_node: Node = null) -> void:
	view = v
	host = h
	rest = v.position
	var gt := host.get_global_transform().affine_inverse() * v.get_global_transform()
	_origin = gt * v.canvas_to_local(Vector2.ZERO)
	var img := v.canvas()
	var ink := img.get_used_rect() if img != null else Rect2i()
	_ink = Rect2(_origin + Vector2(ink.position), Vector2(ink.size))
	_read_belly(img, ink, gt)
	_place_jets()
	_jets = Control.new()
	_jets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jets.size = host.size
	_jets.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_jets.draw.connect(_draw_jets)
	host.add_child(_jets)
	if under >= 0:
		host.move_child(_jets, under)
	plume = LiftPlume.new()
	plume.size_k = k * plume_k
	plume.setup(host.size.x, host.size.y, 220.0)
	plume.floor_y = floor_y
	plume.vents = vents
	plume.lamps = lamps
	# the steam's far layers and its shadow under the hull, its near layer over it
	host.add_child(plume.back_layer)
	host.move_child(plume.back_layer, _jets.get_index())
	host.add_child(plume)
	_glow = ColorRect.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.size = host.size
	_gmat = ShaderMaterial.new()
	_gmat.shader = preload("res://shaders/launch_glow.gdshader")
	_gmat.set_shader_parameter(&"rect_size", _glow.size)
	_glow.material = _gmat
	host.add_child(_glow)
	if over_node != null:
		host.move_child(plume, over_node.get_index())
		host.move_child(_glow, over_node.get_index())
	_pose()


## THE LIFT at `t` s: spool, a sagging rise, the mains, and away.
func lift_at(t: float) -> void:
	_begin(t)
	_lifting = true
	var spool := clampf(t / SPOOL_S, 0.0, 1.0)
	var lift_e := _ease_io(clampf((t - SPOOL_S) / RISE_S, 0.0, 1.0))
	var sag := -2.0 * sin(clampf((t - SPOOL_S) / SAG_S, 0.0, 1.0) * PI) if t > SPOOL_S else 0.0
	var burn := clampf((t - MAINS_ON) / BURN_S, 0.0, 1.0)
	if t >= PLUME_AT and not plume.fired():
		plume.fire()
	# and it climbs as it goes: up a rising diagonal to its ceiling, faster than it
	# gathers speed across, so it leaves high (Jon, Nov 12: "can also go higher up")
	_off.y = -rise * lift_e - sag * k - _climb() * (1.0 - pow(1.0 - burn, 1.6))
	_off.x = dir * exit_px * pow(burn, 2.6)
	# the floor throws steam up only while the jets are over it and near it: it
	# thins as the hull climbs and slides off its berth, and clears behind it
	var over := clampf(1.0 - maxf(0.0, -_off.y - rise) / (90.0 * k), 0.0, 1.0) 		* clampf(1.0 - absf(_off.x) / maxf(1.0, 0.5 * _ink.size.x), 0.0, 1.0)
	var jets := spool * (1.0 - 0.75 * burn) if t < exit_s() else 0.0
	plume.thrust = jets * over
	_sink(clampf((t - SINK_FROM) / SINK_S, 0.0, 1.0))
	if t >= exit_s():
		# off the picture: its engines dark, nothing of it left at the edge
		_set_engines(-1)
	elif t >= MAINS_ON:
		_set_engines(ThrusterFx.Thrust.FULL)
	else:
		# (dark through the rise: the jets hold it, the mains have not lit)
		_set_engines(-1)
	_lat_want = t >= MAINS_ON and t < exit_s()
	if t >= PLUME_AT and not _heard_take:
		_heard_take = true
		Audio.play_in(LIFT_TAKE, 0.0, 0.0, true)
	# a shiver while it hangs on the jets, harder as the mains light
	var amp := (1.0 if t > 0.2 and t < 2.0 else 0.0) + (2.0 * (1.0 - burn) if t >= 2.0 and burn < 0.85 else 0.0)
	_shake(t, amp)
	_belly_glow(jets)
	if burn > 0.0 and burn < 1.0:
		_nozzle_glow(1.2)
	if _walk == "" and t > 0.3:
		_walkers(true)
	_pose()


## THE LANDING at `t` s (`LAND_S` long): in high on the mains, a hover over the
## stands on the jets with a bob and the smoke building, a slow descent with the
## smoke rolling out as it nears the floor, and the stands take the weight.
func land_at(t: float) -> void:
	_begin(t)
	var hover_at := LAND_FLY_S
	var down_at := hover_at + LAND_HOVER_S
	var touch_at := down_at + LAND_DOWN_S
	# (in slowing hard into the hover, as the takeoff gathers speed out: Jon, Nov 12,
	# "enters too fast"; the belly jets light over the stands as it slows)
	var fly := 1.0 - pow(1.0 - clampf(t / LAND_FLY_S, 0.0, 1.0), 2.6)
	_lat_want = t < hover_at
	_off.x = -dir * in_px * (1.0 - fly)
	var high := approach_px
	var near := 0.0
	if t < down_at:
		# (a gentle bob on the jets once it has slowed: whole pixels, under two a second)
		var bob := roundf(sin((t - hover_at) * TAU * 0.8)) if t > hover_at - 0.3 else 0.0
		_off.y = -high + bob
	elif t < touch_at:
		# (slow and heavy: most of the drop mid-way, a soft start and a soft settle)
		var u := (t - down_at) / LAND_DOWN_S
		var d := u * u * u * (u * (u * 6.0 - 15.0) + 10.0)
		_off.y = -high * (1.0 - d)
		near = d
	elif t < LAND_S:
		# the stands take the weight: a pixel down and back
		_off.y = 1.0 if t < touch_at + LAND_SETTLE_S * 0.5 else 0.0
		near = 1.0
	else:
		_off = Vector2.ZERO
	# (the jets catch on their beat, already seen, then build: a ramp from nothing
	# showed them a fifth of a second late)
	var catch := 0.0 if t < LAND_JETS_AT else 0.35 + 0.65 * smoothstep(LAND_JETS_AT, LAND_JETS_AT + 0.5, t)
	var jets := catch * (1.0 - smoothstep(touch_at - 0.12, touch_at, t))
	# the nearer the floor, the harder the jets throw the smoke out across it
	plume.thrust = jets
	plume.strength = 0.3 + 0.55 * near
	if t >= LAND_PLUME_AT and not plume.fired():
		plume.fire()
	_shake(t, 1.0 if t > hover_at and t < touch_at else 0.0)
	if t >= touch_at and not _touched:
		_touched = true
		plume.touchdown()
	_belly_glow(jets)
	if _walk == "" and t > LAND_JETS_AT:
		_walkers(false)
	# (the idle heard under the dark mains through the hover, until the descent:
	# the landing's sound as the sound builder laid it out)
	view.dark_hum = t < down_at
	if jets > 0.0 and jets_frame < 0:
		jets_frame = Engine.get_process_frames()
	if LAND_TAKE != &"" and t >= LAND_JETS_AT and not _heard_take:
		_heard_take = true
		take_frame = Engine.get_process_frames()
		Audio.play_in(LAND_TAKE)
	_pose()


## Everything back as it was: the lamps, the crew walking on, nothing shaking.
## The smoke stays and drifts.
func release() -> void:
	# (a lift cut short: its drive loop out with it)
	if _lifting and (_lat_on or _loop_out >= 0.0):
		Audio.ship_thrust_off()
		_lat_on = false
		_loop_out = -1.0
	if life != null:
		life.extra = []
		var t := life.scene._t if life.scene != null else 0.0
		for c: Dictionary in life.CREW:
			if c.has("_l"):
				life.rephase(c, float(c.get("_lx", (c["_l"] as Dictionary).x)), t)
				c.erase("_l")
				c.erase("_lx")
				c.erase("ev")
	if shake_node != null and is_instance_valid(shake_node):
		shake_node.position = shake_rest
	_jets_k = 0.0
	if _jets != null and is_instance_valid(_jets):
		_jets.queue_redraw()
	if _gmat != null:
		_gmat.set_shader_parameter(&"n", 0)


## The mains' sideways burn, from `MAINS_ON` to the exit (and the landing's way in
## to the hover): `lateral` on its first frame and its last, with how fast it goes.
func _track_lateral() -> void:
	if not is_nan(_prev_x) and _dt > 0.0:
		lateral_speed = (_off.x - _prev_x) / _dt
	_prev_x = _off.x
	var on := _lat_want
	if on != _lat_on:
		_lat_on = on
		lateral.emit(on, lateral_speed)
		if _lifting:
			_ltc(on)
	# the drive loop under the burn, every frame it runs, and its fade at the exit
	if _lifting and _lat_on:
		Audio.ship_thrust(1.0)
	elif _loop_out >= 0.0:
		var k := 1.0 - (_t - _loop_out) / LOOP_OUT_S
		if k > 0.0:
			Audio.ship_thrust(k)
		else:
			Audio.ship_thrust_off()
			_loop_out = -1.0


## The LTC layer: the departure burn once as the mains light; the loop's fade at the exit.
func _ltc(on: bool) -> void:
	if on:
		var h := view._hull()
		var w := int(h.weight) if h != null else int(HullData.Weight.MEDIUM)
		Audio.play_in(ShipView.DEPART_SFX[w], Audio.SHIP_DB, 0.0, true)
	else:
		_loop_out = _t


## How far it climbs past its rise on the way out: its top up to `ceiling_y`.
func _climb() -> float:
	return maxf(0.0, _ink.position.y - rise - ceiling_y)


## How many of its added lights are on this frame (none once it is gone).
func lit() -> int:
	return _lights.size() + _extra.size()


## Where the hull is now, from its place at rest (whole px).
func offset() -> Vector2:
	# (across in fractions of a pixel, as the dock's flight always has: whole pixels
	# stall a hull gathering or losing speed a frame at a time, LadderTest's one motion)
	return Vector2(_off.x, roundf(_off.y)) + _shiver


# ------------------------------------------------------------------ pieces

func _begin(t: float) -> void:
	_dt = t - _t
	_t = t
	_lights.clear()
	_extra.clear()
	_jets_k = 0.0


func _pose() -> void:
	var o := offset()
	_track_lateral()
	if move_view:
		view.position = rest + o
	if moved.is_valid():
		moved.call(o)
	# the smoke comes from under the jets, wherever the hull is this frame
	var srcs: Array[Vector3] = []
	var sx := 0.0
	var sy := 0.0
	var sw := 0.0
	var x0 := INF
	var x1 := -INF
	for j in _jet_pts:
		srcs.append(Vector3(j.x + o.x, j.y + o.y, j.z))
		sx += (j.x + o.x) * j.z
		sy += (j.y + o.y) * j.z
		sw += j.z
		x0 = minf(x0, j.x)
		x1 = maxf(x1, j.x)
	plume.sources = srcs
	plume.spread = _spread()
	plume.hull = Rect2(_ink.position + o, _ink.size)
	if sw > 0.0:
		plume.src = Vector2(floorf(sx / sw), floorf(sy / sw))
		plume.src_w = maxf(8.0 * k, (x1 - x0) * 0.5)
	if life != null:
		life.extra = plume.lights() + _extra
	var gp := PackedVector4Array()
	var gc := PackedVector4Array()
	gp.resize(8)
	gc.resize(8)
	var n := mini(8, _lights.size())
	for i in n:
		var l: Array = _lights[i]
		gp[i] = Vector4(float(l[0]), float(l[1]), float(l[2]), float(l[3]))
		var c: Color = l[4]
		gc[i] = Vector4(c.r, c.g, c.b, float(l[5]))
	_gmat.set_shader_parameter(&"n", n)
	_gmat.set_shader_parameter(&"gpos", gp)
	_gmat.set_shader_parameter(&"gcol", gc)
	_jets.queue_redraw()


func _sink(e: float) -> void:
	if sink.is_valid():
		sink.call(int(floorf(e * SINK_PX * k)))


func _set_engines(th: int) -> void:
	if _engines == th:
		return
	_engines = th
	if th < 0:
		view.burn(false)
		view._engines_off = true
		view.refresh()
		return
	view._engines_off = false
	view.burn(true)
	view._burn_thrust = th
	view.refresh()


static func _ease_io(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## A whole-pixel shiver, a new offset fifteen times a second.
func _shake(t: float, amp: float) -> void:
	_shiver = Vector2.ZERO
	var a := roundf(amp * maxf(k, 0.75))
	var s := floorf(t * 15.0)
	var j := Vector2(roundf((YardLight.hash1(s * 1.37) - 0.5) * 2.0 * a), roundf((YardLight.hash1(s * 2.91 + 0.4) - 0.5) * 2.0 * a))
	if shiver_hull:
		# (up and down only: its way across stays one motion)
		_shiver = Vector2(0.0, j.y)
		return
	if shake_node != null and is_instance_valid(shake_node):
		shake_node.position = shake_rest + j


## The jets' line of light under the belly; the floor takes its light from the plume.
func _belly_glow(kk: float) -> void:
	if kk <= 0.01:
		return
	var c := plume.src
	# (steady: it follows the plume's eased light, no flicker, Jon's F1)
	_lights.append([c.x, c.y + 4.0, plume.src_w * 1.3, 12.0 * k, Color(1.0, 0.7, 0.4), 0.8 * plume.light_level()])
	_jets_k = kk


func _nozzle_glow(kk: float) -> void:
	var g := view.engine_glow()
	if g.is_empty():
		return
	var at: Vector2 = host.get_global_transform().affine_inverse() * (g.at as Vector2)
	_lights.append([at.x - 6.0, at.y, 46.0 * k, 26.0 * k, Color(1.0, 0.7, 0.4), 0.8 * kk])
	_extra.append([at.x - 10.0, at.y, 140.0 * k, 80.0 * k, 1.4 * kk, Color(1.0, 0.65, 0.35), 1.0])


## The crew near the blast walk off from it; the rest stop and look.
## Why: docs/why/ShipLift.md#crew
func _walkers(_lifting: bool) -> void:
	_walk = "back"
	if life == null:
		return
	var L := life
	var sx := plume.src.x
	var reach := 240.0 * k
	for c: Dictionary in L.CREW:
		var cd := c
		cd["ev"] = func(t: float) -> Dictionary:
			if not cd.has("_l"):
				var p0 := L.walk_at(cd, t)
				cd["_l"] = {"x": float(p0.x), "t": t}
			var S: Dictionary = cd["_l"]
			var x0 := float(S.x)
			var away := -1.0 if x0 < sx else 1.0
			var nm := String(cd["name"])
			if absf(x0 - sx) < reach:
				var C := L.crew_strip(nm)
				var dist := 34.0 * k * maxf(0.0, t - float(S.t) - 0.25)
				var adv := float(C.get("advance", 1.0))
				var stp := floorf(dist / adv)
				cd["_lx"] = x0 + away * stp * adv
				return {"x": cd["_lx"], "dir": away, "f": int(stp) % int(C.get("frames", 8)), "dy": 0.0}
			cd["_lx"] = x0
			return {"x": x0, "dir": -away, "f": L.stand_frame(nm), "dy": 0.0}


## THE LIFT JETS: short flames down from the belly at the jets, a new shape ten
## times a second, longer where a jet carries more of the weight.
func _draw_jets() -> void:
	if _jets_k <= 0.02:
		return
	var o := offset()
	var step := floorf(_t * 10.0)
	var cols := [Color("#fff4d0"), Color("#ffd27a"), Color("#ff9a3c"), Color("#c0501a")]
	for n in _jet_pts.size():
		var jp := _jet_pts[n]
		var x := floorf(jp.x + o.x)
		var y0 := floorf(jp.y + o.y)
		var w := clampf(jp.z, 0.3, 1.0)
		var len := floorf((6.0 + 12.0 * _jets_k) * k * w * (0.7 + 0.5 * YardLight.hash1(step * 1.3 + float(n) * 7.1)))
		for row in int(len):
			var uu := float(row) / maxf(1.0, len)
			var half := floorf((3.0 - 2.0 * uu) * maxf(k, 0.67) + (1.0 if YardLight.hash1(step + float(row) * 0.7 + float(n)) > 0.6 else 0.0))
			_jets.draw_rect(Rect2(x - half, y0 + float(row), half * 2.0 + 1.0, 1), cols[mini(3, int(uu * 4.0))])


## The belly, column by column: each column's lowest inked pixel, in host px at rest.
func _read_belly(img: Image, ink: Rect2i, gt: Transform2D) -> void:
	_profile.clear()
	if img == null:
		return
	for cx in range(ink.position.x, ink.end.x):
		for cy in range(ink.end.y - 1, ink.position.y - 1, -1):
			if img.get_pixel(cx, cy).a8 >= 128:
				_profile.append(gt * view.canvas_to_local(Vector2(float(cx) + 0.5, float(cy) + 1.0)))
				break


## The belly row under host column `x` (the nearest column read), at rest.
func _belly_y(x: float) -> float:
	var best := _ink.end.y
	var d := INF
	for p in _profile:
		if absf(p.x - x) < d:
			d = absf(p.x - x)
			best = p.y
	return best


## The lowest stretch of the belly: the columns within a few rows of its lowest.
func _keel() -> Array[Vector2]:
	var low := -INF
	for p in _profile:
		low = maxf(low, p.y)
	var out: Array[Vector2] = []
	for p in _profile:
		if p.y >= low - 6.0 * k:
			out.append(p)
	return out


## THE JETS from the hull's own pixels, not its picture's box (Jon, Nov 12: P1 "doesn't
## align perfectly with the ships"; his pick P1a): four across the belly's lowest stretch,
## one cloud as wide as it.
## Why: docs/why/ShipLift.md#attach
func _place_jets() -> void:
	_jet_pts.clear()
	if _profile.is_empty():
		_jet_pts.append(Vector3(_ink.get_center().x, _ink.end.y, 1.0))
		return
	var keel := _keel()
	for n in 4:
		var x := lerpf(keel[0].x, keel[-1].x, (float(n) + 0.5) / 4.0)
		_jet_pts.append(Vector3(x, _belly_y(x), 1.0))


## How far either side of a jet its smoke starts.
func _spread() -> float:
	if _jet_pts.size() < 2:
		return 10.0 * k
	return absf(_jet_pts[-1].x - _jet_pts[0].x) * 0.2
