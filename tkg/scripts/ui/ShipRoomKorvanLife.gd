class_name ShipRoomKorvanLife
extends RefCounted

## What Korvan's film drew each frame, ported: the layers in the film's order (`back` before the
## hulls, `front` after), the sprites it drew from, and the Yard's walk (core.Walker).
## Why: docs/why/ShipRoomKorvan.md#life

const F := preload("res://scripts/ui/ShipRoomKorvanFilm.gd")
const P := preload("res://scripts/ui/ShipRoomKorvanPaint.gd")
const PUFF := preload("res://shaders/ship_room_korvan_puff.gdshader")

## The room's life material (not the room: it holds us).
var lit: Material
var atlas: Texture2D
var rects: Dictionary = {}
var _tex: Dictionary[String, Texture2D] = {}
var _src: Dictionary[String, Rect2] = {}
var _layer: Control
var _paints: Array[ShipRoomKorvanPaint] = []
var _puff_mat: ShaderMaterial
var white: Texture2D
var _contact_mat: ShaderMaterial


func _init(m: Material) -> void:
	lit = m
	F.ensure()
	atlas = ShipRoom.tex(&"korvan", "atlas.png")
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(F.DIR + "atlas.json"))
	rects = d if d is Dictionary else {}
	_puff_mat = ShaderMaterial.new()
	_puff_mat.shader = PUFF
	_contact_mat = ShaderMaterial.new()
	_contact_mat.shader = ShipRoomKorvanPaint.CONTACT
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	white = ImageTexture.create_from_image(img)


## New layers go on `c` from here on, in the order asked for.
func on(c: Control) -> void:
	_layer = c


func paint(b: ShipRoomKorvanPaint.Blend = ShipRoomKorvanPaint.Blend.LIT) -> ShipRoomKorvanPaint:
	var p := ShipRoomKorvanPaint.new()
	p.setup(b, lit)
	p.contact_mat = _contact_mat
	if b == ShipRoomKorvanPaint.Blend.LIT:
		p.light(4)
	_layer.add_child(p)
	_paints.append(p)
	return p


func mul() -> ShipRoomKorvanPaint:
	return paint(ShipRoomKorvanPaint.Blend.MUL)


func add() -> ShipRoomKorvanPaint:
	return paint(ShipRoomKorvanPaint.Blend.ADD)


## A layer of puffs (steam, smoke): `puff` rects drawn by the puff shader.
func puffs() -> ShipRoomKorvanPaint:
	var p := paint(ShipRoomKorvanPaint.Blend.UNLIT)
	p.material = _puff_mat
	p.set_meta(&"white", white)
	return p


static func puff(p: ShipRoomKorvanPaint, x: float, y: float, rad: float, al: float) -> void:
	var rr := int(ceilf(rad))
	var xi := F.pyround(x)
	var yi := F.pyround(y)
	p.sprite(p.get_meta(&"white") as Texture2D, Rect2(0, 0, 2 * rr + 1, 2 * rr + 1), xi - rr, yi - rr, false,
		Color(rad / 16.0, al, 0, 1))


func clear_all() -> void:
	for p in _paints:
		if not p.keep:
			p.clear()


## An atlas piece's source rect.
func src(n: String) -> Rect2:
	if _src.has(n):
		return _src[n]
	var r: Array = rects.get(n, [0, 0, 0, 0])
	_src[n] = Rect2(r[0], r[1], r[2], r[3])
	return _src[n]


func piece(p: ShipRoomKorvanPaint, n: String, x: int, y: int, flip: bool = false, mod: Color = Color.WHITE) -> void:
	p.sprite(atlas, src(n), x, y, flip, mod)


func yard_tex(pic: String) -> Texture2D:
	if not _tex.has(pic):
		_tex[pic] = load(F.YARD + pic) as Texture2D
	return _tex[pic]


## A Yard crew look's frame i: its texture region (core.crew_frame).
func crew_src(look: String, i: int) -> Rect2:
	var key := look + str(i)
	if _src.has(key):
		return _src[key]
	var m: Dictionary = F.Y["crew"][look]
	var t := yard_tex(m["picture"])
	var fw := t.get_width() / int(m["frames"])
	_src[key] = Rect2(i * fw, 0, fw, t.get_height())
	return _src[key]


func crew(p: ShipRoomKorvanPaint, look: String, i: int, x: int, y: int, flip: bool = false) -> void:
	p.sprite(yard_tex(String(F.Y["crew"][look]["picture"])), crew_src(look, i), x, y, flip)


