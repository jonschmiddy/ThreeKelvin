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

## What a fitted module ADDED. Bright white, and the white is the point.
##
## The base cells stay the MANUFACTURER's colour — that is the ship, and it is
## what makes a Solari row read as Solari before you have read a word. So the
## bonus has to wear a colour no house flies, or it just reads as more chassis.
##
## White is the one that is left. The seven accents are #d97b2e, #ef9f27,
## #b3924e, #e24b4a, #8a7340, #58c8d8 and #3f8f6b — between them they cover
## orange, gold, red, cyan and green, and none is within reach of white. It is
## also the brightest thing on the panel, which is correct: a bonus should be
## where the eye lands.
##
## The version before this was teal with a bright ring around it, because teal
## collides with Cygnet and Calyx and needed structure to survive them. White
## needs no ring.
const GAIN := Color("#ffffff")

## What a fitted module TOOK AWAY — a Solari flare rack costs stealth, and the
## row has to be able to say so.
##
## Drawn as an UNLIT cell with a red slash through it, never as a red fill:
## Redline's accent is #e24b4a, so a filled red cell is indistinguishable from a
## Redline ship's ordinary ones. An unlit cell struck through reads as absence
## against every accent in the game, because it is not competing on colour at
## all — the cell is dark like an empty one, and the slash says something took it.
const LOSS := Color("#d4614f")

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
	Widgets.clear(self)
	_rows.clear()
	_values.clear()
	_label_w = _measure_labels(rows)
	for a in rows:
		add_child(_build_row(a))
	set_values(rows)

func _build_row(a: Dictionary) -> Control:
	# TWO boxes, and the outer one is why. A row in a VBox stretches to the full
	# panel width, so a single HBox carrying the tooltip made the hover target
	# ~550px wide for ~140px of content — the attribute tooltip fired from empty
	# space halfway across the screen, and from directly over the abilities block
	# below it. The inner box shrinks to its content and owns the hover; the
	# outer one is inert and just holds the slack.
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

	# What the attribute actually gets checked for, on hover. Six labelled rows
	# say what the axes ARE; only the tooltip can say why you would want one.
	row.tooltip_text = Widgets.tip(_hint(a))
	outer.add_child(row)
	var slack := Control.new()
	slack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(slack)
	return outer

## What the attribute is FOR, in the same shape as the weight-class tooltips:
## the name, then one sentence.
##
## It used to also print the value and a "Chassis 40, fitted modules +3" split.
## Both were repeating the row they were attached to — the cells and the number
## are an inch away, and the split is visible in the cells themselves, which
## already paint the chassis in the house colour and anything fitted in white.
## A tooltip that restates what you are pointing at is a tooltip you stop reading.
static func _hint(a: Dictionary) -> String:
	return "%s\n%s" % [String(a.label).capitalize(), String(a.text)]

## Repaint in place. Hull falls as you take damage and Sensors moves every time
## you fit something, so this is called far more often than setup().
func set_values(rows: Array[Dictionary]) -> void:
	for i in mini(rows.size(), _rows.size()):
		var v := int(rows[i].value)
		_rows[i].value = v
		_rows[i].base = int(rows[i].get("base", v))
		_rows[i].queue_redraw()
		_values[i].text = str(v)


class Cells extends Control:
	var value: int = 0
	## What the bare chassis reads. Cells below this are the ship; cells between
	## this and `value` are what you fitted; cells between `value` and this — when
	## a module made the attribute WORSE — are what you gave up.
	var base: int = 0
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

	## A cell the chassis had and a fitted module took away: an unlit cell with a
	## red slash across it. Never a red FILL — see AttrBlock.LOSS.
	##
	## The cell body is drawn exactly like an empty one, because that is what it
	## now is. Only the slash is added, and it is the sole diagonal anywhere in
	## this interface — which is what makes it read as a strike-through rather
	## than as another piece of chrome.
	##
	## draw_line rather than stepped rects: Godot leaves it unantialiased by
	## default, so it stays crisp on the pixel grid at this size.
	func _lost(pos: Vector2) -> void:
		draw_rect(Rect2(pos, AttrBlock.CELL), Color("#10161f"), true)
		draw_rect(Rect2(pos, AttrBlock.CELL), Color("#2a1a1e"), false, 1.0)
		draw_line(pos + Vector2(1, AttrBlock.CELL.y - 1),
			pos + Vector2(AttrBlock.CELL.x - 1, 1), AttrBlock.LOSS, 1.0)
