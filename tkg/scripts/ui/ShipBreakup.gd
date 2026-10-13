class_name ShipBreakup
extends Control

## A SHIP COMING APART, cut out of whatever picture the ship is.
##
## Jon (Oct 13): "Also can we do death animations?" -- for enemy ships. The
## enemy art is being replaced by kept PixelLab sprites while this is written,
## so nothing here may know what a ship looks like: it is handed the ship's own
## pixels (`EnemyArt`'s canvas, or any sprite) and cuts them up itself.
##
## THE CUT. A few large chunks (the "majors") split along jagged cracks -- a
## Voronoi of seeds spread along the hull, its boundaries roughened by value
## noise so a crack never runs straight -- and a band of shards along each crack,
## carved out of the majors and cut small. The shards are what flies; the majors
## drift a few pixels apart and STAY: their resting places are the wreck you
## loot, so the last frame of this and `wreck_image` are the same picture.
##
## LIGHT AS LIGHT (memory draw-light-as-light). The glow along the cracks is not
## a coloured outline: each major carries a light map built from its own crack
## pixels -- a white-hot core, falloff over five pixels, the outer steps
## dithered 2x2 -- drawn ADDITIVELY and cooled from white through orange to red
## by multiplying its colour. Its strength is stepped and eased, never sampled
## from noise, so it cannot flicker.
##
## WHOLE PIXELS. Positions round; a shard tumbles in quarter turns, which are the
## only rotations pixel art survives without shimmering (turn-pixel-art-in-
## whole-pixel-steps); a major never turns at all.
##
## SOUND FOLLOWS WHAT YOU SEE. `broke` fires on the frame a break becomes
## visible, with how big it is; the screen plays the explosion there. Nothing
## here plays a sound itself, so a harness can film it silent.

signal broke(strength: float)
signal finished

enum Style { SNAP, BURN, IMPLODE }

## How long each style runs to its resting wreck, seconds. A normal kill is held
## for this before the fight is allowed to end (audit item 2 as Jon ruled it).
const LIFE := {Style.SNAP: 1.15, Style.BURN: 1.6, Style.IMPLODE: 1.45}
## The core's guard: a chain of bursts first, then the break, then a long cool.
const BOSS_PRELUDE := 1.5
const BOSS_EXTRA := 0.9

const HEAT_RAMP: Array[Color] = [Color("#fff6e2"), Color("#ffdca0"), Color("#ffa63c"),
	Color("#cc641c"), Color("#964214"), Color("#5c280c")]
const WRECK_TINT := Color(0.4, 0.4, 0.45)

var style: int = Style.SNAP
var boss: bool = false
var t: float = 0.0
var duration: float = 1.2
var done: bool = false
## Off for a harness that steps `advance` by hand.
var auto: bool = true

var _img: Image
var _origin: Vector2 = Vector2.ZERO   ## where the image's (0,0) sits, in this control
var _cut: Dictionary = {}
var _majors: Array = []   ## {tex, glow, at (Vector2i image px), off (final), crack (PackedVector2Array)}
var _shards: Array = []   ## {tex, at, v, spin, rot0, life, born}
var _motes: Array = []    ## {p, v, age, life, kind}
var _beats: Array = []    ## [time, strength, fired]
var _flash_tex: ImageTexture
var _flashes: Array = []  ## {p (Vector2), t0, r_scale}
var _light: Control
var _centre: Vector2
var _rng := RandomNumberGenerator.new()


class Layer extends Control:
	var paint: Callable
	func _draw() -> void:
		paint.call(self)


