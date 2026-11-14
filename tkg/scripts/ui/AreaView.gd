class_name AreaView
extends Control

## Every node type gets a lit picture before real art exists, by ART_CONTRACT's two-plane rule.
## Why: docs/why/AreaView.md#place-pictures

var node: MapGen.MapNode
## Where in its system this picture stands; `ANY` draws the whole system, as the sheets do.
var site := ANY
const ANY := -99

## Six value stops from the ART_CONTRACT table, so stations here and on the chart share steel.
var _grey: Array[Color] = [Color("#141721"), Color("#1e202a"), Color("#2e313e"),
	Color("#424758"), Color("#5c6376"), Color("#80889e")]
## Wreck ramp is cold but not near black, or the derelict reads as a hole.
var _dead: Array[Color] = [Color("#0c1219"), Color("#16202b"), Color("#22303f"),
	Color("#33455a"), Color("#465b73"), Color("#5f7890")]
var _heat: Array[Color] = [Color("#5c280c"), Color("#964214"), Color("#cc641c"),
	Color("#ffa63c"), Color("#ffdca0"), Color("#fff6e2")]
var _ink: Color = Color("#0b0f16")

## Two names for one clock: strobes read seconds, the transmission reads cycle position.
var _clock: float = 0.0
var _phase: float = 0.0
## Slow on purpose: a readable pulse would compete with what you came to look at.
const RING_S := 1.9
## 12 Hz, not frame rate: strobes still snap and rings still glide, with far less repainting.
const REDRAW_HZ := 12.0
## Colours the pictures draw every frame, named for what they paint.
const BEACON_RING_VOID := Color("#070a10")
const STROBE_DARK := Color("#2b4759")
const ICE_LIGHT := Color("#8ec8e6")
const DEBRIS_DUST_NEAR := Color("#182430")
const DEBRIS_DUST_FAR := Color("#22303f")
const RAIDER_CANOPY := Color("#3a6b8c")
const RAIDER_CANOPY_GLINT := Color("#cfe8f5")
const RAIDER_WARNING_LIGHT := Color("#d64a3a")
const WRECK_TEAR := Color("#05080c")
const WRECK_PORT := Color("#101922")
const CORE_SHADOW := Color("#05070c")
const PULSAR_RING_DIM := Color("#2f4a58")
const PULSAR_RING := Color("#456878")
const PULSAR_BEAM_HOT := Color("#bff0ff")
const PULSAR_BEAM_MID := Color("#5f9ab0")
const PULSAR_BEAM_FAR := Color("#2c4a5c")
const PULSAR_CORE := Color("#ffffff")
const PULSAR_CORE_BAR := Color("#dff6ff")
var _since_draw: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Off until `setup` decides this place moves, so static sectors run no `_process`.
	set_process(false)

func setup(n: MapGen.MapNode) -> void:
	node = n
	set_process(SHOW_PLACES and _moves())
	queue_redraw()

## Only two places move, so every other sector pays nothing for this.
func _moves() -> bool:
	var what := place_name()
	return what == &"station" or what == &"beacon"

func _process(delta: float) -> void:
	_clock += delta
	_phase = fposmod(_clock / RING_S, 5.0)
	_since_draw += delta
	if _since_draw >= 1.0 / REDRAW_HZ:
		_since_draw = 0.0
		queue_redraw()

## ON since 2026-09-12 by Jon: turn it on now, commission art later.
## The risk stands: placeholder art that reads well can quietly become the shipped answer.
## Why: docs/why/AreaView.md#place-art-switch
const SHOW_PLACES := true

