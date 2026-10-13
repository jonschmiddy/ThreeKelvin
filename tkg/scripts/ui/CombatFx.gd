class_name CombatFx
extends Control

## Everything combat throws across the screen: tracers, beams, impact sparks and
## the debris a dead hull leaves behind.
##
## A layer of its own, over the encounter and under the readouts, because none
## of this is state — it is the report of a state change that already happened.
## Combat resolves instantly and always has; these effects are how long it
## *reads* as taking. Nothing here can alter a number.
##
## Drawn as loose pixels rather than sprites or particles: a 1px tracer with a
## short trail sits correctly beside a pixel-art ship at integer scale, where a
## smooth line or a soft particle would be the only anti-aliased thing on screen.
##
## WHAT THE COMBAT POLISH PASS ADDED (Oct 13): volleys (a card's hits are one
## volley, and `volley_landed` says when the last of them arrived, which is when
## the numbers are allowed to move), misses that fly past rather than vanish, the
## damage numbers that pop where a volley lands, and the impact's light -- a small
## gathered glow, stepped and dithered, drawn additively (memory draw-light-as-
## light) rather than the 1-pixel sparks alone, which read as no impact at all.

## Fired when a shot arrives, so the thing it hit can flinch on impact rather
## than at the moment the card was played. The delay between the two is most of
## what makes a shot feel like it travelled.
signal landed(who: int, to_player: bool, kind: int)
## The last shot of a volley has arrived (or gone past). See `fire`'s `volley`.
signal volley_landed(volley: int)

enum Kind {
	BALLISTIC,   ## cold, solid: a tracer that crosses the gap
	ENERGY,      ## hot: a beam that is simply there, then gone
	HOSTILE,     ## incoming, warm red, so you never mistake it for your own
}

const SHOT_SPEED := 1150.0     ## pixels per second
const BEAM_LIFE := 0.16
const TRAIL := 7.0             ## pixels of tracer behind the head
## Between the hits of one volley. 0.075 s was under three frames at 30 fps, so a
## three-hit card read as one thick shot.
const HIT_GAP := 0.09

class Shot extends RefCounted:
	var from: Vector2
	var to: Vector2
	var kind: int = Kind.BALLISTIC
	var who: int = -1
	var to_player: bool = false
	var delay: float = 0.0
	var t: float = 0.0           ## 0..1 along the path, or age for a beam
	var dur: float = 0.2
	var spent: bool = false
	var miss: bool = false
	var volley: int = -1
	var last: bool = false

class Mote extends RefCounted:
	var at: Vector2
	var vel: Vector2
	var age: float = 0.0
	var life: float = 0.4
	var col: Color
	var size: float = 1.0
	var drag: float = 0.90

class Pop extends RefCounted:
	var at: Vector2
	var text: String
	var col: Color
	var age: float = 0.0
	var life: float = 1.0
	var big: bool = true

class Glow extends RefCounted:
	var at: Vector2
	var age: float = 0.0
	var life: float = 0.2
	var big: bool = false
	var warm: bool = true

var _shots: Array[Shot] = []
var _motes: Array[Mote] = []
var _pops: Array[Pop] = []
var _glows: Array[Glow] = []
var _light: Control
var _glow_small: ImageTexture
var _glow_big: ImageTexture


class LightLayer extends Control:
	var fx: CombatFx
	func _draw() -> void:
		fx._draw_light(self)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_glow_small = ImageTexture.create_from_image(gathered_light(7))
	_glow_big = ImageTexture.create_from_image(gathered_light(22))


func _ready() -> void:
	_light = LightLayer.new()
	_light.fx = self
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = mat
	# Behind this layer's own drawing (the tracers and the numbers), in front of
	# the ships: light falls on the hulls, never across a number.
	_light.show_behind_parent = true
	add_child(_light)


## A gathered light: a white core, a stepped falloff, the outer steps dithered
## 2x2 so there is no hard ring. White, so a draw can colour it.
static func gathered_light(radius: int) -> Image:
	var s := radius * 2 + 1
	var im := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var bayer := [0.0, 0.5, 0.75, 0.25]
	for y in s:
		for x in s:
			var d := Vector2(x - radius, y - radius).length() / float(radius)
			if d > 1.0:
				continue
			var e := pow(1.0 - d, 2.0)
			var thr: float = bayer[(y % 2) * 2 + (x % 2)]
			var lvl := 0.0
			if e > 0.5:
				lvl = 1.0
			elif e > 0.25:
				lvl = 0.6
			elif e > 0.1:
				lvl = 0.32 if thr < 0.75 else 0.16
			elif e > 0.02:
				lvl = 0.14 if thr < 0.5 else 0.0
			if lvl > 0.0:
				im.set_pixel(x, y, Color(lvl, lvl, lvl, 1.0))
	return im


