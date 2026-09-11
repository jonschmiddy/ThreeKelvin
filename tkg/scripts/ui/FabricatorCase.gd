class_name FabricatorCase
extends Control

## The Laboratory's fabricator, built as a fume hood with the work behind its glass.
##
## IT WAS A MACHINE WITH A HOPPER AND A CHUTE, which is a factory. A laboratory's
## machine is the fume hood: a steel cabinet with a glass sash you work behind, a
## light inside it, an exhaust up to the ceiling and a cabinet of reagents under
## the bench. The recipes are still exactly the rows `_refresh_bench` builds --
## they sit behind the glass now, each in a lit bay, which is where somebody
## would actually be doing that work.
##
## THE ONLY GREEN IN THE STATION is still on this machine, as the airflow light in
## the hood's header. A hood with its fan running shows green; nothing else on
## board does.
##
## Drawn rather than loaded, like the rest of the station's furniture.

## The recipe rows standing behind the glass.
var list: Container = null

const BODY := Color("#283544")
const BODY_LIT := Color("#465b72")
const DOOR := Color("#202c3a")
const GLASS := Color("#0b1720")
const GLASS_LIT := Color("#a9c8da")
const SHADE := Color("#070a10")
const LIVE := Color("#7fb89a")
const HEAT := Color("#d97b29")

## How wide the hood's side posts are.
const CASE_W := 14.0
## How deep the header over the sash is: the fan's grille and the airflow light.
const HOOD_H := 18.0
## How deep the base under the sash is: the work surface and the cabinet below it.
const BASE_H := 58.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func watch(l: Container) -> void:
	list = l
	if not l.sort_children.is_connected(queue_redraw):
		l.sort_children.connect(queue_redraw)
	if not l.resized.is_connected(queue_redraw):
		l.resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 60.0 or h <= BASE_H + HOOD_H + 20.0:
		return
	var sash := h - BASE_H

	# --- THE CABINET'S STEEL.
	draw_rect(Rect2(0.0, 0.0, w, sash), BODY)

	# --- THE HEADER: the fan's grille, and the airflow light.
	draw_rect(Rect2(0.0, 0.0, w, HOOD_H), BODY.lerp(BODY_LIT, 0.2))
	draw_rect(Rect2(0.0, 0.0, w, 1.0), BODY_LIT)
	draw_rect(Rect2(0.0, HOOD_H - 1.0, w, 1.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.7))
	var vx := CASE_W + 8.0
	while vx < w - CASE_W - 44.0:
		draw_rect(Rect2(vx, 5.0, 9.0, HOOD_H - 10.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.7))
		vx += 14.0
	# THE ONLY GREEN ON THE STATION: the fan is running. And its readout beside it.
	draw_rect(Rect2(w - CASE_W - 30.0, 6.0, 5.0, 5.0), LIVE)
	draw_rect(Rect2(w - CASE_W - 22.0, 6.0, 12.0, 5.0), GLASS)
	draw_rect(Rect2(w - CASE_W - 21.0, 8.0, 7.0, 1.0), Color(LIVE.r, LIVE.g, LIVE.b, 0.6))

	# --- THE POSTS either side of the glass, one carrying the hood's own warning.
	for px: float in [0.0, w - CASE_W]:
		draw_rect(Rect2(px, HOOD_H, CASE_W, sash - HOOD_H), BODY)
		draw_rect(Rect2(px, HOOD_H, 1.0, sash - HOOD_H), BODY_LIT)
	var hz := Vector2(CASE_W * 0.5, HOOD_H + 16.0)
	for s in 6:
		var half := 6.0 - absf(float(s) - 2.5) * 2.0
		draw_rect(Rect2(hz.x - half, hz.y + float(s) * 2.0, half * 2.0, 2.0), HEAT)
	draw_rect(Rect2(hz.x - 1.0, hz.y + 3.0, 2.0, 4.0), SHADE)

	# --- THE SASH: glass, the light inside it, and what is standing behind it.
	var g := Rect2(CASE_W, HOOD_H, w - CASE_W * 2.0, sash - HOOD_H)
	draw_rect(g, GLASS)
	draw_rect(Rect2(g.position.x + 4.0, g.position.y + 2.0, g.size.x - 8.0, 2.0),
		Color(GLASS_LIT.r, GLASS_LIT.g, GLASS_LIT.b, 0.55))
	draw_rect(Rect2(g.position.x + 4.0, g.position.y + 4.0, g.size.x - 8.0, 10.0),
		Color(GLASS_LIT.r, GLASS_LIT.g, GLASS_LIT.b, 0.06))
	# Glassware at the back of the hood, below wherever the work is laid out.
	var shelf := sash - 14.0
	_flask(Vector2(g.position.x + 26.0, shelf))
	_cylinder(Vector2(g.position.x + 58.0, shelf))
	_flask(Vector2(g.end.x - 42.0, shelf))
	# Glare in two stepped diagonals, so the sash reads as glass and not as a hole.
	for band in 2:
		var gx0 := g.position.x + g.size.x * (0.60 + 0.12 * float(band))
		var yy := 0.0
		while yy < g.size.y - 4.0:
			var sx := gx0 + yy * 0.3
			if sx < g.end.x - 4.0:
				draw_rect(Rect2(sx, g.position.y + yy, 3.0 - float(band), 4.0),
					Color(GLASS_LIT.r, GLASS_LIT.g, GLASS_LIT.b, 0.05))
			yy += 4.0
	# The sash frame, its rail, and the handle you lift it by.
	draw_rect(g, Color(BODY_LIT.r, BODY_LIT.g, BODY_LIT.b, 0.6), false, 1.0)
	draw_rect(Rect2(g.position.x, sash - 10.0, g.size.x, 4.0), BODY_LIT)
	draw_rect(Rect2(g.position.x + g.size.x * 0.38, sash - 13.0, g.size.x * 0.24, 2.0),
		BODY_LIT.lightened(0.2))

	# --- THE RECIPES' BAYS, lit trays behind the glass.
	#
	# `sort_children` has fired by the time this runs, so these are the rows'
	# real rects. Measured every redraw, never cached: the rows are rebuilt on
	# every refresh of the deck.
	if list != null:
		for child in list.get_children():
			var c := child as Control
			if c == null or not c.visible:
				continue
			var at := Vector2(c.position.x + list.position.x - position.x,
				c.position.y + list.position.y - position.y)
			var bay := Rect2(at.x - 5.0, at.y - 3.0, c.size.x + 10.0, c.size.y + 6.0)
			draw_rect(bay, Color(0.02, 0.05, 0.07, 0.85))
			draw_rect(Rect2(bay.position.x, bay.position.y, bay.size.x, 1.0),
				Color(GLASS_LIT.r, GLASS_LIT.g, GLASS_LIT.b, 0.35))
			draw_rect(Rect2(bay.position.x, bay.end.y - 2.0, bay.size.x, 2.0),
				Color(HEAT.r, HEAT.g, HEAT.b, 0.25))
			draw_rect(bay, Color(BODY_LIT.r, BODY_LIT.g, BODY_LIT.b, 0.7), false, 1.0)

	# --- THE BENCH UNDER IT: a work surface, and a cabinet for whatever is too
	# dangerous to keep on a shelf.
	draw_rect(Rect2(0.0, sash, w, BASE_H), BODY.darkened(0.2))
	draw_rect(Rect2(-4.0, sash, w + 8.0, 6.0), BODY_LIT)
	draw_rect(Rect2(-4.0, sash, w + 8.0, 1.0), BODY_LIT.lightened(0.25))
	var cab := Rect2(4.0, sash + 6.0, w - 8.0, BASE_H - 12.0)
	draw_rect(cab, DOOR)
	var doors := 3 if w >= 300.0 else 2
	var dw := cab.size.x / float(doors)
	for i in doors:
		var d := Rect2(cab.position.x + float(i) * dw + 2.0, cab.position.y + 3.0,
			dw - 4.0, cab.size.y - 6.0)
		draw_rect(d, Color(BODY_LIT.r, BODY_LIT.g, BODY_LIT.b, 0.45), false, 1.0)
		draw_rect(Rect2(d.position.x + d.size.x * 0.5 - 5.0, d.position.y + 5.0, 10.0, 2.0),
			BODY_LIT)
	draw_rect(Rect2(8.0, h - 6.0, w - 16.0, 6.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.65))