## `img` is the ship's whole canvas; `used` the ship's box in it (EnemyArt's
## `used_rect`, or the sprite's ink); `origin` where the canvas's top-left sits
## in this control's space. Same `seed`, same cut -- see `wreck_image`.
func setup(img: Image, used: Rect2i, origin: Vector2, the_style: int, seed: int,
		is_boss: bool = false) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_img = img
	_origin = origin.round()
	style = the_style
	boss = is_boss
	_rng.seed = seed * 7919 + 17
	_cut = cut(img, used, seed, is_boss)
	duration = float(LIFE[style]) + (BOSS_PRELUDE + BOSS_EXTRA if boss else 0.0)
	_centre = _origin + Vector2(_cut.centre)
	for m in _cut.majors:
		var tex := ImageTexture.create_from_image(m.image)
		var glow := ImageTexture.create_from_image(_glow_image(m.crack, m.image.get_size()))
		_majors.append({tex = tex, glow = glow, at = m.at, off = m.off, crack = m.crack})
	for s in _cut.shards:
		var tex2 := ImageTexture.create_from_image(s.image)
		var away: Vector2 = (Vector2(s.at) + Vector2(s.image.get_size()) * 0.5) - Vector2(_cut.centre)
		var dir := away.normalized() if away.length() > 0.5 else Vector2.RIGHT.rotated(_rng.randf() * TAU)
		_shards.append({tex = tex2, at = s.at, dir = dir, size = s.image.get_size(),
			speed = _rng.randf_range(0.6, 1.4), spin = _rng.randf_range(2.0, 7.0) * (1.0 if _rng.randf() < 0.5 else -1.0),
			rot0 = _rng.randi() % 4, delay = _rng.randf_range(0.0, 1.0)})
	_flash_tex = ImageTexture.create_from_image(_radial_light(34 if boss else 22))
	_plan_beats()
	var base := Layer.new()
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.paint = _paint_body
	add_child(base)
	_light = Layer.new()
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = mat
	_light.paint = _paint_light
	add_child(_light)


# ------------------------------------------------------------------ the cut

