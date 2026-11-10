class_name MarkOutline
extends Control

## THE ONE MARK on a picture (stripped-down UI C1, Jon, Nov 9): the fight's ember corner
## brackets round the picture's own box, the picture itself untouched. On your ship, an enemy
## and a wreck you can open, when you point at them; on nothing at rest. A child of the art, so
## it rides its bob. The rectangle marks (`draw_rect_mark`, `draw_ring_mark`) stay the mint
## outline, for things that are rectangles or rings. Why: docs/why/MarkOutline.md#one-outline

## A ship's view: its canvas, drawn at `art_scale`.
var view: ShipView = null
## Or any picture drawn whole and centred in its control (an `EnemyArt`).
var art: TextureRect = null
var _key := Rect2(-1, -1, -1, -1)
static var _shader: Shader = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# a flat colour, so a wreck's dimming modulate does not reach the brackets
	if _shader == null:
		_shader = Shader.new()
		_shader.code = "shader_type canvas_item;
render_mode unshaded;
uniform vec4 col : source_color;
void fragment() { COLOR = col; }
"
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("col", UITheme.FLARE)
	material = m


## Redrawn only when the picture's box moves or changes size.
func _process(_d: float) -> void:
	if not visible:
		return
	var box := _ink_box()
	if box != _key:
		_key = box
		queue_redraw()


func _draw() -> void:
	var box := _ink_box()
	if box.size.x <= 0.0:
		return
	AimTarget.draw_brackets(self, box.grow(3.0), 7.0, UITheme.FLARE)


## The picture's own box in this control.
func _ink_box() -> Rect2:
	if view != null:
		return Rect2(view.ship_rect()) if view.texture != null else Rect2()
	if art == null or art.texture == null:
		return Rect2()
	var u: Rect2i = (art as EnemyArt).ink_rect() if art is EnemyArt else Rect2i(Vector2i.ZERO, Vector2i(art.texture.get_size()))
	var origin := ((art.size - Vector2(art.texture.get_size())) * 0.5).floor()
	return Rect2(origin + Vector2(u.position), Vector2(u.size))


## A 2 px outline just inside a rectangle, for things that are rectangles (a card, a deck
## cell, a beacon's box): four filled rects, so no edge lands on a half pixel.
static func draw_rect_mark(ci: CanvasItem, r: Rect2, px: float = float(UITheme.MARK_PX),
		col: Color = UITheme.MARK) -> void:
	var q := Rect2(r.position.round(), r.size.round())
	ci.draw_rect(Rect2(q.position, Vector2(q.size.x, px)), col, true)
	ci.draw_rect(Rect2(q.position + Vector2(0, q.size.y - px), Vector2(q.size.x, px)), col, true)
	ci.draw_rect(Rect2(q.position, Vector2(px, q.size.y)), col, true)
	ci.draw_rect(Rect2(q.position + Vector2(q.size.x - px, 0), Vector2(px, q.size.y)), col, true)


## A ring of whole pixels, `px` thick, round `c` at radius `r`: the outline of a round thing
## drawn elsewhere (a world on the map, a star on the chart). Returns the pixels it set.
static func draw_ring_mark(ci: CanvasItem, c: Vector2, r: float, px: float = float(UITheme.MARK_PX),
		col: Color = UITheme.MARK) -> int:
	var cc := c.round()
	var n := 0
	var ro := r + px * 0.5
	var ri := r - px * 0.5
	var reach := int(ceilf(ro)) + 1
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var d := Vector2(x, y).length()
			if d <= ro and d > ri:
				ci.draw_rect(Rect2(cc + Vector2(x, y), Vector2.ONE), col, true)
				n += 1
	return n
