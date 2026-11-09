class_name HullBar
extends ProgressBar

## Your hull bar, with your brace drawn in steel where the hull fill stops.
##
## Brace fills the missing hull first, then hangs past the right end rather than
## rescaling the bar, so a hull point is the same width however much you brace.

## The most the brace may hang past the bar's right end, in pixels. Past it a
## tick says "more", as `EnemySlot.BracePips` does.
const OVER_MAX := 40.0
## Between hull and brace, so they read as two segments rather than one fill.
const SEAM := Color("#080b11")

var brace: int = 0:
	set(v):
		v = maxi(0, v)
		if v == brace:
			return
		brace = v
		queue_redraw()


func _init() -> void:
	show_percentage = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The brace segment in the bar's own pixels, and whether `OVER_MAX` cut it.
func brace_span() -> Dictionary:
	var cap := maxf(1.0, max_value)
	var per := size.x / cap
	var x0 := clampf(value, 0.0, cap) * per
	var want := x0 + float(brace) * per
	var x1 := minf(want, size.x + OVER_MAX)
	return {x0 = x0, x1 = x1, cut = want > x1 + 0.5}


## The bar as drawn, overhang included, in global coordinates.
func drawn_rect() -> Rect2:
	var r := get_global_rect()
	if brace <= 0:
		return r
	var sp := brace_span()
	var right: float = sp.x1 + (4.0 if sp.cut else 0.0)
	if right > size.x:
		r.size.x += (right - size.x) * get_global_transform().get_scale().x
	return r


func _draw() -> void:
	if brace <= 0:
		return
	var sp := brace_span()
	var x0: float = sp.x0
	var x1: float = maxf(sp.x1, x0 + 1.0)
	draw_rect(Rect2(x0, 0, x1 - x0, size.y), UITheme.BRACE, true)
	if x0 >= 1.0:
		draw_rect(Rect2(x0, 0, 1, size.y), SEAM, true)
	if sp.cut:
		draw_rect(Rect2(x1 + 2.0, 1.0, 2.0, maxf(1.0, size.y - 2.0)), UITheme.BRACE, true)