## Named, not typed, so the sprite and the drawing are chosen by one line and cannot disagree.
## Why: docs/why/AreaView.md#place-picture-choice
func place_name() -> StringName:
	if node == null:
		return &""
	match node.type:
		# THE STATION ONLY WHERE IT IS (dock:A): at a world, the star or open
		# space of its system the hab ring is not beside you
		MapGen.NodeType.STATION:
			return &"station" if Router.at_station(node) else &""
		# No place picture on LOCAL (Jon, Oct 21): the event itself shows; sheets still draw.
		# Why: docs/why/AreaView.md#place-picture-choice
		MapGen.NodeType.SYSTEM:
			if site != ANY:
				return &""
			if OptionTable.system_has_tag(node, &"fight"):
				return &"battlefield_cleared" if node.cleared else &"battlefield"
			if OptionTable.system_has_tag(node, &"salvage"):
				return &"derelict"
			return &"beacon"
		# Core and pulsar are the system's star, which LOCAL's sky draws; no second one.
		# Why: docs/why/AreaView.md#place-picture-choice
		MapGen.NodeType.CORE, MapGen.NodeType.PULSAR:
			return &""
		# Where you start is empty space. Drawing a marker here would put an
		# object in the one sector that is meant to have nothing in it.
		MapGen.NodeType.START:
			return &""
	# (nor a stand-in for a type that has no picture of its own)
	return &"" if site != ANY else &"unknown"

func _draw() -> void:
	if node == null or not SHOW_PLACES:
		return
	var c := (size * 0.5).round()
	var tint := MapGen.star_colour(node)
	var what := place_name()
	if what == &"":
		return
	# Animated parts are overlays drawn after the picture, so the asset stays one still frame.
	# Why: docs/why/AreaView.md#place-picture-choice
	var tex: Texture2D = DB.place_sprite(what)
	if tex != null:
		# The beacon's rings go BEHIND the buoy; everything else that moves
		# goes in front. See `_beacon_rings`.
		if what == &"beacon":
			_beacon_rings(c, tint)
		# Centred and unscaled, on whole pixels. Everything in this game is
		# drawn on a 960x540 grid and a half-pixel offset resamples it.
		draw_texture(tex, (c - tex.get_size() * 0.5).round())
		match what:
			&"station": _station_lights(c)
			&"beacon": _beacon_lamp(c)
		return
	match what:
		&"station": _station(c)
		&"battlefield", &"battlefield_cleared": _battlefield(c)
		&"derelict": _derelict(c)
		&"beacon": _beacon(c, tint)
		&"core": _core(c)
		&"pulsar": _pulsar(c)
		_:
			draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), tint, true)

# --- the two-plane kit ---------------------------------------------------

## `deck` is how much height the top face takes: high looking down, low hanging below.
func _body(pos: Vector2, dim: Vector2, r: Array, deck: float = 0.55) -> void:
	var p := pos.round()
	var w := maxf(1.0, roundf(dim.x))
	var h := maxf(2.0, roundf(dim.y))
	var d := clampf(roundf(h * deck), 1.0, h - 1.0)
	draw_rect(Rect2(p - Vector2.ONE, Vector2(w + 2, h + 2)), _ink, true)
	draw_rect(Rect2(p, Vector2(w, d)), r[3], true)
	draw_rect(Rect2(p, Vector2(w, 1)), r[4], true)
	draw_rect(Rect2(p + Vector2(0, d - 1), Vector2(w, 1)), r[5], true)
	draw_rect(Rect2(p + Vector2(0, d), Vector2(w, h - d)), r[1], true)
	draw_rect(Rect2(p + Vector2(0, d), Vector2(w, minf(2.0, h - d))), r[2], true)
	_dither(Rect2(p + Vector2(0, d + 2), Vector2(w, (h - d) * 0.5)), r[2], 0.4)
	_dither(Rect2(p + Vector2(0, h - 4), Vector2(w, 3)), r[0], 0.45)
	draw_rect(Rect2(p + Vector2(0, h - 1), Vector2(w, 1)), r[0], true)

## Ordered 2x2 dither, the only kind of gradient this art style has.
func _dither(r: Rect2, col: Color, density: float) -> void:
	var th := [0.0, 0.5, 0.75, 0.25]
	for j in int(r.size.y):
		for i in int(r.size.x):
			if th[(i % 2) + (j % 2) * 2] < density:
				draw_rect(Rect2(r.position + Vector2(i, j), Vector2.ONE), col, true)

