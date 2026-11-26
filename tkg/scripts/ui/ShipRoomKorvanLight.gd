class_name ShipRoomKorvanLight
extends RefCounted

## The moving light Korvan's film laid on frame `f` (mix18.render's light half), as the shader's
## uniforms: point lights into the four buffers, the static fields' weights, the beacons and cones.
## Why: docs/why/ShipRoomKorvan.md#light

const F := preload("res://scripts/ui/ShipRoomKorvanFilm.gd")
const DYN := 1
const OBJ := 2
const SHIP := 4
const FLOOR := 8
const MAX_PTS := 32
const NONE := -9999.0

var pa := PackedVector4Array()
var pb := PackedVector4Array()
var pc := PackedVector3Array()
var u: Dictionary[StringName, Variant] = {}


func _point(r: float, c: Vector2i, fall: float, col: Color, w: float, bufs: int, sy: float = 1.0, side: float = NONE) -> void:
	if pa.size() >= MAX_PTS or w <= 0.0:
		return
	pa.append(Vector4(c.x, c.y, r, fall))
	pb.append(Vector4(sy, w, bufs, side))
	pc.append(Vector3(col.r, col.g, col.b))


static func _v3(c: Color, k: float) -> Vector3:
	return Vector3(c.r, c.g, c.b) * k


## Everything for film frame f (t = f / 30).
func build(f: int) -> void:
	F.ensure()
	pa.clear()
	pb.clear()
	pc.clear()
	u.clear()
	var t := float(f) / 30.0
	var K := F.K
	var fr: Dictionary = (F.D["frames"] as Array)[f]
	var tA := fposmod(t, 10.0)
	var tB := F.win(t, F.ENGINE_AT)
	var tC := F.win(t, F.DOOR_AT)
	_lamps(f, tC)
	_crane(t)
	var op := F.opening(tC)
	if op > 0.0:
		_point(110, Vector2i(560, 262), 1.2, F.SODIUM, 0.7 * op, SHIP, 0.3)
	# the arc on the lift
	var wp := F.weld_pose(tA)
	var lvl := float(fr["arcA"]) if wp.y == 1 else 0.0
	var tip := F.arc_tip(wp.x)
	# where the weld wisps' arcs are (their light near the arc)
	u[&"wisp_src0"] = Vector2(tip)
	var w8: Dictionary = (K["weld8"] as Array)[0]
	u[&"wisp_src1"] = Vector2(float(w8["tip"][0]), float(w8["tip"][1]))
	u[&"k_arc_floor"] = _v3(F.ARC, 2.0 * lvl)
	if lvl > 0.0:
		_point(120, tip + Vector2i(1, -1), 1.05, F.ARC, 2.3 * lvl, OBJ, 1.0, float(K["tip_x"]))
		_point(100, tip + Vector2i(0, -1), 1.2, F.ARC, 2.8 * lvl, SHIP, 0.28)
	var wl := Vector2i(int(K["wlx"]), int(K["wly"]))
	_point(44, wl, 1.3, F.WORK, 1.1, OBJ)
	_point(60, wl + Vector2i(-6, -30), 1.2, F.WORK, 1.3, SHIP, 0.3)
	# the lamp tech's beam on the medium's belly, and his lamp
	var spot := F.lamp_spot(t)
	var und_m: Array = K["under_m"]
	var lens := F.lens_at(spot)
	_point(20, Vector2i(spot, int(und_m[spot]) - 2), 0.9, Color(1.0, 0.84, 0.58), 3.6, SHIP, 0.5)
	_point(16, lens, 1.6, Color(1.0, 0.86, 0.62), 0.8, DYN)
	var dr := F.drone_at(t)
	u[&"survey"] = Vector2(F.pyround(dr.x), 1.25 if dr.y > 0.5 else 0.8)
	_engine(fr, tB)
	_point(70, Vector2i(F.FL_X, 296), 1.2, F.WORK, 1.7, SHIP, 0.32)
	_point(48, Vector2i(F.FL_X, 340), 1.3, F.WORK, 1.0, OBJ)
	_ladders(fr, t)
	_crew(t, fr)
	# the door's slab of light and its light on what stands under it
	u[&"slab_lv"] = mini(5, int(op * 6.0 - 1e-6)) if op > 0.0 else 0
	u[&"k_slab"] = _v3(F.SODIUM, 1.7 * op)
	u[&"k_door_obj"] = _v3(F.SODIUM, 1.2 * op)
	u[&"side_x"] = Vector4(float(K["tip_x"]), F.PX, NONE, NONE)
	u[&"n_pts"] = pa.size()
	while pa.size() < MAX_PTS:
		pa.append(Vector4(NONE, NONE, 0, 1))
		pb.append(Vector4.ZERO)
		pc.append(Vector3.ZERO)
	u[&"pa"] = pa
	u[&"pb"] = pb
	u[&"pc"] = pc