## THE PARTITION, as data, deterministic in `seed`. Static so the wreck on
## LOCAL can be drawn from the same cut long after the animation is gone.
##   majors: [{image, at (Vector2i), off (Vector2i final drift), crack (PackedVector2Array local)}]
##   shards: [{image, at}]
##   centre: Vector2i
static func cut(img: Image, used: Rect2i, seed: int, is_boss: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var r := used.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var w := r.size.x
	var h := r.size.y
	var n := w * h
	var mask := PackedByteArray()
	mask.resize(n)
	for y in h:
		for x in w:
			var c := img.get_pixel(r.position.x + x, r.position.y + y)
			mask[y * w + x] = 1 if c.a > 0.6 else 0
	# Lone pixels are the canvas's starfield, not hull.
	var keep := PackedByteArray()
	keep.resize(n)
	var cx := 0.0
	var cy := 0.0
	var count := 0
	for y in h:
		for x in w:
			if mask[y * w + x] == 0:
				continue
			var nb := 0
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var xx: int = x + dx
					var yy: int = y + dy
					if xx >= 0 and yy >= 0 and xx < w and yy < h and mask[yy * w + xx] == 1:
						nb += 1
			if nb >= 2:
				keep[y * w + x] = 1
				cx += x
				cy += y
				count += 1
	if count == 0:
		return {majors = [], shards = [], centre = r.get_center()}
	cx /= count
	cy /= count
	# Seeds spread along the hull's length, jittered: hulls are long, so the
	# cracks should run across them rather than along them.
	var k := 4 if is_boss else 3
	if w < 70:
		k = 2
	var seeds: Array[Vector2] = []
	for i in k:
		var sx := (float(i) + 0.5) / float(k) * w + rng.randf_range(-0.12, 0.12) * w
		var sy := cy + rng.randf_range(-0.25, 0.25) * h
		seeds.append(Vector2(sx, sy))
	# Value noise on a coarse grid, one field per seed, so neighbouring borders
	# wander independently.
	var cell := 5
	var gw := w / cell + 2
	var gh := h / cell + 2
	var fields: Array = []
	for i in k:
		var f := PackedFloat32Array()
		f.resize(gw * gh)
		for j in f.size():
			f[j] = rng.randf_range(-1.0, 1.0)
		fields.append(f)
	var amp := 0.11 * float(w) / float(k)
	var label := PackedInt32Array()
	label.resize(n)
	for y in h:
		for x in w:
			var idx := y * w + x
			if keep[idx] == 0:
				label[idx] = -1
				continue
			var best := 1e9
			var bi := 0
			for i in k:
				var d := Vector2(x, y).distance_to(seeds[i]) \
					+ amp * _noise(fields[i], gw, float(x) / cell, float(y) / cell)
				if d < best:
					best = d
					bi = i
			label[idx] = bi
	# The crack band: every hull pixel within a jagged radius of a border
	# between two majors becomes shard material.
	var border := PackedByteArray()
	border.resize(n)
	for y in h:
		for x in w:
			var idx2 := y * w + x
			if label[idx2] < 0:
				continue
			for o in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
				var xx2: int = x + o.x
				var yy2: int = y + o.y
				if xx2 >= 0 and yy2 >= 0 and xx2 < w and yy2 < h:
					var l2 := label[yy2 * w + xx2]
					if l2 >= 0 and l2 != label[idx2]:
						border[idx2] = 1
						border[yy2 * w + xx2] = 1
	var bandf := PackedFloat32Array()
	bandf.resize(gw * gh)
	for j2 in bandf.size():
		bandf[j2] = rng.randf_range(0.0, 1.0)
	var shard := PackedByteArray()
	shard.resize(n)
	var reach := 2 if not is_boss else 3
	for y in h:
		for x in w:
			if border[y * w + x] == 0:
				continue
			var rad := 1 + int(_noise(bandf, gw, float(x) / cell, float(y) / cell) * (reach - 0.4))
			for dy2 in range(-rad, rad + 1):
				for dx2 in range(-rad, rad + 1):
					var xx3: int = x + dx2
					var yy3: int = y + dy2
					if xx3 >= 0 and yy3 >= 0 and xx3 < w and yy3 < h and label[yy3 * w + xx3] >= 0 \
							and dx2 * dx2 + dy2 * dy2 <= rad * rad:
						shard[yy3 * w + xx3] = 1
	# Chips off the outline too, so the silhouette breaks and not only its
	# middle: a few bites along the hull's edge.
	var bites := 5 if not is_boss else 9
	for b in bites:
		for tries in 40:
			var px := rng.randi_range(0, w - 1)
			var py := rng.randi_range(0, h - 1)
			var id3 := py * w + px
			if label[id3] < 0:
				continue
			var edge := false
			for o2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ex: int = px + o2.x
				var ey: int = py + o2.y
				if ex < 0 or ey < 0 or ex >= w or ey >= h or label[ey * w + ex] < 0:
					edge = true
			if not edge:
				continue
			var br := rng.randi_range(2, 4)
			for dy4 in range(-br, br + 1):
				for dx4 in range(-br, br + 1):
					var bx: int = px + dx4
					var by: int = py + dy4
					if bx >= 0 and by >= 0 and bx < w and by < h and label[by * w + bx] >= 0 \
							and dx4 * dx4 + dy4 * dy4 <= br * br:
						shard[by * w + bx] = 1
			break
	# Majors: what is left of each label. The crack is every major pixel that
	# touches shard material or another major.
	var majors: Array = []
	for i in k:
		var minx := w
		var miny := h
		var maxx := -1
		var maxy := -1
		for y in h:
			for x in w:
				var id4 := y * w + x
				if label[id4] == i and shard[id4] == 0:
					minx = mini(minx, x)
					miny = mini(miny, y)
					maxx = maxi(maxx, x)
					maxy = maxi(maxy, y)
		if maxx < 0:
			continue
		var bw := maxx - minx + 1
		var bh := maxy - miny + 1
		var im := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
		var crack := PackedVector2Array()
		for y in range(miny, maxy + 1):
			for x in range(minx, maxx + 1):
				var id5 := y * w + x
				if label[id5] != i or shard[id5] != 0:
					continue
				im.set_pixel(x - minx, y - miny, _dead_pixel(img.get_pixel(r.position.x + x, r.position.y + y)))
				var on_crack := false
				for o3 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var qx: int = x + o3.x
					var qy: int = y + o3.y
					if qx >= 0 and qy >= 0 and qx < w and qy < h:
						var q := qy * w + qx
						if (label[q] >= 0 and shard[q] == 1) or (label[q] >= 0 and label[q] != i):
							on_crack = true
				if on_crack:
					crack.append(Vector2(x - minx, y - miny))
		# Drift away from the hull's middle, a few whole pixels: enough that the
		# cracks read as gaps, little enough that the wreck is still the ship.
		var mid := Vector2((minx + maxx) * 0.5, (miny + maxy) * 0.5)
		var away := mid - Vector2(cx, cy)
		var reach_px := rng.randf_range(2.5, 5.0) * (0.8 if is_boss else 1.0)
		var off := Vector2i((away.normalized() * reach_px).round()) if away.length() > 1.0 \
			else Vector2i(0, rng.randi_range(-2, 2))
		off.y += rng.randi_range(-1, 1)
		majors.append({image = im, at = r.position + Vector2i(minx, miny), off = off, crack = crack})
	# Shards: the band cut small, by a Voronoi of seeds spaced through it.
	var spts: Array[Vector2i] = []
	for y in h:
		for x in w:
			if shard[y * w + x] == 1 and rng.randf() < 0.035:
				spts.append(Vector2i(x, y))
	if spts.is_empty():
		spts.append(Vector2i(int(cx), int(cy)))
	var groups := {}
	for y in h:
		for x in w:
			if shard[y * w + x] == 0:
				continue
			var bj := 0
			var bd := 1 << 30
			for j3 in spts.size():
				var d2 := (spts[j3] - Vector2i(x, y)).length_squared()
				if d2 < bd:
					bd = d2
					bj = j3
			if not groups.has(bj):
				groups[bj] = []
			(groups[bj] as Array).append(Vector2i(x, y))
	var shards: Array = []
	for g in groups.values():
		var arr: Array = g
		var mn := Vector2i(1 << 20, 1 << 20)
		var mx := Vector2i(-1, -1)
		for p in arr:
			mn = Vector2i(mini(mn.x, p.x), mini(mn.y, p.y))
			mx = Vector2i(maxi(mx.x, p.x), maxi(mx.y, p.y))
		var sz := mx - mn + Vector2i.ONE
		# A piece must be square to turn in quarter steps about its middle
		# without walking off its own pixels.
		var side := maxi(sz.x, sz.y)
		var im2 := Image.create(side, side, false, Image.FORMAT_RGBA8)
		var pad := (Vector2i(side, side) - sz) / 2
		for p2 in arr:
			var q2: Vector2i = p2
			im2.set_pixel(q2.x - mn.x + pad.x, q2.y - mn.y + pad.y,
				img.get_pixel(r.position.x + q2.x, r.position.y + q2.y))
		shards.append({image = im2, at = r.position + mn - pad})
	return {majors = majors, shards = shards, centre = r.position + Vector2i(int(cx), int(cy))}


## How far each style throws the chunks apart, from the cut's own direction.
## The wreck is drawn from the same number, so the last frame is the wreck.
const DRIFT := {Style.SNAP: 1.7, Style.BURN: 1.3, Style.IMPLODE: 1.0}

static func drift(off: Vector2i, the_style: int) -> Vector2i:
	return Vector2i((Vector2(off) * float(DRIFT.get(the_style, 1.0))).round())


## A dead ship's engines are out: the flame and the lit ports, the brightest
## warm pixels, go to the darkest ember the heat ramp has.
static func _dead_pixel(c: Color) -> Color:
	if c.a > 0.0 and c.r > 0.75 and c.r >= c.b + 0.25 and c.get_luminance() > 0.55:
		return Color(HEAT_RAMP[5].r, HEAT_RAMP[5].g, HEAT_RAMP[5].b, c.a)
	return c


static func _noise(f: PackedFloat32Array, gw: int, x: float, y: float) -> float:
	var x0 := int(x)
	var y0 := int(y)
	var fx := x - x0
	var fy := y - y0
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := f[y0 * gw + x0]
	var b := f[y0 * gw + x0 + 1]
	var c := f[(y0 + 1) * gw + x0]
	var d := f[(y0 + 1) * gw + x0 + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## THE WRECK THIS LEAVES, on a canvas the size of `img`: every major at its
## resting drift, nothing else. Not darkened -- the slot greys a dead hull with
## `modulate` already, and the animation's last frame uses the same tint.
static func wreck_image(img: Image, used: Rect2i, seed: int, is_boss: bool = false,
		the_style: int = Style.SNAP) -> Image:
	var c := cut(img, used, seed, is_boss)
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for m in c.majors:
		var im: Image = m.image
		out.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), m.at + drift(m.off, the_style))
	return out