## A torus seen at the same three-quarter tilt as every hull in the game:
## the far arc catches the light, the near arc falls into shadow.
func _ring(c: Vector2, rx: float, ry: float, thick: float, r: Array) -> void:
	for i in int(rx * 2.0) + 1:
		var x := -rx + float(i)
		var k := 1.0 - (x / rx) * (x / rx)
		if k <= 0.0:
			continue
		var dy := ry * sqrt(k)
		for raw in [-1.0, 1.0]:
			var side := float(raw)
			var top := c.y + dy * side - (thick if side < 0.0 else 0.0)
			var lit := side < 0.0
			draw_rect(Rect2(Vector2(c.x + x, top - 1), Vector2(1, thick + 2)), _ink, true)
			draw_rect(Rect2(Vector2(c.x + x, top), Vector2(1, thick)),
				r[3] if lit else r[1], true)
			draw_rect(Rect2(Vector2(c.x + x, top), Vector2(1, 1)),
				r[4] if lit else r[2], true)
			draw_rect(Rect2(Vector2(c.x + x, top + thick - 1), Vector2(1, 1)),
				r[5] if lit else r[0], true)

## A window with a light behind it. Warm, because someone is home; two
## values, because a single flat pixel of orange is a dot and this is a room.
func _window(pos: Vector2, dim: Vector2) -> void:
	draw_rect(Rect2(pos - Vector2.ONE, dim + Vector2(2, 2)), _ink, true)
	draw_rect(Rect2(pos, dim), _heat[1], true)
	draw_rect(Rect2(pos, Vector2(dim.x, maxf(1.0, dim.y * 0.5))), _heat[3], true)
	draw_rect(Rect2(pos, Vector2(maxf(1.0, dim.x * 0.6), 1)), _heat[5], true)

# --- the places ----------------------------------------------------------

## A ring station: habitat torus on a docking spine, the only warm and friendly thing here.
func _station(c: Vector2) -> void:
	_ring(c, 62.0, 26.0, 9.0, _grey)
	# Spokes, drawn between the arcs so the ring reads as one solid object
	# rather than two unrelated bands.
	for raw in [-30.0, 30.0]:
		var sx := float(raw)
		_body(c + Vector2(sx - 3.0, -24.0), Vector2(6, 48), _grey, 0.5)
	# Hub and docking spine
	_body(c + Vector2(-20, -13), Vector2(40, 26), _grey, 0.6)
	_body(c + Vector2(-52, -4), Vector2(104, 8), _grey, 0.5)
	_body(c + Vector2(-7, -34), Vector2(14, 22), _grey, 0.55)
	# Windows sit on the arc, not a line at its apex, or outer ones float off the ring.
	for i in 9:
		var wx := -52.0 + float(i) * 13.0
		var wy := 26.0 * sqrt(maxf(0.0, 1.0 - (wx / 62.0) * (wx / 62.0)))
		_window(c + Vector2(wx, -wy - 8.0), Vector2(6, 4))
	for i in 5:
		_window(c + Vector2(-30 + i * 15, -6), Vector2(5, 3))
	_window(c + Vector2(-3, -30), Vector2(6, 3))
	_station_lights(c)

## Strobes are the one animation, kept separate so a sprite can keep them over a still station.
## Why: docs/why/AreaView.md#station-and-beacon
func _station_lights(c: Vector2) -> void:
	var dark := STROBE_DARK
	draw_rect(Rect2(c + Vector2(-64, -2), Vector2(3, 3)),
		dark.lerp(ICE_LIGHT, _strobe(2.3, 0.0)), true)
	draw_rect(Rect2(c + Vector2(61, -2), Vector2(3, 3)),
		dark.lerp(ICE_LIGHT, _strobe(3.1, 1.4)), true)

## Not a sine: a flash after long dark reads as a signalling machine, not a pulsing glow.
## Why: docs/why/AreaView.md#station-and-beacon
func _strobe(period: float, offset: float) -> float:
	var u := fposmod(_clock + offset, period) / period
	return clampf(1.0 - u * 7.0, 0.0, 1.0)

