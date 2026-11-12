class_name YardLaunch
extends Node

## TRIAL (not for landing): LAUNCH on the front door lifts the picked ship off
## its stands and flies it off the right edge, then the run starts (Jon, Nov 12:
## "have the ship lift off ... and then fly off the screen to the right?").
## Three ideas by `-- yardlaunch=1|2|3`, each with the shared `LiftPlume`
## (`-- plume=P1..P6`). Inert without the flag.
##   1 HEAVY: clamps off, the stands sink, a slow sagging rise on the lift jets,
##     the hall's lamps stutter, then the main engines and away.
##   2 GANTRY: the hall's hoist lifts it to a launch rail run out from the right,
##     lamps chase along the rail, one short burst and it slides out.
##   3 PUNCH: a short hover, a flash over the whole hall, a streak and a cut.

var front: YardFront
var cs: Control
var berth: YardStandSet
var view: ShipView
var idea := 1
var done: Callable

var plume: LiftPlume
var glow: ColorRect
var _gmat: ShaderMaterial
var rig: Control

var _t := 0.0
var _pos0 := Vector2.ZERO
var _thing0 := Rect2i()
var _off := Vector2.ZERO
var _shake := Vector2.ZERO
var _finished := false
var _rise := 46.0
var _exit := 300.0
var _lights: Array = []
var _trail: Array = []
var _rail_x := 1e9
var _rail_y := 0.0
var _cable := 0.0
var _chase := -1.0
var _burst := -1.0
var _walk := ""
var _walk_t := -1.0
var _flash := 0.0
var _jets_k := 0.0
## L2: the nozzle at the burst, less the hull's offset then; the smoke comes from there.
var _nozzle0 := Vector2(-1, -1)


static func idea_arg() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("yardlaunch="):
			return clampi(int(a.substr(11)), 0, 3)
	return 0


static func go(owner: Control, f: YardFront, w: int, then: Callable) -> YardLaunch:
	var L := YardLaunch.new()
	L.cs = owner
	L.front = f
	L.berth = f.set_of(w as HullData.Weight)
	L.view = L.berth._view
	L.idea = idea_arg()
	L.done = then
	f.add_child(L)
	L._begin()
	return L


func _begin() -> void:
	front.launching = true
	_pos0 = berth.position
	_thing0 = berth.thing
	var w := berth.weight
	_rise = 72.0 if w == HullData.Weight.HEAVY else (50.0 if w == HullData.Weight.LIGHT else 46.0)
	_exit = float(YardFront.W) + 60.0 - float(_thing0.position.x)
	front.launch_mask_begin(berth)
	# nothing on the hall answers the pointer from here on
	var block := Control.new()
	block.mouse_filter = Control.MOUSE_FILTER_STOP
	block.size = Vector2(YardFront.W, YardFront.H)
	cs.add_child(block)
	# the rail, the hoist and the trail under the ships; the smoke and the light over them
	rig = Control.new()
	rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rig.size = Vector2(YardFront.W, YardFront.H)
	rig.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rig.draw.connect(_draw_rig)
	front.add_child(rig)
	front.move_child(rig, front.get_children().find(front.sets.values()[0]))
	plume = LiftPlume.new()
	plume.style = LiftPlume.style_arg(1)
	plume.setup(YardFront.W, YardFront.H)
	plume.floor_y = float(berth.feet)
	plume.size_k = 1.15 if w == HullData.Weight.HEAVY else 1.0
	plume.vents = _vents()
	front.add_child(plume)
	front.move_child(plume, front._fall.get_index())
	glow = ColorRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.size = Vector2(YardFront.W, YardFront.H)
	_gmat = ShaderMaterial.new()
	_gmat.shader = preload("res://shaders/launch_glow.gdshader")
	_gmat.set_shader_parameter(&"rect_size", glow.size)
	glow.material = _gmat
	front.add_child(glow)
	front.move_child(glow, front._fall.get_index())
	_src()


