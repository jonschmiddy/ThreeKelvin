class_name GameTorch
extends MiniGame

## CUTTING TORCH (Jon loved, Nov 17; the torch starts on the loop, so every tap is a cut): cut a
## loop round a cargo crate in a wreck's hull without slicing the live lines. A port of the
## approved `wreck1.js` in its approved layout and UI kit (Nov 20); the rules are `TorchSim`. Its
## canvas is 152 wide, a column off each side; the kit's header and deck are drawn 1 px in.
## Why: docs/why/MiniGame.md#the-round-2-games

const PW := 152
const PH := 100
const HUD := 30
const MSG := {zap = "ZAP! LIVE LINE", fuel = "FUEL LINE!", burn = "CRATE BURNT", piece = "EMPTY PIECE", free = "CUT FREE", gas = "OUT OF GAS", fire = "TORCH OUT"}
## The kit's HITS meter width, right-aligned on the control row; GAS takes the rest.
const HITS_W := 25
const METAL: Array[Color] = [Color("#080b11"), Color("#111823"), Color("#182230"), Color("#22303f"), Color("#2d3c4e"), Color("#3d4d61"), Color("#6b7d94"), Color("#8fa3ba")]
const CABLE: Array[Color] = [Color("#1c1609"), Color("#3e3016"), Color("#6e5626"), MiniPix.WARN, Color("#e0bd6a")]
const PIPE: Array[Color] = [Color("#2a0f0b"), Color("#4a1c16"), Color("#7a2f24"), MiniPix.BAD, Color("#e07a62")]
const CRATE: Array[Color] = [Color("#080b11"), Color("#26333f"), Color("#3a4a5c"), MiniPix.COLD, MiniPix.CHILL, MiniPix.ICE]
const HEAT: Array[Color] = [Color("#2a160b"), Color("#5a2e10"), MiniPix.EMBER, MiniPix.FLARE, MiniPix.HOT, Color("#fff4dc")]
const SMOKE: Array[Color] = [Color("#1a222c"), Color("#2d3c4e"), MiniPix.COLD, MiniPix.CHILL]
const HOSE: Array[Color] = [Color("#2f4a3c"), Color("#4f7a62"), MiniPix.GOOD]
const BRASS := Color("#e0bd6a")
const KNOB_DK := Color("#7a2f24")
const BURN_RED := Color("#5a2018")
const WHITE_HOT := Color("#fff4dc")
const N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const N8: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]

var P: Dictionary = {}
var S: Dictionary = {}
var path: Array[Vector2] = []
var held := false
var drag := false
var down_at := Vector2.ZERO
var done_fired := false
var end_t := 0.0
var status := ""
var status_col := MiniPix.CHILL
var status_t := 0.0
var shake_t := 0.0
var torch_a := NAN
var fx: Array = []
var corner := Vector2.ZERO
var torn_r: Array[float] = []
var stars: Array = []
var lr: Array = []
var debris: Array = []
var cut := PackedFloat32Array()
var cut_list: Array[int] = []
var _plate: Image
var _faint: Image
var _finish_at := -1.0
## The kit's 150-wide layer, laid 1 px in.
var _kit_px: MiniPix
var _acc := 0.0


func id() -> StringName:
	return &"torch"


func hint() -> String:
	return "Cut out the crate."


func controls() -> Array[String]:
	return ["click"]


func _mount() -> void:
	px = MiniPix.new(PW, PH + HUD)
	P = TorchSim.gen(depth, sensors, rng)
	if P.is_empty():
		push_error("GameTorch: no puzzle at depth %d" % depth)
		done_fired = true
		done(0.0, "No puzzle")
		return
	S = TorchSim.new_sim()
	var lp: Array = P.loop
	TorchSim.pierce(S, P, lp[0].x, lp[0].y)
	cut.resize(PW * PH)
	cut.fill(-1.0)
	_static_layer()
	for i in 7:
		debris.append({x = rng.randf() * PW, y = rng.randf() * PH, vx = (rng.randf() - 0.5) * 3.0, vy = (rng.randf() - 0.5) * 2.0,
			sz = 1 + int(rng.randf() * 2), c = METAL[6] if rng.randf() < 0.5 else METAL[5], ph = rng.randf() * 6.0})
	_draw()


func _flame_on() -> bool:
	return S.torch != null and not S.over and not path.is_empty() and (path[0] - (S.torch as Vector2)).length() > 0.6


# ---------------------------------------------------------------- the static plate

func torn(x: float, y: float) -> bool:
	var dx := x - corner.x
	var dy := y - corner.y
	var d := sqrt(dx * dx + dy * dy)
	var a := atan2(absf(dy), absf(dx)) / (PI / 2.0) * 24.0
	var i := int(floorf(a))
	var f := a - i
	var lim := torn_r[i] * (1.0 - f) + torn_r[mini(24, i + 1)] * f
	return d < lim


