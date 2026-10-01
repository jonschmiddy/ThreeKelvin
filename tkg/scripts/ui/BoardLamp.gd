class_name BoardLamp
extends Control

## THE LIGHT ON THE HIRING BOARD, and the room it leaves dim.
##
## Jon, 2026-10-01, after 80 generated boards lost to the coded one ("the
## aesthetic of the computed placeholder is kinda the vibe i liked"): keep the
## board, light it, dust in the light, and a power-on once a docking like the
## Shipyard and the Laboratory. Then, of a hanging lamp: "why dont we just use
## the lighting from the labs or something like that. flourescent bars"; and
## of the bars on the rail, "no light bar and just have it lit from behind?
## same flicker and all". So the board is lit by tubes nobody sees, over the
## viewer's shoulder: one at an unclaimed station, two at an outpost or a
## settlement, three in a city or a capital, in the level's colour.
##
## THE TUBES BEHAVE LIKE THE LAB'S. On the power-on they strike one after
## another, the fluorescent ping; after that each stutters now and then on its
## own clock (`YardLight.stutter`, the lab's tubes), and an unclaimed station's
## one tube is the tiredest.
##
## A LAYER OVER EVERYTHING ON THE BOARD, notices included, because a light
## lights the paper pinned to the board as much as the board. It takes no
## clicks.
##
## THE LIGHT IS A MAP, NOT A HAZE: banded, dithered at each band's edge, worked
## out once for the board's size and level and kept as two textures -- the
## room's dark and the tubes' light, added -- that the tubes only scale.
##
## THE NOTICES HAVE TO STAY READABLE. They are the deck. So the room never goes
## more than DARK away from the light, and dead tubes take only OFF more.

## The station's development level (MapGen.Development).
var dev := 2:
	set(v):
		dev = v
		_built = Vector2.ZERO
## Seconds on the real clock when the lights powered on, or long ago.
var _boot_at := -1000.0
var _dark: ImageTexture = null
var _glow: ImageTexture = null
var _built := Vector2.ZERO
## The tubes' light, ADDED: a layer of its own because a blend mode belongs to
## a canvas item, not to a draw call.
var _add: Control = null

## The most the room loses, at the board's far corners.
const DARK := 0.48
## How much more it loses while the tubes are out.
const OFF := 0.26
## How much light the tubes add at the heart of the pool, in their colour.
const TINT := 0.30
const MOTES := 46
const SHADE := Color("#070a10")
## Per level: how many tubes light it, their colour, and how often one stutters.
const BARS := [
	{"n": 1, "c": Color("#fff0cc"), "per": 4.5},
	{"n": 2, "c": Color("#e8eef8"), "per": 8.0},
	{"n": 2, "c": Color("#ffe2b4"), "per": 9.0, "tint": 0.3},
	{"n": 3, "c": Color("#7fe3ff"), "per": 10.0},
	{"n": 3, "c": Color("#fff2d0"), "per": 13.0},
]
## Power-on: dark for WAIT, then each tube strikes for STRIKE, GAP after the last.
const WAIT := 0.35
const STRIKE := 0.55
const GAP := 0.32
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add = Control.new()
	_add.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add.material = mat
	_add.draw.connect(_draw_add)
	add_child(_add)


## Strike the tubes, or -- `settled`, back on a deck already powered this
## docking -- have them already lit.
func power_on(settled: bool = false) -> void:
	_boot_at = _now() - (60.0 if settled else 0.0)
	queue_redraw()


static func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _process(_dt: float) -> void:
	if is_visible_in_tree():
		queue_redraw()
		_add.queue_redraw()


func _bars() -> Dictionary:
	return BARS[clampi(dev, 0, BARS.size() - 1)]


## How lit a point is, 0 to 1. THE LIGHTS ARE BEHIND YOU (Jon: "cant we have
## like no light bar and just have it lit from behind? same flicker and all"):
## no fixture on the board, a broad pool on its face from lights over the
## viewer's shoulder, brightest a little above the middle and falling away to
## the frame.
func light_at(x: float, y: float) -> float:
	var dx := (x - size.x * 0.5) / (size.x * 0.66)
	var dy := (y - size.y * 0.42) / (size.y * 0.78)
	return clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0)


## Each tube's brightness now, 0 to 1: dark, then striking in turn on the
## power-on; after that lit, stuttering now and then on its own clock.
func tube(k: int) -> float:
	var u := _now() - _boot_at
	var from := WAIT + float(k) * GAP
	if u < from:
		return 0.0
	if u < from + STRIKE:
		return YardLight.strikes(u, from, STRIKE, 3.1 + float(k) * 1.7)
	return YardLight.stutter(_now(), 0.7 + float(k) * 2.3, float(_bars()["per"]))