## The stand tops the steam (P4) bursts from.
func _vents() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for x in berth._stand_x:
		var sw := float(berth._stand_img.get_width()) if berth._stand_img != null else 40.0
		out.append(Vector2(float(x) + sw * 0.5, float(berth._stand_top) + 10.0))
		out.append(Vector2(float(x) + sw * 0.5, float(berth.feet) - 6.0))
	return out


func _src() -> void:
	var r := Rect2(_thing0)
	if _nozzle0.x >= 0.0:
		plume.src = Vector2(floorf(_nozzle0.x + minf(_off.x, 40.0)), floorf(_nozzle0.y + _off.y))
		plume.src_w = 10.0
		return
	plume.src = Vector2(floorf(r.position.x + r.size.x * 0.5 + _off.x), floorf(r.end.y + _off.y))
	plume.src_w = r.size.x * 0.4


func _process(dt: float) -> void:
	if _finished:
		return
	_t += dt
	_lights.clear()
	_jets_k = 0.0
	match idea:
		1: _heavy(_t)
		2: _gantry(_t)
		_: _punch(_t)
	var o := Vector2(roundf(_off.x), roundf(_off.y))
	berth.position = _pos0 + o
	front.launch_mask_at(Vector2i(o))
	cs.position = Vector2(roundf(_shake.x), roundf(_shake.y))
	_src()
	_feed_light()
	rig.queue_redraw()
	if _finished:
		cs.position = Vector2.ZERO
		done.call()


## 1 HEAVY AND GROUNDED, 3.9 s. Why so long: the weight is the idea, and a
## heavy thing rising slowly needs a second and a half to read as heavy.
func _heavy(t: float) -> void:
	# spool: the lift jets come up, the hull shivers on its clamps
	var spool := clampf(t / 0.45, 0.0, 1.0)
	var lift_e := _ease_io(clampf((t - 0.45) / 1.7, 0.0, 1.0))
	var sag := -2.0 * sin(clampf((t - 0.45) / 0.35, 0.0, 1.0) * PI) if t > 0.45 else 0.0
	var burn := clampf((t - 2.05) / 1.05, 0.0, 1.0)
	if t >= 0.15 and not plume.fired():
		plume.fire()
		_engines(ThrusterFx.Thrust.IDLE)
	plume.thrust = spool * (1.0 - 0.75 * burn) if t < 3.2 else 0.0
	_off.y = -_rise * lift_e - sag - 10.0 * burn * burn
	_off.x = _exit * pow(burn, 2.6) - (2.0 * sin(clampf((t - 1.85) / 0.25, 0.0, 1.0) * PI) if t > 1.85 and t < 2.1 else 0.0)
	berth.retract = int(floorf(clampf((t - 0.7) / 0.8, 0.0, 1.0) * 52.0 * YardSlot.depth_k(berth.weight)))
	if t >= 1.85 and view._burn_thrust != ThrusterFx.Thrust.FULL:
		_engines(ThrusterFx.Thrust.CRUISE if t < 2.05 else ThrusterFx.Thrust.FULL)
	if t >= 2.05:
		_engines(ThrusterFx.Thrust.FULL)
	# a shiver while it hangs on the jets, harder as the main engines light
	var amp := (1.0 if t > 0.2 and t < 2.0 else 0.0) + (2.0 * (1.0 - burn) if t >= 2.0 and t < 2.9 else 0.0)
	_shake = _jolt(t, amp, 15.0)
	_lamps(t, 0.25 * spool + 0.45 * (1.0 - absf(burn * 2.0 - 1.0)) * (1.0 if burn > 0.0 else 0.0))
	_belly_glow(plume.thrust)
	if burn > 0.0 and burn < 1.0:
		_nozzle_glow(1.2)
	if _walk == "" and t > 0.3:
		_walkers("back", 0.0)
	if t >= 3.9:
		_finished = true


