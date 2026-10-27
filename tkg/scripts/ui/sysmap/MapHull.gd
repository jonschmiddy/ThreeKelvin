extends RefCounted

## YOUR OWN SHIP ON THE SECTOR MAP (Jeremy, friends' alpha: the map flew a
## generic arrow, not the ship he had built). The hull's own picture, the one
## LOCAL draws (`ShipView.hull_art`: its art at its grade, paint and markings
## and all), shrunk to the map's scale and turned the way the game turns a
## sprite (`PixelTurn`, SOFT): never rotated on screen, each turn its own
## picture, every pixel of it averaged from SS x SS points in linear light with
## its edge partly clear. The map's other rules stay the overlay's: what hides
## the ship, the flash it catches, the flame (`SystemOverlay._draw_ship`).
##
## NO PARTS ON IT. At this scale a gun is a pixel or two; the hull's outline is
## what says whose ship it is, and the pictures that do draw parts draw the
## weapons only (`MountPoints.weapons_only`).
##
## Cached for the session: a picture per hull picture, a turn per angle step,
## each made the first time it is drawn (one a frame at most, since a frame
## draws one ship), so a hull swap costs one shrink and nothing else changes.

## THE HULL'S LENGTH ON THE MAP, its ink alone, by weight (LIGHT, MEDIUM,
## HEAVY). The old arrow was 10 px; the weights' own pictures differ in
## proportion from one manufacturer to the next, so the length is set here and
## the height follows the picture.
const LEN: Array[int] = [14, 17, 20]
## A block of the picture is ink on the map when this much of it is.
const INK := 0.4
## Turned pictures in a whole turn: at the heavy's nose a step moves it a
## quarter of a pixel, which the soft turn shows as a glide, not a tick.
const BINS := 256
## Points a side sampled across each pixel of a turned picture (PixelTurn's
## SOFT takes 16).
const SS := 4
## The dark rim round the hull, the old arrow's.
const OUTLINE := Color("#05070b")

static var _pics: Dictionary = {}
static var _lin: PackedFloat32Array = PackedFloat32Array()


static func _lut() -> PackedFloat32Array:
	if _lin.is_empty():
		_lin.resize(256)
		for i in 256:
			_lin[i] = Color(i / 255.0, 0.0, 0.0).srgb_to_linear().r
	return _lin


