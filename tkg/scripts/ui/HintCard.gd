class_name HintCard
extends Control

## ONE FIRST-RUN HINT ON SCREEN (`Hints`): two short lines in the first-run
## intro's caption style, beside the thing it is about, with a small notch
## pointing at it.
##
## IT IS NOT A BUTTON, and it does not look like one. It has no hover, no hand
## cursor and no edge that lights, and it ignores the mouse, so a click lands on
## whatever is under it. Any click anywhere dismisses it (`Hints`), and that click
## still does its own job. It never covers what it points at: it is placed on
## whichever side of its subject is clear of the subject, the things listed to
## avoid, and the screen's edge.

## Between the card and its subject; the notch lives in this gap, px.
const GAP := 7.0
## The screen margin it keeps, px.
const EDGE := 4.0
## The fade in, s (none under reduced motion).
const FADE_S := 0.15
## How far it may be stepped out past GAP to clear what it must keep off, px.
const MAX_PUSH := 80.0

var id: StringName
var subject := Rect2()
## Which side of the subject it sits on: &"above", &"below", &"left", &"right".
var side: StringName = &""

var _panel: PanelContainer
var _avoid: Array = []


func _init(hint_id: StringName = &"", lines: Array = []) -> void:
	id = hint_id
	name = "HintCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel",
		UITheme.flat(Color(UITheme.PANEL, 0.94), UITheme.LINE, 0, 6, 9))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	for k in lines.size():
		var l := UITheme.body(String(lines[k]), UITheme.ICE if k == 0 else UITheme.CHILL, UITheme.FS_SMALL)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)


func _ready() -> void:
	if Router.animating():
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, FADE_S)


## Put it beside `at` (global, the game's picture), clear of `avoid` (Rect2s).
## Moved again only when the subject has moved more than a few px, so a bobbing
## hull does not shake it.
func aim(at: Rect2, avoid: Array) -> void:
	if side != &"" and at.position.distance_to(subject.position) < 6.0 \
			and at.size.distance_to(subject.size) < 6.0:
		return
	subject = at
	_avoid = avoid
	var sz := _panel.get_combined_minimum_size()
	var screen := get_viewport_rect().grow(-EDGE)
	var best := Vector2.ZERO
	var best_cost := INF
	var best_side: StringName = &""
	for s: StringName in [&"above", &"below", &"right", &"left"]:
		var p := _spot(s, at, sz)
		var out := _outward(s)
		var clamped := Vector2.ZERO
		var r := Rect2()
		var push := 0.0
		# STEPPED OUT along its side until it is clear of what it must keep off
		# (the drawer under the choices, a name sign over a hull), up to MAX_PUSH
		while true:
			var q := p + out * push
			clamped = Vector2(clampf(q.x, screen.position.x, screen.end.x - sz.x),
				clampf(q.y, screen.position.y, screen.end.y - sz.y))
			r = Rect2(clamped, sz)
			var hit := false
			for a in avoid:
				if _overlap(r, a as Rect2) > 0.0:
					hit = true
			if not hit or push >= MAX_PUSH:
				break
			push += 2.0
		# covering the subject is the one thing it must not do; then what it was
		# told to keep off; then how far it was pushed from its spot
		var cost := _overlap(r, at) * 1000.0 + clamped.distance_to(p)
		for a in avoid:
			cost += _overlap(r, a as Rect2) * 10.0
		if cost < best_cost:
			best_cost = cost
			best = clamped
			best_side = s
	side = best_side
	position = best
	size = sz
	_panel.position = Vector2.ZERO
	_panel.size = sz
	queue_redraw()


## Its own rect, global.
func card_rect() -> Rect2:
	return Rect2(position, size)


func _outward(s: StringName) -> Vector2:
	match s:
		&"above":
			return Vector2.UP
		&"below":
			return Vector2.DOWN
		&"right":
			return Vector2.RIGHT
	return Vector2.LEFT


func _spot(s: StringName, at: Rect2, sz: Vector2) -> Vector2:
	var c := at.get_center()
	match s:
		&"above":
			return Vector2(c.x - sz.x * 0.5, at.position.y - GAP - sz.y)
		&"below":
			return Vector2(c.x - sz.x * 0.5, at.end.y + GAP)
		&"right":
			return Vector2(at.end.x + GAP, c.y - sz.y * 0.5)
	return Vector2(at.position.x - GAP - sz.x, c.y - sz.y * 0.5)


static func _overlap(a: Rect2, b: Rect2) -> float:
	var i := a.intersection(b)
	return i.size.x * i.size.y if a.intersects(b) else 0.0


## The notch: a small triangle from the card's edge toward the subject, in the
## card's own fill and edge; when the card was stepped out past GAP, a 1 px
## leader in the edge's colour carries on to the subject.
func _draw() -> void:
	var c := subject.get_center() - position
	var sub := Rect2(subject.position - position, subject.size)
	var w := size.x
	var h := size.y
	var pts := PackedVector2Array()
	var reach := Vector2.ZERO
	match side:
		&"above":
			var x := clampf(c.x, 8.0, w - 8.0)
			pts = [Vector2(x - 4, h - 1), Vector2(x + 4, h - 1), Vector2(x, h + GAP - 2)]
			reach = Vector2(x, sub.position.y - 1)
		&"below":
			var x := clampf(c.x, 8.0, w - 8.0)
			pts = [Vector2(x - 4, 1), Vector2(x + 4, 1), Vector2(x, -GAP + 2)]
			reach = Vector2(x, sub.end.y + 1)
		&"right":
			var y := clampf(c.y, 8.0, h - 8.0)
			pts = [Vector2(1, y - 4), Vector2(1, y + 4), Vector2(-GAP + 2, y)]
			reach = Vector2(sub.end.x + 1, y)
		&"left":
			var y := clampf(c.y, 8.0, h - 8.0)
			pts = [Vector2(w - 1, y - 4), Vector2(w - 1, y + 4), Vector2(w + GAP - 2, y)]
			reach = Vector2(sub.position.x - 1, y)
	if pts.is_empty():
		return
	if pts[2].distance_to(reach) > 2.0 and (reach - pts[2]).dot(pts[2] - (pts[0] + pts[1]) * 0.5) > 0.0:
		draw_line(pts[2], reach, UITheme.LINE, 1.0)
	draw_colored_polygon(pts, Color(UITheme.PANEL, 0.94))
	draw_line(pts[0], pts[2], UITheme.LINE, 1.0)
	draw_line(pts[1], pts[2], UITheme.LINE, 1.0)
