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
## HOW A SHIP IS MARKED, for Jon's pick (Nov 9: the full stroke on a wreck was "WAY too intense"):
## 0 today's stroke, 1 (A) a 1 px outer silhouette, 2 (B) a lift with a rim light, 3 (C) the
## fight's ember brackets round its box. `-- marklook=N`; the default stays until he picks.
## Why: docs/why/MarkOutline.md#ship-looks
static var look: int = 0
var _outside: ImageTexture = null
var _outside_key := Vector2i(-1, -1)


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
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("canvas", wh)
	mat.set_shader_parameter("mode", look)
	if _marks != null:
		_marks.visible = look == 3
	if look == 3:
		# C: the fight's brackets, in ember, round the picture's own box, drawn by a child
		# without this outline's shader and in its own flat colour, so a wreck's dimming
		# modulate does not reach them
		if _marks == null:
			_marks = Marks.new()
			add_child(_marks)
		_marks.box = _ink_box().grow(3.0)
		_marks.visible = true
		_marks.queue_redraw()
		return
	if look == 1 or look == 2:
		mat.set_shader_parameter("outside", _outside_mask())
		mat.set_shader_parameter("px", 1.0)
		m = 1.0
	else:
		mat.set_shader_parameter("px", float(UITheme.MARK_PX))
	# `MARK_PX` canvas pixels of margin all round: the outline's pixels are clear ones, so
	# the ring round the edge of the canvas is part of it.
	draw_texture_rect(s.tex, Rect2((s.origin as Vector2) - Vector2(m, m) * kk,
		(wh + Vector2(m, m) * 2.0) * kk), false)


var _marks: Marks = null


## Look C's brackets: a flat-colour shader, so the parent's modulate is not applied.
class Marks extends Control:
	var box := Rect2()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;
render_mode unshaded;
uniform vec4 col : source_color;
void fragment() { COLOR = col; }
"
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("col", UITheme.FLARE)
		material = m

	func _draw() -> void:
		AimTarget.draw_brackets(self, box, 7.0, UITheme.FLARE)


## The picture's own box in this control, for look C.
func _ink_box() -> Rect2:
	if view != null:
		return view.ship_rect()
	var u: Rect2i = (art as EnemyArt).ink_rect() if art is EnemyArt else Rect2i(Vector2i.ZERO, Vector2i(art.texture.get_size()))
	var origin := ((art.size - Vector2(art.texture.get_size())) * 0.5).floor()
	return Rect2(origin + Vector2(u.position), Vector2(u.size))


## Which clear pixels are OUTSIDE the sprite (reached from the canvas edge through clear
## pixels), as a mask the shader reads: an inner hole or a gap between pieces is not outside,
## so looks A and B stroke the silhouette alone. Found on the CPU, once per canvas size.
func _outside_mask() -> ImageTexture:
	var img: Image = view.canvas() if view != null else (art.texture as Texture2D).get_image()
	var key := Vector2i(img.get_width(), img.get_height())
	if _outside != null and _outside_key == key:
		return _outside
	_outside_key = key
	var w := key.x
	var h := key.y
	var seen := PackedByteArray()
	seen.resize(w * h)
	var queue: Array[int] = []
	for x in w:
		for y: int in [0, h - 1]:
			if img.get_pixel(x, y).a <= 0.1 and seen[y * w + x] == 0:
				seen[y * w + x] = 1
				queue.append(y * w + x)
	for y in h:
		for x: int in [0, w - 1]:
			if img.get_pixel(x, y).a <= 0.1 and seen[y * w + x] == 0:
				seen[y * w + x] = 1
				queue.append(y * w + x)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % w
		var y := i / w
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var j := ny * w + nx
			if seen[j] == 0 and img.get_pixel(nx, ny).a <= 0.1:
				seen[j] = 1
				queue.append(j)
	var mask := Image.create(w, h, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			mask.set_pixel(x, y, Color(1, 1, 1) if seen[y * w + x] == 1 else Color(0, 0, 0))
	_outside = ImageTexture.create_from_image(mask)
	return _outside


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
uniform int mode = 0;
uniform sampler2D outside;

// a macro, not a function: the canvas's TEXTURE cannot be handed to one
#define SOLID(q) (all(greaterThanEqual(q, vec2(0.0))) && all(lessThan(q, canvas)) && textureLod(TEXTURE, ((q) + 0.5) / canvas, 0.0).a > 0.1)
#define OUT(q) (any(lessThan(q, vec2(0.0))) || any(greaterThanEqual(q, canvas)) || textureLod(outside, ((q) + 0.5) / canvas, 0.0).r > 0.5)

void fragment() {
	vec2 p = floor(UV * (canvas + 2.0 * px)) - px;
	if (SOLID(p)) {
		if (mode == 2) {
			// B: the sprite lifted a step
			vec4 c = textureLod(TEXTURE, (p + 0.5) / canvas, 0.0);
			COLOR = vec4(min(c.rgb * 1.18 + 0.05, vec3(1.0)), c.a);
		} else {
			COLOR = vec4(0.0);
		}
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
		if (mode == 1) {
			// A: the outer silhouette alone, a touch softer
			COLOR = (near && OUT(p)) ? vec4(col.rgb, 0.8) : vec4(0.0);
		} else if (mode == 2) {
			// B: a thin rim light on the outer edge
			COLOR = (near && OUT(p)) ? vec4(col.rgb, 0.55) : vec4(0.0);
		} else {
			COLOR = near ? col : vec4(0.0);
		}
	}
}
"""