## The room's light: the tubes together.
func level() -> float:
	var n := int(_bars()["n"])
	var sum := 0.0
	for k in n:
		sum += tube(k)
	return sum / float(n)


func _build() -> void:
	var w := int(size.x)
	var h := int(size.y)
	_built = size
	if w < 8 or h < 8:
		return
	var dark := PackedByteArray()
	dark.resize(w * h * 4)
	var glow := PackedByteArray()
	glow.resize(w * h * 4)
	var sr := int(SHADE.r8)
	var sg := int(SHADE.g8)
	var sb := int(SHADE.b8)
	for y in h:
		for x in w:
			var L := light_at(float(x), float(y))
			# five bands, each edge dithered: a light map, not a gradient
			var band := clampf(floorf(L * 5.0 + float(BAYER[y % 4][x % 4]) / 16.0) / 5.0, 0.0, 1.0)
			var i := (y * w + x) * 4
			dark[i] = sr
			dark[i + 1] = sg
			dark[i + 2] = sb
			dark[i + 3] = int(255.0 * DARK * (1.0 - band))
			glow[i] = 255
			glow[i + 1] = 255
			glow[i + 2] = 255
			glow[i + 3] = int(255.0 * TINT * band * band * band)
	_dark = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, dark))
	_glow = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, glow))


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	if dev >= 3:
		_draw_screen()
		return
	if _built != size or _dark == null:
		_build()
	var v := level()
	var lc: Color = _bars()["c"]
	draw_texture(_dark, Vector2.ZERO)
	if v < 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(SHADE.r, SHADE.g, SHADE.b, OFF * (1.0 - v)))
	_motes(v, lc)


## A SCREEN LIGHTS ITSELF: in a city or a capital the board is a panel, so
## there is no room light on it and no dust in front of it. Its power-on is the
## panel coming on -- black, a flash of its backlight, the picture -- and the
## tubes' stutters are its backlight dipping, a bright line rolling through.
func _draw_screen() -> void:
	var u := _now() - _boot_at
	var v := level()
	var dim := 1.0 - v
	# THE GLASS ONLY: the casing is not lit from inside, so it does not flicker
	# with the backlight (Jon: "the frame shouldn't flicker lol")
	var e := PostingBoard.FRAME_W
	var g := Rect2(e, e, size.x - e * 2.0, size.y - e * 2.0)
	if u < WAIT:
		dim = 1.0
	elif u < WAIT + 0.12:
		# the backlight catching: a white flash before the picture
		draw_rect(g, Color(0.8, 0.95, 1.0, 0.35))
		dim = 0.0
	if dim > 0.0:
		draw_rect(g, Color(0.0, 0.01, 0.03, 0.85 * dim))
	# scanlines, faint, across everything shown
	var y := g.position.y
	while y < g.end.y:
		draw_rect(Rect2(g.position.x, y, g.size.x, 1.0), Color(0, 0, 0, 0.07))
		y += 2.0
	if v < 0.9 and u > WAIT + STRIKE:
		var ly := g.position.y + fposmod(_now() * 240.0, g.size.y - 2.0)
		draw_rect(Rect2(g.position.x, floorf(ly), g.size.x, 2.0), Color(0.6, 0.9, 1.0, 0.25))


func _draw_add() -> void:
	if _glow == null or dev >= 3:
		return
	var lc: Color = _bars()["c"]
	# a white board throws the light back: less added, or it glares blank
	var k := float(_bars().get("tint", 1.0))
	_add.draw_texture(_glow, Vector2.ZERO, Color(lc.r, lc.g, lc.b, level() * k))


## DUST IN THE LIGHT, the shop rooms' way (`ShopScene._draw_glow`): each mote
## drifts on the clock and shows only where the light reaches, a pixel of its
## light, fainter or stronger by its seed.
func _motes(v: float, lc: Color) -> void:
	if v <= 0.05:
		return
	var t := _now()
	for k in MOTES:
		var sx := ShopLight.hash1(float(k) * 1.37 + 0.11)
		var sy := ShopLight.hash1(float(k) * 2.71 + 5.3)
		var sp := 0.15 + 0.5 * ShopLight.hash1(float(k) * 3.91 + 1.7)
		var x := fposmod(sx * size.x + t * sp * 7.0 + 13.0 * sin(t * 0.21 + sx * 31.0), size.x)
		var y := fposmod(sy * size.y - t * sp * 4.0 + 9.0 * sin(t * 0.17 + sy * 27.0), size.y)
		var L := light_at(x, y)
		if L < 0.35:
			continue
		var a := minf(0.85, (L - 0.25) * v * (0.5 + 0.6 * ShopLight.hash1(float(k) * 7.7)))
		draw_rect(Rect2(floorf(x), floorf(y), 1.0, 1.0), Color(lc.r, lc.g, lc.b, a))
