class_name ShipView
extends TextureRect

## The ship sprite is a UI element: it shows your build, your heat, and your
## damage at a glance. Hull shape reads weight class; bolted-on modules read
## manufacturer via shape and palette.
##
## TWO RENDERERS, one control. When the hull carries a `sprite` it is blitted
## whole; when it does not, draw_ship() draws it procedurally exactly as it
## always has. That fallback is the point — real art arrives one asset at a time
## and the game has to stay playable through a migration that will take a while.
##
## Every screen goes through this class rather than through ShipSprite, which was
## written for real art and never instantiated. Five call sites already use this
## one, and it already owns magnification, showroom preview, heat and damage.
##
## ONE SUBJECT, NOT ONE SHIP. Every read used to go straight to `Run` — the
## hull, the fitted modules, the hull points, the heat — which is exactly right
## for the only ship a solo game has. A party has four, and three of them are
## being flown on other machines, so the drawing code now takes a `ShipBuild`
## and the question "whose ship is this" is answered once, in `_b()`, rather
## than at every point of use. See ShipBuild.

## The PROCEDURAL canvas. Real hull sprites are authored at 220x128, 260x156 and
## 300x188, none of which is this size, so the canvas cannot be a constant any
## more — see _w/_h below.
const W := 240
const H := 120

## The canvas actually in use. Equal to W/H while drawing procedurally, and equal
## to the hull sprite's own dimensions when there is one.
##
## Variables rather than constants because the alternative is scaling the sprite
## to fit 240x120, and scaling pixel art by a non-integer factor is the one thing
## the art direction forbids outright.
var _w: int = W
var _h: int = H

var _img: Image
var _tex: ImageTexture

## Idle bob: the ship drifts a couple of pixels up and down so it reads as
## floating rather than pinned to the panel.
##
## Moved in WHOLE PIXELS, inside the image, and only redrawn on the frames the
## offset actually changes — which at these settings is about eight times a
## second, not sixty. Both halves matter. A sub-pixel offset would resample the
## sprite and undo the nearest-neighbour crispness the whole art direction rests
## on; and animating the Control's `position` instead would fight the containers
## every screen puts this inside.
var _bob_amp: int = 0
var _bob_hz: float = 0.3
var _bob_off: int = 0

## Exhaust playback. The plume is a strip of authored frames that change SHAPE
## as they burn, so nothing here has to fake motion — it just picks a frame.
##
## This replaced a palette cycle that stepped every pixel up and down the
## flame's own brightness ramp. That animated all of it, but only ever in
## brightness; a flame gutters and swells, and shape is most of what sells it.
const FLAME_HZ := 10.0
var _flame_step: int = 0

## OFF unless a screen asks for it.
##
## The engines only burn on the chassis select, where the ship is a showroom
## piece being sold to you. Everywhere else it is parked — the refit screen is a
## workbench, the sector is a place you have arrived at, the dock is a dock — and
## a permanently firing engine on a stationary ship reads as a loop nobody
## switched off rather than as motion.
var _burning: bool = false

## ARRIVAL. The ship flies in from the left, cuts its engines, and drifts to a
## halt at its resting position, then settles into the idle bob.
##
## Eased out rather than linear, because the DRIFT is the whole point: constant
## speed reads as a slide. The engines cut at ARRIVE_CUT, before the stop, so the
## last third is visibly unpowered coasting.
## Slow, and slower than feels right when you read the number. The approach is
## the only unhurried thing in the game and it is doing scene-setting work: four
## and a half seconds of coasting says "you have got somewhere" in a way that a
## second and a half does not. Most of it is the unpowered drift, which is the
## part worth having.
const ARRIVE_MS := 4500.0
## The engines do not snap off. They burn clean to FLAME_FADE, then STUTTER —
## blinking with a duty cycle that falls to nothing by FLAME_OUT — and the ship
## coasts the rest dark. A hard cut read as a switch being thrown.
const FLAME_FADE := 0.42
const FLAME_OUT := 0.66
const FLAME_STUTTER_HZ := 26.0
var _arrive_at: int = -1
var _arrive_dx: int = 0
var _arrive_bob: int = 2
## How far left of its resting place the ship starts, in screen pixels. Measured
## on the first tick, once layout has actually happened.
var _arrive_span: int = 0