func _lamps(f: int, tC: float) -> void:
	var row: Array = (F.D["lamps"] as Array)[f]
	var tw := PackedFloat32Array()
	var sum := 0.0
	var spans := _relight_spans()
	for i in row.size():
		var v := float(row[i])
		# CATCH: in the relight each lamp holds a value 3 or 4 frames, so it stutters on 8-10 times a second
		var sp: Vector2i = spans[i]
		if f >= sp.x and f < sp.y:
			var k := 3 + i % 2
			v = float(((F.D["lamps"] as Array)[sp.x + floori(float(f - sp.x) / k) * k] as Array)[i])
		tw.append(v / 10000.0)
		sum += v / 10000.0
	u[&"tw"] = tw
	u[&"lk"] = sum / float(row.size())
	var t := float(f) / 30.0
	var mv := F.moving(tC) and tC > 0.0
	var blink := mv and int(t * 4.0) % 2 == 0
	u[&"door_lamp"] = 2.2 if blink else (0.25 if mv else 1.0)


## The lamps' relight after the engine test (film frames 506-548): per lamp, the first frame it takes
## one of the relight's values to the frame it holds full.
## Why: docs/why/ShipRoomKorvan.md#relight
const RELIT := [3000, 4500, 5500, 6500, 9000, 10000]
static var _spans: Array[Vector2i] = []


static func _relight_spans() -> Array[Vector2i]:
	if _spans.is_empty():
		var L: Array = F.D["lamps"]
		for i in (L[0] as Array).size():
			var s := -1
			var e := -1
			for f in range(506, 549):
				var v := int((L[f] as Array)[i])
				if s < 0 and v in RELIT:
					s = f
				if s >= 0 and v != 10000:
					e = f + 1
			_spans.append(Vector2i(s, maxi(e, s + 1)) if s >= 0 else Vector2i(-1, -1))
	return _spans


func _crane(t: float) -> void:
	var cr := F.crane(t)
	u[&"crane"] = Vector4(cr.lx + 6, cr.lx + cr.lw + 6, cr.ly + cr.lh, 0)
	var d := F.drones(t)
	u[&"drone_load"] = Vector2(d.xc, d.lw / 2.0) if d != null else Vector2(NONE, 0)
	# the beacons sweep spots along the top deck and the wall behind the load
	var spots := [[cr.x - 14, 22, 14], [cr.x + 14, 22, 14], [cr.lx + cr.lw / 2, cr.ly + 30, 20]]
	for i in 3:
		var th := TAU * (1.3 * t + i * 0.5)
		var c := cos(th)
		var v := Vector3.ZERO
		if c > 0.1:
			var s: Array = spots[i]
			v = Vector3(F.pyround(float(s[0]) + (60.0 if i < 2 else 110.0) * sin(th)), float(s[1]), c)
		u[StringName("cb%d" % i)] = v
	if d != null:
		for p: Vector2i in d.d:
			if p.x >= 0 and p.x < 960:
				_point(22, p + Vector2i(0, 20), 1.2, Color(1.0, 0.95, 0.85), 0.9, DYN | OBJ)