## THE HULL AT THE MAP'S SCALE, from `src` (`ShipView.hull_art`): {} when it has
## no picture to shrink.
##   W, H      the picture's size, its outline in, both odd so its middle is a
##             pixel's middle (an unturned ship lands pixel for pixel)
##   pm        per pixel: red, green, blue (linear, premultiplied), alpha, and
##             1 where it is hull and not the outline
##   img       the same, as an image (sRGB), to look at
##   ev        the engines' row, from the middle row (the hull's own thrusters,
##             else the middle)
##   stern     per row from the middle (`ev` - 1 to + 1): the first column
##             drawn, from the middle column
##   nose      per row (-1 to +1 from the middle): the last column drawn
##   R         the farthest a turned picture's pixel can be from its middle
static func picture(h: HullData, src: Texture2D) -> Dictionary:
	if h == null or src == null:
		return {}
	var key := "%d|%d" % [src.get_instance_id(), int(h.weight)]
	if _pics.has(key):
		return _pics[key]
	var img := src.get_image()
	if img == null or img.is_empty():
		return {}
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img = img.duplicate() as Image
		img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	if used.size.x < 4 or used.size.y < 2:
		return {}
	var w: int = LEN[clampi(int(h.weight), 0, LEN.size() - 1)]
	var hh := maxi(3, roundi(float(used.size.y) * float(w) / float(used.size.x)))
	# THE INK ALONE, AT THE ART'S OWN PIXEL: hull art is drawn at 2x (every pixel
	# a 2x2 block, `HullData.sprite_half`), so halving it by nearest loses
	# nothing and leaves a quarter of the pixels to add up (a Korvan light took
	# 192 ms on Jon's Mac at the full size)
	var ink := img.get_region(used)
	if ink.get_width() >= 8 * w:
		ink.resize(ink.get_width() / 2, ink.get_height() / 2, Image.INTERPOLATE_NEAREST)
	var IW := ink.get_width()
	var IH := ink.get_height()
	# EACH MAP PIXEL, THE AVERAGE OF ITS BLOCK of the picture, in linear light and
	# weighted by how much of it is ink
	var lut := _lut()
	var acc := PackedFloat32Array()
	acc.resize(w * hh * 4)
	var cnt := PackedInt32Array()
	cnt.resize(w * hh)
	var data := ink.get_data()
	for oy in hh:
		var y0 := (oy * IH + hh - 1) / hh
		var y1 := ((oy + 1) * IH + hh - 1) / hh
		for ox in w:
			var x0 := (ox * IW + w - 1) / w
			var x1 := ((ox + 1) * IW + w - 1) / w
			var r := 0.0
			var g := 0.0
			var b := 0.0
			var al := 0.0
			for y in range(y0, y1):
				var i := (y * IW + x0) * 4
				for x in range(x0, x1):
					var a := data[i + 3]
					if a != 0:
						var af := a / 255.0
						r += lut[data[i]] * af
						g += lut[data[i + 1]] * af
						b += lut[data[i + 2]] * af
						al += af
					i += 4
			var o := oy * w + ox
			cnt[o] = (y1 - y0) * (x1 - x0)
			acc[o * 4] = r
			acc[o * 4 + 1] = g
			acc[o * 4 + 2] = b
			acc[o * 4 + 3] = al
	# THE OUTLINE ROUND IT, and a clear column or row more where a side is even
	var W := w + 2
	var H := hh + 2
	W += 1 - (W & 1)
	H += 1 - (H & 1)
	var kind := PackedByteArray()
	kind.resize(W * H)
	var col := PackedColorArray()
	col.resize(W * H)
	for y in hh:
		for x in w:
			var o := y * w + x
			var a := acc[o * 4 + 3]
			if cnt[o] > 0 and a / cnt[o] >= INK:
				kind[(y + 1) * W + x + 1] = 1
				col[(y + 1) * W + x + 1] = Color(acc[o * 4] / a, acc[o * 4 + 1] / a, acc[o * 4 + 2] / a)
	var ol := OUTLINE.srgb_to_linear()
	for y in H:
		for x in W:
			if kind[y * W + x] != 0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var X := x + d.x
				var Y := y + d.y
				if X >= 0 and Y >= 0 and X < W and Y < H and kind[Y * W + X] == 1:
					kind[y * W + x] = 2
					col[y * W + x] = ol
					break
	var pm := PackedFloat32Array()
	pm.resize(W * H * 5)
	var small := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var k := kind[y * W + x]
			if k == 0:
				continue
			var c := col[y * W + x]
			var j := (y * W + x) * 5
			pm[j] = c.r
			pm[j + 1] = c.g
			pm[j + 2] = c.b
			pm[j + 3] = 1.0
			pm[j + 4] = 1.0 if k == 1 else 0.0
			small.set_pixel(x, y, Color(c.linear_to_srgb(), 1.0))
	var mx := (W - 1) / 2
	var my := (H - 1) / 2
	# THE ENGINES' ROW: where the hull's own plumes attach (`HullData.thrusters`,
	# on the picture's canvas), on the map's rows
	var ev := 0
	if not h.thrusters.is_empty():
		var sum := 0.0
		for e: Dictionary in h.thrusters:
			var tx: Texture2D = e.get("tex")
			sum += float((e.get("at", Vector2i.ZERO) as Vector2i).y) + (float(tx.get_height()) * 0.5 if tx != null else 0.0)
		var ny := sum / float(h.thrusters.size())
		ev = clampi(1 + int((ny - used.position.y) * hh / used.size.y), 1, hh) - my
	var first := func(y: int) -> int:
		for x in W:
			if kind[y * W + x] != 0:
				return x - mx
		return -mx
	var last := func(y: int) -> int:
		for x in range(W - 1, -1, -1):
			if kind[y * W + x] != 0:
				return x - mx
		return mx
	var stern: Array[int] = []
	var nose: Array[int] = []
	for dv in [-1, 0, 1]:
		stern.append(first.call(clampi(my + ev + dv, 0, H - 1)))
		nose.append(last.call(clampi(my + dv, 0, H - 1)))
	var pic := {"W": W, "H": H, "pm": pm, "img": small, "ev": ev, "stern": stern, "nose": nose,
		"R": int(ceil(Vector2(W, H).length() * 0.5)), "turns": {}, "src": src}
	_pics[key] = pic
	return pic


