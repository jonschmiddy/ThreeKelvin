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
enum Mode { ROOM, BACK, HULL, FRONT, POST, AIR, BLOOM }
const SHADERS := {Mode.AIR: preload("res://shaders/ship_room_solari_air.gdshader"),
	Mode.BLOOM: preload("res://shaders/ship_room_solari_bloom.gdshader")}

var mats: Dictionary[int, ShaderMaterial] = {}
var _fields: Image = null
var _fscale: PackedFloat32Array = PackedFloat32Array()
var _sol: Dictionary = {}
# this frame's light (set by `_light`, read by the hulls' bounce)
var _pools: Array[PackedFloat32Array] = []
var _hull_lights: Array[PackedFloat32Array] = []
var _pour_w := PackedFloat32Array([0, 0, 0, 0, 0, 0])
## this frame's door, arc, grinder and lamp weights, for the CPU's light (`l3_at`)
var _lw: Dictionary[StringName, Variant] = {}
var bed: ShipRoomSolariBed
var crew: ShipRoomSolariCrew
var fx: ShipRoomSolariFx
var _layers: Array[Layer] = []


## A layer of the room's life: it paints itself with `paint` each frame.
class Layer extends Control:
	var paint: Callable

	func _init(p: Callable, mat: Material) -> void:
		paint = p
		material = mat
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(ShipRoom.W, ShipRoom.H)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		paint.call(self)


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
		mat.shader = SHADERS.get(m, preload("res://shaders/ship_room_solari.gdshader"))
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
	bed = ShipRoomSolariBed.new(self)
	crew = ShipRoomSolariCrew.new(self)
	fx = ShipRoomSolariFx.new(self)
	_add_layer(under, func(ci: CanvasItem) -> void: bed.paint(ci, t, crew), mats[Mode.BACK])
	_add_layer(under, func(ci: CanvasItem) -> void: fx.paint(ci, t), null)
	_screen(under, Mode.AIR)
	_add_layer(under, func(ci: CanvasItem) -> void: fx.paint_dust(ci, t), null)
	_add_layer(above, func(ci: CanvasItem) -> void: crew.paint_front(ci, t, m_at), mats[Mode.FRONT])
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_layer(above, func(ci: CanvasItem) -> void: crew.paint_beam_light(ci, t), add)
	_screen(above, Mode.BLOOM)
	_light()


func _add_layer(parent: Control, p: Callable, mat: Material) -> void:
	var l := Layer.new(p, mat)
	parent.add_child(l)
	_layers.append(l)


## A full-frame pass reading what is drawn under it (a fresh copy of the screen first).
func _screen(parent: Control, m: Mode) -> void:
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	parent.add_child(bb)
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(W, H)
	r.material = mats[m]
	parent.add_child(r)


## The material a thing drawn in the room uses: BACK into the albedo, FRONT over the hulls.
func material_for(m: Mode) -> ShaderMaterial:
	return mats[m]


func _tick(dt: float) -> void:
	_light()
	_bounce()
	fx.step(t, dt)
	crew.step(t, dt)
	for l in _layers:
		l.queue_redraw()


# ------------------------------------------------------------------ this frame's light (show18.frame)
func _pool(c: Vector4, b: Vector4, col: Color, steady: float, breath: float = 1.0, no_ring: bool = false) -> void:
	if steady <= 0.001 or _pools.size() >= MAX_POOLS:
		return
	_pools.append(PackedFloat32Array([c.x, c.y, c.z, c.w, b.x, b.y, b.z, b.w,
		col.r * steady, col.g * steady, col.b * steady, steady, breath, 1.0 if no_ring else 0.0]))


func hull_light(x: float, y: float, r: float, col: Color, s: float) -> void:
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
		hull_light(C.TAPS[i], 120, 300, FIRE, 0.30 * 0.55 * k)
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
		hull_light(C.TAPS[1], 120, 560, WHITE_HEAT, op * door_b)
	var dxp := int(roundf(tl / C.LOOP * (W + 120) - 60))
	_pool(Vector4(dxp, 66, 12, 18), Vector4(0.4, 0, 0, 0), Color(0.8, 0.9, 1.0), 0.35)
	var tired := fposmod(t, 7.3)
	var cl := _crew_light()
	_lw = cl.duplicate()
	_lw[&"door_k"] = door_k
	_lw[&"door_w"] = op
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
		m.set_shader_parameter(&"beam_op", op)
		for k: StringName in cl:
			m.set_shader_parameter(k, cl[k])
	_send_lists()


