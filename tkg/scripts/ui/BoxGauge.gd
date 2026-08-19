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

## HULL is a PROPORTION, not a count. Heat and energy cells map one-to-one onto
## a point of the thing they measure, because you spend those in single points
## and the exact number is the decision. Hull does not work that way: it runs
## from 22 on a Hairpin to 55 on an Ore Barge, so one cell per point would draw
## a gauge that changes length when you change ships and needs fifty-five cells
## at the top end.
##
## Ten cells always, each one a tenth of whatever your maximum happens to be.
## The exact figure lives in the tooltip, because "how close am I to dying" is
## the question you ask every turn and "37 of 40" is the one you ask rarely.
enum Mode { HEAT, ENERGY, HULL }

const HULL_CELLS := 10

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

## Set from hp and max_hp.
##
## Rounds DOWN, with a floor of one cell while any hull remains. Both halves of
## that matter and they pull opposite ways. Rounding down means ten cells is
## reachable only at FULL hull, so "have I taken a scratch" is answerable at a
## glance — rounding up hid the first 10% of damage behind a full-looking bar.
## The floor of one means a ship on 1 of 40 still draws a cell, because an empty
## gauge has to mean destroyed and nothing else.
func set_hull(hp: int, max_hp: int) -> void:
	mode = Mode.HULL
	cap = HULL_CELLS
	_ratio = 0.0 if max_hp <= 0 else clampf(float(hp) / float(max_hp), 0.0, 1.0)
	value = 0 if hp <= 0 else maxi(1, int(floor(_ratio * HULL_CELLS)))
	custom_minimum_size = Vector2(_width(), CELL.y)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	queue_redraw()

var _ratio: float = 1.0

## 0 empty · 1 cool · 2 hot · 3 critical · 4 sound
func _fill_for(i: int) -> int:
	if i >= value:
		return 0
	if mode == Mode.ENERGY:
		return 2
	if mode == Mode.HULL:
		# Whole-bar colour, not per-cell. Hull is one condition, and a gauge that
		# shades cell by cell reads as a gradient you have to interpret rather
		# than a state you can see. 0.35 is the same threshold the hull figure
		# has always turned amber at.
		if _ratio < 0.35:
			return 3
		return 2 if _ratio < 0.6 else 4
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
		4:
			bg = UITheme.HULL_GREEN
			hi = UITheme.GOOD
			lo = Color("#25402f")

	draw_rect(Rect2(pos, CELL), bg, true)
	draw_rect(Rect2(pos, Vector2(CELL.x, 1)), hi, true)
	draw_rect(Rect2(pos, Vector2(1, CELL.y)), hi, true)
	draw_rect(Rect2(pos + Vector2(0, CELL.y - 1), Vector2(CELL.x, 1)), lo, true)
	draw_rect(Rect2(pos + Vector2(CELL.x - 1, 0), Vector2(1, CELL.y)), lo, true)