## The torn hull plate, its rivets and rim, the crate and its straps, the lines' bodies.
func _static_layer() -> void:
	var r: Rect2 = P.R
	var ccx := (r.position.x + r.end.x) / 4.0
	var ccy := (r.position.y + r.end.y) / 4.0
	var best := Vector2.ZERO
	for c: Vector2 in [Vector2(0, 0), Vector2(PW, 0), Vector2(0, PH), Vector2(PW, PH)]:
		if Vector2(c.x - ccx, c.y - ccy).length() > Vector2(best.x - ccx, best.y - ccy).length():
			best = c
	corner = best
	for i in 25:
		torn_r.append(16.0 + rng.randf() * 14.0 + (rng.randf() * 8.0 if i % 3 == 0 else 0.0))
	for i in 60:
		stars.append(Vector3(int(floorf(rng.randf() * PW)), int(floorf(rng.randf() * PH)), rng.randf()))
	var plates: Array = []
	var row := 0
	while row * 25 < PH:
		var off := 19 if row % 2 else 0
		var x := -off
		while x < PW:
			plates.append(Rect2i(x, row * 25, 38, 25))
			x += 38
		row += 1
	var tones: Array[int] = []
	for i in plates.size():
		tones.append(int(floorf(rng.randf() * 3)))
	var s := MiniPix.new(PW, PH)
	_plates(s, plates, tones)
	_crate(s, r)
	lr.clear()
	for l: Dictionary in P.lines:
		lr.append({l = l, map = _raster(l)})
	var f := MiniPix.new(PW, PH)
	f.clear(Color(0, 0, 0, 0))
	for o: Dictionary in lr:
		if o.l.faint and sensors < 4:
			_paint_line(f, o, 1.0)
			_paint_line(s, o, 0.22)
		else:
			_paint_line(s, o, 1.0)
	_plate = s.img
	_faint = f.img


func _plates(s: MiniPix, plates: Array, tones: Array[int]) -> void:
	for y in PH:
		for x in PW:
			if torn(x, y):
				s.dot(x, y, MiniPix.VOID)
				continue
			var k := 0
			while not (plates[k] as Rect2i).has_point(Vector2i(x, y)):
				k += 1
			var pl: Rect2i = plates[k]
			var lx := x - pl.position.x
			var ly := y - pl.position.y
			var c := 2 + (1 if tones[k] == 2 else 0)
			var sh := (float(lx) / pl.size.x + float(ly) / pl.size.y) / 2.0
			if MiniPix.bay(x, y) < 0.35 - sh * 0.5:
				c += 1
			if MiniPix.bay(x + 1, y + 2) < sh * 0.35:
				c -= 1
			var nz := sin(x * 0.37 + y * 0.11) * sin(x * 0.13 - y * 0.29) + sin(x * 0.05 + y * 0.21)
			if nz > 1.05 and MiniPix.bay(x, y) < 0.5:
				c -= 1
			if lx == 0 or ly == 0:
				c = 5
			if lx == pl.size.x - 1 or ly == pl.size.y - 1:
				c = 0
			s.dot(x, y, METAL[clampi(c, 0, 7)])
	for pl: Rect2i in plates:
		for o: Vector2i in [Vector2i(3, 3), Vector2i(pl.size.x - 4, 3), Vector2i(3, pl.size.y - 4), Vector2i(pl.size.x - 4, pl.size.y - 4), Vector2i(pl.size.x / 2, 3)]:
			var x := pl.position.x + o.x
			var y := pl.position.y + o.y
			if x < 0 or x >= PW - 1 or y >= PH - 1 or torn(x, y):
				continue
			s.dot(x, y, METAL[6])
			s.dot(x + 1, y + 1, METAL[0])
			s.dot(x + 1, y, METAL[4])
	s.text("HOLD 3", 3 if corner.x else PW - 26, 3 if corner.y else PH - 8, METAL[3])
	for y in PH:
		for x in PW:
			if torn(x, y):
				continue
			var edge := false
			var below := false
			for d in N4:
				var nx := x + d.x
				var ny := y + d.y
				if nx >= 0 and ny >= 0 and nx < PW and ny < PH and torn(nx, ny):
					edge = true
					if d.x + d.y > 0:
						below = true
			if edge:
				s.dot(x, y, METAL[7] if below else METAL[6])
	for y in PH:
		for x in PW:
			if not torn(x, y):
				continue
			for d in N4:
				var nx := x + d.x
				var ny := y + d.y
				if nx >= 0 and ny >= 0 and nx < PW and ny < PH and not torn(nx, ny):
					s.dot(x, y, METAL[0])
					break


func _crate(s: MiniPix, r: Rect2) -> void:
	var cx0 := MiniPix.jr(r.position.x / 2.0)
	var cy0 := MiniPix.jr(r.position.y / 2.0)
	var cx1 := MiniPix.jr(r.end.x / 2.0) - 1
	var cy1 := MiniPix.jr(r.end.y / 2.0) - 1
	for y in range(cy0 + 2, cy1 + 4):
		for x in range(cx0 + 2, cx1 + 4):
			if (x > cx1 or y > cy1) and MiniPix.bay(x, y) < 0.6:
				s.dot(x, y, METAL[0])
	for y in range(cy0, cy1 + 1):
		for x in range(cx0, cx1 + 1):
			var c := 2
			var lx := float(x - cx0) / (cx1 - cx0)
			var ly := float(y - cy0) / (cy1 - cy0)
			if MiniPix.bay(x, y) < 0.45 - (lx + ly) * 0.3:
				c = 3
			if x == cx0 or y == cy0 or x == cx1 or y == cy1:
				c = 0
			elif x == cx0 + 1 or y == cy0 + 1:
				c = 4
			elif x == cx1 - 1 or y == cy1 - 1:
				c = 1
			s.dot(x, y, CRATE[c])
	for f0: float in [0.28, 0.72]:
		var x := MiniPix.jr(cx0 + (cx1 - cx0) * f0)
		for y in range(cy0 + 1, cy1):
			s.dot(x, y, CRATE[1])
			s.dot(x + 1, y, CRATE[4])
	for c: Vector4i in [Vector4i(cx0 + 2, cy0 + 2, 1, 1), Vector4i(cx1 - 2, cy0 + 2, -1, 1), Vector4i(cx0 + 2, cy1 - 2, 1, -1), Vector4i(cx1 - 2, cy1 - 2, -1, -1)]:
		s.dot(c.x, c.y, MiniPix.TRACTOR)
		s.dot(c.x + c.z, c.y, MiniPix.TRACTOR)
		s.dot(c.x, c.y + c.w, MiniPix.TRACTOR)
	s.text("SAMPLE", MiniPix.jr((cx0 + cx1) / 2.0), MiniPix.jr((cy0 + cy1) / 2.0) - 2, MiniPix.MARK, "center")