## 2 CRANE AND GANTRY, 4.0 s. Why: the hoist has to be seen to come down, take
## the weight and climb before the rail means anything; the burst itself is short.
func _gantry(t: float) -> void:
	var r := Rect2(_thing0)
	var top := r.position.y
	# the hooks come down from the roof to the hull's back
	_cable = clampf(t / 0.6, 0.0, 1.0)
	# the hoist climbs at a winch's even speed, a jolt as it takes the weight
	var hoist := clampf((t - 0.85) / 1.3, 0.0, 1.0)
	var climb := hoist if hoist < 0.92 else 0.92 + (hoist - 0.92) * 0.5
	_off.y = -(_rise + 22.0) * minf(1.0, climb / 0.96) + (1.0 if t > 0.85 and t < 0.95 else 0.0)
	berth.retract = int(floorf(clampf((t - 0.7) / 0.5, 0.0, 1.0) * 52.0 * YardSlot.depth_k(berth.weight)))
	# the rail runs out from the right edge to meet it
	_rail_y = top - (_rise + 22.0) - 9.0
	var run := _ease_io(clampf((t - 1.3) / 0.9, 0.0, 1.0))
	_rail_x = lerpf(float(YardFront.W) + 4.0, r.position.x + r.size.x * 0.2, run)
	_chase = clampf((t - 2.25) / 0.7, 0.0, 1.0) if t >= 2.25 else -1.0
	if t >= 2.95 and _burst < 0.0:
		_burst = t
		var g := view.engine_glow()
		var nz: Vector2 = front.get_global_transform().affine_inverse() * (g.at as Vector2) if not g.is_empty() else plume.src
		_nozzle0 = nz - Vector2(roundf(_off.x), roundf(_off.y))
		plume.floor_y = nz.y + 26.0
		plume.fire()
		_engines(ThrusterFx.Thrust.FULL)
	if _burst >= 0.0:
		var u := t - _burst
		plume.thrust = clampf(1.0 - u / 0.45, 0.0, 1.0)
		_off.x = _exit * pow(clampf(u / 0.5, 0.0, 1.0), 2.2)
		_shake = _jolt(t, 2.0 * clampf(1.0 - u / 0.25, 0.0, 1.0), 20.0)
		_nozzle_glow(1.4 * clampf(1.0 - u / 0.6, 0.2, 1.0))
		_belly_glow(plume.thrust * 0.7)
	_lamps(t, 0.3 * clampf(1.0 - (t - _burst) / 0.3, 0.0, 1.0) if _burst >= 0.0 else 0.0)
	if _walk == "" and t > 0.5:
		_walkers("watch", 0.0)
	if t >= 4.0:
		_finished = true


