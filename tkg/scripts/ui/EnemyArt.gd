class_name EnemyArt
extends TextureRect

## Procedural enemy sprites. Ships get riveted industrial plating; fauna get
## dithered organic segments. The Hulk's "winding up" telegraph lights its ram
## prow — art and mechanics doing the same job.

const W := 240
const H := 120

var _img: Image
var _tex: ImageTexture

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Draw at native size, centred. KEEP_ASPECT_CENTERED rescales the texture to
	# whatever rect it is handed, so the enemy changed size whenever a side rail
	# opened — and scaled pixel art by arbitrary fractions while doing it.
	stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	custom_minimum_size = Vector2(W, H)
	_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	texture = _tex

func px(x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			var xx := x + i
			var yy := y + j
			if xx >= 0 and xx < W and yy >= 0 and yy < H:
				_img.set_pixel(xx, yy, c)

func dither(x: int, y: int, w: int, h: int, c: Color, density: float) -> void:
	var thresholds := [0.0, 0.5, 0.75, 0.25]
	for j in h:
		for i in w:
			var t: float = thresholds[(i % 2) + (j % 2) * 2]
			if t < density:
				px(x + i, y + j, 1, 1, c)

func rivets(x: int, y: int, count: int, step: int, c: Color) -> void:
	for i in count:
		px(x + i * step, y, 1, 1, c)

func set_enemy(e: Combat.EnemyState, telegraphing: bool) -> void:
	# Transparent: the encounter draws one starfield behind everything, and an
	# opaque fill turns the sprite into a box sitting on top of it.
	_img.fill(Color(0, 0, 0, 0))
	_starfield(77, 26)
	var wounded := float(e.hp) / float(maxi(1, e.max_hp))
	match e.template.art:
		&"cutter": _draw_cutter(wounded)
		&"hulk": _draw_hulk(wounded, telegraphing)
		_: _draw_fauna(wounded, e.max_hp > 60)
	if wounded < 0.3:
		_blend_rect(0, 0, W, H, Color(0.031, 0.043, 0.067, 0.35))
	_tex.update(_img)

func _draw_cutter(wounded: float) -> void:
	var outline := Color("#0a0e13")
	px(58, 58, 84, 11, Color("#2b2c36"))
	px(68, 48, 70, 13, Color("#3a3b47"))
	px(68, 48, 70, 2, Color("#4c4e5c"))
	dither(68, 50, 70, 4, Color("#4c4e5c"), 0.5)
	px(68, 60, 70, 1, outline)
	px(96, 48, 1, 21, outline)
	px(68, 64, 64, 5, Color("#1f2028"))
	px(138, 43, 18, 9, Color("#565866"))
	px(138, 64, 18, 9, Color("#565866"))
	px(146, 52, 11, 13, Color("#6b5a3a"))
	px(146, 52, 11, 1, Color("#8a7448"))
	px(156, 54, 13, 9, Color("#2a2b33"))
	px(169, 56, 4, 5, outline)
	px(128, 52, 7, 4, Color("#7fa8c4"))
	px(128, 52, 7, 1, Color("#c3d2e2"))
	px(60, 60, 5, 5, Color("#8a3a2a"))
	dither(50, 60, 10, 5, Color("#c2661f"), 0.5)
	rivets(72, 46, 13, 4, Color("#22232b"))
	if wounded < 0.5:
		px(104, 50, 8, 5, Color("#1a1010"))

func _draw_hulk(wounded: float, telegraphing: bool) -> void:
	var outline := Color("#0a0e13")
	px(44, 32, 112, 54, Color("#2f2b22"))
	px(48, 36, 104, 46, Color("#4a4436"))
	px(48, 36, 104, 4, Color("#5c5443"))
	px(48, 36, 104, 1, Color("#6f6551"))
	dither(48, 40, 104, 6, Color("#5c5443"), 0.45)
	px(48, 74, 104, 8, Color("#3a352a"))
	dither(48, 69, 104, 5, Color("#3a352a"), 0.4)
	for x in [74, 100, 126]:
		px(x, 36, 1, 46, outline)
	px(48, 58, 104, 1, outline)
	px(75, 36, 1, 46, Color("#6f6551"))
	px(101, 36, 1, 46, Color("#6f6551"))
	rivets(52, 38, 25, 4, Color("#332f26"))
	rivets(52, 80, 25, 4, Color("#332f26"))
	px(152, 42, 16, 30, Color("#7a6f58"))
	px(152, 42, 16, 2, Color("#8f8368"))
	px(168, 50, 4, 14, outline)
	px(58, 23, 24, 10, Color("#2b2720"))
	px(110, 23, 24, 10, Color("#2b2720"))
	px(58, 23, 24, 2, Color("#4a4436"))
	px(110, 23, 24, 2, Color("#4a4436"))
	for x in [54, 82, 110]:
		px(x, 52, 13, 9, Color("#8a5a2a"))
		px(x, 52, 13, 1, Color("#c28a3a"))
	if telegraphing:
		px(34, 48, 10, 22, Color("#8a4416"))
		px(28, 52, 8, 14, Color("#c2661f"))
		px(22, 55, 7, 7, Color("#ffb45e"))
		dither(12, 50, 12, 16, Color("#ffd28a"), 0.6)
	if wounded < 0.5:
		px(88, 60, 12, 8, Color("#1a1010"))

func _draw_fauna(wounded: float, big: bool) -> void:
	var segments := 13 if big else 11
	var seg_w := 10 if big else 9
	var span := 58 if big else 48
	for i in segments:
		var w := int(round(span - abs(i - segments / 2.0 + 0.5) * 4.2))
		px(38 + i * seg_w, 60 - int(w / 2.0), seg_w, w, Color("#22303f"))
	for i in segments:
		var w2 := int(round(span - abs(i - segments / 2.0 + 0.5) * 4.2))
		px(38 + i * seg_w, 60 - int(w2 / 2.0), seg_w, int(w2 * 0.5), Color("#2e3f52"))
	for i in segments:
		var w3 := int(round(span - abs(i - segments / 2.0 + 0.5) * 4.2))
		dither(38 + i * seg_w, 60 - int(w3 / 2.0), seg_w, 4, Color("#3d5670"), 0.6)
	for i in range(1, segments):
		px(38 + i * seg_w, 38, 1, 44, Color("#1a2532"))
	px(36, 38, 26, 11, Color("#2e3f52"))
	dither(28, 40, 10, 9, Color("#2e3f52"), 0.5)
	px(48, 52, 7, 5, Color("#4a6a86"))
	px(49, 53, 4, 2, Color("#9fc8e0"))
	for i in 6:
		px(60 + i * 12, 70, 8, 3, Color("#3d5670"))
	if wounded < 0.55:
		px(96, 48, 11, 7, Color("#5a2c44"))
		dither(88, 46, 20, 11, Color("#7a3a54"), 0.4)

func _starfield(seed_value: int, count: int) -> void:
	var s := seed_value
	for i in count:
		s = (s * 9301 + 49297) % 233280
		var x := int(float(s) / 233280.0 * W)
		s = (s * 9301 + 49297) % 233280
		var y := int(float(s) / 233280.0 * H)
		px(x, y, 1, 1, Color("#141c26"))

func _blend_rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			var xx := x + i
			var yy := y + j
			if xx >= 0 and xx < W and yy >= 0 and yy < H:
				_img.set_pixel(xx, yy, _img.get_pixel(xx, yy).lerp(c, c.a))