## A thick polyline stamped into pixels: each keeps the nearest sample, its side and how far along.
## Each pixel's [distance, side, along] in doubles, as the prototype keeps them.
func _raster(l: Dictionary) -> Dictionary[int, PackedFloat64Array]:
	var r := float(l.half) / 2.0
	var map: Dictionary[int, PackedFloat64Array] = {}
	var pts: Array = l.pts
	for i in pts.size() - 1:
		var ax: float = pts[i].x
		var ay: float = pts[i].y
		var bx: float = pts[i + 1].x
		var by: float = pts[i + 1].y
		var ln := sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
		var nn := maxi(1, ceili(ln))
		var tx := (bx - ax) / (ln if ln else 1.0)
		var ty := (by - ay) / (ln if ln else 1.0)
		for k in nn + 1:
			var x := (ax + (bx - ax) * k / nn) / 2.0
			var y := (ay + (by - ay) * k / nn) / 2.0
			for py in range(int(floorf(y - r - 1.0)), int(ceilf(y + r + 1.0)) + 1):
				for pxx in range(int(floorf(x - r - 1.0)), int(ceilf(x + r + 1.0)) + 1):
					if pxx < 0 or py < 0 or pxx >= PW or py >= PH:
						continue
					var dx := pxx + 0.5 - x
					var dy := py + 0.5 - y
					var d := sqrt(dx * dx + dy * dy)
					if d > r + 0.35:
						continue
					var key := py * PW + pxx
					if not map.has(key) or d < map[key][0]:
						var nx := -ty
						var ny := tx
						if nx * -0.7 + ny * -0.7 < 0.0:
							nx = -nx
							ny = -ny
						map[key] = PackedFloat64Array([d, (dx * nx + dy * ny) / maxf(0.5, r), i + float(k) / nn])
	return map


func _paint_line(c: MiniPix, o: Dictionary, faint_a: float) -> void:
	var l: Dictionary = o.l
	var map: Dictionary = o.map
	var ramp: Array[Color] = CABLE if l.kind == "power" else PIPE
	var outl := {}
	var order: Array[int] = []
	for k: int in map:
		var x := k % PW
		var y := k / PW
		for d in N4:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= PW or ny >= PH:
				continue
			var nk := ny * PW + nx
			if not map.has(nk) and not outl.has(nk):
				outl[nk] = true
				order.append(nk)
	for k in order:
		var x := k % PW
		var y := k / PW
		if faint_a < 1.0 and MiniPix.bay(x, y) > faint_a:
			continue
		c.dot(x, y, ramp[0])
	for k: int in map:
		var x := k % PW
		var y := k / PW
		if faint_a < 1.0 and MiniPix.bay(x, y) > faint_a:
			continue
		var v: PackedFloat64Array = map[k]
		var i := 2
		if v[1] > 0.45:
			i = 3
		if v[1] > 0.9:
			i = 4
		if v[1] < -0.45:
			i = 1
		if l.kind == "fuel" and int(floorf(v[2] * 0.9)) % 3 == 0 and absf(v[1]) < 0.6:
			i = maxi(1, i - 1)
		c.dot(x, y, ramp[i])
	if l.get("feed", false):
		var pts: Array = l.pts
		var p: Vector2 = pts[pts.size() - 1]
		var x := MiniPix.jr(p.x / 2.0)
		var y := MiniPix.jr(p.y / 2.0)
		for j in range(-2, 2):
			for i in range(-2, 2):
				c.dot(x + i, y + j, METAL[6] if i == -2 or j == -2 else (METAL[0] if i == 1 or j == 1 else METAL[5]))


# ---------------------------------------------------------------- the picture

func _in_poly_px(poly: Array, x: int, y: int) -> bool:
	return TorchSim.in_poly(poly, x * 2 + 1, y * 2 + 1)


func _put(x: int, y: int, c: Color) -> void:
	px.dot(x, y, c)


