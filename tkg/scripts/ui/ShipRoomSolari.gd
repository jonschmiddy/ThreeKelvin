class_name ShipRoomSolari
extends ShipRoom

## Solari's Casting bed (Jon, Nov 24: show18 approved): six furnaces and the bed they pour on, lit
## as the film lights it (ship_room_solari.gdshader), its casting cycle, jibs, handlers and air.
## Why: docs/why/ShipRoomSolari.md#light

const C := preload("res://scripts/ui/ShipRoomSolariCycle.gd")
const FIRE := Color(1.0, 0.62, 0.30)
const WARM := Color(1.0, 0.55, 0.24)
const WHITE_HEAT := Color(1.0, 0.93, 0.78)
const ARC := Color(0.72, 0.85, 1.0)
const MAX_POOLS := 32
const MAX_HULL_LIGHTS := 20
const FOOT_ROW := 207
enum Mode { ROOM, BACK, HULL, FRONT, POST }

var mats: Dictionary[int, ShaderMaterial] = {}
var _fields: Image = null
var _fscale: PackedFloat32Array = PackedFloat32Array()
var _sol: Dictionary = {}
# this frame's light (set by `_light`, read by the hulls' bounce)
var _pools: Array[PackedFloat32Array] = []
var _hull_lights: Array[PackedFloat32Array] = []
var _pour_w := PackedFloat32Array([0, 0, 0, 0, 0, 0])


func hull_amb() -> float:
	return 0.5


func band_colour() -> Color:
	return Color8(12, 8, 6)


func hull_material() -> Material:
	return mats[Mode.HULL]


func thing_material() -> Material:
	return mats[Mode.POST]


func _build() -> void:
	_sol = layout.get("solari", {})
	var sc: Dictionary = _sol.get("fields", {})
	_fscale.resize(32)
	_fscale.fill(1.0)
	for k: String in sc:
		_fscale[int(sc[k][0])] = float(sc[k][1])
	var asc := PackedFloat32Array()
	asc.resize(28)
	var ad: Dictionary = _sol.get("air", {})
	for k: String in ad:
		asc[int(ad[k][0])] = float(ad[k][1])
	var ft := tex(id, "fields.png")
	_fields = ft.get_image() if ft != null else null
	if _fields != null and _fields.is_compressed():
		_fields.decompress()
	for m: int in Mode.values():
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/ship_room_solari.gdshader")
		mat.set_shader_parameter(&"mode", m)
		mat.set_shader_parameter(&"albedo", tex(id, "albedo.png"))
		mat.set_shader_parameter(&"emissive", tex(id, "emissive.png"))
		mat.set_shader_parameter(&"masks", tex(id, "masks.png"))
		mat.set_shader_parameter(&"fields", ft)
		mat.set_shader_parameter(&"air", tex(id, "air.png"))
		mat.set_shader_parameter(&"fscale", _fscale)
		mat.set_shader_parameter(&"ascale", asc)
		mats[m] = mat
	# the room's own picture replaces the package's
	(under.get_child(0) as ColorRect).material = mats[Mode.ROOM]
	_light()


## The material a thing drawn in the room uses: BACK into the albedo, FRONT over the hulls.
func material_for(m: Mode) -> ShaderMaterial:
	return mats[m]


func _tick(_dt: float) -> void:
	_light()
	_bounce()


# ------------------------------------------------------------------ this frame's light (show18.frame)
func _pool(c: Vector4, b: Vector4, col: Color, steady: float, breath: float = 1.0, no_ring: bool = false) -> void:
	if steady <= 0.001 or _pools.size() >= MAX_POOLS:
		return
	_pools.append(PackedFloat32Array([c.x, c.y, c.z, c.w, b.x, b.y, b.z, b.w,
		col.r * steady, col.g * steady, col.b * steady, steady, breath, 1.0 if no_ring else 0.0]))


func _hull_light(x: float, y: float, r: float, col: Color, s: float) -> void:
	if _hull_lights.size() < MAX_HULL_LIGHTS:
		_hull_lights.append(PackedFloat32Array([x, y, r, col.r * s, col.g * s, col.b * s]))


