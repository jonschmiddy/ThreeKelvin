extends Node2D

## Zoom redraws the pulsar bigger with its own shaders, never stretched.
## Beat time syncs each flash to what is heard.
## Why: docs/why/PulsarView.md#pulsar-view

const SkyBakeS := preload("res://scripts/ui/sysmap/SkyBake.gd")
const SHADER := preload("res://shaders/pulsar.gdshader")
const WEB_SHADER := preload("res://shaders/pulsar_web.gdshader")

## the renderer's box, centred on the pulsar: drawn large so its beams are never cut short
const BOX := Vector2i(480, 320)
## the map's orbits are seen at this tilt, and the pulsar's spin axis with them
const TILT := 0.38
## amb_pulsar's passes peak about 0.5 s into each second; Jon set +50 ms by ear (2026-10-01)
const PEAK_S := 0.5
const OFF_S := 0.05
const LOOP_S := 5.0
## a sky flash, when the system rolled one, is this blue added over the whole
## map at `sky_flash` strength ("lighter", as the mockup's overlay drew it)
const SKY_FLASH_COLOR := Color8(60, 110, 220)
## the motions a system can roll, one or two of them
const POOL: Array[StringName] = [&"glow", &"spark", &"jets", &"sky", &"quake", &"wobble"]
const SPRAY_N := 150
const SPRAY_DT := 0.045

## what the system rolled: its cloud and its motions (see `roll`)
var spec: Dictionary = {}
## how strongly to add SKY_FLASH_COLOR over the map this moment (0 when the
## system rolled no sky flash, or between flashes)
var sky_flash: float = 0.0
## where the beam points on screen this moment, radians, y down (either end:
## the other is this plus PI); NAN while it points at or away from you
var beam_angle: float = NAN
## the web of filaments and the beam-lit gas, over the whole map: light only
var web: ColorRect
## the map's zoom this moment (see `set_zoom`)
var zoom: float = 1.0
## where the pulsar stood when it was set up: its web is cut there, and carried
## wherever it goes since
var web_anchor := Vector2.ZERO
## Weather rides on beats its sound already plays: a giant pulse and a magnetar flare.
var giant_n := -999999
var mag_t0 := -1.0e9
var mag_k := 0.0

## True centre against the whole-pixel position, so a zoom moves the pulsar smoothly.
var sub := Vector2.ZERO

var _box: ColorRect
var _mat: ShaderMaterial
var _web_mat: ShaderMaterial
var _map_rect := Rect2(264, 0, 696, 540)
## half the box this moment, in game pixels: BOX / 2 x zoom, rounded up
var _half := BOX / 2


func _init() -> void:
	_box = ColorRect.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.position = Vector2(-BOX.x / 2, -BOX.y / 2)
	_box.size = Vector2(BOX)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_box.material = _mat
	web = ColorRect.new()
	web.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_web_mat = ShaderMaterial.new()
	_web_mat.shader = WEB_SHADER
	web.material = _web_mat
	web.visible = false


## `map_rect` is the map's area in parent pixels: the web is cut from noise at those coordinates.
func setup(system_index: int, map_rect: Rect2 = Rect2(264, 0, 696, 540)) -> void:
	spec = roll(system_index)
	_map_rect = map_rect
	web_anchor = position.round()
	if _box.get_parent() == null:
		add_child(_box)
	var m := _mat
	var g: Dictionary = spec.gas
	m.set_shader_parameter("gas_r", g.R)
	m.set_shader_parameter("gas_w", g.w)
	m.set_shader_parameter("gas_tall", g.tall)
	m.set_shader_parameter("gas_turb", g.turb)
	m.set_shader_parameter("gas_warp", g.warp)
	m.set_shader_parameter("gas_haze", g.haze)
	m.set_shader_parameter("gas_i", g.I)
	m.set_shader_parameter("gas_spin", g.spin)
	m.set_shader_parameter("gas_off", Vector2(g.ox, g.oy))
	m.set_shader_parameter("gas_vol", g.vol)
	m.set_shader_parameter("beat_glow", spec.beat_glow)
	m.set_shader_parameter("jets", spec.jets)
	m.set_shader_parameter("quake", spec.quake)
	m.set_shader_parameter("n_spray", 0)
	var w := _web_mat
	w.set_shader_parameter("origin", map_rect.position)
	w.set_shader_parameter("rect_size", map_rect.size)
	w.set_shader_parameter("panel_x", map_rect.position.x)
	w.set_shader_parameter("map_size", map_rect.end)
	w.set_shader_parameter("sd", float(system_index) * 1.37)
	w.set_shader_parameter("anchor", web_anchor)
	web.size = map_rect.size
	set_zoom(zoom)
	# the web goes under the orbits; if the screen has not placed it, it draws here
	if web.get_parent() == null:
		add_child(web)
		move_child(web, 0)
	web.visible = true