## One attack. `hits` staggers several shots down the same line, which is what
## makes a salvo read as a salvo rather than as one bigger number. The last
## `missed` of them go past the target. `volley` names the attack, so the screen
## hears once, on `volley_landed`, when all of it has arrived.
func fire(from: Vector2, to: Vector2, kind: int, hits: int, who: int,
		to_player: bool, volley: int = -1, missed: int = 0) -> void:
	var n := maxi(1, hits)
	for i in n:
		var s := Shot.new()
		s.from = from
		s.to = to
		s.miss = i >= n - missed
		if s.miss:
			# Past the hull and off a little, so a miss reads as one: it went by.
			var dir := (to - from).normalized()
			s.to = to + dir * 70.0 + Vector2(0, (9.0 if i % 2 == 0 else -9.0))
		s.kind = kind
		s.who = who
		s.to_player = to_player
		s.volley = volley
		s.last = i == n - 1
		s.delay = float(i) * HIT_GAP
		s.dur = BEAM_LIFE if kind == Kind.ENERGY else \
			maxf(0.06, from.distance_to(s.to) / SHOT_SPEED)
		_shots.append(s)

## Whether anything is still in the air.
func in_flight() -> bool:
	return not _shots.is_empty()

## A number where a volley landed. Rises a few pixels in whole steps, holds,
## and goes in three steps rather than a smooth fade.
func pop(at: Vector2, text: String, col: Color, big: bool = true, delay: float = 0.0) -> void:
	var p := Pop.new()
	# STACKED, never on top of each other. Three hits in a row on one hull put
	# BLOCKED 5, -5 and -10 in one place as an unreadable smear; a pop that
	# would land on one still being read goes above it instead.
	var spot := at.round()
	var moved := true
	while moved:
		moved = false
		for o in _pops:
			if absf(o.at.x - spot.x) < 40.0 and absf(o.at.y - spot.y) < 10.0 					and o.age < o.life * 0.75:
				spot.y = o.at.y - 11.0
				moved = true
	p.at = spot
	p.text = text
	p.col = col
	p.big = big
	p.age = -delay
	p.life = 1.05 if big else 0.9
	_pops.append(p)

## A light where something went off: `big` for a ship leaving or a large hit.
func flash(at: Vector2, big: bool = false, warm: bool = true) -> void:
	var g := Glow.new()
	g.at = at.round()
	g.big = big
	g.warm = warm
	g.life = 0.34 if big else 0.2
	_glows.append(g)

## A hull coming apart. Bigger, slower and tumbling, so it does not read as
## another burst of sparks. (A kill is `ShipBreakup` now; this stays for the
## places that still want a burst of debris.)
func wreck(at: Vector2, tint: Color) -> void:
	for i in 34:
		var m := Mote.new()
		m.at = at + Vector2(randf_range(-10, 10), randf_range(-8, 8))
		m.vel = Vector2(randf_range(-70, 70), randf_range(-55, 45))
		m.life = randf_range(0.7, 1.6)
		m.size = 2.0 if i % 3 == 0 else 1.0
		m.drag = 0.985
		m.col = tint.lightened(0.15) if i % 4 else UITheme.EMBER
		_motes.append(m)
	# A brief flash at the centre, so the moment of death has a beat.
	for i in 12:
		var f := Mote.new()
		f.at = at
		f.vel = Vector2(randf_range(-190, 190), randf_range(-160, 160))
		f.life = randf_range(0.12, 0.26)
		f.col = UITheme.HOT
		_motes.append(f)

func _spark(at: Vector2, kind: int) -> void:
	var warm: bool = kind != Kind.BALLISTIC
	for i in 11:
		var m := Mote.new()
		m.at = at
		m.vel = Vector2(randf_range(-150, 150), randf_range(-130, 130))
		m.life = randf_range(0.10, 0.30)
		m.col = UITheme.HOT if warm else UITheme.ICE
		if i % 3 == 0:
			m.col = UITheme.FLARE if warm else UITheme.CHILL
		_motes.append(m)
	flash(at, false, warm)

