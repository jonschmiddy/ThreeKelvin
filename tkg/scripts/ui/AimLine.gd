class_name AimLine
extends Control

## The fight's aim line, from the armed card to the pointer: its own Control so it draws over
## the board and ignores the mouse, being a picture. Kept as it was on main (Jon, Nov 9: "I
## really liked the old view for pointing a card at an enemy"); was an inner class of SectorScreen.
## Why: docs/why/SectorScreen.md#aim-line

## Follow rate borrowed from `ModuleIcon.FOLLOW`, a measured value.
const FOLLOW := 16.0

## Two non-harmonic waves (12 and 17) from a bench of forty treatments; numbers kept.
## Why: docs/why/SectorScreen.md#aim-line
const AMP := 5.0
const WAVE_F := [12.0, 17.0]
const WAVE_S := [5.5, -3.6]
const WAVE_A := [1.0, 0.6]

## A generous bow, mirrored on the horizontal so it always bellies away from the card.
## Why: docs/why/SectorScreen.md#aim-line
const BOW := 0.24
const BOW_MAX := 46.0

## How far short of the tip the shaft stops, so it never draws underneath the
## reticle. Slightly more than the reticle's own reach.
const HEAD_GAP := 12.0

## The reticle is a lock of three marks closing from radius 8 to 5.
const LOCK_R := 8.0
const LOCK_CLOSE := 3.0
const LOCK_SPIN := 1.6
const LOCK_RATE := 2.2

const SHADOW := Color("#060a10")

var owner_screen: SectorScreen = null
var target: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	if owner_screen == null or owner_screen._aim_view == null:
		return
	# Exponential, so the tip never overshoots and the rate does not depend
	# on the frame rate.
	var k: float = 1.0 - exp(-FOLLOW * delta)
	owner_screen._aim_tip = owner_screen._aim_tip.lerp(target, k)
	queue_redraw()

## Plotted pixel by pixel: smoothed curves look like strays on 960x540 pixel art.
func _px(x: float, y: float, c: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), 1.0, 1.0), c)

func _draw() -> void:
	if owner_screen == null or owner_screen._aim_view == null:
		return
	var a: Vector2 = owner_screen._aim_anchor()
	var b: Vector2 = owner_screen._aim_tip
	var t := GameClock.now()
	_draw_shaft(a, b, t)
	_draw_lock(b, t)

## Straight run: a bowed arc swung with the aim, and waves on a straight run do not.
## Why: docs/why/SectorScreen.md#aim-line
func _draw_shaft(a: Vector2, b: Vector2, t: float) -> void:
	var run := b - a
	var span := run.length()
	if span < HEAD_GAP + 4.0:
		return
	var lean := -1.0 if run.x >= 0.0 else 1.0
	var ctrl := (a + b) * 0.5 			+ Vector2(-run.y, run.x) / span * minf(span * BOW, BOW_MAX) * lean
	# Steps use an upper bound on the length; stepping by the span left a dashed shaft.
	var steps := int(ceilf(a.distance_to(ctrl) + ctrl.distance_to(b)))
	if steps < 2:
		return
	for i in steps + 1:
		var u := float(i) / float(steps)
		var here := a.lerp(ctrl, u).lerp(ctrl.lerp(b, u), u)
		# Stop short of the reticle. Guarded past the midpoint because a deep
		# bow can start out closer to the tip than the straight line is.
		if u > 0.5 and here.distance_to(b) < HEAD_GAP:
			break
		# The normal turns with the curve, so the waves stay square to the
		# run rather than to the straight line between its ends.
		var tang := (ctrl - a) * (2.0 * (1.0 - u)) + (b - ctrl) * (2.0 * u)
		if tang.length() < 0.001:
			continue
		var nrm := Vector2(-tang.y, tang.x) / tang.length()
		# Widest at the middle, pinched at both ends: it gives the run a waist
		# and keeps the air around the reticle clear.
		var env := 0.2 + sin(u * PI) * 1.1
		var amp := AMP * env
		for w in WAVE_F.size():
			var off: float = sin(u * WAVE_F[w] - t * WAVE_S[w]) * amp * WAVE_A[w]
			var at := here + nrm * off
			if w == 0:
				_px(at.x, at.y + 1.0, SHADOW)
				_px(at.x, at.y, UITheme.FLARE)
			else:
				_px(at.x, at.y, UITheme.EMBER)

## Three marks closing on the mark.
func _draw_lock(b: Vector2, t: float) -> void:
	var r := LOCK_R - roundf(absf(sin(t * LOCK_RATE)) * LOCK_CLOSE)
	var ph := -t * LOCK_SPIN
	for i in 3:
		var th := ph + float(i) * TAU / 3.0
		var c := b + Vector2(cos(th), sin(th)) * r
		var across := Vector2(cos(th + PI * 0.5), sin(th + PI * 0.5))
		for s in range(-2, 3):
			var q := c + across * float(s)
			_px(q.x + 1.0, q.y + 1.0, SHADOW)
		for s2 in range(-2, 3):
			var q2 := c + across * float(s2)
			_px(q2.x, q2.y, UITheme.FLARE)
		var inward := c - Vector2(cos(th), sin(th))
		_px(inward.x, inward.y, UITheme.EMBER)
	draw_rect(Rect2(b.x - 1.0, b.y - 1.0, 3.0, 3.0), SHADOW)
	_px(b.x, b.y, UITheme.HOT)