## 3 FAST AND PUNCHY, 2.0 s. Why: the punch is the idea; any longer and the hover
## becomes a wait. The cut lands while the flash is still in the eye.
func _punch(t: float) -> void:
	const GO := 0.7
	if t >= 0.04 and not plume.fired():
		plume.fire()
		_engines(ThrusterFx.Thrust.CRUISE)
	var hover := 1.0 - pow(1.0 - clampf(t / 0.45, 0.0, 1.0), 3.0)
	var bob := (1.0 if int(t * 8.0) % 2 == 0 else 0.0) if t > 0.45 and t < GO else 0.0
	_off.y = -14.0 * hover - bob
	berth.retract = int(floorf(clampf((t - 0.08) / 0.2, 0.0, 1.0) * 52.0 * YardSlot.depth_k(berth.weight)))
	plume.thrust = minf(1.0, t / 0.15) if t < GO + 0.15 else maxf(0.0, 1.0 - (t - GO - 0.15) / 0.3)
	_belly_glow(plume.thrust)
	if t >= GO:
		var u := t - GO
		if view._burn_thrust != ThrusterFx.Thrust.FULL:
			_engines(ThrusterFx.Thrust.FULL)
		_off.x = _exit * pow(clampf(u / 0.3, 0.0, 1.0), 3.0)
		_off.y -= 4.0 * clampf(u / 0.3, 0.0, 1.0)
		_flash = clampf(1.0 - u / 0.4, 0.0, 1.0)
		_shake = _jolt(t, 3.0 * clampf(1.0 - u / 0.45, 0.0, 1.0), 24.0)
		if u < 0.36:
			_trail.push_front(Vector2(roundf(_off.x), roundf(_off.y)))
			if _trail.size() > 6:
				_trail.pop_back()
		elif not _trail.is_empty():
			_trail.pop_back()
		_lamps(t, 0.6 * _flash)
		if _flash > 0.0:
			var c := plume.src
			# one pulse: hot at the ship, a wash across the hall, gone in 0.4 s
			_lights.append([c.x, c.y - 10.0, 260.0, 120.0, Color(1.0, 0.92, 0.78), 0.7 * _flash])
			_lights.append([c.x, c.y, 1100.0, 600.0, Color(1.0, 0.85, 0.65), 0.22 * _flash])
			_dyn([c.x, float(berth.feet), 620.0, 220.0, 1.3 * _flash, Color(1.0, 0.85, 0.65), 1.0])
		_nozzle_glow(1.5)
		if _walk == "":
			_walkers("shove", 0.0)
	elif _walk == "" and t > 0.25:
		_walkers("watch", 0.0)
	if t >= 2.0:
		_finished = true


# ------------------------------------------------------------------ pieces

func _engines(th: int) -> void:
	if view == null:
		return
	if view._engines_off or not view._burning or view._burn_thrust != th:
		view._engines_off = false
		view.burn(true)
		view._burn_thrust = th
		view.refresh()