func _process(delta: float) -> void:
	if _shots.is_empty() and _motes.is_empty() and _pops.is_empty() and _glows.is_empty():
		return

	var alive: Array[Shot] = []
	var done_volleys: Array[int] = []
	for s in _shots:
		if s.delay > 0.0:
			s.delay -= delta
			alive.append(s)
			continue
		s.t += delta / maxf(0.01, s.dur)
		if s.t >= 1.0:
			if not s.spent:
				s.spent = true
				if not s.miss:
					_spark(s.to, s.kind)
					landed.emit(s.who, s.to_player, s.kind)
				if s.last and s.volley >= 0:
					done_volleys.append(s.volley)
		else:
			alive.append(s)
	_shots = alive
	for v in done_volleys:
		volley_landed.emit(v)

	var kept: Array[Mote] = []
	for m in _motes:
		m.age += delta
		if m.age >= m.life:
			continue
		m.at += m.vel * delta
		m.vel *= m.drag
		kept.append(m)
	_motes = kept

	var pk: Array[Pop] = []
	for p in _pops:
		p.age += delta
		if p.age < p.life:
			pk.append(p)
	_pops = pk

	var gk: Array[Glow] = []
	for g in _glows:
		g.age += delta
		if g.age < g.life:
			gk.append(g)
	_glows = gk

	queue_redraw()
	if _light != null:
		_light.queue_redraw()

func _draw() -> void:
	for s in _shots:
		if s.delay > 0.0:
			continue
		match s.kind:
			Kind.ENERGY:
				_draw_beam(s)
			_:
				_draw_tracer(s)

	for m in _motes:
		var fade := 1.0 - m.age / maxf(0.01, m.life)
		# Stepped rather than smooth: a pixel is lit or it is not, and fading
		# one through alpha is how pixel art starts looking like a screensaver.
		var col := m.col
		if fade < 0.35:
			col = col.darkened(0.55)
		elif fade < 0.7:
			col = col.darkened(0.25)
		draw_rect(Rect2(m.at.round(), Vector2(m.size, m.size)), col, true)

	var f := UITheme.pixel_font()
	for p in _pops:
		if p.age < 0.0:
			continue
		var fs := UITheme.FS_HEAD if p.big else UITheme.FS_SMALL
		# Up 10 pixels over the first third of a second, one whole pixel at a
		# time, then held.
		var rise := roundf(10.0 * (1.0 - pow(1.0 - clampf(p.age / 0.35, 0.0, 1.0), 3.0)))
		var w := f.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := (p.at + Vector2(-w * 0.5, -rise)).round()
		var k := p.age / p.life
		var col := p.col
		var sh := Color(0, 0, 0, 0.8)
		if k > 0.7:
			col = col.darkened(0.25 if k < 0.8 else (0.5 if k < 0.9 else 0.7))
			sh.a = 0.6 if k < 0.9 else 0.35
		draw_string(f, at + Vector2(1, 1), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, sh)
		draw_string(f, at, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## The lights, additively, on their own layer. Each holds full for its first
## frames and falls in three steps.
func _draw_light(ci: CanvasItem) -> void:
	for g in _glows:
		var k := g.age / g.life
		var lvl := 1.0 if k < 0.25 else (0.55 if k < 0.5 else (0.28 if k < 0.75 else 0.12))
		var tex := _glow_big if g.big else _glow_small
		var c := Color(1.0, 0.78, 0.45) if g.warm else Color(0.6, 0.8, 1.0)
		var sz := Vector2(tex.get_size())
		ci.draw_texture(tex, (g.at - sz * 0.5).round(), Color(c.r * lvl, c.g * lvl, c.b * lvl, 1.0))

## A solid round crossing the gap, with a short trail so the eye can catch its
## direction at speed.
func _draw_tracer(s: Shot) -> void:
	var warm: bool = s.kind == Kind.HOSTILE
	var head := s.from.lerp(s.to, clampf(s.t, 0.0, 1.0))
	var back := (s.from - s.to).normalized() * TRAIL
	var tip := UITheme.EMBER if warm else UITheme.ICE
	var tail := Color("#7a4a2c") if warm else Color("#5d7a93")
	for i in int(TRAIL):
		var p := head + back * (float(i) / TRAIL)
		draw_rect(Rect2(p.round(), Vector2.ONE), tail if i > 2 else tip, true)
	draw_rect(Rect2(head.round() - Vector2.ONE, Vector2(2, 2)), tip, true)

## An energy weapon does not travel — it is drawn the instant it fires and then
## decays. Dashed, because a continuous line is the one shape a pixel galaxy
## has nowhere else.
func _draw_beam(s: Shot) -> void:
	var fade := 1.0 - clampf(s.t, 0.0, 1.0)
	var span := s.from.distance_to(s.to)
	var step := (s.to - s.from) / maxf(1.0, span)
	var core := UITheme.HOT if fade > 0.5 else UITheme.FLARE
	var halo := UITheme.FLARE if fade > 0.5 else Color("#8a5320")
	var i := 0.0
	while i < span:
		var p := (s.from + step * i).round()
		# Gaps in the beam, and a thicker core early in its life.
		if int(i) % 5 != 4:
			draw_rect(Rect2(p, Vector2.ONE), core, true)
			if fade > 0.55:
				draw_rect(Rect2(p + Vector2(0, 1), Vector2.ONE), halo, true)
		i += 1.0