## Remnant gas the beam lights, a float texture from the sky's bake; null removes it.
func set_gas(tex: Texture2D) -> void:
	_web_mat.set_shader_parameter("gas_tex", tex)
	_web_mat.set_shader_parameter("has_gas", tex != null)


## Only sizes and uniforms change, so it can be called every frame of a zoom.
func set_zoom(k: float) -> void:
	zoom = maxf(k, 0.05)
	# Box centred on a whole pixel with an even side, or 2x2 blocks sit half a block over.
	var need := Vector2i(ceili(BOX.x * 0.25 * zoom - 1e-4) * 2, ceili(BOX.y * 0.25 * zoom - 1e-4) * 2)
	# The box grows in 32 px steps with room to spare: each resize flashed 7% of the map once.
	# Why: docs/why/PulsarView.md#box-growth
	if need.x > _half.x or need.x < _half.x - 72:
		_half.x = ceili((need.x + 8) / 32.0) * 32
	if need.y > _half.y or need.y < _half.y - 72:
		_half.y = ceili((need.y + 8) / 32.0) * 32
	_box.size = Vector2(_half * 2)
	_place()
	_mat.set_shader_parameter("zoom", zoom)
	_mat.set_shader_parameter("box_half", Vector2(_half))
	_web_mat.set_shader_parameter("zoom", zoom)


## The box and the web's centre on this node's position, rounded to a whole
## pixel, so a pan by part of a pixel never puts the box between pixels.
func _place() -> void:
	var c := position.round()
	_box.position = Vector2(-_half) + (c - position)
	_web_mat.set_shader_parameter("centre", c)
	_mat.set_shader_parameter("sub", sub)
	# (its half is whole multiples of 32: the corner sits on the grid where its centre does)
	_mat.set_shader_parameter("grid_at", Vector2(posmod(int(c.x), 8), posmod(int(c.y), 8)))
	_web_mat.set_shader_parameter("sub", sub)


