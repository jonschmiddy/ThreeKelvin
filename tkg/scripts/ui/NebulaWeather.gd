class_name NebulaWeather
extends Control

## Gas blowing through the sector, when the sector is inside a nebula.
##
## The chart says a system sits in a cloud; this is what that looks like from
## the inside. Drawn behind the ship and the subject so it reads as weather they
## are flying through rather than as an overlay on top of them.
##
## Two layers at different speeds and depths, because one layer of drifting
## pixels reads as static on a moving object and two read as a medium. The near
## layer is sparse, brighter and quick; the far layer is dense, dim and slow.
##
## Deliberately cheap: about six hundred pixels a frame, no allocation, and it
## tiles rather than tracking particles, so it costs the same whether you look
## at it for a second or ten minutes.

const NEAR := 46      ## tile size, near layer
const FAR := 27
const DRIFT := 26.0   ## pixels per second, near layer

var emission: bool = false
var tint: Color = Color("#4a7a8a")

var _t: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func setup(is_emission: bool, colour: Color) -> void:
	emission = is_emission
	tint = colour
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	# Far layer first: dim, dense, slow. Emission gas carries its own light, so
	# it sits a shade brighter than reflection gas, which only catches it.
	var base := tint
	_layer(FAR, DRIFT * 0.35, base.darkened(0.62), base.darkened(0.45), 4831)
	_layer(NEAR, DRIFT, base.darkened(0.34) if emission else base.darkened(0.5),
		base.lightened(0.12) if emission else base.darkened(0.2), 9173)

## Hashed per tile so a cell's contents never change as the sheet scrolls.
func _hash(i: int, j: int, salt: int) -> int:
	var h := (i * 374761393 + j * 668265263 + salt * 144665) & 0x7fffffff
	h = (h ^ (h >> 13)) & 0x7fffffff
	h = (h * 1274126177) & 0x7fffffff
	return (h ^ (h >> 16)) & 0x7fffffff

## One sheet of gas, tiled so it can scroll forever without tracking anything.
func _layer(cell: int, speed: float, dim: Color, lit: Color, salt: int) -> void:
	var shift := fmod(_t * speed, float(cell))
	var cols := int(size.x / float(cell)) + 2
	var rows := int(size.y / float(cell)) + 2
	for i in cols:
		for j in rows:
			var h := _hash(i, j, salt)
			# Most cells are empty. Gas is thin; drawing something in every cell
			# gives a uniform fog, and a uniform fog is a colour wash rather
			# than weather.
			if (h % 100) < 58:
				continue
			var ox := float((h >> 7) % cell)
			var oy := float((h >> 14) % cell)
			# Drifts left, and wraps. The subject sits on the right, so gas
			# moving this way reads as the ship pushing through it.
			var x := fmod(float(i * cell) + ox - shift + float(cell), size.x + float(cell) * 2.0)
			var y := float(j * cell) + oy
			if x < -2.0 or x > size.x or y < 0.0 or y > size.y:
				continue
			var bright: bool = (h % 977) < 90
			var w: float = 2.0 if bright else 1.0
			# A short horizontal streak rather than a dot: it says which way the
			# gas is going without needing to be animated any faster.
			draw_rect(Rect2(Vector2(x, y).round(), Vector2(w + 1.0, w)),
				lit if bright else dim, true)