static func _ease_io(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## Whole-pixel shake, a new offset `hz` times a second.
func _jolt(t: float, amp: float, hz: float) -> Vector2:
	if amp <= 0.0:
		return Vector2.ZERO
	var s := floorf(t * hz)
	return Vector2(roundf((YardLight.hash1(s * 1.37) - 0.5) * 2.0 * amp), roundf((YardLight.hash1(s * 2.91 + 0.4) - 0.5) * 2.0 * amp))


## The hall's lamps stutter with the thrust, in uneven held steps.
func _lamps(t: float, depth: float) -> void:
	if depth <= 0.0:
		front.launch_lamp_k = 1.0
		return
	var h := YardLight.hash1(floorf(t * 12.0) * 3.17)
	front.launch_lamp_k = 1.0 - depth * (1.0 if h < 0.35 else (0.5 if h < 0.7 else 0.0))


func _belly_glow(k: float) -> void:
	if k <= 0.01:
		return
	var c := plume.src
	var flick := 0.88 + 0.12 * YardLight.hash1(floorf(_t * 10.0) * 1.7)
	# the jets' line under the belly; the floor and stands take theirs from the hall's light
	_lights.append([c.x, c.y + 4.0, plume.src_w * 1.3, 12.0, Color(1.0, 0.7, 0.4), 0.8 * k * flick])
	_jets_k = k


func _nozzle_glow(k: float) -> void:
	var g := view.engine_glow()
	if g.is_empty():
		return
	var at: Vector2 = front.get_global_transform().affine_inverse() * (g.at as Vector2)
	_lights.append([at.x - 6.0, at.y, 46.0, 26.0, Color(1.0, 0.7, 0.4), 0.8 * k])
	_dyn([at.x - 10.0, at.y, 140.0, 80.0, 1.4 * k, Color(1.0, 0.65, 0.35), 1.0])


var _extra: Array = []


func _dyn(l: Array) -> void:
	_extra.append(l)


func _feed_light() -> void:
	var life := front.scene.life
	if life != null:
		life.extra = plume.lights() + _extra
	_extra = []
	if _chase >= 0.0:
		_chase_lights()
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


# ------------------------------------------------------------------ the crew

## "back": those near the blast walk off from it, the rest stop and look;
## "watch": everyone stops and looks; "shove": the flash knocks the near ones back.
func _walkers(mode: String, _unused: float) -> void:
	_walk = mode
	var life := front.scene.life
	if life == null:
		return
	var sx := plume.src.x
	for c: Dictionary in life.CREW:
		var cd := c
		cd["ev"] = func(t: float) -> Dictionary:
			if not cd.has("_l"):
				var p0 := life.walk_at(cd, t)
				cd["_l"] = {"x": float(p0.x), "t": t, "f": int(p0.f)}
			var L: Dictionary = cd["_l"]
			var x0 := float(L.x)
			var away := -1.0 if x0 < sx else 1.0
			var near := absf(x0 - sx) < 240.0
			var u := t - float(L.t)
			var face := -away
			var nm := String(cd["name"])
			if mode == "back" and near:
				var C := life.crew_strip(nm)
				var dist := 34.0 * maxf(0.0, u - 0.25)
				var adv := float(C.get("advance", 1.0))
				var stp := floorf(dist / adv)
				return {"x": x0 + away * stp * adv, "dir": away, "f": int(stp) % int(C.get("frames", 8)), "dy": 0.0}
			if mode == "shove" and near:
				var k := 1.0 - pow(1.0 - clampf(u / 0.3, 0.0, 1.0), 3.0)
				return {"x": x0 + away * floorf(14.0 * k), "dir": face, "f": life.stand_frame(nm), "dy": 0.0}
			return {"x": x0, "dir": face, "f": life.stand_frame(nm), "dy": 0.0}


# ------------------------------------------------------------------ the rig

## THE LIFT JETS: short flames down from the belly, a new shape ten times a second.
func _draw_jets(ci: CanvasItem) -> void:
	if _jets_k <= 0.02:
		return
	var r := Rect2(_thing0)
	var o := Vector2(roundf(_off.x), roundf(_off.y))
	var step := floorf(_t * 10.0)
	var cols := [Color("#fff4d0"), Color("#ffd27a"), Color("#ff9a3c"), Color("#c0501a")]
	for j in 4:
		var x := floorf(r.position.x + r.size.x * (0.22 + 0.19 * float(j)) + o.x)
		var y0 := floorf(_belly_at(x - o.x) + o.y)
		var len := floorf((6.0 + 12.0 * _jets_k) * (0.7 + 0.5 * YardLight.hash1(step * 1.3 + float(j) * 7.1)))
		for row in int(len):
			var u := float(row) / maxf(1.0, len)
			var half := floorf((3.0 - 2.0 * u) + (1.0 if YardLight.hash1(step + float(row) * 0.7 + float(j)) > 0.6 else 0.0))
			var c: Color = cols[mini(3, int(u * 4.0))]
			ci.draw_rect(Rect2(x - half, y0 + float(row), half * 2.0 + 1.0, 1), c)


## The hull's lowest inked row under hall column `x`, at its berth.
var _belly_cache := {}


func _belly_at(x: float) -> float:
	var key := int(floorf(x))
	if _belly_cache.has(key):
		return float(_belly_cache[key])
	_belly_cache[key] = _belly_scan(x)
	return float(_belly_cache[key])


func _belly_scan(x: float) -> float:
	var img := view.canvas()
	var vx := int(floorf(x - _pos0.x - view.position.x))
	if img == null or vx < 0 or vx >= img.get_width():
		return float(_thing0.end.y)
	for y in range(img.get_height() - 1, -1, -1):
		if img.get_pixel(vx, y).a8 >= 128:
			return _pos0.y + view.position.y + float(y) + 1.0
	return float(_thing0.end.y)

func _chase_lights() -> void:
	if _rail_x > float(YardFront.W):
		return
	var head := _rail_x + (float(YardFront.W) - _rail_x) * fposmod(_chase * 3.0, 1.0)
	for k in 4:
		var x := floorf((head - float(k) * 14.0) / 14.0) * 14.0
		if x < _rail_x:
			continue
		_lights.append([x + 1.0, _rail_y + 6.0, 14.0, 8.0, Color(0.55, 0.95, 1.0), 1.0 - float(k) * 0.22])


func _draw_rig() -> void:
	var ci := rig
	_draw_jets(ci)
	var steel := Color8(38, 44, 54)
	var lit := Color8(88, 100, 112)
	var amber := Color8(196, 140, 48)
	var r := Rect2(_thing0)
	var o := Vector2(roundf(_off.x), roundf(_off.y))
	# THE HOIST: two hooks on cables from the roof, down to the hull's back
	if idea == 2 and _cable > 0.0 and _burst < 0.0:
		for fx: float in [0.3, 0.7]:
			var x := floorf(r.position.x + r.size.x * fx + o.x)
			var hook_y := floorf(lerpf(-10.0, r.position.y + o.y - 5.0, _ease_io(_cable)))
			ci.draw_rect(Rect2(x, 0, 1, hook_y), steel)
			ci.draw_rect(Rect2(x + 1, 0, 1, hook_y), lit)
			ci.draw_rect(Rect2(x - 4, hook_y, 10, 5), steel)
			ci.draw_rect(Rect2(x - 4, hook_y, 10, 1), lit)
			ci.draw_rect(Rect2(x - 4, hook_y + 4, 10, 1), amber)
	# THE RAIL, run out from the right edge, lamps under it
	if idea == 2 and _rail_x < float(YardFront.W):
		var y := floorf(_rail_y)
		var x0 := floorf(_rail_x)
		ci.draw_rect(Rect2(x0, y, float(YardFront.W) - x0, 6), steel)
		ci.draw_rect(Rect2(x0, y, float(YardFront.W) - x0, 1), lit)
		ci.draw_rect(Rect2(x0, y + 5, float(YardFront.W) - x0, 1), Color8(20, 24, 30))
		var xs := x0
		while xs < float(YardFront.W):
			ci.draw_rect(Rect2(xs, y + 2, 1, 2), Color8(24, 28, 36))
			ci.draw_rect(Rect2(xs + 6, y + 6, 2, 1), Color8(60, 120, 130))
			xs += 14.0
		ci.draw_rect(Rect2(x0 - 3, y - 1, 3, 8), amber)
		# the carriage the hull hangs from, riding the rail
		if _cable >= 1.0 and _off.y <= -(_rise + 21.0):
			for fx: float in [0.3, 0.7]:
				var cx := floorf(r.position.x + r.size.x * fx + o.x)
				ci.draw_rect(Rect2(cx - 5, y + 6, 12, floorf(r.position.y + o.y) - y - 6), steel)
				ci.draw_rect(Rect2(cx - 5, y + 6, 1, floorf(r.position.y + o.y) - y - 6), lit)
	# THE STREAK: the hull's afterimages, fading, and speed lines off its tail
	if idea == 3 and view != null:
		var tex := view.texture
		var vp := _pos0 + view.position
		for i in range(_trail.size() - 1, 0, -1):
			var a := 0.5 * (1.0 - float(i) / float(_trail.size() + 1))
			var tp: Vector2 = _trail[i]
			ci.draw_texture_rect(tex, Rect2(vp + tp, view.size), false, Color(0.7, 0.85, 1.0, a))
		if not _trail.is_empty():
			var head: Vector2 = _trail[0]
			var tail: Vector2 = _trail[_trail.size() - 1]
			var len := head.x - tail.x
			var row := r.position.y + 4.0
			while row < r.end.y - 2.0:
				var h := YardLight.hash1(row * 0.37 + floorf(_t * 30.0))
				var l := floorf(len * (0.6 + 0.4 * h))
				ci.draw_rect(Rect2(floorf(r.position.x + head.x - l), floorf(row + head.y), l, 1), Color(0.85, 0.93, 1.0, 0.35 + 0.3 * h))
				row += 5.0
