class_name BoxGauge
extends Control

## Cells, not a bar: over-cap heat costs 1 hull a point, so the count is the decision.
## Why: docs/why/BoxGauge.md#box-gauge

## Hull and heat are tenths so the gauge keeps its length across ships; over cap, a cell a point.
## Why: docs/why/BoxGauge.md#cell-meaning
enum Mode { HEAT, ENERGY, HULL }

## Slots below the maximum, for the two modes that scale.
const CELLS := 10

const CELL := Vector2(6, 9)
const GAP := 1

## Capped at ten cells then a tick: 27 over-cap cells pushed HUD buttons off the screen.
## Why: docs/why/BoxGauge.md#over-cap
const OVER_MAX := 10

var mode: Mode = Mode.HEAT
var cap: int = 12
var value: int = 0

func setup(m: Mode, c: int, v: int) -> void:
	mode = m
	cap = maxi(1, c)
	set_value(v)

func set_value(v: int) -> void:
	value = maxi(0, v)
	_ratio = clampf(float(value) / float(maxi(1, cap)), 0.0, 1.0)
	_cells = _cells_for(value)
	custom_minimum_size = Vector2(_width(), CELL.y)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	queue_redraw()

## Heat rounds up and hull down, so heat's first point shows and ten hull cells means full.
## Why: docs/why/BoxGauge.md#rounding
func _cells_for(v: int) -> int:
	if mode == Mode.ENERGY:
		return v
	if mode == Mode.HULL:
		return 0 if v <= 0 else maxi(1, int(floor(_ratio * CELLS)))
	return 0 if v <= 0 else mini(CELLS, int(ceil(_ratio * CELLS)))

## Slots drawn below the divider.
func _slots() -> int:
	return cap if mode == Mode.ENERGY else CELLS

func _width() -> float:
	var raw := maxi(0, value - cap)
	var over := mini(raw, OVER_MAX)
	var w := _slots() * (CELL.x + GAP)
	if over > 0:
		w += 4 + over * (CELL.x + GAP)
	if raw > OVER_MAX:
		w += 4
	return w

func _draw() -> void:
	# Centred in the container's height; +1 is optical, as Silkscreen's caps sit high.
	var y: float = floor((size.y - CELL.y) * 0.5) + 1.0
	var x := 0.0
	for i in _slots():
		_cell(Vector2(x, y), _fill_for(i))
		x += CELL.x + GAP

	var over := maxi(0, value - cap)
	if over <= 0:
		return
	# The divider is the cap line. Everything right of it is self-damage.
	draw_rect(Rect2(Vector2(x + 1, y - 2), Vector2(1, CELL.y + 4)), UITheme.CHILL, true)
	x += 4
	for i in mini(over, OVER_MAX):
		_cell(Vector2(x, y), 3)
		x += CELL.x + GAP
	# AND THE REST IS A TICK. See `OVER_MAX`.
	if over > OVER_MAX:
		draw_rect(Rect2(Vector2(x + 1, y + 1), Vector2(2, CELL.y - 2)),
			UITheme.FLARE, true)

## Hull rounds down with a floor of one cell, so full means full and empty means destroyed.
## Why: docs/why/BoxGauge.md#rounding
func set_hull(hp: int, max_hp: int) -> void:
	mode = Mode.HULL
	cap = CELLS
	_ratio = 0.0 if max_hp <= 0 else clampf(float(hp) / float(max_hp), 0.0, 1.0)
	# Deliberately NOT set_value(): hull's ratio is hp against max_hp, not
	# against `cap`, which here is the slot count rather than a hull figure.
	value = _cells_for(hp)
	_cells = value
	custom_minimum_size = Vector2(_width(), CELL.y)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	queue_redraw()

var _ratio: float = 1.0
var _cells: int = 0

## 0 empty · 1 cool · 2 hot · 3 critical · 4 sound
func _fill_for(i: int) -> int:
	if i >= _cells:
		return 0
	if mode == Mode.ENERGY:
		return 2
	if mode == Mode.HULL:
		# Whole-bar colour, not per cell; 0.35 matches the hull figure's amber threshold.
		if _ratio < 0.35:
			return 3
		return 2 if _ratio < 0.6 else 4
	# Against the slot count, not the cap: the two are no longer the same number.
	return 2 if i >= int(_slots() * 0.66) else 1

func _cell(pos: Vector2, kind: int) -> void:
	var bg := Color("#10161f")
	var hi := UITheme.BEVEL_LO
	var lo := Color("#2a3644")
	match kind:
		1:
			bg = UITheme.COLD
			hi = UITheme.CHILL
			lo = UITheme.BEVEL_HI
		2:
			bg = UITheme.FLARE if mode == Mode.ENERGY else UITheme.EMBER
			hi = UITheme.HOT
			lo = Color("#964214")
		3:
			bg = Color("#d64a3a")
			hi = UITheme.FLARE
			lo = Color("#5c280c")
		4:
			bg = UITheme.HULL_GREEN
			hi = UITheme.GOOD
			lo = Color("#25402f")

	draw_rect(Rect2(pos, CELL), bg, true)
	draw_rect(Rect2(pos, Vector2(CELL.x, 1)), hi, true)
	draw_rect(Rect2(pos, Vector2(1, CELL.y)), hi, true)
	draw_rect(Rect2(pos + Vector2(0, CELL.y - 1), Vector2(CELL.x, 1)), lo, true)
	draw_rect(Rect2(pos + Vector2(CELL.x - 1, 0), Vector2(1, CELL.y)), lo, true)