## A Yard life strip's frame i (core.strip_frame).
func strip_src(n: String, i: int) -> Rect2:
	var m: Dictionary = F.Y["life"][n]
	var t := yard_tex(m["picture"])
	return Rect2(i * int(m["fw"]), 0, int(m["fw"]), t.get_height())


func strip(p: ShipRoomKorvanPaint, n: String, i: int, x: int, y: int, flip: bool = false) -> void:
	var m: Dictionary = F.Y["life"][n]
	p.sprite(yard_tex(m["picture"]), strip_src(n, i), x, y, flip)


## A line of single pixels from a to b in n + 1 steps (the film's seg8 at step 1, rounded).
static func seg(a: Vector2, b: Vector2, step: float = 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := maxi(1, int(maxf(absf(b.x - a.x), absf(b.y - a.y)) / step))
	for i in n + 1:
		out.append(a + (b - a) * float(i) / float(n))
	return out


## The Yard's walk (core.Walker): one pose per `advance` px at the look's pace, feet planted.
## plan: ["in", x, y, t] then ["walk", x, y] / ["stand", secs] / ["out"].
class Walker:
	var look := ""
	var adv := 2.0
	var stand_i := 0
	var pace := 10.0
	var segs: Array[Array] = []
	var t_in := 0.0
	var t_out := 0.0

	func _init(lk: String, plan: Array, pace_over: float = 0.0) -> void:
		look = lk
		var m: Dictionary = ShipRoomKorvanFilm.Y["crew"][lk]
		adv = float(m["advance"])
		stand_i = int(m.get("stand", 0))
		pace = pace_over if pace_over > 0.0 else float(m["pace"])
		var x := float(plan[0][1])
		var y := float(plan[0][2])
		var t := float(plan[0][3])
		t_in = t
		var d := 1
		var out_set := false
		for i in range(1, plan.size()):
			var p: Array = plan[i]
			if p[0] == "walk":
				var dur := Vector2(float(p[1]) - x, float(p[2]) - y).length() / pace
				segs.append(["walk", t, t + dur, x, y, float(p[1]), float(p[2])])
				d = 1 if float(p[1]) >= x else -1
				x = float(p[1])
				y = float(p[2])
				t += dur
			elif p[0] == "stand":
				segs.append(["stand", t, t + float(p[1]), x, y, d])
				t += float(p[1])
			elif p[0] == "out":
				t_out = t
				out_set = true
		if not out_set:
			t_out = t

	static func fade(t: float, t0: float, t1: float) -> float:
		if t < t0 or t > t1:
			return 0.0
		return minf(1.0, minf((t - t0) / 0.27, (t1 - t) / 0.27))

	## [x, y, frame, flip (1/0), alpha], empty when he is not out.
	func at(t0: float) -> PackedFloat32Array:
		var t := t0
		var a := 0.0
		for tt: float in [t0, t0 - 30.0, t0 + 30.0]:
			a = fade(tt, t_in, t_out)
			if a > 0.0:
				t = tt
				break
		if a <= 0.0:
			return PackedFloat32Array()
		for s: Array in segs:
			if t >= float(s[1]) and t <= float(s[2]):
				if s[0] == "walk":
					var dist := Vector2(float(s[5]) - float(s[3]), float(s[6]) - float(s[4])).length()
					var steps := floorf(pace * (t - float(s[1])) / adv)
					var u := minf(1.0, steps * adv / maxf(1e-6, dist))
					return PackedFloat32Array([ShipRoomKorvanFilm.pyround(float(s[3]) + (float(s[5]) - float(s[3])) * u),
						ShipRoomKorvanFilm.pyround(float(s[4]) + (float(s[6]) - float(s[4])) * u), posmod(int(steps), 8),
						1.0 if float(s[5]) < float(s[3]) else 0.0, a])
				return PackedFloat32Array([ShipRoomKorvanFilm.pyround(float(s[3])), ShipRoomKorvanFilm.pyround(float(s[4])),
					stand_i, 1.0 if int(s[5]) < 0 else 0.0, a])
		var l: Array = segs[-1]
		if l[0] == "walk":
			return PackedFloat32Array([ShipRoomKorvanFilm.pyround(float(l[5])), ShipRoomKorvanFilm.pyround(float(l[6])),
				stand_i, 1.0 if float(l[5]) < float(l[3]) else 0.0, a])
		return PackedFloat32Array([ShipRoomKorvanFilm.pyround(float(l[3])), ShipRoomKorvanFilm.pyround(float(l[4])),
			stand_i, 1.0 if int(l[5]) < 0 else 0.0, a])
