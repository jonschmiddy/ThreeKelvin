class_name TornTag
extends Control

## THE ONE TOOLTIP (stripped-down UI T1, Jon, Nov 9): a small torn black tag right above the
## thing you point at. No frame, no title, no icon; one sentence in the game's 8 px face. On
## the game's dark scenes a 1 px grey torn edge is what shows it. Drawn by hand (`draw_tag`)
## for the chart's and the map's own tips, and as this Control for every tooltip `TagLayer` shows.
## Why: docs/why/TornTag.md#one-tag

const PAD_H := 5
const PAD_V := 4
const LINE_H := 11
## Between the tag and the thing it names.
const GAP := 3
const FILL := Color("#05080d", 0.94)
const EDGE := Color("#5e6b7a")

## [[text, Color], ...], one entry a line.
var lines: Array = []
var alpha := 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_lines(ls: Array) -> void:
	lines = ls
	size = measure(ls)
	custom_minimum_size = size
	queue_redraw()


func _draw() -> void:
	draw_tag(self, Rect2(Vector2.ZERO, size), lines, alpha)


## The tag's box for these lines: the widest line plus the padding, a line's height each.
static func measure(ls: Array) -> Vector2:
	var f := UITheme.pixel_font()
	var w := 0.0
	for l in ls:
		w = maxf(w, f.get_string_size(String((l as Array)[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x)
	return Vector2(ceilf(w) + PAD_H * 2.0, float(ls.size() * LINE_H + PAD_V * 2 - 2))


## One sentence, wrapped to `width` characters, as the tag's lines in `col`.
static func sentence(text: String, col: Color = UITheme.ICE, width: int = UITheme.TOOLTIP_WRAP) -> Array[Array]:
	var out: Array[Array] = []
	for para in text.split("\n"):
		var line := ""
		for word in (para as String).split(" "):
			if word == "":
				continue
			if line == "":
				line = word
			elif line.length() + 1 + (word as String).length() <= width:
				line += " " + word
			else:
				out.append([line, col])
				line = word
		if line != "":
			out.append([line, col])
	return out


## The fill, its torn edge and the words, in `rect` on `ci`, at `a` alpha.
static func draw_tag(ci: CanvasItem, rect: Rect2, ls: Array, a: float = 1.0) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	var fill := Color(FILL, FILL.a * a)
	var edge := Color(EDGE, a)
	ci.draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), fill, true)
	torn(ci, r, edge)
	var f := UITheme.pixel_font()
	var y := r.position.y + PAD_V + f.get_ascent(UITheme.FS_SMALL) - 1.0
	for l in ls:
		var pair: Array = l
		var c: Color = pair[1]
		ci.draw_string(f, Vector2(r.position.x + PAD_H, y), String(pair[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, Color(c, c.a * a))
		y += LINE_H


## The 1 px edge, stepping in a pixel here and there like torn paper: the steps come
## from a fixed hash of the position, so a tag never shimmers from frame to frame.
static func torn(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var w := int(r.size.x)
	var h := int(r.size.y)
	var x0 := r.position.x
	var y0 := r.position.y
	for x in range(1, w - 1):
		var j := _jag(x, 1)
		ci.draw_rect(Rect2(x0 + x, y0 + j, 1, 1), col, true)
		var k := _jag(x, 2)
		ci.draw_rect(Rect2(x0 + x, y0 + h - 1 - k, 1, 1), col, true)
	for y in range(1, h - 1):
		var j := _jag(y, 3)
		ci.draw_rect(Rect2(x0 + j, y0 + y, 1, 1), col, true)
		var k := _jag(y, 4)
		ci.draw_rect(Rect2(x0 + w - 1 - k, y0 + y, 1, 1), col, true)


## 1 for a torn-in pixel, 0 on the line; about one step in three, in runs of two or three.
static func _jag(i: int, salt: int) -> int:
	var hsh := ((i / 2) * 1103515245 + salt * 12345) >> 7
	return 1 if (hsh & 7) < 3 else 0


## Where a tag of `sz` goes for a thing in `about` (the same coordinates): centred above it,
## `GAP` clear; below it when there is no room above; slid inside `bound`; never over `about`
## while both fit. Whole pixels.
static func place(sz: Vector2, about: Rect2, bound: Rect2) -> Vector2:
	var x := about.get_center().x - sz.x * 0.5
	var y := about.position.y - GAP - sz.y
	if y < bound.position.y:
		y = about.end.y + GAP
	if y + sz.y > bound.end.y:
		y = maxf(bound.position.y, about.position.y - GAP - sz.y)
	x = clampf(x, bound.position.x, maxf(bound.position.x, bound.end.x - sz.x))
	return Vector2(x, y).round()
