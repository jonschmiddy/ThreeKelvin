class_name AttrBlock
extends VBoxContainer

## Cells not bars: checks are `attribute >= N`, so the exact number matters. Shared to keep
## order identical.
## Why: docs/why/AttrBlock.md#attribute-cells

const CELL := Vector2(7, 9)
const GAP := 1

## Bonus cells are white: no manufacturer accent is near it, and a teal ring collided with
## Cygnet and Calyx.
## Why: docs/why/AttrBlock.md#gain-colour
const GAIN := Color("#ffffff")

## A loss is an unlit cell with a red slash, since a red fill matches Redline's accent
## #e24b4a.
## Why: docs/why/AttrBlock.md#loss-cell
const LOSS := Color("#d4614f")


## Separator so pip count and hull do not read as one number (Jon, Oct 29, hull:B);
## `HullNumberTest`.
const AMOUNT_SEP := "· "

var _rows: Array[Cells] = []
var _values: Array[Label] = []
## The readout after a row's number, by row index: only rows that carry an
## `amount` (HULL, today) and only in a block set up with `amounts` on.
var _amounts: Dictionary = {}
var _accent: Color = UITheme.CHILL
var _label_w: float = 0.0
var _show_amounts := false

## Names are spelled out. Width is measured off the font: a guessed minimum shoves one
## row's cells out.
## Why: docs/why/AttrBlock.md#label-column-width
func _measure_labels(rows: Array[Dictionary]) -> float:
	var f := UITheme.pixel_font()
	var w := 0.0
	for a in rows:
		w = maxf(w, f.get_string_size(String(a.label), HORIZONTAL_ALIGNMENT_LEFT,
			-1, UITheme.FS_SMALL).x)
	return ceilf(w) + 4.0

## `amounts` prints the real hull next to the pips (ruling 12 C, Jon, Oct 27), but only
## where width allows.
## Why: docs/why/AttrBlock.md#amounts-and-accent
func setup(rows: Array[Dictionary], accent: Color = UITheme.CHILL,
		amounts: bool = false) -> void:
	_accent = accent
	_show_amounts = amounts
	add_theme_constant_override("separation", 2)
	Widgets.clear(self)
	_rows.clear()
	_values.clear()
	_amounts.clear()
	_label_w = _measure_labels(rows)
	for a in rows:
		add_child(_build_row(a))
	set_values(rows)

func _build_row(a: Dictionary) -> Control:
	# Two boxes: a row in a VBox is panel-wide, so one box made the tooltip fire from empty
	# space.
	# Why: docs/why/AttrBlock.md#hover-box
	var outer := HBoxContainer.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# Or the tooltip below never fires: the labels in this row are Labels, which
	# default to MOUSE_FILTER_IGNORE, so the row itself has to catch the hover.
	row.mouse_filter = Control.MOUSE_FILTER_STOP

	var label := UITheme.body(String(a.label), UITheme.CHILL, UITheme.FS_SMALL)
	label.custom_minimum_size = Vector2(_label_w, 0)
	row.add_child(label)

	var cells := Cells.new()
	cells.accent = _accent
	cells.value = int(a.value)
	cells.base = int(a.get("base", a.value))
	row.add_child(cells)
	_rows.append(cells)

	var num := UITheme.body(str(int(a.value)), UITheme.ICE, UITheme.FS_SMALL)
	num.custom_minimum_size = Vector2(9, 0)
	row.add_child(num)
	_values.append(num)

	# The real quantity the pips round from, in steel so the bright number stays the one a
	# check reads.
	if _show_amounts and a.has("amount"):
		var amt := UITheme.body(AMOUNT_SEP + String(a.amount), UITheme.CHILL, UITheme.FS_SMALL)
		row.add_child(amt)
		_amounts[_values.size() - 1] = amt

	# Change shows as a signed number, not painted cells: the cell version read red on a
	# better frame.
	# Why: docs/why/AttrBlock.md#change-column
	var d := int(a.get("delta", 0))
	if a.has("delta"):
		var mark := "" if d == 0 else ("+%d" % d if d > 0 else str(d))
		var dl := UITheme.body(mark,
			UITheme.GOOD if d > 0 else (LOSS if d < 0 else UITheme.QUOTE),
			UITheme.FS_SMALL)
		dl.custom_minimum_size = Vector2(20, 0)
		row.add_child(dl)

	# What the attribute actually gets checked for, on hover. Six labelled rows
	# say what the axes ARE; only the tooltip can say why you would want one.
	row.tooltip_text = Widgets.tip(_hint(a))
	outer.add_child(row)
	var slack := Control.new()
	slack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(slack)
	return outer