## A bay's moving light: its pour's wall glow and landing, its cooling mould, its jib, its stack.
func _bay_light(j: int, u: float, pk: float, gutter: float) -> void:
	var tx := float(C.TAPS[j])
	if pk > 0.0:
		_pool(Vector4(tx, 160, 46, 34), Vector4(0.3, 0, 0, 0), FIRE, 1.15 * pk, gutter, true)
		hull_light(tx, 172, 330, FIRE, 0.75 * pk * 1.15 * pk * gutter)
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
			hull_light(tx, 175, 220, WARM, 0.35 * hs * 0.35 * hs)
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
	if crew == null:
		return {&"people": PackedVector4Array([Vector4.ZERO, Vector4.ZERO, Vector4.ZERO])}
	return crew.light_state(t, self)


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
## Each hull's belly takes the floor's light under it (light_hulls: five cells under its canvas);
## each hull's box and bounce go to the shader by its columns, as a canvas item takes no instance uniforms.
func _bounce() -> void:
	var hulls: Dictionary = _sol.get("hulls", {})
	var box := PackedVector4Array([Vector4(-1, -1, 0, 1), Vector4(-1, -1, 0, 1), Vector4(-1, -1, 0, 1)])
	var bnc := PackedVector4Array([Vector4.ZERO, Vector4.ZERO, Vector4.ZERO])
	var i := 0
	for st: Variant in sets:
		var s := st as YardStandSet
		if s == null or s._view == null or i >= 3:
			continue
		var r := s.thing
		box[i] = Vector4(r.position.x - 12, r.end.x + 12, r.position.y, r.end.y - 1)
		var hb: Array = hulls.get(HullData.weight_name(s.weight).to_lower(), [])
		if hb.size() >= 4:
			var ww := int(hb[2])
			var cx := int(hb[0]) + ww / 2
			var y := mini(H - 1, int(hb[1]) + int(hb[3]) + 18)
			var fl := Vector3.ZERO
			for dx: int in [-ww / 3, -ww / 6, 0, ww / 6, ww / 3]:
				fl += l3_at(cx + dx, y)
			fl /= 5.0
			bnc[i] = Vector4(fl.x, fl.y, fl.z, 0)
		i += 1
	var m := mats[Mode.HULL]
	m.set_shader_parameter(&"hull_box", box)
	m.set_shader_parameter(&"hull_bounce", bnc)


func _placed() -> void:
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
	var dk := int(_lw.get(&"door_k", 0))
	if dk > 0:
		l3 += _f(c, 16 + dk) * float(_lw.get(&"door_w", 0.0)) * Vector3(1.0, 0.93, 0.78)
	var ai := int(_lw.get(&"arc_i", -1))
	if ai >= 0:
		l3 += _f(c, 22 + ai) * float(_lw.get(&"arc_w", 0.0)) * Vector3(0.72, 0.85, 1.0)
	if float(_lw.get(&"grind_w", 0.0)) > 0.0:
		l3 += _f(c, 25) * 0.6 * Vector3(FIRE.r, FIRE.g, FIRE.b)
	var ti := int(_lw.get(&"tech_i", -1))
	if ti >= 0:
		l3 += _f(c, 26 + ti) * 0.5 * Vector3(1.0, 0.92, 0.75)
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


## The light multiplier m at a frame pixel on the CPU (no breath): the steam's and the spray's tint.
func m_at(x: int, y: int) -> Vector3:
	var l3 := l3_at(x, y)
	var l := maxf(l3.x, maxf(l3.y, l3.z))
	var q := floorf(l * 6.0 + 0.5) / 6.0
	var tq := minf(q, 1.0) if l >= 0.25 else l
	var ov := minf(q - 1.0, 0.35) if l >= 0.25 and q > 1.0 else 0.0
	var tr := l3 / maxf(l, 1e-6)
	var amb := Vector3(1.0, 0.84, 0.72) * 0.10
	var m := amb * (1.0 - tq) + (Vector3.ONE - 0.45 * (Vector3.ONE - tr)) * tq
	return m + ov * 0.3 * m