func _light() -> void:
	_pools.clear()
	_hull_lights.clear()
	var fk := PackedFloat32Array()
	var lip := PackedFloat32Array()
	var efl := PackedFloat32Array()
	var pb := PackedFloat32Array()
	var roar := C.roar_k(t)
	var pk_max := 0.0
	for i in 6:
		var k := C.fire_k(i, t)
		var fl := C.pour_flare(i, t)
		fk.append(k)
		lip.append(maxf(fl, roar) if i == 1 else fl)
		efl.append(maxf(fl, 1.5 * roar) if i == 1 else fl)
		_hull_light(C.TAPS[i], 120, 300, FIRE, 0.30 * 0.55 * k)
		var u := C.u_of(i, t)
		var pk := C.pour_k(u)
		pk_max = maxf(pk_max, pk)
		_pour_w[i] = 0.7 * pk
		pb.append(0.9 + 0.2 * C.hash1([i, int(t * 10.0)]))
		_bay_light(i, u, pk, pb[i])
	var op := 0.85 * roar
	var tl := fposmod(t, C.LOOP)
	if tl >= 6.0 and tl < 13.6:
		var ph := fposmod(t * 1.2, 1.0)
		var lvl: float = [0.4, 0.65, 1.0][mini(2, int(maxf(0.0, cos(TAU * ph)) * 3.0))]
		var sx := C.TAPS[1] - 2 + 1 + int(roundf(40.0 * sin(TAU * ph)))
		_pool(Vector4(sx, 64, 18, 22), Vector4(0.35, 0, 0, 0), Color(1.0, 0.62, 0.15), 0.55 * lvl)
	var door_k := 0
	var door_b := 1.0
	if op > 0.0:
		door_b = [0.93, 0.97, 1.0][int(C.hash1([5, int(t * 8.0)]) * 3.0)]
		_pool(Vector4(C.TAPS[1], 100, 190, 130), Vector4(0.3, 0, 0, 0), WHITE_HEAT, 1.35 * op, door_b, true)
		door_k = clampi(int(roundf(op * 6.0)), 1, 5)
		_hull_light(C.TAPS[1], 120, 560, WHITE_HEAT, op * door_b)
	var dxp := int(roundf(tl / C.LOOP * (W + 120) - 60))
	_pool(Vector4(dxp, 66, 12, 18), Vector4(0.4, 0, 0, 0), Color(0.8, 0.9, 1.0), 0.35)
	var tired := fposmod(t, 7.3)
	var crew := _crew_light()
	for m: ShaderMaterial in mats.values():
		m.set_shader_parameter(&"t_room", t)
		m.set_shader_parameter(&"lamp_k", lamp_k)
		m.set_shader_parameter(&"fk", fk)
		m.set_shader_parameter(&"flare", lip)
		m.set_shader_parameter(&"eflare", efl)
		m.set_shader_parameter(&"pour_w", _pour_w)
		m.set_shader_parameter(&"pour_b", pb)
		m.set_shader_parameter(&"door_k", door_k)
		m.set_shader_parameter(&"door_w", op)
		m.set_shader_parameter(&"door_b", door_b)
		m.set_shader_parameter(&"tired_b", 0.35 if tired < 0.12 or (tired > 3.1 and tired < 3.18) else 1.0)
		m.set_shader_parameter(&"brass", 0.45 + 0.5 * pk_max + 0.7 * op)
		for k: StringName in crew:
			m.set_shader_parameter(k, crew[k])
	_send_lists()


## A bay's moving light: its pour's wall glow and landing, its cooling mould, its jib, its stack.
func _bay_light(j: int, u: float, pk: float, gutter: float) -> void:
	var tx := float(C.TAPS[j])
	if pk > 0.0:
		_pool(Vector4(tx, 160, 46, 34), Vector4(0.3, 0, 0, 0), FIRE, 1.15 * pk, gutter, true)
		_hull_light(tx, 172, 330, FIRE, 0.75 * pk * 1.15 * pk * gutter)
		var n := C.fill_of(u)
		var yl := C.IN1 - n + 1 if n > 0 else C.IN1
		_pool(Vector4(tx, yl, 16, 9), Vector4(0.4, 0, 0, 0), WHITE_HEAT, 0.6 * pk,
			0.75 + 0.5 * C.hash1([j, int(t * 12.0)]))
	if u < C.JIB.lift.x and u >= C.FALL:
		var hs := floorf(C.heat_of(u) * 6.0) / 6.0
		var col := WHITE_HEAT * hs + WARM * (1.0 - hs)
		_pool(Vector4(tx, 166, 30, 18), Vector4(0.35, 0, 0, 0), col, 0.5 * hs)
		_pool(Vector4(tx, FOOT_ROW + 4, 54, 12), Vector4(0.35, 0.6, FOOT_ROW, 400), WARM, 0.35 * hs)
		if hs > 0.5:
			_hull_light(tx, 175, 220, WARM, 0.35 * hs * 0.35 * hs)
	if C.jib_moving(u):
		var js := C.jib_state(u)
		var jx := C.jib_tip_x(j, js.phi)
		var blink := 1.0 if fposmod(t * 2.0, 1.0) < 0.6 else 0.45
		_pool(Vector4(jx, C.ARM_Y + 6, 16, 14), Vector4(0.4, 0, 0, 0), Color(1.0, 0.7, 0.25), 0.4, blink)
		if js.carry:
			_pool(Vector4(jx, js.hy + 5, 18, 10), Vector4(0.4, 0, 0, 0), WARM, 0.9 * C.heat_of(u))
	if u >= C.JIB.lower.x and u < 29.0 and C.heat_of(u) > 0.08:
		_pool(Vector4(C.stack_x(j), 196, 20, 12), Vector4(0.4, 0, 0, 0), WARM, 0.4 * C.heat_of(u))


## The welder's arc, the fettler's grinder, the lamp tech's lamp and who walks through the light.
func _crew_light() -> Dictionary[StringName, Variant]:
	return {&"arc_i": -1, &"arc_w": 0.0, &"grind_w": 0.0, &"tech_i": -1,
		&"people": PackedVector4Array([Vector4.ZERO, Vector4.ZERO, Vector4.ZERO])}


