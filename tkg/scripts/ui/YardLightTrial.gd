class_name YardLightTrial
extends RefCounted

## TRIAL ONLY (Jon, Nov 12: "the lights are not emanating from the top"): each light
## source off in turn, or option A (a lamp over each berth), B (one light bar) or
## C (the hall's own five lamps), by `-- yardlight=a,b,...`. Inert without it.

static var _tokens: PackedStringArray = PackedStringArray()
static var _read := false

## The floor's camera (yard.json "cam") and the wall's foot.
const VX := 383.0
const HY := 30.0
const F := 500.0
const CH := 300.0
const WALL := 207
const WARM := Color(1.0, 0.93, 0.8)
## A: each berth's lamps (screen x, the lens row), in the banners' gaps.
const A_LAMPS := {HullData.Weight.LIGHT: [[206.0, 156.0]], HullData.Weight.MEDIUM: [[766.0, 156.0]],
	HullData.Weight.HEAVY: [[430.0, 146.0], [542.0, 146.0]]}
## C: the hall's painted ceiling lamps, and their copy on the hall continued.
const C_LAMPS := [100.0, 256.0, 411.0, 570.0, 727.0, 866.0]


static func has(tok: String) -> bool:
	if not _read:
		_read = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("yardlight="):
				_tokens = a.substr(10).split(",")
	return tok in _tokens


## The option on trial: "A", "B", "C", or "" for the game as it is.
static func option() -> String:
	for o in ["A", "B", "C"]:
		if has(o):
			return o
	return ""


## The hall's ambient and the ceiling lamps' weight under each option.
static func amb(base: float) -> float:
	match option():
		"A": return 0.09
		"B": return 0.15
		"C": return 0.08
	return base


static func ceil_gain(base: float) -> float:
	match option():
		"A": return 0.3
		"B": return 0.25
	return base


## How bright a hull's full light is (the shader's `ship_k`).
static func ship_k() -> float:
	match option():
		"A": return 1.7
		"B": return 1.35
		"C": return 1.3
	return 1.0


# ------------------------------------------------------------------ the floor

## A floor point's place in the world: (across, depth) from its screen point.
static func world(x: float, y: float) -> Vector2:
	var z := CH * F / maxf(1.0, y - HY)
	return Vector2((x - VX) * z / F, z)


## The floor's light under the option, as the bay map (`YardLight.set_bay`):
## the half grid as wide as the frame, 16-bit in R and G over 0..2.
static func pools(front: YardFront) -> Image:
	var img := Image.create(481, 242, false, Image.FORMAT_RGBA8)
	var opt := option()
	var hulls: Array[Rect2] = []
	for w: HullData.Weight in front.sets:
		var s: YardStandSet = front.sets[w]
		var a := world(float(s.thing.position.x), float(s.feet))
		var b := world(float(s.thing.end.x), float(s.feet))
		hulls.append(Rect2(a.x + 6.0, a.y - 10.0, b.x - a.x - 12.0, 16.0))
	for cy in 242:
		var y := float(cy) * 2.0 + 1.0
		if y < float(WALL):
			continue
		for cx in 481:
			var v := _floor_at(opt, front, world(float(cx) * 2.0 + 1.0, y), hulls)
			var q := clampi(roundi(clampf(v, 0.0, 2.0) / 2.0 * 65535.0), 0, 65535)
			img.set_pixel(cx, cy, Color8(q >> 8, q & 255, 0, 255))
	return img


static func _floor_at(opt: String, front: YardFront, p: Vector2, hulls: Array[Rect2]) -> float:
	var v := 0.0
	if opt == "A":
		v = 0.22
		for w: HullData.Weight in A_LAMPS:
			var s: YardStandSet = front.sets[w]
			var foot := world(0.0, float(s.feet))
			var gain := 1.5 if front.picked == int(w) else 1.0
			for L: Array in A_LAMPS[w]:
				var c := world(float(L[0]), float(s.feet))
				var d := Vector2((p.x - c.x) / 95.0, (p.y - foot.y) / 38.0).length()
				# a lamp's circle: a plateau and a quick edge
				v += 0.95 * gain * pow(clampf(1.0 - d * d, 0.0, 1.0), 0.45)
		v *= _hull_shadow(p, hulls, 0.55)
	elif opt == "B":
		# one bar overhead: the same light everywhere across, falling off in depth from under it
		v = 0.5 + 0.35 * exp(-pow((p.y - 620.0) / 380.0, 2.0))
		v *= _hull_shadow(p, hulls, 0.6)
	elif opt == "C":
		var zw := CH * F / (float(WALL) - HY)
		v = 0.14
		for lx: float in C_LAMPS:
			var c := world(lx, float(WALL))
			var d := Vector2(p.x - c.x, (p.y - zw) * 0.8).length()
			v += 1.15 * pow(1.0 / (1.0 + pow(d / 210.0, 2.0)), 2.0)
	return v


