class_name Rings
extends RefCounted

## A WORLD'S RINGS ACROSS THEIR WIDTH: how thick and how bright the ring is at
## each distance from the world's centre, rolled from the world's seed, as one
## strip of texture `planet_ring.gdshader` draws the ring from and
## `planet.gdshader` reads to lay the ring's shadow across the world.
##
## Three looks, for Jon to pick from (Jon: "can these rings be a bit nicer?
## they're flat"):
##   ICY    -- bright and many-ringed, Saturn's: a faint inner sheet, a broad
##             dense ring, a clear dark gap, an outer ring with a thin gap of
##             its own, and a narrow ring outside it all.
##   DUSTY  -- two or three broad soft bands with a soft trough between, and a
##             thin haze reaching out past them; thick enough that the world's
##             shadow cuts a black notch out of them.
##   DARK   -- Uranus's: a handful of thin dark rings and one bright one.
##
## THE GAP HAS TO SHOW. A real gap is a hair wide; on the map a world's ring is
## ten blocks across, and a gap thinner than a block averages away into a slightly
## dimmer ring. So every feature here is at least `px` wide, `px` being how far
## one block of the picture reaches across the ring at the world's size: the
## gap stays a dark line a block wide however small the world is drawn, and the
## dark rings stay a block wide with a block between them, or are left out.

enum Look { DOTS, ICY, DUSTY, DARK }

## Texels across the ring's width.
const N := 256

## The world's own colours for its rings; anything else grey.
const RAMP_FOR := {&"banded": &"banded", &"icegiant": &"icegiant", &"storm": &"storm",
	&"violet": &"violet", &"hotjup": &"haze"}

static var _cache := {}


## A world's rings in look `look`, at `px` (one block's width, in world radii).
## Returns {tex, rin, rout, ramp_a, ramp_b, cast, dark_shadow}: the strip
## (red: how much of the light the ring stops; green: how bright its stuff is;
## blue: 1 where it is drawn in the second, dark ramp), the ring's inner and outer
## edge in world radii, its two ramps, how dark its shadow on the world is, and
## how dark the world's shadow on it.
static func build(look: int, world: StringName, seed: int, px: float) -> Dictionary:
	# the block width in quarter-octave steps, so a zoom easing in does not
	# build a new strip every frame
	var pq := pow(2.0, round(log(maxf(px, 1e-4)) / log(2.0) * 4.0) / 4.0)
	var key := "%d:%s:%d:%.5f" % [look, world, seed, pq]
	if _cache.has(key):
		return _cache[key]
	var R := Worlds.XRng.new(float(seed) * 131.0 + 977.0 + float(look) * 7.0)
	var out: Dictionary
	match look:
		Look.DUSTY:
			out = _dusty(R, pq)
		Look.DARK:
			out = _dark(R, pq)
		_:
			out = _icy(R, pq)
	out.ramp_a = Worlds.ramp_id(RAMP_FOR.get(world, &"moon"))
	out.ramp_b = Worlds.ramp_id(&"graphite")
	if _cache.size() > 64:
		_cache.clear()
	_cache[key] = out
	return out


# ---------------------------------------------------------------- the strip
class _Strip extends RefCounted:
	var rin: float
	var rout: float
	var op := PackedFloat32Array()
	var al := PackedFloat32Array()
	var dk := PackedFloat32Array()

	func _init(a: float, b: float) -> void:
		rin = a
		rout = b
		op.resize(N)
		al.resize(N)
		dk.resize(N)

	func rho(i: int) -> float:
		return rin + (float(i) + 0.5) / float(N) * (rout - rin)

	## how far inside [a, b] the point is, with edges `soft` wide (0: hard)
	static func inside(x: float, a: float, b: float, soft: float) -> float:
		if soft <= 0.0:
			return 1.0 if (x >= a and x < b) else 0.0
		return clampf((x - a) / soft + 0.5, 0.0, 1.0) * clampf((b - x) / soft + 0.5, 0.0, 1.0)

	## a band of ring: where it is, it sets the thickness and brightness
	func band(a: float, b: float, o: float, l: float, soft: float = 0.0, dark: float = 0.0) -> void:
		for i in N:
			var k := inside(rho(i), a, b, soft)
			if k > 0.0:
				op[i] = lerpf(op[i], o, k)
				al[i] = lerpf(al[i], l, k)
				dk[i] = lerpf(dk[i], dark, k)

	## a gap: thins whatever is there
	func gap(a: float, b: float, keep: float, soft: float = 0.0) -> void:
		for i in N:
			var k := inside(rho(i), a, b, soft)
			op[i] *= lerpf(1.0, keep, k)

	## fine ringlets: the thickness wavering by `amp` over a few wavelengths,
	## and the brightness by `lamp` (a ring too thick to thin shows its
	## ringlets as bands of brightness, a ramp step apart)
	func waver(a: float, b: float, amp: float, R: Worlds.XRng, shortest: float, lamp: float = -1.0) -> void:
		if lamp < 0.0:
			lamp = amp * 0.35
		var waves: Array[Vector3] = []
		for w in 4:
			waves.append(Vector3(maxf(shortest, 0.012 + R.next() * 0.06), R.next() * TAU, 0.4 + R.next() * 0.6))
		for i in N:
			var x := rho(i)
			if x < a or x >= b:
				continue
			var s := 0.0
			var n := 0.0
			for wv in waves:
				s += sin(x / wv.x * TAU + wv.y) * wv.z
				n += wv.z
			op[i] = clampf(op[i] * (1.0 + amp * s / n), 0.0, 1.0)
			al[i] = clampf(al[i] * (1.0 + lamp * s / n), 0.0, 1.0)

	func texture() -> ImageTexture:
		var img := Image.create(N, 1, false, Image.FORMAT_RGBA8)
		for i in N:
			img.set_pixel(i, 0, Color(clampf(op[i], 0.0, 1.0), clampf(al[i], 0.0, 1.0), clampf(dk[i], 0.0, 1.0), 1.0))
		return ImageTexture.create_from_image(img)