## Fly in, then idle. Safe on a view that is already parked.
##
## `delay` holds the ship off screen before it starts. A convoy is the reason it
## exists: four hulls beginning the same eased approach on the same frame arrive
## as one object with four parts, and a fraction of a second between them is the
## whole difference between a formation and a sprite sheet.
func arrive(bob_amp: int = 2, delay: float = 0.0) -> void:
	_arrive_bob = maxi(0, bob_amp)
	_arrive_at = Time.get_ticks_msec() + int(maxf(0.0, delay) * 1000.0)
	_arrive_dx = 0
	_arrive_span = 0
	_bob_amp = 0
	_bob_off = 0
	_burning = true
	set_process(true)
	refresh()

## Light the engines. Chassis select only; see _burning.
func burn(on: bool = true) -> void:
	_burning = on
	if on:
		set_process(true)
	refresh()

## Sliced frames, keyed by source texture and shared by every ShipView on
## screen. Slicing is done once per texture, not once per view.
static var _flame_cache: Dictionary = {}

## Opt in. `amp` is in source pixels, so it is multiplied by the magnification
## like everything else.
func bob(amp: int, hz: float = 0.3) -> void:
	_bob_amp = maxi(0, amp)
	_bob_hz = hz
	set_process(true)

func _ready_anim() -> void:
	if _burning and _hull() != null and _hull().exhaust != null:
		set_process(true)