## Light left on the floor under the hulls, a soft-edged shadow straight down.
static func _hull_shadow(p: Vector2, hulls: Array[Rect2], k: float) -> float:
	var out := 1.0
	for r in hulls:
		var dx := maxf(r.position.x - p.x, p.x - r.end.x)
		var dz := maxf(r.position.y - p.y, p.y - r.end.y)
		# full inside, fading over 18 across and 12 in depth outside
		var e := maxf(dx / 18.0, dz / 12.0)
		var m := 1.0 if e <= 0.0 else clampf(1.0 - e, 0.0, 1.0)
		m = m * m * (3.0 - 2.0 * m)
		out *= 1.0 - k * m
	return out


# ------------------------------------------------------------------ the hulls

## Each hull's light into the ship map's blue (`YardFront._rebake` made R).
static func shade_ships(img: Image, front: YardFront) -> void:
	var opt := option()
	for w: HullData.Weight in front.sets:
		var s: YardStandSet = front.sets[w]
		var r := s.thing
		var picked := front.picked == int(w)
		for x in range(maxi(0, r.position.x), mini(img.get_width(), r.end.x)):
			var top := -1
			var bot := -1
			for y in range(maxi(0, r.position.y), mini(img.get_height(), r.end.y)):
				if img.get_pixel(x, y).r8 == 255:
					if top < 0:
						top = y
					bot = y
			if top < 0:
				continue
			for y in range(top, bot + 1):
				var c := img.get_pixel(x, y)
				if c.r8 != 255:
					continue
				var u := float(y - top) / float(maxi(1, bot - top))
				c.b8 = clampi(roundi(_hull_at(opt, w, float(x), u, picked, front) * 255.0), 1, 255)
				img.set_pixel(x, y, c)


static func _hull_at(opt: String, w: HullData.Weight, x: float, u: float, picked: bool, front: YardFront) -> float:
	if opt == "A":
		var g := 0.0
		for L: Array in A_LAMPS[w]:
			g = maxf(g, exp(-pow((x - float(L[0])) / 120.0, 2.0)))
		var top := pow(1.0 - u, 1.6)
		var peak := 1.0 if picked or front.picked < 0 else 0.72
		return peak * (0.22 + 0.78 * top * (0.45 + 0.55 * g))
	if opt == "B":
		return 0.28 + 0.72 * pow(1.0 - u, 1.2)
	if opt == "C":
		var g2 := 0.0
		for lx: float in C_LAMPS:
			g2 = maxf(g2, exp(-pow((x - lx) / 110.0, 2.0)))
		return 0.22 + 0.78 * exp(-u * 4.0) * (0.45 + 0.55 * g2)
	return 1.0


# ------------------------------------------------------------------ what you see of the light

## The beams, under the crew and the hulls: light in the air, a smooth fade
## down the beam and a dithered edge.
static func draw_beams(ci: CanvasItem, front: YardFront) -> void:
	var opt := option()
	if opt == "A":
		for w: HullData.Weight in A_LAMPS:
			var s: YardStandSet = front.sets[w]
			var gain := 1.6 if front.picked == int(w) else 1.0
			for L: Array in A_LAMPS[w]:
				var lx := float(L[0])
				var ly := float(L[1]) + 3.0
				var reach := 95.0 * F / world(0.0, float(s.feet)).y * 0.7
				# the hull under the lamp stops the beam: below it is its shadow
				var stop := float(s.feet) - 4.0
				for y in range(int(ly), s.feet):
					if s.on_ink(Vector2(lx, float(y) + 0.5)):
						stop = float(y) + 2.0
						break
				var half1 := lerpf(6.0, reach, (stop - ly) / maxf(1.0, float(s.feet) - 4.0 - ly))
				_beam(ci, lx, ly, 6.0, stop, half1, 52.0 * gain)
	elif opt == "B":
		# the bar's own glow on the wall under it, fading by the wall's middle
		for y in range(26, 120):
			var a := 30.0 * pow(1.0 - float(y - 26) / 94.0, 2.0)
			ci.draw_rect(Rect2(0, y, YardFront.W, 1), Color(WARM.r, WARM.g, WARM.b, a / 255.0), true)
	elif opt == "C":
		for lx: float in C_LAMPS:
			_beam(ci, lx, 4.0, 10.0, float(WALL), 70.0, 22.0)
			# on the floor, the cone runs on toward the camera along the floor's lines
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			var x0 := lx - 70.0
			var x1 := lx + 70.0
			var yb := 300.0
			var k := (yb - HY) / (float(WALL) - HY)
			pts.append_array([Vector2(x0, WALL), Vector2(x1, WALL), Vector2(VX + (x1 - VX) * k, yb), Vector2(VX + (x0 - VX) * k, yb)])
			var top := Color(WARM.r, WARM.g, WARM.b, 34.0 / 255.0)
			var bot := Color(WARM.r, WARM.g, WARM.b, 0.0)
			cols.append_array([top, top, bot, bot])
			ci.draw_polygon(pts, cols)