## This moment, `t` the beat time in seconds.
func step(t: float) -> void:
	if spec.is_empty():
		return
	_place()
	var G := frame(spec, t)
	var m := _mat
	var mv: Vector3 = G.m
	m.set_shader_parameter("time", t)
	m.set_shader_parameter("m_axis", mv)
	m.set_shader_parameter("s_axis", G.s)
	m.set_shader_parameter("e1", G.e1)
	m.set_shader_parameter("e2", G.e2)
	var fl: float = G.flash
	var bi := 1.5
	var bl := 200.0
	var sf: float = 0.16 * fl if spec.sky and fl > 0.02 else 0.0
	if giant_n > -999999 or mag_k > 0.0:
		var tb := t - PEAK_S - OFF_S
		var nb := roundi(tb)
		# eased about the beat itself, so the beams are brighter while they are seen
		var wb := exp(-pow((tb - float(nb)) / 0.3, 2.0))
		var k := nb - giant_n
		if k == -2:
			bi = 1.5 * (1.0 + 0.15 * wb)
		elif k == -1:
			bi = 1.5 * (1.0 + 0.3 * wb)
		elif k == 0:
			# Beam and flash at 1.5x, not 2x: twice clipped about 1,300 blocks to white a minute.
			# Why: docs/why/PulsarView.md#beam-brightness
			bi = 1.5 * (1.0 + 0.55 * wb)
			bl = 200.0 + 80.0 * wb
			sf = maxf(sf, 0.08 * fl)
			fl *= 1.0 + 0.6 * wb
		if mag_k > 0.0:
			var ma := t - mag_t0
			m.set_shader_parameter("mag_age", ma)
			m.set_shader_parameter("mag_k", mag_k if ma >= 0.0 else 0.0)
			if ma >= 0.0:
				# the flush, capped, for an instant; then each beat's flash ringing down
				var ring := 1.0 + 1.5 * exp(-ma / 8.0) * mag_k
				if ma > 0.5:
					fl *= ring
					sf *= ring
				sf = maxf(sf, 0.28 * exp(-ma / 0.3) * mag_k)
	m.set_shader_parameter("flash", fl)
	m.set_shader_parameter("beam_i", bi)
	m.set_shader_parameter("beam_len", bl)
	m.set_shader_parameter("glitch_k", G.glitch_k)
	m.set_shader_parameter("beat_age", beat_age(t))
	m.set_shader_parameter("loop_at", loop_at(t))
	var g: Dictionary = spec.gas
	m.set_shader_parameter("gas_rot", fmod(g.spin * t, TAU))
	m.set_shader_parameter("gas_ph", fposmod(t / 10.0, 1.0))
	if spec.jets:
		m.set_shader_parameter("jet_ph1", fmod(t * 1.6, TAU))
		m.set_shader_parameter("jet_ph2", fmod(t * 3.2, TAU))
	if spec.spark:
		var sp := spray(G, t, zoom, _half, sub)
		var n := sp.size()
		sp.resize(SPRAY_N * 2)
		m.set_shader_parameter("spray", sp)
		m.set_shader_parameter("n_spray", n)
	beam_angle = atan2(mv.y, mv.x) if Vector2(mv.x, mv.y).length() > 0.05 else NAN
	sky_flash = minf(sf, 0.28)
	var w := _web_mat
	w.set_shader_parameter("turn", fmod(t * 0.012, TAU))
	w.set_shader_parameter("shimmer_t", fmod(t * 0.9, TAU))
	w.set_shader_parameter("has_beam", not is_nan(beam_angle))
	w.set_shader_parameter("beam_angle", 0.0 if is_nan(beam_angle) else beam_angle)
	# wherever the screen put the web, it covers the map's area
	var par := get_parent() as CanvasItem
	if web.is_inside_tree() and par != null:
		web.global_position = par.get_global_transform() * _map_rect.position


# ---------------------------------------------------------------- the roll

## A system's pulsar rolls its cloud density at random for variety (Jon).
static func roll(seed: int) -> Dictionary:
	var d := SkyBakeS.hash2(seed, 11)
	var size := SkyBakeS.hash2(seed, 12)
	var spin := SkyBakeS.hash2(seed, 13)
	var gas := {
		"R": 28.0 + size * 16.0, "w": 6.0 + d * 16.0, "tall": 0.7 + d * 0.4, "turb": 0.99 - d * 0.2,
		"warp": 0.9 + 0.6 * SkyBakeS.hash2(seed, 15), "haze": 0.04 + d * 0.75, "I": 0.5 + d * 0.8,
		"spin": 0.18 + spin * 0.24, "ox": SkyBakeS.hash2(seed, 21) * 400.0, "oy": SkyBakeS.hash2(seed, 22) * 400.0,
		# three heights through the cloud on the map, not five: a third cheaper, and it reads the same at this size
		"vol": 3,
	}
	var n := 1 if SkyBakeS.hash2(seed, 101) < 0.5 else 2
	var a := int(floor(SkyBakeS.hash2(seed, 202) * POOL.size()))
	var b := int(floor(SkyBakeS.hash2(seed, 303) * (POOL.size() - 1)))
	if b >= a:
		b += 1
	var picks: Array[StringName] = [POOL[a]]
	if n == 2:
		picks.append(POOL[b])
	var s := {"seed": seed, "gas": gas, "picks": picks, "beat_glow": false, "spark": false, "jets": false, "sky": false, "quake": false, "wobble": 0.0}
	for k in picks:
		match k:
			&"glow": s.beat_glow = true
			&"spark": s.spark = true
			&"jets": s.jets = true
			&"sky": s.sky = true
			&"quake": s.quake = true
			&"wobble": s.wobble = 0.22 if SkyBakeS.hash2(seed, 404) < 0.5 else 0.5
	return s


