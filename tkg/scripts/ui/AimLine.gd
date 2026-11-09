class_name AimLine
extends Control

## The fight's aim line, from the armed card to the pointer: its own Control so it draws over
## the board and ignores the mouse, being a picture. Was an inner class of SectorScreen.
## Why: docs/why/SectorScreen.md#aim-line

## Follow rate borrowed from `ModuleIcon.FOLLOW`, a measured value.
const FOLLOW := 16.0

## A DASHED STRAIGHT LINE in the one highlight colour, from the card to the pointer (C1,
## Jon, Nov 9): dashes `DASH` px long with `GAP` px between, crawling toward the target at
## `CRAWL` px a second so the line reads as live. The waves, bow and lock it replaces are
## in the why doc.
## Why: docs/why/SectorScreen.md#aim-line
const DASH := 4.0
const GAP := 3.0
const CRAWL := 18.0
## The tip: a 3 px square where the pointer is, since the system cursor is hidden while aiming.
const TIP := 3.0

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

## Plotted pixel by pixel: smoothed lines look like strays on 960x540 pixel art.
func _px(x: float, y: float, c: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), 1.0, 1.0), c)

func _draw() -> void:
	if owner_screen == null or owner_screen._aim_view == null:
		return
	var a: Vector2 = owner_screen._aim_anchor()
	var b: Vector2 = owner_screen._aim_tip
	for q: Vector2 in dash_points(a, b, GameClock.now()):
		_px(q.x + 1.0, q.y + 1.0, SHADOW)
		_px(q.x, q.y, UITheme.MARK)
	draw_rect(Rect2(b.round() - Vector2(TIP, TIP) * 0.5 + Vector2(1, 1), Vector2(TIP, TIP)), SHADOW)
	draw_rect(Rect2(b.round() - Vector2(TIP, TIP) * 0.5, Vector2(TIP, TIP)), UITheme.MARK)

## The dashes' pixels along the straight run from `a` to `b` at time `t`, one per whole
## pixel of travel, stopping short of the tip. Pure, for the test.
static func dash_points(a: Vector2, b: Vector2, t: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var run := b - a
	var span := run.length()
	if span < TIP + 2.0:
		return out
	var dir := run / span
	var period := DASH + GAP
	var phase := fmod(t * CRAWL, period)
	var stop := span - TIP
	var d := 0.0
	while d < stop:
		if fmod(d + period - phase, period) < DASH:
			out.append((a + dir * d).round())
		d += 1.0
	return out
