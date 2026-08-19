class_name ShipView
extends TextureRect

## The ship sprite is a UI element: it shows your build, your heat, and your
## damage at a glance. Hull shape reads weight class; bolted-on modules read
## manufacturer via shape and palette. Everything is generated procedurally so
## the project runs with zero art assets — replace draw_ship() with real
## sprites + hardpoint Marker2D anchors when you have art.

const W := 240
const H := 120

var _img: Image
var _tex: ImageTexture

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Draw at native size, centred. KEEP_ASPECT_CENTERED rescales the texture to
	# whatever rect it is handed, so the ship changed size whenever a side rail
	# opened — and scaled pixel art by arbitrary fractions while doing it.
	stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	custom_minimum_size = Vector2(W, H)
	_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	texture = _tex

## Showroom mode: draw THIS hull rather than the player's, cold, undamaged and
## bare. The chassis select shows three of these side by side, and they have to
## be drawable before the ship they depict is the ship you own — so everything
## that reads live run state (heat glow, battle damage, fitted modules) is
## suppressed rather than reading whatever the current ship happens to be.
var preview: HullData = null

func setup_preview(h: HullData, view_height: int = 0) -> void:
	preview = h
	# A showroom sprite is never the thing you click — the card around it is.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if view_height > 0:
		# A hull occupies about a third of the canvas vertically and is centred
		# in it, so cropping symmetrically trims empty space without moving the
		# ship. Horizontally it is NOT centred, so the width stays full.
		#
		# EXPAND_IGNORE_SIZE is load-bearing and its absence is silent: a
		# TextureRect derives its minimum size from its TEXTURE, so without this
		# the control kept claiming the full 120 rows whatever custom_minimum_size
		# said. The card's own labels were pushed out of the button and drew on
		# top of the attribute block underneath it.
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		custom_minimum_size = Vector2(W, view_height)
		clip_contents = true
	refresh()

func _hull() -> HullData:
	return preview if preview != null else Run.hull

func _ready() -> void:
	if preview == null:
		Sig.ship_changed.connect(refresh)
		Sig.resources_changed.connect(refresh)
		Sig.player_combat_state_changed.connect(refresh)
	refresh()

func refresh() -> void:
	if _hull() == null:
		return
	draw_ship()
	_tex.update(_img)

# --------------------------------------------------------------- pixel helpers

