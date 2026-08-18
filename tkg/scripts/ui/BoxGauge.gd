class_name BoxGauge
extends Control

## Countable cells for heat and energy.
##
## A bar hides the number that matters. Overheating costs 1 hull per point over
## cap, so the player needs to see *how many* points over they are, not roughly
## how full a bar is. Cells past the divider are hull you will pay at end of turn.
##
## Fill colour also states the situation without being read: steel while there is
## room, ember approaching the cap, red past it.

enum Mode { HEAT, ENERGY }

const CELL := Vector2(6, 9)
const GAP := 1

var mode: Mode = Mode.HEAT
var cap: int = 12
var value: int = 0

func setup(m: Mode, c: int, v: int) -> void:
	mode = m
	cap = maxi(1, c)
	value = maxi(0, v)
	custom_minimum_size = Vector2(_width(), CELL.y)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	queue_redraw()

func set_value(v: int) -> void:
	value = maxi(0, v)
	custom_minimum_size = Vector2(_width(), CELL.y)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	queue_redraw()

func _width() -> float:
	var over := maxi(0, value - cap)
	var w := cap * (CELL.x + GAP)
	if over > 0:
		w += 4 + over * (CELL.x + GAP)
	return w

func _draw() -> void:
	# A Control fills its row by default, so painting at y=0 would sit the cells
	# on the top edge while the label beside them is centred. Centre in whatever
	# height the container hands us.
	# +1 is optical, not arithmetic: Silkscreen's caps sit above the line box's
	# middle, so a mathematically centred cell still reads high beside them.
	var y: float = floor((size.y - CELL.y) * 0.5) + 1.0
	var x := 0.0
	for i in cap:
		_cell(Vector2(x, y), _fill_for(i))
		x += CELL.x + GAP

	var over := maxi(0, value - cap)
	if over <= 0:
		return
	# The divider is the cap line. Everything right of it is self-damage.
	draw_rect(Rect2(Vector2(x + 1, y - 2), Vector2(1, CELL.y + 4)), UITheme.CHILL, true)
	x += 4
	for i in over:
		_cell(Vector2(x, y), 3)
		x += CELL.x + GAP

## 0 empty · 1 cool · 2 hot · 3 over cap
func _fill_for(i: int) -> int:
	if i >= value:
		return 0
	if mode == Mode.ENERGY:
		return 2
	return 2 if i >= int(cap * 0.66) else 1

func _cell(pos: Vector2, kind: int) -> void:
	var bg := Color("#10161f")
	var hi := Color("#080b11")
	var lo := Color("#2a3644")
	match kind:
		1:
			bg = UITheme.COLD
			hi = UITheme.CHILL
			lo = Color("#3d4d61")
		2:
			bg = UITheme.FLARE if mode == Mode.ENERGY else UITheme.EMBER
			hi = UITheme.HOT
			lo = Color("#964214")
		3:
			bg = Color("#d64a3a")
			hi = UITheme.FLARE
			lo = Color("#5c280c")

	draw_rect(Rect2(pos, CELL), bg, true)
	draw_rect(Rect2(pos, Vector2(CELL.x, 1)), hi, true)
	draw_rect(Rect2(pos, Vector2(1, CELL.y)), hi, true)
	draw_rect(Rect2(pos + Vector2(0, CELL.y - 1), Vector2(CELL.x, 1)), lo, true)
	draw_rect(Rect2(pos + Vector2(CELL.x - 1, 0), Vector2(1, CELL.y)), lo, true)
