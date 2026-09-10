class_name FabricatorCase
extends Control

## The Laboratory's machine, with the recipes loaded into it.
##
## NAMED FOR THE CASING, because `Fabricator` is taken -- `systems/Fabricator.gd`
## is what actually resolves a recipe, and a UI class shadowing it silently
## broke every call to `Fabricator.available()` in this file. This draws the box
## the machine lives in; the machine itself is somebody else.
##
## THE FURNITURE IS UNDER THE CONTENT, the same move the shelf and the board
## make. A recipe is not a row in a list; it is a job you put INTO something, and
## what makes that read is a hopper it goes in at, a body it happens in, and a
## chute it comes out of.
##
## The rows are untouched -- `_refresh_bench` builds exactly what it built
## before. This measures itself off them and draws the machine around them, so a
## recipe becoming affordable or a row growing a line needs no change here.
##
## Drawn rather than loaded, like the rest of the station's furniture. Art
## replaces the body of `_draw`.

var list: Container = null

const CASE := Color("#1b2530")
const PANEL := Color("#243140")
const EDGE := Color("#3d5265")
const LIP := Color("#5f7794")
const GLASS := Color("#0d1a20")
const SHADE := Color("#070a10")
const LIVE := Color("#7fb89a")
const HEAT := Color("#d97b29")
## How wide the machine's own casing is down each side.
const CASE_W := 15.0
## The hopper across the top and the chute across the bottom.
const HOPPER_H := 13.0
const CHUTE_H := 15.0

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
	if w <= 24.0 or h <= 24.0:
		return

	# --- THE CASE. Darker than the station's walls, because a machine is a thing
	# in a room and the room has already been established elsewhere.
	draw_rect(Rect2(0.0, 0.0, w, h), CASE)

	# --- THE HOPPER ACROSS THE TOP, where what a recipe consumes goes in.
	draw_rect(Rect2(0.0, 0.0, w, HOPPER_H), PANEL)
	draw_rect(Rect2(0.0, 0.0, w, 1.0), LIP)
	draw_rect(Rect2(0.0, HOPPER_H - 1.0, w, 1.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.7))
	# The mouth: a slot with teeth, so it is somewhere things are fed rather than
	# a bar across the top.
	var mx := CASE_W + 10.0
	while mx < w - CASE_W - 16.0:
		draw_rect(Rect2(mx, 3.0, 7.0, HOPPER_H - 6.0), GLASS)
		draw_rect(Rect2(mx, 3.0, 7.0, 1.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.8))
		mx += 13.0

	# --- THE CASING DOWN BOTH SIDES, with cooling fins and a live indicator.
	for cx in [0.0, w - CASE_W]:
		draw_rect(Rect2(cx, HOPPER_H, CASE_W, h - HOPPER_H), PANEL)
		draw_rect(Rect2(cx if cx > 0.0 else CASE_W - 1.0, HOPPER_H, 1.0,
			h - HOPPER_H), EDGE)
	var fy := HOPPER_H + 10.0
	while fy < h - CHUTE_H - 6.0:
		for fx in [3.0, w - CASE_W + 3.0]:
			draw_rect(Rect2(fx, fy, CASE_W - 6.0, 2.0),
				Color(SHADE.r, SHADE.g, SHADE.b, 0.65))
		fy += 7.0
	# THE PILOT LIGHT, and it is the only green in the station. A fabricator is
	# the one machine here that is doing something rather than holding something.
	draw_rect(Rect2(4.0, HOPPER_H + 4.0, 5.0, 3.0), LIVE)
	draw_rect(Rect2(w - CASE_W + 5.0, HOPPER_H + 4.0, 5.0, 3.0), HEAT)

	# --- THE CHUTE AT THE FOOT, where what it makes comes out.
	var cy := h - CHUTE_H
	draw_rect(Rect2(0.0, cy, w, CHUTE_H), PANEL)
	draw_rect(Rect2(0.0, cy, w, 1.0), LIP)
	# A lipped tray, angled by two steps rather than a slope -- nothing here can
	# trust a diagonal to land on the grid.
	draw_rect(Rect2(CASE_W, cy + 4.0, w - CASE_W * 2.0, 3.0), GLASS)
	draw_rect(Rect2(CASE_W + 6.0, cy + 7.0, w - CASE_W * 2.0 - 12.0, 3.0), GLASS)
	draw_rect(Rect2(CASE_W, cy + CHUTE_H - 3.0, w - CASE_W * 2.0, 2.0),
		Color(SHADE.r, SHADE.g, SHADE.b, 0.7))

	# --- AND A BAY BEHIND EVERY RECIPE.
	#
	# A window into the machine, so a job reads as being INSIDE it. Recessed and
	# glassy, with a warm sill under each: the sill is what says the bay is lit
	# from within rather than being a hole.
	if list == null:
		return
	for child in list.get_children():
		var c := child as Control
		if c == null or not c.visible:
			continue
		var at := Vector2(c.position.x + list.position.x - position.x,
			c.position.y + list.position.y - position.y)
		var bay := Rect2(at.x - 5.0, at.y - 3.0, c.size.x + 10.0, c.size.y + 6.0)
		draw_rect(bay, GLASS)
		draw_rect(Rect2(bay.position.x, bay.position.y, bay.size.x, 1.0),
			Color(SHADE.r, SHADE.g, SHADE.b, 0.8))
		draw_rect(Rect2(bay.position.x, bay.end.y - 2.0, bay.size.x, 2.0),
			Color(HEAT.r, HEAT.g, HEAT.b, 0.30))
		draw_rect(bay, EDGE, false, 1.0)