func px(x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			var xx := x + i
			var yy := y + j
			if xx >= 0 and xx < W and yy >= 0 and yy < H:
				_img.set_pixel(xx, yy, c)

## Ordered 2x2 dither — how pixel art does gradients without banding.
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

# ------------------------------------------------------------------- the sprite

func draw_ship() -> void:
	# Transparent: the encounter draws one starfield behind everything, and an
	# opaque fill turns the sprite into a box sitting on top of it.
	_img.fill(Color(0, 0, 0, 0))
	_starfield(41, 30)

	var hull := _hull()
	var ratio := 0.0
	if preview == null and Run.heat_cap() > 0:
		ratio = minf(1.7, float(Run.heat) / float(Run.heat_cap()))
	var t := minf(1.0, ratio * 0.6)

	# Cold palette shifts warm as heat climbs — the whole visual thesis.
	var dark := lerp(Color("#12181f"), Color("#241a12"), t) as Color
	var a := lerp(Color("#1d242e"), Color("#2b2018"), t) as Color
	var b := lerp(Color("#2a3340"), Color("#463122"), t) as Color
	var c := lerp(Color("#39465a"), Color("#5a4028"), t) as Color
	var hi := lerp(Color("#4d5e75"), Color("#6f5033"), t) as Color
	var metal := lerp(Color("#42505f"), Color("#5e4632"), t) as Color
	var outline := Color("#0a0e13")

	# Manufacturer livery: a pigment shift on the plating, not a light.
	#
	# Hulls are built by somebody now, and two chassis in the same weight class
	# draw the same silhouette here — so colour is currently the only channel
	# saying whose ship this is. Kept deliberately weak (0.16) and kept OFF the
	# glow and core tones, because those are the heat channel and the art
	# direction allows exactly one source of warmth in frame: the reactor.
	# Paint is a property of the object; light is not.
	var maker: ManufacturerData = DB.manufacturers.get(hull.manufacturer)
	var livery: Color = maker.colour if maker != null else Color("#5a6a7a")
	if maker != null:
		a = a.lerp(livery, 0.10)
		b = b.lerp(livery, 0.16)
		c = c.lerp(livery, 0.16)
		hi = hi.lerp(livery, 0.16)
		metal = metal.lerp(livery, 0.12)

	var glow: Color
	var core: Color
	if ratio <= 0.03:
		glow = lerp(Color("#1a2029"), Color("#241a12"), t) as Color
		core = Color("#141a21")
	elif ratio < 1.0:
		glow = lerp(Color("#6b3210"), Color("#ff9d3d"), ratio) as Color
		core = lerp(Color("#a34a18"), Color("#ffd28a"), ratio) as Color
	else:
		glow = Color("#ffd9a0")
		core = Color("#fff4de")

	# Ambient warm wash: an overheating ship is the brightest thing in frame.
	if ratio > 0.15:
		var wash := Color(1.0, 0.616, 0.239, 0.05 * minf(1.0, ratio))
		_blend_rect(34, 30, 120, 56, wash)
	if ratio > 1.0:
		_blend_rect(20, 22, 190, 76, Color(1.0, 0.616, 0.239, 0.10))

	# Chassis dimensions read weight class.
	var hw := 82
	var hh := 30
	match hull.weight:
		HullData.Weight.LIGHT:
			hw = 62
			hh = 22
		HullData.Weight.HEAVY:
			hw = 104
			hh = 38
	var hx := 40
	var hy := 60 - hh / 2

	# Thruster and engine block
	px(hx - 14, hy + hh / 2 - 7, 10, 14, a)
	px(hx - 18, hy + hh / 2 - 4, 5, 8, dark)
	px(hx - 22, hy + hh / 2 - 3, 4, 6, glow)
	if ratio > 0.25:
		dither(hx - 29, hy + hh / 2 - 3, 7, 6, core, minf(1.0, ratio * 0.9))

	# Main hull, top-lit with dithered shading
	px(hx - 6, hy + 2, 12, hh - 4, a)
	px(hx, hy, hw, hh, b)
	px(hx, hy, hw, 4, c)
	px(hx, hy, hw, 1, hi)
	# A painted stripe where the top face turns down. One pixel of the maker's
	# actual colour, so the livery is legible even at the tint strength above.
	if maker != null:
		px(hx, hy + 4, hw, 1, livery.darkened(0.25))
	dither(hx, hy + 5, hw, 4, c, 0.5)
	px(hx, hy + hh - 6, hw, 6, a)
	dither(hx, hy + hh - 10, hw, 4, a, 0.45)

	# Panel seams: dark line plus a light catch-edge is what makes plating read.
	var panels := 3
	if hull.weight == HullData.Weight.HEAVY:
		panels = 4
	elif hull.weight == HullData.Weight.LIGHT:
		panels = 2
	for i in range(1, panels):
		var pxx := hx + int(hw * float(i) / panels)
		px(pxx, hy, 1, hh, outline)
		px(pxx + 1, hy, 1, hh, c)
	rivets(hx + 4, hy + 2, int(hw / 5.0), 5, dark)
	rivets(hx + 4, hy + hh - 3, int(hw / 5.0), 5, dark)

	# Bridge and nose
	px(hx + hw, hy + 3, 18, hh - 8, b)
	px(hx + hw, hy + 3, 18, 3, c)
	px(hx + hw + 5, hy + 9, 9, 6, outline)
	px(hx + hw + 6, hy + 10, 7, 4, lerp(Color("#4a6a86"), Color("#7a5a34"), t) as Color)
	px(hx + hw + 6, hy + 10, 7, 1, lerp(Color("#7fa8c4"), Color("#c39a5a"), t) as Color)
	px(hx + hw + 18, hy + 8, 7, hh - 16, a)

	# Vent strips: the primary heat instrument, four escalating stages.
	var vents := 3
	if hull.weight == HullData.Weight.HEAVY:
		vents = 4
	elif hull.weight == HullData.Weight.LIGHT:
		vents = 2
	for i in vents:
		var vx := hx + 8 + int(i * (hw - 20) / float(vents))
		px(vx - 1, hy + 7, 9, hh - 14, outline)
		px(vx, hy + 8, 7, hh - 16, dark)
		px(vx + 1, hy + 9, 5, hh - 18, glow)
		px(vx + 2, hy + 11, 3, hh - 22, core)
		if ratio > 0.6:
			dither(vx - 3, hy + 5, 13, hh - 10, core, (ratio - 0.6) * 0.8)

	_draw_modules(hx, hy, hw, hh, metal, outline)

	# Late-stage heat: lit seams, then hull-wide dither.
	if ratio > 0.5:
		px(hx + 4, hy + hh - 8, hw - 8, 1, glow)
	if ratio > 0.85:
		px(hx, hy - 1, hw, 1, core)
	if ratio > 1.0:
		dither(hx, hy, hw, hh, core, (ratio - 1.0) * 0.5)

	# Battle damage
	# A showroom hull is undamaged by definition: these are ships you have not
	# bought yet, not the one you are flying.
	var dmg := 0.0 if preview != null else 1.0 - float(Run.hp) / float(maxi(1, Run.max_hp()))
	if dmg > 0.3:
		px(hx + int(hw * 0.4), hy + 6, 7, 6, Color("#1a1010"))
	if dmg > 0.6:
		px(hx + int(hw * 0.65), hy + hh - 12, 9, 7, Color("#1a1010"))
		px(hx + int(hw * 0.2), hy + 2, 6, 4, Color("#3a1a10"))

## Installed modules are bolted onto hardpoints in their maker's colours.
func _draw_modules(hx: int, hy: int, hw: int, hh: int, metal: Color, outline: Color) -> void:
	var weapons: Array[ModuleData] = []
	var systems: Array[ModuleData] = []
	var utils: Array[ModuleData] = []
	for m in ([] as Array[ModuleData] if preview != null else Run.installed):
		match m.slot:
			ModuleData.Slot.WEAPON: weapons.append(m)
			ModuleData.Slot.SYSTEM: systems.append(m)
			_: utils.append(m)

	for i in weapons.size():
		var col := DB.manufacturer_colour(weapons[i].manufacturer)
		var dark := lerp(col, Color("#0a0e13"), 0.55) as Color
		var lite := lerp(col, Color.WHITE, 0.25) as Color
		match i:
			0:  # dorsal ordnance
				px(hx + 14, hy - 10, 30, 10, dark)
				px(hx + 14, hy - 10, 30, 3, col)
				px(hx + 14, hy - 10, 30, 1, lite)
				px(hx + 44, hy - 8, 44, 6, metal)
				px(hx + 44, hy - 8, 44, 1, lite)
				px(hx + 88, hy - 7, 3, 4, outline)
			1:  # ventral twin barrels
				px(hx + hw - 24, hy + hh, 26, 8, dark)
				px(hx + hw - 24, hy + hh, 26, 2, col)
				px(hx + hw + 2, hy + hh + 1, 30, 3, metal)
				px(hx + hw + 2, hy + hh + 5, 30, 3, metal)
				px(hx + hw + 2, hy + hh + 1, 30, 1, lite)
			2:  # aft mount
				px(hx + 6, hy + hh, 20, 10, dark)
				px(hx + 6, hy + hh, 20, 2, col)
				px(hx + 26, hy + hh + 3, 22, 4, metal)
				px(hx + 48, hy + hh + 4, 3, 2, outline)
			_:  # upper spine
				px(hx + 30, hy - 19, 16, 9, dark)
				px(hx + 30, hy - 19, 16, 2, col)
				px(hx + 46, hy - 17, 26, 4, metal)

	for i in systems.size():
		var col2 := DB.manufacturer_colour(systems[i].manufacturer)
		var bx := hx + 10 + i * 22
		px(bx, hy + hh - 4, 16, 7, lerp(col2, Color("#0a0e13"), 0.5) as Color)
		px(bx, hy + hh - 4, 16, 2, col2)
		px(bx + 2, hy + hh - 1, 3, 2, lerp(col2, Color.WHITE, 0.3) as Color)

	for i in utils.size():
		var col3 := DB.manufacturer_colour(utils[i].manufacturer)
		var ux := hx + 18 + i * 20
		px(ux, hy - 7, 5, 7, lerp(col3, Color("#0a0e13"), 0.4) as Color)
		px(ux + 1, hy - 11, 3, 5, col3)
		px(ux + 1, hy - 13, 3, 2, lerp(col3, Color.WHITE, 0.4) as Color)

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
				var base := _img.get_pixel(xx, yy)
				_img.set_pixel(xx, yy, base.lerp(c, c.a))