## One major's crack light: a white core on its crack pixels, falling off over
## five, the outer steps dithered. Padded so the light spills past the metal.
const GLOW_PAD := 3

func _glow_image(crack: PackedVector2Array, sz: Vector2i) -> Image:
	var w := sz.x + GLOW_PAD * 2
	var h := sz.y + GLOW_PAD * 2
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(99)
	var q: Array[Vector2i] = []
	for p in crack:
		var v := Vector2i(int(p.x) + GLOW_PAD, int(p.y) + GLOW_PAD)
		dist[v.y * w + v.x] = 0
		q.append(v)
	var head := 0
	while head < q.size():
		var cur := q[head]
		head += 1
		var d := dist[cur.y * w + cur.x]
		if d >= GLOW_PAD:
			continue
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cur.x + o.x
			var ny: int = cur.y + o.y
			if nx >= 0 and ny >= 0 and nx < w and ny < h and dist[ny * w + nx] > d + 1:
				dist[ny * w + nx] = d + 1
				q.append(Vector2i(nx, ny))
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bayer := [0.0, 0.5, 0.75, 0.25]
	for y in h:
		for x in w:
			var d2 := dist[y * w + x]
			if d2 > GLOW_PAD:
				continue
			var thr: float = bayer[(y % 2) * 2 + (x % 2)]
			var c: Color = HEAT_RAMP[mini(d2, HEAT_RAMP.size() - 1)]
			# Outer steps dither out: present on half, then a quarter, of the
			# grid, so the falloff has no hard ring.
			if d2 == 2 and thr >= 0.5:
				continue
			if d2 == 3 and thr >= 0.25:
				continue
			var k := 1.0 if d2 == 0 else (0.7 if d2 == 1 else 0.45)
			im.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, 1.0))
	return im