## A derelict is the station picture with the power off and a hole through it.
func _derelict(c: Vector2) -> void:
	# The keel first, so both halves sit on it. A ship broken in two reads as
	# two boxes until you can see the spine that used to join them.
	_body(c + Vector2(-26, -6), Vector2(48, 6), _dead, 0.4)
	for i in 7:
		draw_rect(Rect2(c + Vector2(-24 + i * 7, -6), Vector2(2, 6)), _dead[0], true)
	# Bow canted up, stern dropped and drifting away from it.
	_body(c + Vector2(-64, -26), Vector2(44, 30), _dead, 0.5)
	_body(c + Vector2(-54, -38), Vector2(26, 13), _dead, 0.66)
	_body(c + Vector2(14, -10), Vector2(52, 32), _dead, 0.5)
	_body(c + Vector2(28, -22), Vector2(20, 13), _dead, 0.66)
	# Torn ends: notches cut back into each half, deepest at the keel line,
	# so the break reads as something that happened rather than a cut.
	for i in 6:
		var dpt: int = [3, 7, 10, 8, 4, 2][i]
		draw_rect(Rect2(c + Vector2(-21 - dpt, -26 + i * 5),
			Vector2(dpt + 2, 5)), WRECK_TEAR, true)
	for i in 7:
		var dpt2: int = [2, 5, 9, 11, 7, 3, 2][i]
		draw_rect(Rect2(c + Vector2(13, -11 + i * 5),
			Vector2(dpt2 + 1, 5)), WRECK_TEAR, true)
	_dither(Rect2(c + Vector2(-22, -24), Vector2(38, 44)), WRECK_TEAR, 0.22)
	# Dead viewports: the same rooms the station lights, unlit.
	for i in 4:
		draw_rect(Rect2(c + Vector2(-58 + i * 10, -8), Vector2(4, 3)),
			WRECK_PORT, true)
	for i in 4:
		draw_rect(Rect2(c + Vector2(20 + i * 11, 4), Vector2(4, 3)),
			WRECK_PORT, true)
	# The pieces that came off it, tumbling away and catching the same light.
	for raw2 in [[64, -34, 5], [78, -20, 3], [72, 12, 4], [90, 2, 2],
			[-70, 22, 3], [-84, 8, 2], [58, 30, 3]]:
		var d: Array = raw2
		var sz: float = float(d[2])
		var p := c + Vector2(float(d[0]), float(d[1]))
		draw_rect(Rect2(p - Vector2.ONE, Vector2(sz + 2, sz + 2)), _ink, true)
		draw_rect(Rect2(p, Vector2(sz, sz)), _dead[2], true)
		draw_rect(Rect2(p, Vector2(sz, 1)), _dead[4], true)

## Rings thin as they go, the only depth cue for something with no surface.
func _beacon(c: Vector2, tint: Color) -> void:
	_beacon_rings(c, tint)
	# The buoy itself. Small — most of the picture is the thing it is doing.
	_body(c + Vector2(-4, -34), Vector2(8, 62), _grey, 0.5)
	_body(c + Vector2(-16, -44), Vector2(32, 12), _grey, 0.7)
	_body(c + Vector2(-11, 24), Vector2(22, 7), _grey, 0.4)
	_beacon_lamp(c)

## Rings split from the lamp: a buoy sprite goes between them, rings first, lamp on top.
## Why: docs/why/AreaView.md#station-and-beacon
func _beacon_rings(c: Vector2, tint: Color) -> void:
	# Rings walk outward on one cycle so the loop hides itself: an empty system still talking.
	# Why: docs/why/AreaView.md#station-and-beacon
	for i in 5:
		var k := fposmod(float(i) + _phase, 5.0)
		var rr := 26.0 + k * 15.0
		var col := tint.lerp(BEACON_RING_VOID, 0.18 + k * 0.17)
		var step: int = 2 + int(k)
		var n := int(rr * 2.4)
		for j in n:
			var a := TAU * float(j) / float(n)
			if j % step != 0:
				continue
			draw_rect(Rect2(c + Vector2(cos(a) * rr, sin(a) * rr * 0.62),
				Vector2(2, 2)), col, true)

