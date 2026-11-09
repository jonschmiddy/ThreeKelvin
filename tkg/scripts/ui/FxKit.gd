class_name FxKit
extends RefCounted

## Pixel idioms the hit effects drew by hand: the same expressions, in one place.


## `c` at brightness `lvl`, opaque.
static func lv(c: Color, lvl: float) -> Color:
	return Color(c.r * lvl, c.g * lvl, c.b * lvl, 1.0)


## A flash's held brightness steps at `x` = age / life; four steps, not a fade.
static func flash_level(x: float) -> float:
	return 1.0 if x < 0.25 else (0.6 if x < 0.5 else (0.32 if x < 0.75 else 0.14))


## A square chip turned `quarter_turns` quarter turns about its centre, at `alpha`.
static func draw_chip(ci: CanvasItem, tex: Texture2D, top_left: Vector2, size: Vector2, quarter_turns: int, alpha: float) -> void:
	ci.draw_set_transform(top_left + size * 0.5, float(quarter_turns) * PI * 0.5, Vector2.ONE)
	ci.draw_texture(tex, -size * 0.5, Color(1, 1, 1, alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A one-pixel spark at `p` with a half-bright tail two pixels back along `v`.
static func draw_spark(ci: CanvasItem, p: Vector2, v: Vector2, c: Color) -> void:
	var p2 := p.round()
	ci.draw_rect(Rect2(p2, Vector2.ONE), c)
	var tail := (p - v.normalized() * 2.0).round()
	if tail != p2:
		ci.draw_rect(Rect2(tail, Vector2.ONE), c * Color(0.5, 0.5, 0.5, 1))