## A gathered light for the flash: a core and a stepped, dithered falloff.
static func _radial_light(radius: int) -> Image:
	var s := radius * 2 + 1
	var im := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var bayer := [0.0, 0.5, 0.75, 0.25]
	for y in s:
		for x in s:
			var d := Vector2(x - radius, y - radius).length() / float(radius)
			if d > 1.0:
				continue
			var e := pow(1.0 - d, 2.2)
			var thr: float = bayer[(y % 2) * 2 + (x % 2)]
			# Four steps, the last two dithered.
			var lvl := 0.0
			if e > 0.55:
				lvl = 1.0
			elif e > 0.28:
				lvl = 0.62
			elif e > 0.12:
				lvl = 0.36 if thr < 0.75 else 0.2
			elif e > 0.03:
				lvl = 0.18 if thr < 0.5 else 0.0
			if lvl <= 0.0:
				continue
			var c := HEAT_RAMP[0].lerp(HEAT_RAMP[2], 1.0 - lvl)
			im.set_pixel(x, y, Color(c.r * lvl, c.g * lvl, c.b * lvl, 1.0))
	return im


# ------------------------------------------------------------------ the clock

## When things happen, per style, as fractions of the base life. The boss runs
## a prelude of local bursts first, each one a beat of its own.
var _split_at := 0.0     ## when the majors start to drift and the shards fly
var _split_dur := 0.3

