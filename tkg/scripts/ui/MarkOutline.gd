class_name MarkOutline
extends Control

## THE ONE OUTLINE, in a sprite's own pixels: every clear pixel within `UITheme.MARK_PX` of an
## opaque one, in `UITheme.MARK`, so the line hugs the silhouette. Found on the GPU from the
## texture the sprite is drawn from, so it follows every repaint for nothing. A child of the
## art, so it rides its bob. Shows on what you point at and on what a card will hit (C1).
## Why: docs/why/MarkOutline.md#one-outline

## A ship's view: its canvas, drawn at `art_scale`.
var view: ShipView = null
## Or any picture drawn whole and centred in its control (an `EnemyArt`).
var art: TextureRect = null
var _key := Vector4(-1, -1, -1, -1)
static var _shader: Shader = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("col", UITheme.MARK)
	m.set_shader_parameter("px", float(UITheme.MARK_PX))
	material = m


## What to outline: the texture, its size in its own pixels, where its (0, 0) sits
## in this control, and how many screen px one of its pixels is.
func _source() -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	if view != null:
		var img := view.canvas()
		if img == null or view.texture == null:
			return out
		out["tex"] = view.texture
		out["wh"] = Vector2(img.get_width(), img.get_height())
		out["origin"] = ((view.size - Vector2(view.canvas_width(), view.canvas_height())) * 0.5).floor()
		out["k"] = view.art_scale()
	elif art != null and art.texture != null:
		var wh := Vector2(art.texture.get_size())
		out["tex"] = art.texture
		out["wh"] = wh
		out["origin"] = ((art.size - wh) * 0.5).floor()
		out["k"] = 1.0
	return out


## Redrawn only when the canvas's size or place changes: the texture's contents (the bob,
## the heat, the damage) reach the shader by themselves.
func _process(_d: float) -> void:
	if not visible:
		return
	var s := _source()
	if s.is_empty():
		return
	var host: Control = view if view != null else art
	var wh: Vector2 = s.wh
	var k := Vector4(wh.x, wh.y, float(s.k), host.size.x * 4096.0 + host.size.y)
	if k != _key:
		_key = k
		queue_redraw()


func _draw() -> void:
	var s := _source()
	if s.is_empty():
		return
	var kk: float = s.k
	var wh: Vector2 = s.wh
	var m := float(UITheme.MARK_PX)
	(material as ShaderMaterial).set_shader_parameter("canvas", wh)
	# `MARK_PX` canvas pixels of margin all round: the outline's pixels are clear ones, so
	# the ring round the edge of the canvas is part of it.
	draw_texture_rect(s.tex, Rect2((s.origin as Vector2) - Vector2(m, m) * kk,
		(wh + Vector2(m, m) * 2.0) * kk), false)


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


const SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec2 canvas;
uniform vec4 col : source_color;
uniform float px = 2.0;

// a macro, not a function: the canvas's TEXTURE cannot be handed to one
#define SOLID(q) (all(greaterThanEqual(q, vec2(0.0))) && all(lessThan(q, canvas)) && textureLod(TEXTURE, ((q) + 0.5) / canvas, 0.0).a > 0.1)

void fragment() {
	vec2 p = floor(UV * (canvas + 2.0 * px)) - px;
	if (SOLID(p)) {
		COLOR = vec4(0.0);
	} else {
		bool near = false;
		int reach = int(px);
		for (int dy = -reach; dy <= reach; dy++) {
			for (int dx = -reach; dx <= reach; dx++) {
				if (abs(dx) + abs(dy) > reach || (dx == 0 && dy == 0)) {
					continue;
				}
				if (SOLID(p + vec2(float(dx), float(dy)))) {
					near = true;
				}
			}
		}
		COLOR = near ? col : vec4(0.0);
	}
}
"""