## Tooltip says what a pip buys, not the value or odds: `SkillCheck.badge` prints the real
## number at choice.
## Why: docs/why/AttrBlock.md#attribute-tooltip
static func _hint(a: Dictionary) -> String:
	var out := "%s\n%s" % [String(a.label).capitalize(), String(a.text)]
	var effect := String(a.get("effect", ""))
	if effect != "":
		out += "\n\n%s" % effect
	return out


## Repaint in place. Hull falls as you take damage and Sensors moves every time
## you fit something, so this is called far more often than setup().
func set_values(rows: Array[Dictionary]) -> void:
	for i in mini(rows.size(), _rows.size()):
		var v := int(rows[i].value)
		_rows[i].value = v
		_rows[i].base = int(rows[i].get("base", v))
		_rows[i].queue_redraw()
		_values[i].text = str(v)
		if _amounts.has(i):
			(_amounts[i] as Label).text = AMOUNT_SEP + String(rows[i].get("amount", ""))


class Cells extends Control:
	var value: int = 0
	## Base is the bare chassis: cells below it are the ship, above it fitted, lost ones given
	## up.
	var base: int = 0
	var accent: Color = UITheme.CHILL

	func _init() -> void:
		custom_minimum_size = Vector2(
			Run.ATTR_MAX * (AttrBlock.CELL.x + AttrBlock.GAP), AttrBlock.CELL.y)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Over ten is drawn, not clipped (Pillar 5), and needs no code: every cell lights when `i
	## < value`.
	## Why: docs/why/AttrBlock.md#over-ten
	func _draw() -> void:
		# Same optical +1 as BoxGauge: Silkscreen's caps sit high in the line box,
		# so a mathematically centred cell reads above the label beside it.
		var y: float = floor((size.y - AttrBlock.CELL.y) * 0.5) + 1.0
		var kept := mini(base, value)
		for i in Run.ATTR_MAX:
			var pos := Vector2(i * (AttrBlock.CELL.x + AttrBlock.GAP), y)
			if i < kept:
				_solid(pos, accent)
			elif i < value:
				_solid(pos, AttrBlock.GAIN)
			elif i < base:
				_lost(pos)
			else:
				draw_rect(Rect2(pos, AttrBlock.CELL), Color("#10161f"), true)
				draw_rect(Rect2(pos, AttrBlock.CELL), Color("#1e2836"), false, 1.0)

	## A filled cell with the bevel every countable box in this game wears.
	func _solid(pos: Vector2, c: Color) -> void:
		draw_rect(Rect2(pos, AttrBlock.CELL), c, true)
		draw_rect(Rect2(pos, Vector2(AttrBlock.CELL.x, 1)), c.lightened(0.35), true)
		draw_rect(Rect2(pos, Vector2(1, AttrBlock.CELL.y)), c.lightened(0.35), true)
		draw_rect(Rect2(pos + Vector2(0, AttrBlock.CELL.y - 1),
			Vector2(AttrBlock.CELL.x, 1)), c.darkened(0.45), true)
		draw_rect(Rect2(pos + Vector2(AttrBlock.CELL.x - 1, 0),
			Vector2(1, AttrBlock.CELL.y)), c.darkened(0.45), true)

	## Lost cell is an empty body plus the one diagonal in the UI. `draw_line` stays crisp
	## unantialiased.
	## Why: docs/why/AttrBlock.md#loss-slash
	func _lost(pos: Vector2) -> void:
		draw_rect(Rect2(pos, AttrBlock.CELL), Color("#10161f"), true)
		draw_rect(Rect2(pos, AttrBlock.CELL), Color("#2a1a1e"), false, 1.0)
		draw_line(pos + Vector2(1, AttrBlock.CELL.y - 1),
			pos + Vector2(AttrBlock.CELL.x - 1, 1), AttrBlock.LOSS, 1.0)