func _plan_beats() -> void:
	var lead := 0.0
	if boss:
		# Three to four bursts across the body, quickening, each a flash at a
		# crack and a sound.
		var times := [0.0, 0.55, 0.95, 1.25]
		for i in times.size():
			var m: Dictionary = _majors[i % _majors.size()] if not _majors.is_empty() else {}
			var p := _centre
			if not m.is_empty() and not (m.crack as PackedVector2Array).is_empty():
				var cr: PackedVector2Array = m.crack
				p = _origin + Vector2(m.at) + cr[_rng.randi() % cr.size()]
			_beats.append([float(times[i]), 0.45 + 0.1 * i, false, p])
		lead = BOSS_PRELUDE
	match style:
		Style.SNAP:
			_split_at = lead
			_split_dur = 0.22
			_beats.append([lead, 1.0, false, _centre])
		Style.BURN:
			_split_at = lead + 0.42
			_split_dur = 0.6
			_beats.append([lead, 0.45, false, _centre])
			_beats.append([lead + 0.42, 1.0, false, _centre])
		Style.IMPLODE:
			_split_at = lead + 0.42
			_split_dur = 0.25
			_beats.append([lead + 0.42, 1.0, false, _centre])


func _process(delta: float) -> void:
	if auto and not done:
		advance(delta)


## One step of the clock. Public so a film can step it 1/30 s a frame.
func advance(delta: float) -> void:
	if done:
		return
	var was := t
	t += delta
	for b in _beats:
		if not b[2] and t >= float(b[0]):
			b[2] = true
			_on_beat(float(b[1]), b[3])
	_step_motes(delta)
	if was < _split_at and t >= _split_at:
		_burst_sparks(_centre, 26 if not boss else 44, 210.0)
	if t >= duration:
		done = true
		finished.emit()
	queue_redraw()
	for c in get_children():
		(c as CanvasItem).queue_redraw()


func _on_beat(strength: float, at: Vector2) -> void:
	_flashes.append({p = at, t0 = t, s = strength})
	_burst_sparks(at, int(10 + 14 * strength), 150.0 * (0.6 + strength))
	broke.emit(strength)


# ------------------------------------------------------------------ motion

func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


## Where a major is now, in whole pixels.
func _major_pos(m: Dictionary) -> Vector2:
	var base := _origin + Vector2(m.at)
	var off := Vector2(drift(m.off, style))
	var k := 0.0
	if t >= _split_at:
		k = _ease_out((t - _split_at) / maxf(0.05, _split_dur * 2.2))
	var extra := Vector2.ZERO
	if style == Style.IMPLODE and t < _split_at and t > _split_at - 0.14:
		# The pull in before it lets go: one or two pixels toward the middle.
		var pull := (_centre - (base + Vector2((m.tex as ImageTexture).get_size()) * 0.5)).normalized()
		extra = (pull * 2.0).round()
	elif style == Style.BURN and t >= _split_at:
		# A slow sag after the break: the chunks keep drifting a little.
		extra = Vector2(0, (t - _split_at) * 1.5).round()
		extra.y = minf(extra.y, 1.0)
	return (base + off * k + extra).round()


