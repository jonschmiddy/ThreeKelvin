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

## Fired when a shot arrives, so the thing it hit can flinch on impact rather
## than at the moment the card was played. The delay between the two is most of
## what makes a shot feel like it travelled.
signal landed(who: int, to_player: bool, kind: int)

enum Kind {
	BALLISTIC,   ## cold, solid: a tracer that crosses the gap
	ENERGY,      ## hot: a beam that is simply there, then gone
	HOSTILE,     ## incoming, warm red, so you never mistake it for your own
}

const SHOT_SPEED := 1150.0     ## pixels per second
const BEAM_LIFE := 0.16
const TRAIL := 7.0             ## pixels of tracer behind the head

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

class Mote extends RefCounted:
	var at: Vector2
	var vel: Vector2
	var age: float = 0.0
	var life: float = 0.4
	var col: Color
	var size: float = 1.0
	var drag: float = 0.90

var _shots: Array[Shot] = []
var _motes: Array[Mote] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

## One attack. `hits` staggers several shots down the same line, which is what
## makes a salvo read as a salvo rather than as one bigger number.
func fire(from: Vector2, to: Vector2, kind: int, hits: int, who: int,
		to_player: bool) -> void:
	var n := maxi(1, hits)
	for i in n:
		var s := Shot.new()
		s.from = from
		s.to = to
		s.kind = kind
		s.who = who
		s.to_player = to_player
		s.delay = float(i) * 0.075
		s.dur = BEAM_LIFE if kind == Kind.ENERGY else \
			maxf(0.06, from.distance_to(to) / SHOT_SPEED)
		_shots.append(s)

## A hull coming apart. Bigger, slower and tumbling, so it does not read as
## another burst of sparks.
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

func _process(delta: float) -> void:
	if _shots.is_empty() and _motes.is_empty():
		return

	var alive: Array[Shot] = []
	for s in _shots:
		if s.delay > 0.0:
			s.delay -= delta
			alive.append(s)
			continue
		s.t += delta / maxf(0.01, s.dur)
		if s.t >= 1.0:
			if not s.spent:
				s.spent = true
				_spark(s.to, s.kind)
				landed.emit(s.who, s.to_player, s.kind)
		else:
			alive.append(s)
	_shots = alive

	var kept: Array[Mote] = []
	for m in _motes:
		m.age += delta
		if m.age >= m.life:
			continue
		m.at += m.vel * delta
		m.vel *= m.drag
		kept.append(m)
	_motes = kept

	queue_redraw()

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
