class_name SpectroReveal
extends Control

## The loot reveal Jon picked (Nov 18, S1 SPECTRO SPLIT): a prism line crosses an item's cell,
## behind it the item shows as red, green and blue copies that converge on the peak, its sound.
## Why: docs/why/SpectroReveal.md#spectro-split

## One second an item, its peak (where it lands and rings) 65% of the way in.
const LEN := 1.0
const PEAK := 0.65
const PRE := LEN * PEAK
const POST := LEN - PRE

## The prism line's fringe, left to right of its core (the core is the item's grade colour).
const FRINGE_RED := Color(1.0, 0.275, 0.275, 0.7)
const FRINGE_YELLOW := Color(1.0, 0.863, 0.235, 0.6)
const FRINGE_GREEN := Color(0.275, 1.0, 0.47, 0.6)
const FRINGE_BLUE := Color(0.314, 0.549, 1.0, 0.7)
## The glint the copies leave on the item's edges once it has landed: red left, blue right.
const GLINT_RED := Color(1.0, 0.275, 0.275)
const GLINT_BLUE := Color(0.314, 0.549, 1.0)

## A CanvasGroup's picture, added to (or taken from) what is under it, and only between two x
## (group-local): the clip a Control cannot give a group.
const GROUP_SHADER := """
shader_type canvas_item;
render_mode %s, unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float clip_l = -100000.0;
uniform float clip_r = 100000.0;
varying vec2 local;
void vertex() { local = VERTEX; }
void fragment() {
	if (local.x < clip_l || local.x >= clip_r) { discard; }
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) { c.rgb /= c.a; }
	COLOR *= c;
}
"""
static var _add_shader: Shader = null
static var _sub_shader: Shader = null

## Per item on screen: its nodes (`Bits`), so a frame only moves them.
var _bits: Dictionary = {}
## The prism lines to draw this frame: [x, top, height, core colour].
var _lines: Array[Array] = []
var _ink: Control


class Bits:
	var rgb: Array[CanvasGroup] = []
	var glint: Array[CanvasGroup] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink = Control.new()
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.draw.connect(_draw_lines)
	add_child(_ink)


static func _shader(sub: bool) -> Shader:
	if _add_shader == null:
		_add_shader = Shader.new()
		_add_shader.code = GROUP_SHADER % "blend_add"
		_sub_shader = Shader.new()
		_sub_shader.code = GROUP_SHADER % "blend_sub"
	return _sub_shader if sub else _add_shader


static func snap2(v: float) -> float:
	return roundf(v * 0.5) * 2.0


## Each entry: {m: HoldItem, r: Rect2 (its cell, in this control), tau: seconds from its peak, col: Color}.
func show_frame(active: Array[Dictionary]) -> void:
	_lines.clear()
	var seen: Dictionary = {}
	for e in active:
		var m: HoldItem = e.m
		seen[m] = true
		if not _bits.has(m):
			_bits[m] = _make(m, (e.r as Rect2).size)
		_place(_bits[m], e.r, float(e.tau), e.col)
	for m in _bits.keys():
		if not seen.has(m):
			_drop(_bits[m])
			_bits.erase(m)
	_ink.size = size
	move_child(_ink, -1)
	_ink.queue_redraw()


## The icon flattened first (a CanvasGroup), then tinted and added or taken away as one picture:
## added draw call by draw call, its plate and its picture summed and burned white.
func _copy(m: HoldItem, sz: Vector2, tint: Color, sub: bool) -> CanvasGroup:
	var ic := ItemIcon.make(m, &"bag")
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.tooltip_text = ""
	ic.custom_minimum_size = Vector2.ZERO
	ic.size = sz
	var g := CanvasGroup.new()
	g.add_child(ic)
	g.modulate = tint
	var mat := ShaderMaterial.new()
	mat.shader = _shader(sub)
	g.material = mat
	add_child(g)
	return g


func _make(m: HoldItem, sz: Vector2) -> Bits:
	var b := Bits.new()
	for tint in [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)]:
		b.rgb.append(_copy(m, sz, tint, false))
	# an edge, not a tint: the shifted copy added, the copy in place taken away again
	for tint in [GLINT_RED, GLINT_BLUE]:
		for sub in [false, true]:
			b.glint.append(_copy(m, sz, tint, sub))
	return b


func _drop(b: Bits) -> void:
	for g in b.rgb + b.glint:
		remove_child(g)
		g.queue_free()


func _clip(g: CanvasGroup, l: float, r: float) -> void:
	var mat := g.material as ShaderMaterial
	mat.set_shader_parameter(&"clip_l", l - g.position.x)
	mat.set_shader_parameter(&"clip_r", r - g.position.x)


## Where everything of one item sits at `tau`: the sweep and the converging copies before the
## peak, the glint after. Every offset is a whole 2 px art pixel.
func _place(b: Bits, r: Rect2, tau: float, col: Color) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var w := r.size.x
	if tau < 0.0:
		var pp := clampf((tau + PRE) / PRE, 0.0, 1.0)
		var lx := snap2(x0 - 8.0 + (w + 16.0) * clampf(pp / 0.55, 0.0, 1.0))
		var o := snap2(8.0 * (1.0 if pp < 0.55 else 1.0 - (pp - 0.55) / 0.45))
		var oy := 2.0 if o >= 4.0 else 0.0
		var offs: Array[Vector2] = [Vector2(-o, -oy), Vector2.ZERO, Vector2(o, oy)]
		for k in 3:
			b.rgb[k].visible = true
			b.rgb[k].position = r.position + offs[k]
			_clip(b.rgb[k], x0 - 12.0, lx)
		for g in b.glint:
			g.visible = false
		if pp < 0.6:
			_lines.append([lx, y0 - 6.0, r.size.y + 12.0, col])
		return
	for g in b.rgb:
		g.visible = false
	var qq := tau / POST
	var on := qq < 0.6
	var a := 1.0 if qq < 0.3 else 0.5
	var half := snap2(w * 0.5)
	# red on the left half (shifted 2 left), blue on the right (2 right)
	var shift: Array[float] = [-2.0, 0.0, 2.0, 0.0]
	for k in 4:
		var g := b.glint[k]
		g.visible = on
		g.position = r.position + Vector2(shift[k], 0.0)
		g.modulate.a = 0.7 * a
		if k < 2:
			_clip(g, x0 - 2.0, x0 + half)
		else:
			_clip(g, x0 + half, x0 + w + 2.0)


func _draw_lines() -> void:
	for ln in _lines:
		var x: float = ln[0]
		var top: float = ln[1]
		var h: float = ln[2]
		var core: Color = ln[3]
		_ink.draw_rect(Rect2(x - 6.0, top, 2.0, h), FRINGE_RED, true)
		_ink.draw_rect(Rect2(x - 4.0, top, 2.0, h), FRINGE_YELLOW, true)
		_ink.draw_rect(Rect2(x - 2.0, top, 2.0, h), FRINGE_GREEN, true)
		_ink.draw_rect(Rect2(x, top, 2.0, h), core, true)
		_ink.draw_rect(Rect2(x + 2.0, top, 2.0, h), FRINGE_BLUE, true)
		_ink.draw_rect(Rect2(x + 4.0, top, 2.0, h), Color(core.r, core.g, core.b, 0.2), true)