## ICY: Saturn's order, each edge moved a little by the seed.
static func _icy(R: Worlds.XRng, px: float) -> Dictionary:
	var c0 := 1.24 + R.next() * 0.04
	var b0 := 1.5 + R.next() * 0.06
	var b1 := 1.9 + R.next() * 0.06
	var gw := maxf(0.07 + R.next() * 0.03, px * 1.3)
	var a0 := b1 + gw
	var a1 := a0 + 0.22 + R.next() * 0.06
	var fw := maxf(0.012, px * 0.8)
	var f0 := a1 + maxf(0.05, px * 1.6)
	var S := _Strip.new(1.2, f0 + fw + 0.02)
	# the faint inner sheet, many thin ringlets
	S.band(c0, b0, 0.22, 0.5)
	S.waver(c0, b0, 0.8, R, px * 0.7)
	# the broad dense ring, brightest in its middle
	S.band(b0, b1, 0.9, 0.86)
	S.band(b0 + (b1 - b0) * 0.35, b0 + (b1 - b0) * 0.8, 0.97, 0.94, 0.06)
	S.waver(b0, b1, 0.18, R, px * 1.2, 0.16)
	# the outer ring, a little thinner and a little duller
	S.band(a0, a1, 0.65, 0.82)
	S.waver(a0, a1, 0.12, R, px * 1.2, 0.12)
	# its own thin gap, where there is room to see one
	var ew := maxf(0.015, px * 0.8)
	if ew < (a1 - a0) * 0.3:
		var e := a0 + (a1 - a0) * (0.78 + R.next() * 0.08)
		S.gap(e - ew * 0.5, e + ew * 0.5, 0.1)
	# the narrow ring outside it all
	S.band(f0, f0 + fw, 0.75, 0.95)
	return {"tex": S.texture(), "rin": S.rin, "rout": S.rout, "cast": 0.82, "dark_shadow": 0.88}


## DUSTY: broad soft bands, a soft trough, a haze past them.
static func _dusty(R: Worlds.XRng, px: float) -> Dictionary:
	var S := _Strip.new(1.32, 2.75)
	var soft := maxf(0.07, px * 1.2)
	var n := 2 + int(R.next() * 2.0)
	var x := 1.42 + R.next() * 0.06
	var span := 2.25 - x
	for i in n:
		var w := span / float(n) * (0.7 + R.next() * 0.25)
		S.band(x, x + w, 0.6 + R.next() * 0.3, 0.6 + R.next() * 0.18, soft)
		x += span / float(n)
	# the trough between the first two bands, never quite empty
	var tw := maxf(0.06, px * 1.5)
	var tx := 1.42 + span / float(n) * (0.9 + R.next() * 0.15)
	S.gap(tx - tw * 0.5, tx + tw * 0.5, 0.3, soft * 0.6)
	S.waver(1.4, 2.3, 0.1, R, px)
	# the haze, thinning outward
	for i in N:
		var r := S.rho(i)
		if r > 2.15:
			var h := 0.2 * clampf(1.0 - (r - 2.2) / 0.5, 0.0, 1.0)
			if S.op[i] < h:
				S.op[i] = h
				S.al[i] = 0.55
	return {"tex": S.texture(), "rin": S.rin, "rout": S.rout, "cast": 0.95, "dark_shadow": 1.0}


## DARK: thin dark rings, a block wide with a block between, and one bright one.
static func _dark(R: Worlds.XRng, px: float) -> Dictionary:
	var S := _Strip.new(1.5, 2.2)
	var lo := 1.58
	var bright := 2.0 + R.next() * 0.06
	var bw := maxf(0.035, px * 1.25)
	var w := maxf(0.014, px * 0.85)
	var step := maxf(w * 2.2, px * 2.0)
	# a faint sheet of dust between them
	S.band(lo, bright, 0.05, 0.3)
	var want := 5 + int(R.next() * 4.0)
	var x := lo
	var placed := 0
	while placed < want and x + w < bright - step:
		S.band(x, x + w, 0.85, 0.66 + R.next() * 0.16, 0.0, 1.0)
		placed += 1
		x += step * (1.0 + R.next() * 1.4)
	# the bright one, outermost, wider on one side than the other in life;
	# here a little brighter at its middle
	S.band(bright, bright + bw, 0.95, 0.9)
	return {"tex": S.texture(), "rin": S.rin, "rout": S.rout, "cast": 0.7, "dark_shadow": 0.9}


## The harnesses' switch, `ring=A|B|C|DOTS` (ICY, DUSTY, DARK, the old dots) on
## the command line; none, the game's own (ICY).
static func look_from_args() -> int:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("ring="):
			return {"A": Look.ICY, "B": Look.DUSTY, "C": Look.DARK, "DOTS": Look.DOTS}.get((a as String).substr(5).to_upper(), Look.ICY)
	return Look.ICY