func _shard_state(s: Dictionary) -> Dictionary:
	var start := _split_at
	if style == Style.BURN:
		# Peel off one by one rather than all at once.
		start += float(s.delay) * 0.55
	if t < start:
		return {p = _origin + Vector2(s.at), rot = 0, a = 1.0, out = false}
	var age := t - start
	var spd := (200.0 if style == Style.SNAP else (95.0 if style == Style.BURN else 170.0)) * float(s.speed)
	if boss:
		spd *= 0.8
	# Drag: distance travelled with exponential slowdown.
	var drag := 2.4
	var dist := spd * (1.0 - exp(-drag * age)) / drag
	var p: Vector2 = _origin + Vector2(s.at) + (s.dir as Vector2) * dist
	p.y += 6.0 * age * age   # a little settle, so it is not a perfect starburst
	var rot := (int(s.rot0) + int(floor(age * float(s.spin)))) % 4
	var life := 0.75 if style == Style.SNAP else (1.0 if style == Style.BURN else 0.85)
	var a := 1.0
	if age > life * 0.6:
		# Stepped fade, three levels.
		var f := (age - life * 0.6) / (life * 0.4)
		a = 0.66 if f < 0.34 else (0.33 if f < 0.67 else (0.0 if f >= 1.0 else 0.15))
	return {p = p.round(), rot = rot, a = a, out = age >= life}


## How hot the cracks are, 0..1, stepped in quarters so the glow holds rather
## than shimmering, and how far it has cooled (1 white-hot, 0 dull red).
func _crack_heat() -> Vector2:
	var lead := BOSS_PRELUDE if boss else 0.0
	var tt := t - lead
	var on := 0.0
	var heat := 1.0
	match style:
		Style.SNAP:
			on = 1.0 if tt < 0.15 else clampf(1.0 - (tt - 0.15) / 0.75, 0.0, 1.0)
			heat = clampf(1.0 - tt / 0.6, 0.0, 1.0)
		Style.BURN:
			on = clampf(tt / 0.3, 0.0, 1.0) if tt < 0.42 else clampf(1.0 - (tt - 0.9) / 0.7, 0.0, 1.0)
			heat = 1.0 if tt < 0.5 else clampf(1.0 - (tt - 0.5) / 0.9, 0.0, 1.0)
		Style.IMPLODE:
			on = clampf(tt / 0.35, 0.0, 1.0) if tt < 0.42 else clampf(1.0 - (tt - 0.5) / 0.7, 0.0, 1.0)
			heat = clampf(0.5 + tt, 0.0, 1.0) if tt < 0.42 else clampf(1.0 - (tt - 0.42) / 0.8, 0.0, 1.0)
	if boss and tt < 0.0:
		# The prelude: cracks wake one burst at a time.
		on = clampf((t + 0.2) / BOSS_PRELUDE, 0.0, 1.0) * 0.75
		heat = 0.7
	if boss and tt > 0.0 and tt < 0.6:
		on = minf(1.0, on + 0.25)
	return Vector2(snappedf(on, 0.25), snappedf(heat, 0.25))


# ------------------------------------------------------------------ motes

func _burst_sparks(at: Vector2, count: int, speed: float) -> void:
	for i in count:
		var a := _rng.randf() * TAU
		var v := Vector2(cos(a), sin(a)) * _rng.randf_range(0.35, 1.0) * speed
		_motes.append({p = at + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-3, 3)),
			v = v, age = 0.0, life = _rng.randf_range(0.14, 0.38), kind = 0})


## Fire: embers leave the hot cracks while they are hot.
func _step_motes(delta: float) -> void:
	var hv := _crack_heat()
	var rate := 0.0
	match style:
		Style.SNAP: rate = 40.0
		Style.BURN: rate = 230.0
		Style.IMPLODE: rate = 55.0
	if boss:
		rate *= 1.8
	rate *= hv.x
	var n := int(rate * delta + _rng.randf())
	for i in n:
		if _majors.is_empty():
			break
		var m: Dictionary = _majors[_rng.randi() % _majors.size()]
		var cr: PackedVector2Array = m.crack
		if cr.is_empty():
			continue
		var p := _major_pos(m) + cr[_rng.randi() % cr.size()]
		_motes.append({p = p, v = Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-26, -6)),
			age = 0.0, life = _rng.randf_range(0.35, 0.9), kind = 1,
			big = _rng.randf() < 0.3})
	var kept: Array = []
	for mo in _motes:
		mo.age += delta
		if mo.age >= mo.life:
			continue
		mo.p += mo.v * delta
		mo.v *= (0.86 if mo.kind == 0 else 0.97)
		kept.append(mo)
	_motes = kept


