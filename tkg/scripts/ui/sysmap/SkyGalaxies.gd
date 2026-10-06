extends Node2D

## THE DISTANT GALAXIES behind a system's sky (Jon: "No distant stars or
## galaxies parallax in the background of the sector"): a few small sprites --
## face-on spirals, round ellipticals, thin edge-ons -- seeded per system, at
## infinity like the rest of the sky (they never zoom), sliding a little as
## the map pans, behind every star field and every cloud. Each is worked out
## once as a sprite of whole 2x2 blocks; drawn as light, faint, a warm core
## and bluish arms (PAINTED: in B's own ramps, the arm blues and the bulge's
## creams, hand-painted in bands).

## the tile they wrap round, as the star fields' (`SystemView._Field`)
const TW := 1280.0
const TH := 800.0

## how far they slide for a pixel of pan (the farthest thing in the sky)
var rate := 0.015
var off := Vector2.ZERO
var _sprites: Array = []

## their tones, for a cut palette to keep (a few blocks each, the cut never finds them)
const TONES := [Vector3(0.20, 0.17, 0.15), Vector3(0.42, 0.34, 0.27), Vector3(0.72, 0.58, 0.44), Vector3(0.95, 0.80, 0.62),
	Vector3(0.13, 0.15, 0.24), Vector3(0.25, 0.29, 0.44), Vector3(0.40, 0.47, 0.68)]
const ARM := [Color("#0f1230"), Color("#1d2a5c"), Color("#2f4c91"), Color("#4f7bc6"), Color("#86b2e8")]
const BULGE := [Color("#5e1c1e"), Color("#9c3a1e"), Color("#d26a26"), Color("#f0a040"), Color("#fbd27a"), Color("#fff3d0")]


## A few galaxies for the system with this seed; `painted`: in B's ramps, banded.
func setup(seed: int, painted: bool) -> void:
	var R := Worlds.XRng.new(float(seed) * 7.0 + 31.0)
	_sprites.clear()
	var n := 5 + int(R.next() * 3.99)
	for k in n:
		var kind := int(R.next() * 2.99)
		# blocks across: mostly small, now and then a big one
		var size := 9 + int(pow(R.next(), 1.5) * 12.0)
		if kind == 2:
			size += 3
		var img := _sprite(kind, size, R, painted)
		var tex := ImageTexture.create_from_image(img)
		# (half of them where the map's window looks at the opening, the rest anywhere
		# round the tile: placed at random, a system's few all fell outside it)
		var gx := R.next()
		var gy := R.next()
		if k % 2 == 0:
			_sprites.append([(TW - 960.0) / 2.0 + 180.0 + gx * 600.0, (TH - 540.0) / 2.0 + 60.0 + gy * 400.0, tex])
		else:
			_sprites.append([gx * TW, gy * TH, tex])
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


## One galaxy, `size` blocks across, drawn at 2 px a block.
func _sprite(kind: int, size: int, R: Worlds.XRng, painted: bool) -> Image:
	var rot := R.next() * TAU
	var squash := 0.45 + 0.5 * R.next() if kind == 0 else (0.55 + 0.4 * R.next() if kind == 1 else 0.16 + 0.08 * R.next())
	var wind := 2.2 + 1.6 * R.next()
	var bright := 0.55 + 0.35 * R.next()
	var img := Image.create(size * 2, size * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (float(size) - 1.0) * 0.5
	var cr := cos(rot)
	var sr := sin(rot)
	for by in size:
		for bx in size:
			var dx := (float(bx) - c) / maxf(c, 0.5)
			var dy := (float(by) - c) / maxf(c, 0.5)
			# into the galaxy's own frame: turned, then the tilt undone
			var u := dx * cr + dy * sr
			var v := (-dx * sr + dy * cr) / squash
			var r := sqrt(u * u + v * v)
			if r > 1.05:
				continue
			var core := exp(-r * r / 0.035)
			var body := 0.0
			var arm := 0.0
			if kind == 0:
				# two arms winding out from the core
				var a := atan2(v, u)
				arm = pow(0.5 + 0.5 * cos(2.0 * a - wind * log(maxf(r, 0.05)) * 2.0), 3.0) * exp(-r * 1.6) * smoothstep(0.08, 0.25, r)
				body = exp(-r * 2.6) * 0.35
			elif kind == 1:
				body = exp(-r * r / 0.22)
			else:
				body = exp(-r * r / 0.30) * 0.8 + exp(-pow(v * squash * 3.0, 2.0)) * exp(-r * 1.4) * 0.5
			var I := (core * 1.2 + body * 0.9 + arm * 1.5) * bright
			if I < 0.035:
				continue
			var warm := clampf(core * 1.4 + body * (0.5 if kind != 0 else 0.25), 0.0, 1.0)
			var col: Color
			if painted:
				# banded: the bulge's creams in the middle, the arm blues outside
				var lv := clampf(I * 2.2, 0.0, 0.999)
				if warm > 0.5:
					col = BULGE[clampi(int(lv * 4.0) + 1, 0, BULGE.size() - 1)]
				else:
					col = ARM[clampi(int(lv * 4.0) + 1, 0, ARM.size() - 1)]
				col = col * clampf(0.45 + I, 0.0, 1.0)
			else:
				var cw := Color(1.0, 0.82, 0.62).lerp(Color(0.62, 0.72, 1.0), 1.0 - warm)
				col = cw * clampf(I, 0.0, 0.9)
			col.a = 1.0
			for py in 2:
				for px in 2:
					img.set_pixel(bx * 2 + px, by * 2 + py, col)
	return img


func _draw() -> void:
	var ox := (TW - 960.0) / 2.0
	var oy := (TH - 540.0) / 2.0
	for s: Array in _sprites:
		var tex: ImageTexture = s[2]
		var p := Vector2(fposmod(float(s[0]) + off.x, TW) - ox, fposmod(float(s[1]) + off.y, TH) - oy)
		p = (p / 2.0).floor() * 2.0
		var sz := tex.get_size()
		if p.x < -sz.x or p.y < -sz.y or p.x > 962.0 or p.y > 542.0:
			continue
		draw_texture(tex, p)
