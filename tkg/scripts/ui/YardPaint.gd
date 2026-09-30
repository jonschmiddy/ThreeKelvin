class_name YardPaint
extends RefCounted

## One layer of the Yard, drawn fresh every tick in the page's order.
##
## THE PAGE WROTE EVERYTHING INTO ONE FRAME, back to front: a walker's shadow,
## his reflection, then him, then the next one along. Here each of those needs a
## different way of being lit -- a shadow is only dark, a reflection takes the
## light where it lies, a walker the light at his feet -- and a canvas item has
## one material. So a layer is a run of canvas items, one per stretch of draws
## that are lit the same way, in the order they were asked for: the page's order.
## A walker standing somewhere else gets his own item, because the light at his
## feet is the item's (`cell`, `yard_light.gdshader`).
##
## Items are kept between ticks and cleared, never freed and made again.

const PLAIN := 0
const FLOOR := 1
const SHIP := 2
const MIRROR := 3
const HALL := 4
const ADD := 5

var parent: RID
var mats: Dictionary = {}
var _pool: Array[RID] = []
var _n := 0
var _cur := RID()
var _kind := -1
var _cell := Vector2(-1, -1)


func _init(p: RID, materials: Dictionary) -> void:
	parent = p
	mats = materials


func begin() -> void:
	_n = 0
	_kind = -1


## The item to draw into now, lit this way (and, standing on the floor, at `cell`).
func use(kind: int, cell: Vector2 = Vector2(-1, -1)) -> RID:
	if kind == _kind and (kind != FLOOR or cell == _cell):
		return _cur
	if _n >= _pool.size():
		var r := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(r, parent)
		_pool.append(r)
	_cur = _pool[_n]
	RenderingServer.canvas_item_clear(_cur)
	RenderingServer.canvas_item_set_draw_index(_cur, _n)
	var m: Variant = mats.get(kind)
	RenderingServer.canvas_item_set_material(_cur, (m as Material).get_rid() if m is Material else RID())
	if kind == FLOOR:
		RenderingServer.canvas_item_set_instance_shader_parameter(_cur, &"cell", cell)
	_n += 1
	_kind = kind
	_cell = cell
	return _cur


func end() -> void:
	for i in range(_n, _pool.size()):
		RenderingServer.canvas_item_clear(_pool[i])


func release() -> void:
	for r in _pool:
		RenderingServer.free_rid(r)
	_pool.clear()


# ------------------------------------------------------------------ drawing

func rect(r: Rect2, c: Color) -> void:
	RenderingServer.canvas_item_add_rect(_cur, r, c)


## JavaScript's Math.round, which the page used everywhere: halves go up.
static func jr(v: float) -> float:
	return floorf(v + 0.5)


func px(x: float, y: float, w: float, h: float, c: Color) -> void:
	RenderingServer.canvas_item_add_rect(_cur, Rect2(jr(x), jr(y), w, h), c)


## A picture, or a piece of one, at whole pixels; `flip` mirrors it left to right.
func tex(t: Texture2D, at: Vector2, src: Rect2 = Rect2(), mod: Color = Color.WHITE, flip: bool = false) -> void:
	if t == null:
		return
	if src.size == Vector2.ZERO:
		src = Rect2(Vector2.ZERO, t.get_size())
	var dst := Rect2(Vector2(jr(at.x), jr(at.y)), src.size)
	if flip:
		# A NEGATIVE WIDTH MIRRORS THE PICTURE IN PLACE: the rect still starts at
		# its x (measured, not assumed -- it drew a whole width to the right).
		dst = Rect2(dst.position, Vector2(-src.size.x, src.size.y))
	RenderingServer.canvas_item_add_texture_rect_region(_cur, dst, t.get_rid(), src, mod)


## A picture's reflection in the floor's polish (the page's `mirror`): flipped
## about its foot, fading from `alpha` at the top to nothing, tinted.
func mirror(t: Texture2D, src: Rect2, x0: float, ytop: float, alpha: float, tint: Color, flip: bool) -> void:
	if t == null or alpha <= 0.0:
		return
	var w := src.size.x
	var h := src.size.y
	var x := jr(x0)
	var y := jr(ytop)
	# the fade is per row, at each row's middle: alpha x (1 - row / h)
	var a0 := alpha * (1.0 + 0.5 / h)
	var a1 := alpha * (0.5 / h)
	var sx0 := src.position.x
	var sx1 := src.position.x + w
	if flip:
		sx0 = src.position.x + w
		sx1 = src.position.x
	var ts := t.get_size()
	var top := src.position.y + h
	var bot := src.position.y
	var pts := PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	var uvs := PackedVector2Array([Vector2(sx0, top) / ts, Vector2(sx1, top) / ts, Vector2(sx1, bot) / ts, Vector2(sx0, bot) / ts])
	var ca := Color(tint.r, tint.g, tint.b, a0)
	var cb := Color(tint.r, tint.g, tint.b, a1)
	var cols := PackedColorArray([ca, ca, cb, cb])
	RenderingServer.canvas_item_add_polygon(_cur, pts, cols, uvs, t.get_rid())


func text(font: Font, at: Vector2, s: String, size: int, c: Color) -> void:
	font.draw_string(_cur, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


## A one-pixel line, stepped the way the page steps its lines.
func line(x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
	var n := maxi(1, roundi(maxf(absf(x1 - x0), absf(y1 - y0))))
	for k in n + 1:
		var fx := x0 + (x1 - x0) * float(k) / float(n)
		var fy := y0 + (y1 - y0) * float(k) / float(n)
		RenderingServer.canvas_item_add_rect(_cur, Rect2(floorf(fx + 0.5), floorf(fy + 0.5), 1, 1), c)