## The lamp, which answers the rings. Drawn over the buoy, generated or not.
func _beacon_lamp(c: Vector2) -> void:
	# The lamp brightens as a ring leaves, so they read as one machine.
	var fire := 1.0 - clampf(fposmod(_phase, 1.0) * 3.2, 0.0, 1.0)
	draw_rect(Rect2(c + Vector2(-6, -50), Vector2(12, 6)), _ink, true)
	draw_rect(Rect2(c + Vector2(-5, -49), Vector2(10, 4)),
		_heat[1].lerp(_heat[2], fire), true)
	draw_rect(Rect2(c + Vector2(-5, -49), Vector2(10, 2)),
		_heat[3].lerp(_heat[4], fire), true)
	draw_rect(Rect2(c + Vector2(-3, -49), Vector2(6, 1)),
		_heat[4].lerp(_heat[5], fire), true)

## The Custodian's hole. A disc seen nearly edge-on, brightest where it is
## about to fall in, with the shadow left as a shadow.
func _core(c: Vector2) -> void:
	# Halo is dithered, not stacked translucent boxes, whose corners showed at this size.
	for i in 6:
		var rr := 92.0 - float(i) * 13.0
		var col: Color = [_heat[0], _heat[0], _heat[1], _heat[1],
			_heat[2], _heat[3]][i]
		var dens := 0.16 + float(i) * 0.13
		var ry := rr * 0.42
		for j in int(ry * 2.0) + 1:
			var y := -ry + float(j)
			var k := 1.0 - (y / ry) * (y / ry)
			if k <= 0.0:
				continue
			var hw := rr * sqrt(k)
			_dither(Rect2(c + Vector2(-hw, y), Vector2(hw * 2.0, 1)), col, dens)
	# The disc, seen nearly edge on: the far side lensed up over the top,
	# the near side passing in front of the shadow.
	for raw in [-1.0, 1.0]:
		var side := float(raw)
		for i in 145:
			var x := -72.0 + float(i)
			var k2 := 1.0 - (x / 72.0) * (x / 72.0)
			if k2 <= 0.0:
				continue
			var dy := 22.0 * sqrt(k2) * side
			draw_rect(Rect2(c + Vector2(x, dy - 1), Vector2(1, 3)),
				_heat[4] if side < 0.0 else _heat[2], true)
			draw_rect(Rect2(c + Vector2(x, dy - 1), Vector2(1, 1)),
				_heat[5] if side < 0.0 else _heat[3], true)
	draw_rect(Rect2(c + Vector2(-76, -2), Vector2(152, 5)), _heat[3], true)
	draw_rect(Rect2(c + Vector2(-76, -1), Vector2(152, 2)), _heat[5], true)
	# The shadow, painted over the near side of the disc — the one thing in
	# the picture that is an absence rather than an object.
	for j in 29:
		var t := float(j) / 28.0
		var hw2 := 15.0 * sqrt(maxf(0.0, 1.0 - (t * 2.0 - 1.0) * (t * 2.0 - 1.0)))
		draw_rect(Rect2(c + Vector2(-hw2, -14.0 + t * 28.0),
			Vector2(hw2 * 2.0, 1)), CORE_SHADOW, true)