# ------------------------------------------------------------------ drawing

func _paint_body(ci: CanvasItem) -> void:
	var k := 0.0
	if t > _split_at:
		k = clampf((t - _split_at) / maxf(0.2, duration - _split_at - 0.15), 0.0, 1.0)
	# The hull cools to the wreck's grey in three steps, landing exactly on
	# the tint the slot gives a dead ship.
	var steps := snappedf(k, 0.34)
	var tint := Color.WHITE.lerp(WRECK_TINT, minf(1.0, steps * 1.0))
	if done:
		tint = WRECK_TINT
	for m in _majors:
		ci.draw_texture(m.tex, _major_pos(m), tint)
	for s in _shards:
		var st := _shard_state(s)
		if st.out or float(st.a) <= 0.0:
			continue
		var sz: Vector2 = Vector2(s.size)
		var c := tint
		c.a = float(st.a)
		ci.draw_set_transform(Vector2(st.p) + sz * 0.5, float(st.rot) * PI * 0.5, Vector2.ONE)
		ci.draw_texture(s.tex, -sz * 0.5, c)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint_light(ci: CanvasItem) -> void:
	if t <= 0.0:
		return
	var hv := _crack_heat()
	if hv.x > 0.0:
		# Multiplying an additive light's colour cools it: white-hot keeps all
		# three channels, cooling drops blue then green.
		var heat := hv.y
		var col := Color(hv.x, hv.x * (0.45 + 0.55 * heat), hv.x * (0.15 + 0.85 * heat * heat), 1.0)
		for m in _majors:
			ci.draw_texture(m.glow, _major_pos(m) - Vector2(GLOW_PAD, GLOW_PAD), col)
	# Flashes: up at once, held two frames, falling in three steps.
	for f in _flashes:
		var age := t - float(f.t0)
		var life := 0.28 if not boss else 0.36
		if age > life:
			continue
		var lvl := 1.0 if age < 0.07 else (0.6 if age < 0.14 else (0.32 if age < 0.21 else 0.14))
		lvl *= clampf(float(f.s), 0.3, 1.0)
		var sz := _flash_tex.get_size()
		# NEVER SCALED: a resampled dither is mush. Strength is brightness.
		ci.draw_texture(_flash_tex, (Vector2(f.p) - Vector2(sz) * 0.5).round(), Color(lvl, lvl, lvl, 1.0))
	for mo in _motes:
		var f2: float = mo.age / mo.life
		var c: Color
		if mo.kind == 0:
			c = HEAT_RAMP[0] if f2 < 0.4 else (HEAT_RAMP[2] if f2 < 0.75 else HEAT_RAMP[4])
			var p: Vector2 = (mo.p as Vector2).round()
			ci.draw_rect(Rect2(p, Vector2.ONE), c)
			var tail: Vector2 = ((mo.p as Vector2) - (mo.v as Vector2).normalized() * 2.0).round()
			if tail != p:
				ci.draw_rect(Rect2(tail, Vector2.ONE), c * Color(0.5, 0.5, 0.5, 1))
		else:
			c = HEAT_RAMP[1] if f2 < 0.25 else (HEAT_RAMP[2] if f2 < 0.5 else (HEAT_RAMP[3] if f2 < 0.8 else HEAT_RAMP[5]))
			var sz := Vector2(2, 2) if mo.get("big", false) and f2 < 0.5 else Vector2.ONE
			ci.draw_rect(Rect2((mo.p as Vector2).round(), sz), c)