## The angle step a screen angle (`ShipFlight.ang`) is drawn at.
static func bin_of(ang: float) -> int:
	return posmod(roundi(ang / TAU * BINS), BINS)


static func bin_angle(b: int) -> float:
	return TAU * float(b) / float(BINS)


## THE PICTURE TURNED to angle step `b`, as pixels round its middle: `o` each
## pixel's offset (screen px), `c` its colour (alpha: how much of it the hull
## covers), `hull` how much of it is hull and not the outline, `n` the way its
## edge faces where it does (for the flash it catches), `box` all of it.
static func turned(pic: Dictionary, b: int) -> Dictionary:
	var turns: Dictionary = pic.turns
	if turns.has(b):
		return turns[b]
	var W: int = pic.W
	var H: int = pic.H
	var pm: PackedFloat32Array = pic.pm
	var R: int = pic.R
	var a := bin_angle(b)
	var c := cos(a)
	var s := sin(a)
	var cx := W * 0.5
	var cy := H * 0.5
	var n := SS * SS
	var du := PackedFloat32Array()
	var dv := PackedFloat32Array()
	for sy in SS:
		for sx in SS:
			var dx := (sx + 0.5) / SS - 0.5
			var dy := (sy + 0.5) / SS - 0.5
			du.append(dx * c + dy * s)
			dv.append(-dx * s + dy * c)
	var offs := PackedVector2Array()
	var cols := PackedColorArray()
	var hulls := PackedFloat32Array()
	var at := {}
	for oy in range(-R, R + 1):
		for ox in range(-R, R + 1):
			var u0 := ox * c + oy * s + cx
			var v0 := -ox * s + oy * c + cy
			if u0 < -1.0 or v0 < -1.0 or u0 > W + 1.0 or v0 > H + 1.0:
				continue
			var r := 0.0
			var g := 0.0
			var bl := 0.0
			var al := 0.0
			var hl := 0.0
			for k in n:
				var X := floori(u0 + du[k])
				var Y := floori(v0 + dv[k])
				if X < 0 or Y < 0 or X >= W or Y >= H:
					continue
				var j := (Y * W + X) * 5
				if pm[j + 3] <= 0.0:
					continue
				r += pm[j]
				g += pm[j + 1]
				bl += pm[j + 2]
				al += pm[j + 3]
				hl += pm[j + 4]
			if al <= 0.0:
				continue
			at[Vector2i(ox, oy)] = hulls.size()
			offs.append(Vector2(ox, oy))
			cols.append(Color(Color(r / al, g / al, bl / al).linear_to_srgb(), al / n))
			hulls.append(hl / n)
	# THE EDGE'S FACING, out of the hull: toward the neighbours less hull than it
	var nrm := PackedVector2Array()
	nrm.resize(offs.size())
	var box := Rect2()
	for i in offs.size():
		var p := Vector2i(offs[i])
		box = Rect2(offs[i], Vector2.ONE) if i == 0 else box.merge(Rect2(offs[i], Vector2.ONE))
		if hulls[i] < 0.3:
			continue
		var nl := Vector2.ZERO
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: int = at.get(p + d, -1)
			nl += Vector2(d) * (hulls[i] - (hulls[q] if q >= 0 else 0.0))
		if nl.length() > 0.25:
			nrm[i] = nl.normalized()
	var out := {"o": offs, "c": cols, "hull": hulls, "n": nrm, "box": box}
	turns[b] = out
	return out