## A fight that has already happened, or one about to. Cleared, the sector is
## the debris; uncleared, it is one raider holding station and waiting.
func _battlefield(c: Vector2) -> void:
	if node.cleared:
		# Dust first, chunks over it. Drawn the other way round the haze is a
		# grey rectangle laid on top of the only objects in the picture.
		for ring in 2:
			var rx := 58.0 - float(ring) * 24.0
			var ry := 23.0 - float(ring) * 10.0
			for j in int(ry * 2.0) + 1:
				var y := -ry + float(j)
				var k := 1.0 - (y / ry) * (y / ry)
				if k <= 0.0:
					continue
				var hw := rx * sqrt(k)
				_dither(Rect2(c + Vector2(-hw, y), Vector2(hw * 2.0, 1)),
					DEBRIS_DUST_NEAR if ring == 0 else DEBRIS_DUST_FAR,
					0.28 + float(ring) * 0.1)
		# Chunks of what used to be a ship, still lit from above and still
		# drifting apart along the axis it broke on.
		for i in 15:
			var a := float(i) * 1.31
			var p := (c + Vector2(cos(a) * (14.0 + float(i) * 4.6),
				sin(a) * (8.0 + float(i) * 2.4))).round()
			var s := 5.0 - float(i % 3) * 1.5
			draw_rect(Rect2(p - Vector2.ONE, Vector2(s + 2, s + 2)), _ink, true)
			draw_rect(Rect2(p, Vector2(s, s)), _dead[2], true)
			draw_rect(Rect2(p, Vector2(s, 1)), _dead[4], true)
			if i % 4 == 0:
				draw_rect(Rect2(p + Vector2(s, 1), Vector2(s * 1.6, 1)),
					_dead[1], true)
		return
	# A raider, nose left, drawn at the same scale as the wreck field so the
	# two states of this sector are obviously the same place.
	_body(c + Vector2(-56, -13), Vector2(112, 28), _grey, 0.55)
	_body(c + Vector2(-20, -27), Vector2(46, 15), _grey, 0.64)
	_body(c + Vector2(-10, 15), Vector2(32, 9), FxKit.ramp_under(_grey), 0.28)
	for i in 6:
		draw_rect(Rect2(c + Vector2(-42 + i * 17, -9), Vector2(1, 11)),
			_grey[1], true)
		draw_rect(Rect2(c + Vector2(-41 + i * 17, -9), Vector2(1, 11)),
			_grey[4], true)
	draw_rect(Rect2(c + Vector2(-50, -9), Vector2(16, 5)), RAIDER_CANOPY, true)
	draw_rect(Rect2(c + Vector2(-50, -9), Vector2(11, 2)), ICE_LIGHT, true)
	draw_rect(Rect2(c + Vector2(-50, -9), Vector2(7, 1)), RAIDER_CANOPY_GLINT, true)
	# It has its engines lit and its warning light on. Both are emitted.
	for i in 10:
		var t := float(i) / 10.0
		var hh := 8.0 - t * 6.0
		draw_rect(Rect2(c + Vector2(56 + float(i) * 4, -hh * 0.5),
			Vector2(4, hh)),
			_heat[5] if t < 0.18 else (_heat[3] if t < 0.5 else _heat[1]), true)
	draw_rect(Rect2(c + Vector2(-4, -31), Vector2(3, 3)), RAIDER_WARNING_LIGHT, true)

## A pulsar's star is barely a pixel, so draw the sweeping beam and the remnant round it.
func _pulsar(c: Vector2) -> void:
	for i in 26:
		var a := float(i) * 0.242
		var rr := 26.0 + float(i) * 3.4
		var p := c + Vector2(cos(a) * rr, sin(a) * rr * 0.5)
		draw_rect(Rect2(p, Vector2(2, 2)), PULSAR_RING_DIM, true)
		draw_rect(Rect2(p, Vector2(2, 1)), PULSAR_RING, true)
	for raw in [-1.0, 1.0]:
		var side := float(raw)
		for i in 22:
			var t := float(i) / 22.0
			var spread := 2.0 + t * 16.0
			for j in int(spread * 0.6):
				var off := (float(j) / maxf(1.0, spread * 0.6) - 0.5) * spread
				var col := PULSAR_BEAM_HOT if t < 0.35 else PULSAR_BEAM_MID
				if t > 0.7:
					col = PULSAR_BEAM_FAR
				draw_rect(Rect2(c + Vector2(side * (10.0 + t * 74.0),
					off - 12.0 * side * t), Vector2.ONE), col, true)
	draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), PULSAR_CORE, true)
	draw_rect(Rect2(c - Vector2(4, 1), Vector2(8, 2)), PULSAR_CORE_BAR, true)