static func _beam(ci: CanvasItem, lx: float, y0: float, half0: float, y1: float, half1: float, alpha: float) -> void:
	var a0 := Color(WARM.r, WARM.g, WARM.b, alpha / 255.0)
	var a1 := Color(WARM.r, WARM.g, WARM.b, alpha * 0.35 / 255.0)
	ci.draw_polygon(PackedVector2Array([Vector2(lx - half0, y0), Vector2(lx + half0, y0), Vector2(lx + half1, y1), Vector2(lx - half1, y1)]),
		PackedColorArray([a0, a0, a1, a1]))
	# the dithered edge: two columns of checker just outside each side
	for yi in range(int(y0), int(y1), 1):
		var f := (float(yi) - y0) / maxf(1.0, y1 - y0)
		var h := lerpf(half0, half1, f)
		var a := lerpf(alpha, alpha * 0.35, f) / 255.0
		for side: float in [-1.0, 1.0]:
			for k in 2:
				var ex := floorf(lx + side * (h + 1.0 + float(k)))
				if (int(ex) + yi) % 2 == 0:
					ci.draw_rect(Rect2(ex, yi, 1, 1), Color(WARM.r, WARM.g, WARM.b, a * 0.6), true)


## The fixtures, over the banners: A's pendant lamps, B's light bar, C's lamps' glow.
static func draw_fixtures(ci: CanvasItem, front: YardFront) -> void:
	var opt := option()
	var steel := Color8(46, 50, 58)
	var lip := Color8(92, 98, 110)
	if opt == "A":
		for w: HullData.Weight in A_LAMPS:
			for L: Array in A_LAMPS[w]:
				var lx := floorf(float(L[0]))
				var ly := float(L[1])
				var on := 1.6 if front.picked == int(w) else 1.0
				ci.draw_rect(Rect2(lx, 0, 1, ly - 9.0), Color8(28, 30, 36), true)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(lx - 3, ly - 9), Vector2(lx + 4, ly - 9),
					Vector2(lx + 10, ly), Vector2(lx - 9, ly)]), steel)
				ci.draw_rect(Rect2(lx - 3, ly - 9, 7, 1), lip, true)
				ci.draw_rect(Rect2(lx - 9, ly, 19, 1), lip, true)
				_glow(ci, lx + 0.5, ly + 1.5, 9.0, on)
				ci.draw_rect(Rect2(lx - 7, ly + 1, 15, 1), Color(1.0, 0.97, 0.88), true)
	elif opt == "B":
		ci.draw_rect(Rect2(0, 20, YardFront.W, 4), steel, true)
		ci.draw_rect(Rect2(0, 20, YardFront.W, 1), lip, true)
		ci.draw_rect(Rect2(0, 24, YardFront.W, 2), Color(1.0, 0.97, 0.88), true)
		for x in range(0, YardFront.W, 64):
			ci.draw_rect(Rect2(x, 24, 2, 2), steel, true)
		for y in range(26, 32):
			var a := 0.35 * (1.0 - float(y - 26) / 6.0)
			for x in range(0, YardFront.W, 1):
				if (x + y) % 2 == 0 or y < 28:
					ci.draw_rect(Rect2(x, y, 1, 1), Color(1.0, 0.95, 0.82, a), true)
	elif opt == "C":
		for lx: float in C_LAMPS:
			_glow(ci, lx, 5.0, 12.0, 1.0)


## A lamp's glow: stepped rings, dithered at the edge, brightest at the core.
static func _glow(ci: CanvasItem, cx: float, cy: float, r: float, k: float) -> void:
	for yi in range(int(cy - r), int(cy + r) + 1):
		for xi in range(int(cx - r), int(cx + r) + 1):
			var d := Vector2(float(xi) + 0.5 - cx, (float(yi) + 0.5 - cy) * 1.6).length() / r
			if d >= 1.0:
				continue
			var a := 0.0
			if d < 0.35:
				a = 0.55
			elif d < 0.65:
				a = 0.3
			elif (xi + yi) % 2 == 0:
				a = 0.16
			if a > 0.0:
				ci.draw_rect(Rect2(xi, yi, 1, 1), Color(1.0, 0.93, 0.78, minf(1.0, a * k)), true)