# ---------------------------------------------------------------- the spin
# x right, y down, z toward you. The magnetic axis turns once a second, flashing at 0.55 s.

static func _mag_at(s: Vector3, e1: Vector3, e2: Vector3, al: float, phi: float) -> Vector3:
	return s * cos(al) + (e1 * cos(phi) + e2 * sin(phi)) * sin(al)


static func beat_age(t: float) -> float:
	return fposmod(t - PEAK_S - OFF_S, 1.0)


static func loop_at(t: float) -> float:
	return fposmod(t - PEAK_S - OFF_S, LOOP_S)


## The frame at beat time t (`PS.frame`, with the map's ax 0 and inc asin(TILT)).
static func frame(s: Dictionary, t: float) -> Dictionary:
	var ax := 0.0
	var inc := asin(TILT)
	var sa := Vector3(sin(ax) * cos(inc), -cos(ax) * cos(inc), sin(inc))
	var e1 := sa.cross(Vector3(0, 0, 1)).normalized()
	var e2 := sa.cross(e1)
	# THE WOBBLE: the beams' own spin axis nods slowly round, keeping the same
	# angle to you, so each turn sweeps a new path and still flashes on the beat
	var bs := sa
	var b1 := e1
	var b2 := e2
	var wob: float = s.wobble
	if wob > 0.0:
		var bax := ax + wob * sin(t * TAU / 14.0) + wob * 0.25 * sin(t * 1.7)
		bs = Vector3(sin(bax) * cos(inc), -cos(bax) * cos(inc), sin(inc))
		b1 = bs.cross(Vector3(0, 0, 1)).normalized()
		b2 = bs.cross(b1)
	var al := PI / 2.0 - inc
	var phi := atan2(b2.z, b1.z) + TAU * (t - PEAK_S - OFF_S)
	var m := _mag_at(bs, b1, b2, al, phi)
	var fl := pow(maxf(0.0, m.z), 6.0) + pow(maxf(0.0, -m.z), 6.0)
	var gk := maxf(0.0, 1.0 - loop_at(t) / 0.8) if s.quake else 0.0
	return {"s": sa, "e1": e1, "e2": e2, "bs": bs, "b1": b1, "b2": b2, "m": m, "al": al, "phi": phi, "flash": fl, "glitch_k": gk}


## Sprinkler: particles thrown along each beam as it turns, sorted by row for the shader.
static func spray(G: Dictionary, t: float, k: float = 1.0, half: Vector2i = BOX / 2, off := Vector2.ZERO) -> PackedVector4Array:
	var pts: Array[Vector4] = []
	var V := 34.0
	var I := 1.6
	var ph := fmod(t, SPRAY_DT)
	for sg: float in [1.0, -1.0]:
		for j in SPRAY_N:
			var age := j * SPRAY_DT + ph
			var me := _mag_at(G.bs, G.b1, G.b2, G.al, G.phi - TAU * age)
			var r := age * V + 2.0
			var x := floorf(half.x + off.x + sg * me.x * r * k + 0.5)
			var y := floorf(half.y + off.y + sg * me.y * r * k + 0.5)
			if x < 0 or y < 0 or x >= half.x * 2 or y >= half.y * 2:
				continue
			pts.append(Vector4(x, y, I * (1.0 - float(j) / SPRAY_N) * (1.0 if sg * me.z > 0.0 else 0.6), 1.0 if j < 50 else 0.0))
	pts.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.y < b.y)
	return PackedVector4Array(pts)