## An Erlenmeyer flask, standing on `at`, half full.
func _flask(at: Vector2) -> void:
	draw_rect(Rect2(at.x - 2.0, at.y - 22.0, 4.0, 8.0),
		Color(GLASS_LIT.r, GLASS_LIT.g, GLASS_LIT.b, 0.30))
	var row := 0.0
	while row < 14.0:
		var half := 3.0 + row * 0.6
		var ink := Color(HEAT.r, HEAT.g, HEAT.b, 0.40) if row > 6.0 \
			else Color(GLASS_LIT.r, GLASS_LIT.g, GLASS_LIT.b, 0.22)
		draw_rect(Rect2(floorf(at.x - half), at.y - 14.0 + row, floorf(half * 2.0), 1.0), ink)
		row += 1.0


## A graduated cylinder, standing on `at`.
func _cylinder(at: Vector2) -> void:
	draw_rect(Rect2(at.x - 3.0, at.y - 28.0, 6.0, 28.0),
		Color(GLASS_LIT.r, GLASS_LIT.g, GLASS_LIT.b, 0.22))
	draw_rect(Rect2(at.x - 3.0, at.y - 12.0, 6.0, 12.0), Color(0.30, 0.60, 0.63, 0.45))
	draw_rect(Rect2(at.x - 5.0, at.y - 1.0, 10.0, 1.0),
		Color(GLASS_LIT.r, GLASS_LIT.g, GLASS_LIT.b, 0.35))
	for m in 4:
		draw_rect(Rect2(at.x + 1.0, at.y - 26.0 + float(m) * 6.0, 2.0, 1.0),
			Color(GLASS_LIT.r, GLASS_LIT.g, GLASS_LIT.b, 0.4))