func _engine(fr: Dictionary, tB: float) -> void:
	var b := F.burn(tB)
	var hh := F.heat(tB)
	var fl := float(fr["burn_fl"]) * b
	u[&"k_burn_wf"] = _v3(F.FIRE, 1.7 * fl) if b > 0.0 else Vector3.ZERO
	u[&"k_burn_obj"] = _v3(F.FIRE, 1.6 * fl) if b > 0.0 else Vector3.ZERO
	u[&"k_burn_ship"] = _v3(F.FIRE, 1.2 * fl) if b > 0.0 else Vector3.ZERO
	_point(26, Vector2i(F.PX, F.PY), 1.5, Color(1.0, 0.35, 0.12), 0.9 * hh, DYN)
	var on := F.beacon_on(tB) and tB > 0.0
	for i in 2:
		var v := Vector3.ZERO
		if on:
			var bc: Vector2i = F.BEACONS[i]
			var th := TAU * (1.25 * tB + i * 0.37)
			var c := cos(th)
			if c > 0.05:
				v = Vector3(F.pyround(bc.x + 70.0 * sin(th)), bc.y + 18, c)
		u[StringName("beacon%d" % i)] = v


func _ladders(fr: Dictionary, t: float) -> void:
	var w8: Array = F.K["weld8"]
	u[&"k_wfloor0"] = Vector3.ZERO
	u[&"k_wfloor1"] = Vector3.ZERO
	for i in w8.size():
		var sp: Dictionary = w8[i]
		var st := F.weld_state(sp, t)
		var lvl := float((fr["arc8"] as Array)[i]) if st.y > 0.5 else 0.0
		if lvl <= 0.0:
			continue
		var tip := Vector2i(int(sp["tip"][0]), int(sp["tip"][1]))
		if sp["kind"] == "grind":
			var gfl := float(fr["gfl"])
			var warm := Color(1.0, 0.62, 0.28)
			_point(60, tip + Vector2i(-2, 0), 1.15, warm, 1.5 * gfl, OBJ, 1.0, tip.x)
			_point(60, tip, 1.2, warm, 1.6 * gfl, SHIP, 0.45)
			u[&"k_wfloor1"] = _v3(warm, 0.9 * gfl)
		else:
			_point(90, tip + Vector2i(-1, 0), 1.05, F.ARC, 2.1 * lvl, OBJ, 1.0, tip.x)
			_point(90, tip, 1.2, F.ARC, 2.6 * lvl, SHIP, 0.45)
			u[&"k_wfloor0"] = _v3(F.ARC, 1.4 * lvl)


func _crew(t: float, fr: Dictionary) -> void:
	var desk: Array = F.K["lamp_desk"]
	_point(16, Vector2i(int(desk[0]), int(desk[1]) + 2), 1.3, Color(1.0, 0.86, 0.62), 1.2, DYN)
	_point(12, Vector2i(843, 183), 1.3, Color(0.55, 1.0, 0.7), 0.9, DYN)
	_point(16, Vector2i(905, 158), 1.2, F.WORK, 1.0, DYN)
	_point(34, Vector2i(893, 100), 1.2, Color(1.0, 0.8, 0.45), 1.5, DYN, 0.8)
	var fx := F.fork_x(t)
	if not is_nan(fx) and int(t / 0.2) % 2 == 0:
		var bxx := int(fx) + int(F.K["fork_beacon"][0])
		var amber := Color(1.0, 0.66, 0.22)
		_point(56, Vector2i(bxx, F.FORK_LANE - 2), 1.2, amber, 1.3, DYN, 0.3)
		_point(34, Vector2i(bxx, F.FORK_LANE - 60), 1.4, amber, 0.9, OBJ, 1.0, bxx)
	# the back room's holo-table spills cyan on the wall and the heavy's top
	var w := 0.75 + 0.1 * float(fr["holo_fl"])
	var cyan := Color(0.45, 0.85, 1.0)
	_point(40, Vector2i(436, 176), 1.4, cyan, 0.75 * w, DYN)
	_point(46, Vector2i(436, 196), 1.3, cyan, 0.7 * w, SHIP, 0.5)
	if F.in_any(t, F.GRIND):
		var gk := float(fr["gk"])
		var g := Vector2i(int(F.K["g_ox"]), int(F.K["g_oy"]))
		var hot := Color(1.0, 0.7, 0.35)
		_point(34, g + Vector2i(-6, 4), 1.3, hot, 1.5 * gk, OBJ)
		_point(40, Vector2i(g.x - 12, int(F.K["bfeet"]) - 2), 1.2, hot, 1.3 * gk, DYN, 0.35)
