class_name AttrBlock
extends VBoxContainer

## The six attributes, as countable cells.
##
## Cells rather than bars, for the same reason heat and energy are cells: a
## check is `attribute >= N`, so the player needs the exact number, not roughly
## how full something is. A bar that looks two-thirds full answers no question
## anyone is about to be asked.
##
## Shared by the ship tab and the chassis select so the two can never disagree
## about the order, the names or the ceiling — and the order itself comes from
## RunState.attributes(), which is the only place it is written down.

const CELL := Vector2(7, 9)
const GAP := 1

var _rows: Array[Cells] = []
var _values: Array[Label] = []
var _accent: Color = UITheme.CHILL
var _label_w: float = 0.0

## Names are spelled out rather than abbreviated — HUL/THR/MNV is a code you
## have to learn, and six rows leave room to just say what they are.
##
## The column width is MEASURED off the font rather than guessed at, because a
## Label's custom_minimum_size is a minimum: guess low and the longest name
## takes its natural width instead, shoving that one row's cells out of the
## column while the other five stay put. Asking the font is the only version
## that cannot be wrong at a size nobody re-checked.
func _measure_labels(rows: Array[Dictionary]) -> float:
	var f := UITheme.pixel_font()
	var w := 0.0
	for a in rows:
		w = maxf(w, f.get_string_size(String(a.label), HORIZONTAL_ALIGNMENT_LEFT,
			-1, UITheme.FS_SMALL).x)
	return ceilf(w) + 4.0

## `accent` tints the filled cells. The chassis select passes the manufacturer's
## colour, which is what makes a Solari attribute row read as Solari before you
## have read a word of it; the ship tab passes the hull's maker for the same
## reason. Steel is the fallback for an unbranded frame.
func setup(rows: Array[Dictionary], accent: Color = UITheme.CHILL) -> void:
	_accent = accent
	add_theme_constant_override("separation", 2)
	for c in get_children():
		c.queue_free()
	_rows.clear()
	_values.clear()
	_label_w = _measure_labels(rows)
	for a in rows:
		add_child(_build_row(a))
	set_values(rows)

func _build_row(a: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	# Or the tooltip below never fires: the labels in this row are Labels, which
	# default to MOUSE_FILTER_IGNORE, so the row itself has to catch the hover.
	row.mouse_filter = Control.MOUSE_FILTER_STOP

	var label := UITheme.body(String(a.label), UITheme.CHILL, UITheme.FS_SMALL)
	label.custom_minimum_size = Vector2(_label_w, 0)
	row.add_child(label)

	var cells := Cells.new()
	cells.accent = _accent
	cells.value = int(a.value)
	row.add_child(cells)
	_rows.append(cells)

	var num := UITheme.body(str(int(a.value)), UITheme.ICE, UITheme.FS_SMALL)
	num.custom_minimum_size = Vector2(9, 0)
	row.add_child(num)
	_values.append(num)

	# What the attribute actually gets checked for, on hover. Six labelled rows
	# say what the axes ARE; only the tooltip can say why you would want one.
	row.tooltip_text = "%s — %s" % [String(a.label), String(a.text)]
	return row

## Repaint in place. Hull falls as you take damage and Sensors moves every time
## you fit something, so this is called far more often than setup().
func set_values(rows: Array[Dictionary]) -> void:
	for i in mini(rows.size(), _rows.size()):
		var v := int(rows[i].value)
		_rows[i].value = v
		_rows[i].queue_redraw()
		_values[i].text = str(v)


class Cells extends Control:
	var value: int = 0
	var accent: Color = UITheme.CHILL

	func _init() -> void:
		custom_minimum_size = Vector2(
			Run.ATTR_MAX * (AttrBlock.CELL.x + AttrBlock.GAP), AttrBlock.CELL.y)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# Same optical +1 as BoxGauge: Silkscreen's caps sit high in the line box,
		# so a mathematically centred cell reads above the label beside it.
		var y: float = floor((size.y - AttrBlock.CELL.y) * 0.5) + 1.0
		for i in Run.ATTR_MAX:
			var pos := Vector2(i * (AttrBlock.CELL.x + AttrBlock.GAP), y)
			if i < value:
				draw_rect(Rect2(pos, AttrBlock.CELL), accent, true)
				draw_rect(Rect2(pos, Vector2(AttrBlock.CELL.x, 1)),
					accent.lightened(0.35), true)
				draw_rect(Rect2(pos, Vector2(1, AttrBlock.CELL.y)),
					accent.lightened(0.35), true)
				draw_rect(Rect2(pos + Vector2(0, AttrBlock.CELL.y - 1),
					Vector2(AttrBlock.CELL.x, 1)), accent.darkened(0.45), true)
				draw_rect(Rect2(pos + Vector2(AttrBlock.CELL.x - 1, 0),
					Vector2(1, AttrBlock.CELL.y)), accent.darkened(0.45), true)
			else:
				draw_rect(Rect2(pos, AttrBlock.CELL), Color("#10161f"), true)
				draw_rect(Rect2(pos, AttrBlock.CELL), Color("#1e2836"), false, 1.0)
