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

## WHICH BOX THE TAG WEARS: `DEFAULT_LOOK`, 14 GLITCH, Jon's pick (Nov 9) out of the twenty in
## `TipFrames`; 0 is this torn tag; `-- tiplook=N` shows any of them.
## Why: docs/why/TornTag.md#tip-looks
const DEFAULT_LOOK := 14
static var look: int = DEFAULT_LOOK

## [[text, Color], ...], one entry a line.
var lines: Array = []
var alpha := 1.0
## 1 when the tag sits above its thing, -1 below it, 0 unknown: look 2's leader points that way.
var point := 0
## When the words were set, on the game's clock: the look's open animation runs from here.
var _born := -INF


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_lines(ls: Array) -> void:
	lines = ls
	size = measure(ls)
	custom_minimum_size = size
	_born = GameClock.now() if look != 0 else -INF
	set_process(look != 0)
	queue_redraw()


## Seconds since the words were set; INF for today's tag, which is still.
func age() -> float:
	return INF if _born == -INF else GameClock.now() - _born


## Redrawn each frame while the look moves; stopped once it is still.
func _process(_dt: float) -> void:
	if TipFrames.settled(look, age()):
		set_process(false)
	queue_redraw()


func _draw() -> void:
	draw_tag(self, Rect2(Vector2.ZERO, size), lines, alpha, point, age())


## The tag's box for these lines: the widest line plus the padding, a line's height each.
static func measure(ls: Array) -> Vector2:
	var f := UITheme.pixel_font()
	var w := 0.0
	for l in ls:
		w = maxf(w, f.get_string_size(String((l as Array)[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x)
	var p := TipFrames.pad(look)
	return Vector2(ceilf(w) + p.position.x + p.size.x, float(ls.size() * LINE_H + p.position.y + p.size.y - 2))


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


## The box (`look`), then the words, in `rect` on `ci`, at `a` alpha. `point` is where the thing
## is (see `point`); `age` is seconds since the tag opened, INF for the still frame.
static func draw_tag(ci: CanvasItem, rect: Rect2, ls: Array, a: float = 1.0, point: int = 0,
		age: float = INF) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	if look == 0:
		var fill := Color(FILL, FILL.a * a)
		ci.draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), fill, true)
		torn(ci, r, Color(EDGE, a))
	else:
		a *= TipFrames.alpha_at(look, age)
		TipFrames.draw(ci, r, look, a, point, age)
	var p := TipFrames.pad(look)
	var f := UITheme.pixel_font()
	var y := r.position.y + p.position.y + f.get_ascent(UITheme.FS_SMALL) - 1.0
	var total := 0
	for l in ls:
		total += String((l as Array)[0]).length()
	var left := TipFrames.letters_at(look, age, total)
	for l in ls:
		var pair: Array = l
		var c: Color = pair[1]
		var text := String(pair[0]).left(left)
		left -= text.length()
		ci.draw_string(f, Vector2(r.position.x + p.position.x, y), text,
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