func _send_lists() -> void:
	var a := PackedVector4Array()
	var b := PackedVector4Array()
	var c := PackedVector4Array()
	var d := PackedVector4Array()
	for p in _pools:
		a.append(Vector4(p[0], p[1], p[2], p[3]))
		b.append(Vector4(p[4], p[5], p[6], p[7]))
		c.append(Vector4(p[8], p[9], p[10], p[11]))
		d.append(Vector4(p[12], p[13], 0, 0))
	var n := a.size()
	a.resize(MAX_POOLS)
	b.resize(MAX_POOLS)
	c.resize(MAX_POOLS)
	d.resize(MAX_POOLS)
	var hp := PackedVector4Array()
	var hc := PackedVector4Array()
	for h in _hull_lights:
		hp.append(Vector4(h[0], h[1], h[2], 0))
		hc.append(Vector4(h[3], h[4], h[5], 0))
	var nh := hp.size()
	hp.resize(MAX_HULL_LIGHTS)
	hc.resize(MAX_HULL_LIGHTS)
	for m: ShaderMaterial in mats.values():
		m.set_shader_parameter(&"n_pools", n)
		m.set_shader_parameter(&"pool_a", a)
		m.set_shader_parameter(&"pool_b", b)
		m.set_shader_parameter(&"pool_c", c)
		m.set_shader_parameter(&"pool_d", d)
		m.set_shader_parameter(&"n_hl", nh)
		m.set_shader_parameter(&"hl_pos", hp)
		m.set_shader_parameter(&"hl_col", hc)


# ------------------------------------------------------------------ the hulls' floor bounce
## Each hull's belly takes the floor's light under it (light_hulls: five cells under its canvas).
func _bounce() -> void:
	var hulls: Dictionary = _sol.get("hulls", {})
	for st: Variant in sets:
		var s := st as YardStandSet
		if s == null or s._view == null:
			continue
		var hb: Array = hulls.get(HullData.weight_name(s.weight).to_lower(), [])
		if hb.size() < 4:
			continue
		var ww := int(hb[2])
		var cx := int(hb[0]) + ww / 2
		var y := mini(H - 1, int(hb[1]) + int(hb[3]) + 18)
		var fl := Vector3.ZERO
		for dx: int in [-ww / 3, -ww / 6, 0, ww / 6, ww / 3]:
			fl += l3_at(cx + dx, y)
		fl /= 5.0
		s._view.set_instance_shader_parameter(&"bounce", fl)
		if s.mounts != null:
			s.mounts.set_instance_shader_parameter(&"bounce", fl)


func _placed() -> void:
	for st: Variant in sets:
		var s := st as YardStandSet
		if s != null and s.mounts != null and s._view != null:
			s.mounts.set_instance_shader_parameter(&"rows", Vector2(s.thing.position.y, s.thing.end.y - 1))
	_bounce()


func _f(c: Vector2i, k: int) -> float:
	var v := _fields.get_pixel(clampi(c.x, 0, 479), clampi(c.y, 0, 269) + (k / 4) * 270)
	var ch := [v.r, v.g, v.b, v.a]
	return float(ch[k % 4]) * _fscale[k]


## The light (l3, before stepping) at a frame pixel, as the shader sums it (no walkers' shadows).
func l3_at(x: int, y: int) -> Vector3:
	if _fields == null:
		return Vector3.ZERO
	var c := Vector2i(x / 2, y / 2)
	var l3 := Vector3(_f(c, 0), _f(c, 1), _f(c, 2)) + _f(c, 29) * Vector3(1.0, 0.78, 0.5)
	for i in 6:
		var v := _f(c, 4 + i) + (0.24 + _pour_w[i]) * _f(c, 10 + i)
		l3 += v * Vector3(FIRE.r, FIRE.g, FIRE.b)
	var p := Vector2(c.x * 2.0 + 0.5, c.y * 2.0 + 0.5)
	for q in _pools:
		l3 += _pool_at(p, q) * Vector3(q[8], q[9], q[10])
	return l3


func _pool_at(p: Vector2, q: PackedFloat32Array) -> float:
	var f := 0.0
	if q[1] >= FOOT_ROW:
		var r := Vector2((p.x - q[0]) / q[2], (p.y - q[1]) / q[3]).length()
		f = clampf((1.0 - r) / q[4], 0.0, 1.0)
	else:
		var ux := clampf(absf(p.x - q[0]) / q[2], 0.0, 1.0)
		var uy := clampf(absf(p.y - q[1]) / q[3], 0.0, 1.0)
		f = pow(1.0 - ux * ux, 2.0) * pow(1.0 - uy * uy, 2.0)
	if q[5] > 0.0:
		f *= 1.0 - q[5] * clampf((p.y - (q[1] - q[3])) / (2.0 * q[3]), 0.0, 1.0)
	if q[7] > q[6] and (p.y < q[6] or p.y >= q[7]):
		f = 0.0
	return f