func _draw() -> void:
	var t_: float = S.t
	px.img.blit_rect(_plate, Rect2i(0, 0, PW, PH), Vector2i.ZERO)
	for sr: Vector3 in stars:
		if not torn(sr.x, sr.y):
			continue
		_put(int(sr.x), int(sr.y), MiniPix.ICE if sr.z > 0.8 else (METAL[6] if sr.z > 0.5 else METAL[4]))
	var holes: Array = (S.pieces as Array).map(func(pc: Dictionary) -> Array: return pc.poly)
	if S.freed and not (S.poly as Array).is_empty():
		holes.append(S.poly)
	for poly: Array in holes:
		var bb := _bounds(poly)
		for y in range(int(floorf(bb.position.y / 2.0)), int(ceilf(bb.end.y / 2.0)) + 1):
			for x in range(int(floorf(bb.position.x / 2.0)), int(ceilf(bb.end.x / 2.0)) + 1):
				if x < 0 or y < 0 or x >= PW or y >= PH:
					continue
				if _in_poly_px(poly, x, y):
					_put(x, y, METAL[5] if (x * 7 + y * 13) % 23 == 0 else MiniPix.VOID)
	_faint_near()
	_current(t_)
	_dashed_loop()
	_chevrons(t_)
	_kerf(t_)
	for f: Dictionary in fx:
		if f.k == "burn":
			for j in range(-2, 3):
				for i in range(-2, 3):
					var d := i * i + j * j
					if d > 5:
						continue
					var x := MiniPix.jr(f.x) + i
					var y := MiniPix.jr(f.y) + j
					if d <= 2 or MiniPix.bay(x, y) < 0.5:
						_put(x, y, MiniPix.VOID if d <= 1 else METAL[0])
	if S.freed and not (S.poly as Array).is_empty():
		_freed_piece(t_)
	for d: Dictionary in debris:
		var x := int(floorf(d.x))
		var y := int(floorf(d.y))
		_put(x, y, METAL[7] if sin(t_ * 2.0 + float(d.ph)) > 0.3 else d.c)
		if int(d.sz) > 1:
			_put(x + 1, y, METAL[3])
			_put(x, y + 1, METAL[2])
	_effects()
	_plan()
	if not S.freed and not (S.over and t_ - end_t > 0.8):
		_draw_torch(t_)
	for y in PH:
		for x in PW:
			var dx := maxf(0.0, absf(x - PW / 2.0) - PW * 0.38) / (PW * 0.12)
			var dy := maxf(0.0, absf(y - PH / 2.0) - PH * 0.36) / (PH * 0.14)
			var v := sqrt(dx * dx + dy * dy)
			if v > 0.0 and MiniPix.bay(x, y) < v * 0.45:
				_put(x, y, MiniPix.BEVEL_LO)
	for c: Vector4i in [Vector4i(1, 11, 1, 1), Vector4i(PW - 2, 11, -1, 1), Vector4i(1, 96, 1, -1), Vector4i(PW - 2, 96, -1, -1)]:
		for i in 5:
			_put(c.x + c.z * i, c.y, METAL[6])
			_put(c.x, c.y + c.w * i, METAL[6])
	_hud(t_)
	dirty = true


static func _bounds(poly: Array) -> Rect2:
	var x0 := 1e9
	var y0 := 1e9
	var x1 := -1.0
	var y1 := -1.0
	for p: Vector2 in poly:
		x0 = minf(x0, p.x)
		y0 = minf(y0, p.y)
		x1 = maxf(x1, p.x)
		y1 = maxf(y1, p.y)
	return Rect2(x0, y0, x1 - x0, y1 - y0)


## Faint lines show near the torch (below 4 sensors): the faint layer through a disc round it.
func _faint_near() -> void:
	if sensors >= 4 or S.torch == null:
		return
	var tp: Vector2 = S.torch
	var tx := int(floorf(tp.x / 2.0))
	var ty := int(floorf(tp.y / 2.0))
	var rad := 26
	for y in range(-rad, rad + 1):
		var w := int(floorf(sqrt(rad * rad - y * y)))
		var yy := ty + y
		if yy < 0 or yy >= PH:
			continue
		for x in range(tx - w, tx + w + 1):
			if x < 0 or x >= PW:
				continue
			var c := _faint.get_pixel(x, yy)
			if c.a > 0.0:
				px.img.set_pixel(x, yy, c)


func _near(l: Dictionary, r: float) -> bool:
	if S.torch == null:
		return false
	var tp: Vector2 = S.torch
	for p: Vector2 in l.pts:
		if (p - tp).length() < r * 2.0:
			return true
	return false


## Live current running along the power lines.
func _current(t_: float) -> void:
	for o: Dictionary in lr:
		var l: Dictionary = o.l
		if l.kind != "power" or (l.faint and sensors < 4 and not (S.torch != null and _near(l, 40.0))):
			continue
		if not TorchSim.live(l, t_):
			continue
		for k: int in o.map:
			var v: PackedFloat64Array = o.map[k]
			if absf(v[1]) > 0.5:
				continue
			var ph := fmod(v[2] * 1.6 - t_ * 9.0, 6.0)
			if (ph > -1.2) if ph < 0.0 else (ph < 1.2):
				_put(k % PW, k / PW, MiniPix.HOT if fmod(ph + 6.0, 6.0) < 0.6 else MiniPix.FLARE)


## The planned cut: a dashed loop round the crate; where it has been cut the kerf replaces it.
func _dashed_loop() -> void:
	if S.freed:
		return
	var lp: Array = P.loop
	for i in lp.size():
		if (i >> 1) % 2:
			continue
		var q: Vector2 = lp[i]
		var x := MiniPix.jr(q.x / 2.0)
		var y := MiniPix.jr(q.y / 2.0)
		if x < 0 or y < 0 or x >= PW or y >= PH:
			continue
		var skip := false
		for j in range(-2, 3):
			for k in range(-2, 3):
				var nx := x + k
				var ny := y + j
				if nx >= 0 and ny >= 0 and nx < PW and ny < PH and cut[ny * PW + nx] >= 0.0:
					skip = true
		if skip:
			continue
		_put(x + 1, y + 1, METAL[0])
		_put(x, y, MiniPix.MARK)


## Until the first point is set, chevrons march along the loop from the torch, the way to go.
func _chevrons(t_: float) -> void:
	if S.over or (S.pts as Array).size() > 1 or not path.is_empty():
		return
	var lp: Array = P.loop
	var nn := lp.size()
	for c in 3:
		var i := (4 + c * 5 + int(floorf(t_ * 10.0)) % 5) % nn
		var a: Vector2 = lp[(i + nn - 1) % nn]
		var b: Vector2 = lp[(i + 1) % nn]
		var q: Vector2 = lp[i]
		var dx := float(b.x) - a.x
		var dy := float(b.y) - a.y
		var dl := sqrt(dx * dx + dy * dy)
		if dl == 0.0:
			dl = 1.0
		dx /= dl
		dy /= dl
		var qx := q.x / 2.0
		var qy := q.y / 2.0
		for w in 3:
			_put(MiniPix.jr(qx + dx * (1.5 - w) + dy * w), MiniPix.jr(qy + dy * (1.5 - w) - dx * w), MiniPix.HOT)
			_put(MiniPix.jr(qx + dx * (1.5 - w) - dy * w), MiniPix.jr(qy + dy * (1.5 - w) + dx * w), MiniPix.HOT)


