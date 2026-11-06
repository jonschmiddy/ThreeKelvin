class_name HullBar
extends ProgressBar

## Your hull bar, with your brace on the end of it.
##
## BRACE ON THE BAR (issue #37, James's playtest of Nov 6, Jon: good idea).
## Brace sat under the bar as a chip, "brace 17" under "37 / 40", which reads as
## a status rather than as health. It is health: damage goes through it first
## and then through the hull. So it is drawn where the hull fill stops, in
## steel (`UITheme.BRACE`), and the number reads "37 / 40 +17" under it.
##
## IT EXTENDS PAST THE END rather than rescaling the bar or covering the hull.
## A hull point is the same number of pixels whatever brace you carry, so the
## green part keeps meaning exactly what it meant, and the steel part shows how
## many more hits' worth stand in front of it. Brace first fills the hull you
## are missing, then hangs off the right-hand end. Rescaling the whole bar to
## hull plus brace would shrink your hull every time you braced, and drawing
## the excess over the hull fill would hide the number you most need to see.
##
## The overhang is capped at `OVER_MAX`, so a brace of 60 on a hull of 40 does
## not draw a bar across the arena; past the cap a small mark says "more" (the
## same answer `EnemySlot.BracePips` gives), and the number says how much.
##
## Still a ProgressBar, so the box collectors that look for one
## (`EncounterView._collect_boxes`) still find it, and the hull fill is the
## theme's own.

## The most the brace may hang past the bar's right end, in pixels.
const OVER_MAX := 40.0
## The dark seam between the hull fill and the brace, so the two read as two
## segments of one bar rather than one longer, paler fill.
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
	value_changed.connect(func(_v: float) -> void: queue_redraw())


## Where the brace segment starts and ends, in the bar's own pixels, and
## whether it was cut short by `OVER_MAX`. Empty (`x0 == x1`) with no brace.
func brace_span() -> Dictionary:
	var cap := maxf(1.0, max_value)
	var per := size.x / cap
	var x0 := clampf(value, 0.0, cap) * per
	var want := x0 + float(brace) * per
	var x1 := minf(want, size.x + OVER_MAX)
	return {x0 = x0, x1 = x1, cut = want > x1 + 0.5}


## The bar as drawn, overhang included, in global coordinates. What a caller
## keeping things off the readout should avoid; `get_global_rect` stops at the
## bar's own right end.
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
	var x1: float = sp.x1
	if x1 - x0 < 1.0:
		x1 = x0 + 1.0
	draw_rect(Rect2(Vector2(x0, 0), Vector2(x1 - x0, size.y)), UITheme.BRACE, true)
	# the seam, only where there is hull on its left to separate it from
	if x0 >= 1.0:
		draw_rect(Rect2(Vector2(x0, 0), Vector2(1, size.y)), SEAM, true)
	if sp.cut:
		draw_rect(Rect2(Vector2(x1 + 2.0, 1.0), Vector2(2.0, maxf(1.0, size.y - 2.0))),
			UITheme.BRACE, true)