func _process(_delta: float) -> void:
	if _hull() == null:
		return
	var t := float(Time.get_ticks_msec()) / 1000.0
	var dirty := false
	if _arrive_at >= 0 and _tick_arrival():
		dirty = true
	if _bob_amp > 0:
		var off := int(round(sin(t * TAU * _bob_hz) * float(_bob_amp)))
		if off != _bob_off:
			_bob_off = off
			dirty = true
	if _burning and _hull().exhaust != null:
		var step := int(t * FLAME_HZ) % maxi(1, _hull().exhaust_frames)
		if step != _flame_step:
			_flame_step = step
			dirty = true
	# One repaint per CHANGE, not per frame. Between them the texture is simply
	# left alone, which is why an animated ship costs about twenty redraws a
	# second rather than sixty.
	if dirty:
		refresh()

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Draw at native size, centred. KEEP_ASPECT_CENTERED rescales the texture to
	# whatever rect it is handed, so the ship changed size whenever a side rail
	# opened — and scaled pixel art by arbitrary fractions while doing it.
	stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	custom_minimum_size = Vector2(_w, _h)
	_img = Image.create(_w, _h, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	texture = _tex

## WHOSE SHIP. Set by setup_preview() or follow_peer(); both left alone means
## the ship you are flying, which is what every existing call site wants and
## why none of them changed.
##
## Two fields rather than one because the two cases refresh differently. A fixed
## build is a snapshot and never moves on its own; a partner's build is replaced
## wholesale every time the host pushes a roster, so it has to be looked up
## again rather than held.
var _fixed: ShipBuild = null
var _peer: int = 0

## Your own build, rebuilt on demand and dropped whenever the ship or its gauges
## change. Not held for speed — `ShipBuild.local()` walks six modules — but so
## that the ~20 repaints a second the bob and the exhaust cost do not each
## rebuild it.
var _mine: ShipBuild = null

## The partner's build as it was at the last repaint. See _repaint_partner().
var _seen: ShipBuild = null

## A ship nobody is flying: no hull, nothing on it. Shared, and nothing writes
## to it. It exists so that `_b()` is never null and the drawing code below can
## read it without asking — a hull of null already stops refresh(), so one guard
## covers what would otherwise be a check at every point of use.
static var _NOBODY := ShipBuild.new()

## The ship this view draws. The one place that asks whose it is.
func _b() -> ShipBuild:
	if _fixed != null:
		return _fixed
	if _peer != 0:
		# Null until that player has left their chassis select. They are in the
		# party and they have no ship, which is a state the convoy slot says out
		# loud rather than one this has to invent a hull for.
		var theirs := Net.build_of(_peer)
		return theirs if theirs != null else _NOBODY
	if _mine == null:
		_mine = ShipBuild.local()
	return _mine

## The composed pixels, for anything that wants them without a renderer.
##
## `texture.get_image()` reads back through the RenderingServer, which under
## --headless is a dummy that hands back nothing — so the contact sheet came out
## eight transparent rectangles. This is the image the view actually painted.
func canvas() -> Image:
	return _img

## Draw a build handed in from outside — a hull nobody owns, a partner's ship
## captured for a contact sheet, anything that is not the live local ship.
##
## A snapshot: nothing repaints it but a caller. setup_preview() and the
## `-- shipsheet` harness are both this with different framing.
func show_build(b: ShipBuild) -> void:
	_fixed = b
	refresh()

## Draw a party member's ship instead of your own.
##
## The build is looked up rather than stored: `_push_roster_to` replaces every
## slot on arrival, so a held reference would be last second's ship — and the
## whole point of this view is that a partner's new gun appears on it.
func follow_peer(id: int) -> void:
	_peer = id
	if not Sig.party_changed.is_connected(_repaint_partner):
		Sig.party_changed.connect(_repaint_partner)
	_repaint_partner()

## Repaint only when THAT partner's ship changed.
##
## `party_changed` fires for anything the roster says, including somebody else
## venting a point of heat, and a procedural hull is fifteen thousand pixels of
## GDScript to redraw. `NetSession.build_of()` hands back the same object while
## the wire is unchanged, so object identity is the test.
func _repaint_partner() -> void:
	var b := Net.build_of(_peer)
	if b == _seen:
		return
	_seen = b
	refresh()

## Whole-number magnification for the preview. The sprite is drawn once at 240
## by 120 and then resized with INTERPOLATE_NEAREST, which is what keeps a
## doubled pixel exactly four pixels rather than a blurred one — the same reason
## the project only ever scales its window by integers.
##
## Done to the IMAGE rather than by stretching the TextureRect because the two
## stretch modes that could do it are both wrong here: KEEP_CENTERED never
## scales at all, and KEEP_ASPECT_CENTERED fits the whole texture into the
## control, so cropping the empty rows above and below the hull would shrink the
## ship instead of magnifying it.
var _k: int = 1

## Magnify and crop WITHOUT going into showroom mode.
##
## The refit screen wants the live ship — its heat glow, its battle damage, the
## modules actually bolted to it — just bigger. setup_preview() would give it
## the size and take all three away, because preview means "a hull you do not
## own yet". Same geometry, different question.
func magnify(k: int, view_height: int) -> void:
	_k = maxi(1, k)
	crop(_w * _k, view_height)

## Show only the middle of the canvas, at whatever magnification is set.
##
## The convoy strip is the reason this is separate from magnify(): three
## partners have to fit beside your ship in an arena that is already full, and
## a hull sits in the middle of a canvas with empty rows above and below it. So
## the way to make a partner small is to show less of the canvas, never to scale
## the ship — the art direction allows integer magnification and nothing else,
## and half a pixel is not a pixel.
func crop(view_width: int, view_height: int) -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	custom_minimum_size = Vector2(view_width, view_height)
	clip_contents = true
	refresh()

func setup_preview(h: HullData, view_height: int = 0, k: int = 1) -> void:
	_fixed = ShipBuild.showroom(h)
	_k = maxi(1, k)
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
		custom_minimum_size = Vector2(_w * _k, view_height)
		clip_contents = true
	refresh()

func _hull() -> HullData:
	return _b().hull

func _ready() -> void:
	_ready_anim()
	# Only a view of YOUR ship listens to your ship's signals. A showroom hull
	# never changes, and a partner's changes when the roster says so — see
	# follow_peer().
	if _fixed == null and _peer == 0:
		Sig.ship_changed.connect(_restate)
		Sig.resources_changed.connect(_restate)
		Sig.player_combat_state_changed.connect(_restate)
	refresh()

## Your ship moved. Drop the cached build and repaint from the new one.
func _restate() -> void:
	_mine = null
	refresh()

func refresh() -> void:
	if _hull() == null:
		return
	if _hull().sprite != null:
		_blit_sprite()
	else:
		_resize_canvas(W, H)
		draw_ship()
	# set_image, not update: update() requires the same dimensions, and neither a
	# resized canvas nor a magnified copy matches what the texture last held.
	if _k <= 1:
		_tex.set_image(_img)
		return
	var up := _img.duplicate() as Image
	up.resize(_w * _k, _h * _k, Image.INTERPOLATE_NEAREST)
	_tex.set_image(up)

## Real art. The hull sprite goes down whole; everything the procedural path
## layers on top of it — heat glow, battle damage, module shapes — is not drawn
## here, because that is the shader's job now and the modules are their own
## sprites. See shaders/heat.gdshader.
## One step of the fly-in. Returns whether the canvas needs repainting.
func _tick_arrival() -> bool:
	# The span is taken once, on the first tick that has a real layout: far
	# enough left that the ship's trailing edge starts off the SCREEN, not off
	# its own texture. Sliding inside the canvas was the bug — the canvas is only
	# as wide as the ship, so it popped into being at the panel edge.
	if _arrive_span <= 0:
		if size.x <= 0.0:
			return false
		_arrive_span = int(ceil(global_position.x + size.x)) + 16
		position.x = -float(_arrive_span)

	# Still waiting its turn. Held off screen rather than parked at rest, so a
	# staggered convoy does not show three ships standing still while the first
	# one flies in.
	if Time.get_ticks_msec() < _arrive_at:
		return false

	var e := float(Time.get_ticks_msec() - _arrive_at) / ARRIVE_MS
	if e >= 1.0:
		_arrive_at = -1
		_arrive_dx = 0
		_arrive_span = 0
		position.x = 0.0
		_burning = false
		_bob_amp = _arrive_bob
		return true

	var dirty := false
	# Ease-out cubic: it arrives with speed and gives it all up to the drift.
	var p := 1.0 - pow(1.0 - e, 3.0)
	var dx := int(round(lerpf(float(-_arrive_span), 0.0, p)))
	if dx != _arrive_dx:
		_arrive_dx = dx
		position.x = float(dx)
	var lit := _flame_lit(e)
	if lit != _burning:
		_burning = lit
		dirty = true
	return dirty

## Engines guttering out rather than switching off. Full burn, then a blink whose
## on-time falls to zero, then dark.
static func _flame_lit(e: float) -> bool:
	if e < FLAME_FADE:
		return true
	if e >= FLAME_OUT:
		return false
	var duty := (FLAME_OUT - e) / (FLAME_OUT - FLAME_FADE)
	return fmod(e * FLAME_STUTTER_HZ, 1.0) < duty

## Copy `img` at (dx, dy), clipping whatever falls off the left edge.
##
## The canvas is only as wide as the ship, so a fly-in has nowhere to start
## from — the ship enters from behind its own panel edge. A negative destination
## is not allowed, so the offset comes out of the SOURCE rect instead. Nose
## first, which is correct: the nose points right.
func _paste(img: Image, dx: int, dy: int, blend: bool) -> void:
	var sx := maxi(0, -dx)
	var iw := img.get_width() - sx
	if iw <= 0:
		return
	var src := Rect2i(sx, 0, iw, img.get_height())
	var at := Vector2i(maxi(0, dx), dy)
	if blend:
		_img.blend_rect(img, src, at)
	else:
		_img.blit_rect(img, src, at)

func _blit_sprite() -> void:
	# The hull at its CONDITION GRADE. HullWear draws the difference between a
	# kept ship and a neglected one rather than shipping four sprites per hull —
	# see its header for why that is code and not art.
	#
	# worn_cached, never worn: this function runs every time the idle bob changes
	# offset, several times a second, and wear is a whole-image pass over sixteen
	# thousand pixels. Grade 0 returns the sprite untouched, so a C-class frame
	# costs exactly what it always did.
	var h := _hull()
	var img: Image = HullWear.worn_cached(h.sprite, h.tier, HullWear.seed_for(h))
	if img == null:
		img = h.sprite.get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img = img.duplicate() as Image
		img.convert(Image.FORMAT_RGBA8)
	# Headroom above and below so the bob has somewhere to travel without the
	# sprite being clipped at the extremes of its own canvas.
	_resize_canvas(img.get_width(), img.get_height() + _bob_amp * 2)
	_paste(img, 0, _bob_amp + _bob_off, false)
	_blit_exhaust(_bob_amp + _bob_off)

## The canvas follows whatever is being drawn into it. Cheap to call every
## refresh: it only allocates when the size actually changed.
func _resize_canvas(w: int, h: int) -> void:
	if w == _w and h == _h and _img != null:
		_img.fill(Color(0, 0, 0, 0))
		return
	_w = w
	_h = h
	_img = Image.create(_w, _h, false, Image.FORMAT_RGBA8)
	if _k <= 1:
		custom_minimum_size = Vector2(_w, _h)

## The plume, over the hull, at this step of the cycle.
##
## blend_rect and not blit_rect: blit COPIES alpha, so it would punch the flame
## frame's empty pixels straight through the hull underneath it.
func _blit_exhaust(dy: int) -> void:
	var hull := _hull()
	if not _burning or hull.exhaust == null:
		return
	var frames: Array = _flame_frames(hull.exhaust, hull.exhaust_frames)
	if frames.is_empty():
		return
	var f := frames[_flame_step % frames.size()] as Image
	_paste(f, hull.exhaust_offset.x, hull.exhaust_offset.y + dy, true)

## Cut a horizontal strip into equal frames, once per texture.
static func _flame_frames(ex: Texture2D, count: int) -> Array:
	if _flame_cache.has(ex):
		return _flame_cache[ex]
	var src := ex.get_image()
	if src.get_format() != Image.FORMAT_RGBA8:
		src = src.duplicate() as Image
		src.convert(Image.FORMAT_RGBA8)
	var n := maxi(1, count)
	var fw := src.get_width() / n
	var out: Array = []
	if fw > 0:
		for i in n:
			out.append(src.get_region(Rect2i(i * fw, 0, fw, src.get_height())))
	_flame_cache[ex] = out
	return out

# --------------------------------------------------------------- pixel helpers

func px(x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			var xx := x + i
			var yy := y + j
			if xx >= 0 and xx < _w and yy >= 0 and yy < _h:
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

	var ship := _b()
	var hull := ship.hull
	var ratio := ship.heat_ratio()
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

	# Battle damage. A showroom hull is undamaged because ShipBuild.showroom()
	# hands it full hull points, not because this branch knows what a showroom
	# is — which is the whole reason the flag went.
	var dmg := ship.damage()
	if dmg > 0.3:
		px(hx + int(hw * 0.4), hy + 6, 7, 6, Color("#1a1010"))
	if dmg > 0.6:
		px(hx + int(hw * 0.65), hy + hh - 12, 9, 7, Color("#1a1010"))
		px(hx + int(hw * 0.2), hy + 2, 6, 4, Color("#3a1a10"))

## Installed modules are bolted onto hardpoints in their maker's colours.
##
## Position comes from `m.mount`, never from the order of `installed`. These
## have always been fixed places on the hull — weapon 0 is the dorsal ordnance,
## 1 the ventral barrels — but the index used to be read off the array, so
## taking the dorsal gun off slid the ventral one up onto the spine and the ship
## rebuilt itself under a change the player had not made. The mount is now a
## choice the refit screen records and this view reports.
func _draw_modules(hx: int, hy: int, hw: int, hh: int, metal: Color, outline: Color) -> void:
	for part in _b().parts:
		var at := maxi(int(part.get("mount", 0)), 0)
		var maker := StringName(part.get("maker", &""))
		match int(part.get("slot", ModuleData.Slot.WEAPON)):
			ModuleData.Slot.WEAPON: _draw_weapon(maker, at, hx, hy, hw, hh, metal, outline)
			ModuleData.Slot.SYSTEM: _draw_system(maker, at, hx, hy, hh)
			_: _draw_util(maker, at, hx, hy)

func _draw_weapon(maker: StringName, at: int, hx: int, hy: int, hw: int, hh: int,
		metal: Color, outline: Color) -> void:
	var col := DB.manufacturer_colour(maker)
	var dark := lerp(col, Color("#0a0e13"), 0.55) as Color
	var lite := lerp(col, Color.WHITE, 0.25) as Color
	match at:
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

func _draw_system(maker: StringName, at: int, hx: int, hy: int, hh: int) -> void:
	var col := DB.manufacturer_colour(maker)
	var bx := hx + 10 + at * 22
	px(bx, hy + hh - 4, 16, 7, lerp(col, Color("#0a0e13"), 0.5) as Color)
	px(bx, hy + hh - 4, 16, 2, col)
	px(bx + 2, hy + hh - 1, 3, 2, lerp(col, Color.WHITE, 0.3) as Color)

func _draw_util(maker: StringName, at: int, hx: int, hy: int) -> void:
	var col := DB.manufacturer_colour(maker)
	var ux := hx + 18 + at * 20
	px(ux, hy - 7, 5, 7, lerp(col, Color("#0a0e13"), 0.4) as Color)
	px(ux + 1, hy - 11, 3, 5, col)
	px(ux + 1, hy - 13, 3, 2, lerp(col, Color.WHITE, 0.4) as Color)

func _starfield(seed_value: int, count: int) -> void:
	var s := seed_value
	for i in count:
		s = (s * 9301 + 49297) % 233280
		var x := int(float(s) / 233280.0 * _w)
		s = (s * 9301 + 49297) % 233280
		var y := int(float(s) / 233280.0 * _h)
		px(x, y, 1, 1, Color("#141c26"))

func _blend_rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			var xx := x + i
			var yy := y + j
			if xx >= 0 and xx < _w and yy >= 0 and yy < _h:
				var base := _img.get_pixel(xx, yy)
				_img.set_pixel(xx, yy, base.lerp(c, c.a))