## The kerf: a black slit with molten edges cooling hot, ember, dark.
func _kerf(t_: float) -> void:
	for k in cut_list:
		var x := k % PW
		var y := k / PW
		var age := t_ - cut[k]
		for d in N8:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= PW or ny >= PH:
				continue
			if cut[ny * PW + nx] >= 0.0:
				continue
			var diag := d.x != 0 and d.y != 0
			var c: Color
			if age < 0.4:
				c = HEAT[3] if diag else HEAT[4]
			elif age < 0.9:
				c = HEAT[2] if diag else HEAT[3]
			elif age < 1.6:
				c = HEAT[1] if diag else HEAT[2]
			elif age < 2.4:
				c = HEAT[1] if MiniPix.bay(nx, ny) < 0.5 else HEAT[0]
			else:
				c = HEAT[0]
			if diag and age >= 1.6:
				continue
			_put(nx, ny, c)
	for k in cut_list:
		_put(k % PW, k / PW, HEAT[5] if t_ - cut[k] < 0.3 else MiniPix.VOID)


## The freed piece floats out toward the ship (by whole pixels), a hot rim cooling on it.
func _freed_piece(t_: float) -> void:
	var k := clampf((t_ - end_t) / 1.4, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var ox := MiniPix.jr(e * 10.0)
	var oy := MiniPix.jr(-e * 14.0)
	var poly: Array = S.poly
	var bb := _bounds(poly)
	for y in range(int(floorf(bb.position.y / 2.0)), int(ceilf(bb.end.y / 2.0)) + 1):
		for x in range(int(floorf(bb.position.x / 2.0)), int(ceilf(bb.end.x / 2.0)) + 1):
			if not _in_poly_px(poly, x, y):
				continue
			var c := _plate.get_pixel(x, y) if x >= 0 and y >= 0 and x < PW and y < PH else Color(0, 0, 0, 0)
			_put(x + ox, y + oy, Color(c.r, c.g, c.b, 1.0))
	if k < 1.0:
		for p: Vector2 in poly:
			if MiniPix.bay(MiniPix.jr(p.x / 2.0), MiniPix.jr(p.y / 2.0)) < 1.0 - k:
				_put(MiniPix.jr(p.x / 2.0) + ox, MiniPix.jr(p.y / 2.0) + oy, MiniPix.FLARE if k < 0.5 else MiniPix.EMBER)
	if k >= 1.0 and _finish_at < 0.0:
		_finish_at = t + 0.3


func _effects() -> void:
	for f: Dictionary in fx:
		var k := float(f.age) / float(f.life)
		match String(f.k):
			"spark":
				var x := MiniPix.jr(f.x)
				var y := MiniPix.jr(f.y)
				if x >= 0 and y >= 0 and x < PW and y < PH:
					_put(x, y, f.c if k < 0.5 else MiniPix.EMBER)
					if k < 0.3:
						_put(MiniPix.jr(float(f.x) - float(f.vx) * 0.03), MiniPix.jr(float(f.y) - float(f.vy) * 0.03), MiniPix.EMBER)
			"arc":
				if int(floorf(float(f.age) * 20.0)) % 2 == 0:
					for j in 4:
						var x: float = f.x
						var y: float = f.y
						var a := (j / 4.0) * 6.283 + float(f.age) * 3.0
						for st in 7:
							x += cos(a) * 1.6 + (randf() - 0.5) * 2.4
							y += sin(a) * 1.6 + (randf() - 0.5) * 2.4
							_put(MiniPix.jr(x), MiniPix.jr(y), MiniPix.ICE if st < 2 else MiniPix.TRACTOR)
			"puff":
				_puff(f, k)
			"flash":
				var r := 2.0 + 7.0 * k
				for a in 24:
					var x := MiniPix.jr(float(f.x) + cos(a / 24.0 * 6.283) * r)
					var y := MiniPix.jr(float(f.y) + sin(a / 24.0 * 6.283) * r)
					if x >= 0 and y >= 0 and x < PW and y < PH and MiniPix.bay(x, y) < 1.0 - k:
						_put(x, y, WHITE_HOT if k < 0.4 else MiniPix.BAD)
				if k < 0.3:
					for j in range(-1, 2):
						for i in range(-1, 2):
							_put(MiniPix.jr(f.x) + i, MiniPix.jr(f.y) + j, WHITE_HOT)
			"piece":
				if int(floorf(float(f.age) * 6.0)) % 2 == 0:
					for p: Vector2 in f.poly:
						_put(MiniPix.jr(p.x / 2.0), MiniPix.jr(p.y / 2.0), MiniPix.WARN)


func _puff(f: Dictionary, k: float) -> void:
	var r := 2.0 + 9.0 * k
	var cy := float(f.y) - 4.0 * k
	for j in range(-ceili(r), int(r) + 1):
		for i in range(-ceili(r), int(r) + 1):
			var d := sqrt(i * i + j * j) / r
			if d > 1.0:
				continue
			var x := MiniPix.jr(float(f.x) + i)
			var y := MiniPix.jr(cy + j)
			if MiniPix.bay(x, y) > (1.0 - d) * (1.0 - k) * 1.6:
				continue
			var c: Color
			if k < 0.25 and d < 0.5:
				c = MiniPix.HOT if d < 0.25 else MiniPix.FLARE
			elif k < 0.45 and d < 0.6:
				c = MiniPix.EMBER
			else:
				c = SMOKE[mini(3, int(floorf((1.0 - d) * 3.0)))]
			_put(x, y, c)


## The planned cut: a dotted line from the torch through each clicked point, each a pin.
func _plan() -> void:
	if S.torch == null or S.over or path.is_empty():
		return
	var tp: Vector2 = S.torch
	var ax := tp.x / 2.0
	var ay := tp.y / 2.0
	var nn := 0
	for qi in path.size():
		var bx := path[qi].x / 2.0
		var by := path[qi].y / 2.0
		var ln := sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
		var m := maxi(1, MiniPix.jr(ln))
		for k in m + 1:
			var x := MiniPix.jr(ax + (bx - ax) * k / m)
			var y := MiniPix.jr(ay + (by - ay) * k / m)
			if ((nn + k) >> 1) % 2 == 0 and sqrt((x - tp.x / 2.0) * (x - tp.x / 2.0) + (y - tp.y / 2.0) * (y - tp.y / 2.0)) > 3.0:
				_put(x, y, MiniPix.FLARE if qi == 0 else MiniPix.EMBER)
		nn += m
		ax = bx
		ay = by
		var x := MiniPix.jr(bx)
		var y := MiniPix.jr(by)
		var lit := qi == 0
		for o: Vector2i in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			_put(x + o.x, y + o.y, HEAT[0])
		for o in N4:
			_put(x + o.x, y + o.y, MiniPix.FLARE if lit else MiniPix.EMBER)
		_put(x, y, MiniPix.HOT if lit else MiniPix.FLARE)


## The kit over the camera: the header (ARM CAM and its REC lamp), the tell card, the deck with the
## status line and the GAS and HITS meters. Drawn on a 150-wide layer laid 1 px in.
func _hud(t_: float) -> void:
	if _kit_px == null:
		_kit_px = MiniPix.new(MiniKit.W, MiniKit.H)
	var k := _kit_px
	k.clear(Color(0, 0, 0, 0))
	var hd := MiniKit.header(k, "ARM CAM", null)
	if int(floorf(t_ * 2.0)) % 2:
		k.dot(hd.x, 4, MiniPix.BAD)
	if not S.over and (S.pts as Array).size() <= 1 and path.is_empty():
		MiniKit.tell(k, "CUT OUT THE CRATE.", ["click"] as Array[String], t_)
	MiniKit.deck(k, true)
	var gl := clampf(1.0 - float(S.used) / float(P.gas), 0.0, 1.0)
	var low := gl < 0.2
	var hx := MiniKit.W - MiniKit.GUT - HITS_W
	var cy := MiniKit.CTRL_CY
	k.text("GAS", MiniKit.GUT, cy - 6, MiniPix.BAD if low else MiniKit.LABEL)
	MiniKit.meter(k, MiniKit.GUT, cy, hx - 4 - MiniKit.GUT, gl, "bad" if low else "neutral")
	k.text("HITS", hx, cy - 6, MiniPix.BAD if int(S.hits) else MiniKit.LABEL)
	MiniKit.meter(k, hx, cy, HITS_W, float(S.hits) / TorchSim.HITS_MAX, "bad")
	if (status_t > 0.0 or S.over) and status != "":
		var kind := "bad" if status_col == MiniPix.BAD else ("good" if status_col == MiniPix.GOOD else "neutral")
		MiniKit.status(k, status, kind, true)
	px.blit(k.img, 1, 0)


func _dot(x: float, y: float, c: Color) -> void:
	var xi := MiniPix.jr(x)
	var yi := MiniPix.jr(y)
	if xi >= 0 and yi >= 0 and xi < PW and yi < PH:
		_put(xi, yi, c)


## The torch: a hose off the frame, a handle, a brass ring, a nozzle at the cut point. Cutting, a
## flickering jet, a hot bite and sparks; idle, a blue pilot light.
func _draw_torch(t_: float) -> void:
	var lit := S.torch != null
	var flame := _flame_on()
	var tp: Vector2 = S.torch if lit else Vector2((PW - 30) * 2, (PH - 38) * 2)
	var hx := tp.x / 2.0
	var hy := tp.y / 2.0
	var r: Rect2 = P.R
	var ox0 := hx - (r.position.x + r.end.x) / 4.0
	var oy0 := hy - (r.position.y + r.end.y) / 4.0
	var ol := sqrt(ox0 * ox0 + oy0 * oy0)
	if ol == 0.0:
		ol = 1.0
	var ta := atan2(oy0 / ol + 0.25, ox0 / ol + 0.25)
	if is_nan(torch_a):
		torch_a = ta
	else:
		var d := ta - torch_a
		d = atan2(sin(d), cos(d))
		torch_a += d * 0.18
	var ux := cos(torch_a)
	var uy := sin(torch_a)
	var ax := hx + ux * 90.0
	var ay := hy + uy * 90.0
	var sh := (1.0 if int(floorf(t_ * 36.0)) % 2 else -1.0) if shake_t > 0.0 else 0.0
	var ox := sh * -uy
	var oy := sh * ux
	var tip := 5.0 if flame else 4.0
	var h0x := hx + ux * (tip + 16.0) + ox
	var h0y := hy + uy * (tip + 16.0) + oy
	var mx := (h0x + ax) / 2.0 + 6.0
	var my := maxf(h0y, ay) + 4.0
	for k in 49:
		var q := k / 48.0
		var x := (1 - q) * (1 - q) * h0x + 2 * (1 - q) * q * mx + q * q * ax
		var y := (1 - q) * (1 - q) * h0y + 2 * (1 - q) * q * my + q * q * ay
		_dot(x - 1, y + 1, METAL[0])
		_dot(x + 1, y + 2, METAL[0])
		_dot(x, y + 1, HOSE[0])
		_dot(x + 1, y + 1, HOSE[0])
		_dot(x, y, HOSE[1])
		_dot(x + 1, y, HOSE[1])
		_dot(x, y - 1, HOSE[2])
	var lit_side := 1 if (-uy - ux) < 0.0 else -1
	var d0 := tip + 6.0
	while d0 <= tip + 16.0:
		for o in range(-2, 3):
			_dot(hx + ux * d0 - uy * o + ox, hy + uy * d0 + ux * o + oy, METAL[0])
		d0 += 0.5
	d0 = tip + 6.5
	while d0 <= tip + 15.5:
		for o in range(-1, 2):
			_dot(hx + ux * d0 - uy * o + ox, hy + uy * d0 + ux * o + oy, METAL[6] if o == 0 else (METAL[7] if o == lit_side else METAL[4]))
		d0 += 0.5
	for d: float in [tip + 9.0, tip + 12.0]:
		for o in range(-1, 2):
			_dot(hx + ux * d - uy * o + ox, hy + uy * d + ux * o + oy, METAL[3])
	for d: float in [tip + 4.5, tip + 5.5]:
		for o in range(-2, 3):
			_dot(hx + ux * d - uy * o + ox, hy + uy * d + ux * o + oy, METAL[0] if o == -2 or o == 2 else (BRASS if o == lit_side else MiniPix.WARN))
	_dot(hx + ux * (tip + 11.0) + uy * lit_side * 3 + ox, hy + uy * (tip + 11.0) - ux * lit_side * 3 + oy, MiniPix.BAD)
	_dot(hx + ux * (tip + 11.5) + uy * lit_side * 3 + ox, hy + uy * (tip + 11.5) - ux * lit_side * 3 + oy, KNOB_DK)
	d0 = tip
	while d0 <= tip + 4.5:
		_dot(hx + ux * d0 + ox, hy + uy * d0 + oy, MiniPix.ICE if d0 < tip + 1.0 else METAL[7])
		_dot(hx + ux * d0 + uy * lit_side + ox, hy + uy * d0 - ux * lit_side + oy, METAL[0])
		d0 += 0.5
	if not flame:
		var f := int(floorf(t_ * 14.0)) % 3
		_dot(hx + ux * (tip - 1.0) + ox, hy + uy * (tip - 1.0) + oy, MiniPix.TRACTOR)
		if f:
			_dot(hx + ux * (tip - 2.0) + ox, hy + uy * (tip - 2.0) + oy, MiniPix.ICE if f == 1 else MiniPix.COLD)
		if lit:
			_dot(hx, hy, MiniPix.EMBER)
		return
	_jet(t_, hx, hy, ux, uy, ox, oy, tip)


func _jet(t_: float, hx: float, hy: float, ux: float, uy: float, ox: float, oy: float, tip: float) -> void:
	var ln := tip + (0.0 if int(floorf(t_ * 30.0)) % 2 else 1.0)
	var d := 0.0
	while d <= ln:
		_dot(hx + ux * d + ox, hy + uy * d + oy, WHITE_HOT if d < 1.5 else MiniPix.HOT)
		if d < 3.5:
			_dot(hx + ux * d - uy + ox, hy + uy * d + ux + oy, MiniPix.FLARE)
			_dot(hx + ux * d + uy + ox, hy + uy * d - ux + oy, MiniPix.FLARE)
		d += 0.5
	var warn: bool = sensors >= 2 and float(S.near) < 6.0
	var rad := 6
	for j in range(-rad, rad + 1):
		for i in range(-rad, rad + 1):
			var dd := sqrt(i * i + j * j)
			if dd > rad or dd < 1.5:
				continue
			var x := MiniPix.jr(hx) + i
			var y := MiniPix.jr(hy) + j
			var v := 1.0 - dd / rad
			if MiniPix.bay(x, y) > v * 0.7:
				continue
			_dot(x, y, (MiniPix.BAD if v > 0.5 else BURN_RED) if warn else (MiniPix.FLARE if v > 0.55 else (MiniPix.EMBER if v > 0.3 else HEAT[1])))
	_dot(hx, hy, WHITE_HOT)
	_dot(hx - 1, hy, MiniPix.HOT)
	_dot(hx + 1, hy, MiniPix.HOT)
	_dot(hx, hy - 1, MiniPix.HOT)
	_dot(hx, hy + 1, MiniPix.HOT)
	# sparks are the flame's look: the global generator, as the prototype's Math.random
	if randf() < 0.9:
		for i in 2:
			var a := atan2(-uy, -ux) + (randf() - 0.5) * 2.2
			var v := 14.0 + randf() * 24.0
			fx.append({k = "spark", x = hx, y = hy, vx = cos(a) * v, vy = sin(a) * v, age = 0.0, life = 0.2 + randf() * 0.35, c = MiniPix.HOT if randf() < 0.5 else WHITE_HOT})


# ---------------------------------------------------------------- the clock

func _say(txt: String, c: Color, secs: float = 2.5) -> void:
	status = txt
	status_col = c
	status_t = secs


func _sparks(x: float, y: float, nn: int, cols: Array[Color], sp: float) -> void:
	for i in nn:
		var a := randf() * 6.283
		var v := (0.3 + randf()) * sp
		fx.append({k = "spark", x = x, y = y, vx = cos(a) * v, vy = sin(a) * v, age = 0.0, life = 0.25 + randf() * 0.45, c = cols[int(randf() * cols.size())]})


func _events() -> void:
	var evs: Array = S.events
	while not evs.is_empty():
		var ev: Dictionary = evs.pop_front()
		var x := float(ev.get("x", 0.0)) / 2.0
		var y := float(ev.get("y", 0.0)) / 2.0
		match String(ev.type):
			"hit":
				fx.append({k = "flash", x = x, y = y, age = 0.0, life = 0.3})
				shake_t = 0.4
				if ev.kind == "power":
					fx.append({k = "arc", x = x, y = y, age = 0.0, life = 0.5})
					_sparks(x, y, 24, [MiniPix.ICE, MiniPix.TRACTOR, MiniPix.MARK], 40.0)
					_say(MSG.zap, MiniPix.BAD)
				else:
					fx.append({k = "puff", x = x, y = y, age = 0.0, life = 1.6})
					_sparks(x, y, 14, [MiniPix.FLARE, MiniPix.HOT, MiniPix.EMBER], 26.0)
					_say(MSG.fuel, MiniPix.BAD)
			"scorch":
				fx.append({k = "burn", x = x, y = y, age = 0.0, life = 1e9})
				_say(MSG.burn, MiniPix.BAD, 2.0)
			"piece":
				fx.append({k = "piece", poly = ev.poly, age = 0.0, life = 1.5})
				_say(MSG.piece, MiniPix.WARN)
			"freed":
				end_t = S.t
				sfx(&"free")
				sfx(&"win")
				path.clear()
				_say(MSG.free, MiniPix.GOOD, 99.0)
			"fail":
				end_t = S.t
				path.clear()
				_say(MSG.gas if ev.why == "gas" else MSG.fire, MiniPix.BAD, 99.0)


func _finish() -> void:
	if done_fired:
		return
	done_fired = true
	var detail := "Freed, %d hits, %d burns, %d%% gas" % [int(S.hits), int(S.scorch), MiniPix.jr(float(S.used) / float(P.gas) * 100.0)] if S.freed \
		else ("Too many lines cut" if int(S.hits) >= TorchSim.HITS_MAX else "Ran out of gas")
	done(TorchSim.score_of(S, P), detail)


func _step(dt: float) -> void:
	sfx_loop(&"torch", _flame_on())
	var n0 := (S.pts as Array).size()
	if not S.over and S.torch != null:
		var tg := path[0] if not path.is_empty() else (S.torch as Vector2)
		TorchSim.step(S, P, tg.x, tg.y, dt)
		if not path.is_empty() and not (held and drag) and (path[0] - (S.torch as Vector2)).length() < 0.6:
			path.pop_front()
	else:
		S.t += dt
	var pts: Array = S.pts
	for i in range(maxi(0, n0 - 1), pts.size()):
		var p: Vector3 = pts[i]
		var x := int(floorf(p.x / 2.0))
		var y := int(floorf(p.y / 2.0))
		var k := y * PW + x
		if x >= 0 and y >= 0 and x < PW and y < PH and cut[k] < 0.0:
			cut[k] = S.t
			cut_list.append(k)
	_events()
	status_t -= dt
	shake_t = maxf(0.0, shake_t - dt)
	var keep: Array = []
	for f: Dictionary in fx:
		f.age += dt
		if float(f.age) > float(f.life):
			continue
		if f.k == "spark":
			f.x += float(f.vx) * dt
			f.y += float(f.vy) * dt
			f.vx *= 0.97
			f.vy *= 0.97
		keep.append(f)
	fx = keep
	for d: Dictionary in debris:
		d.x = fposmod(float(d.x) + float(d.vx) * dt + PW, PW)
		d.y = fposmod(float(d.y) + float(d.vy) * dt + PH, PH)
	# freed: the piece floats out for 1.4 s, then 0.3 s (the prototype times it from its drawing)
	if S.freed and float(S.t) - end_t >= 1.4 and _finish_at < 0.0:
		_finish_at = t + 0.3
	if S.over and not S.freed and float(S.t) - end_t > 1.6 and _finish_at < 0.0:
		_finish_at = t + 0.1
	if _finish_at >= 0.0 and t >= _finish_at:
		_finish()


func _tick(dt: float) -> void:
	if done_fired:
		return
	_step(minf(0.05, dt))
	_acc += dt
	if _acc >= 1.0 / 30.0:
		_acc = 0.0
		if drawing:
			_draw()


# ---------------------------------------------------------------- input

func _world() -> Vector2:
	return pf * 2.0


func down(_p: Vector2i) -> void:
	if S.over:
		return
	var p := _world()
	# taps on the kit's header or deck do not cut
	if p.y >= 2 * MiniKit.deck_y(true) or p.y < 2 * MiniKit.PLAY_Y:
		return
	held = true
	drag = false
	down_at = p
	if S.torch == null:
		return
	if path.size() < 12:
		path.append(Vector2(clampf(p.x, 2, TorchSim.W - 2), clampf(p.y, 2, TorchSim.H - 2)))


func move(_p: Vector2i) -> void:
	if not held or S.over:
		return
	var p := _world()
	if not drag and (p - down_at).length() > 8.0:
		drag = true
	if drag:
		path.assign([Vector2(clampf(p.x, 2, TorchSim.W - 2), clampf(p.y, 2, TorchSim.H - 2))])


func up(_p: Vector2i, _cancel := false) -> void:
	held = false
	drag = false


func give_up() -> void:
	if done_fired:
		return
	S.over = true
	done_fired = true
	sfx_loop(&"torch", false)
	done(0.0, "Gave up")
