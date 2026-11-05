class_name NewThingsPopup
extends Control

## NEW THINGS (Jon, Nov 5): what changed in each build (`NewThings`), newest
## first, over the title screen in the note's own case (`NoteCard`) so it reads
## as the same kind of page as MESSAGE FROM JON beside it in the menu.
##
## Each version is a heading (the version, and the day it went out on the
## right) over its lines, each line behind a small pip. The list scrolls inside
## the case when it is taller than the window (`NoteCard._fit`): by the wheel,
## the bar, or Up, Down, Page Up, Page Down, Home and End. CLOSE or Escape shuts
## it. Opening it marks the newest notes seen (`NewThings.mark_seen`), which
## takes the mark off the menu's NEW THINGS.
##
## Built once, when it opens. Nothing here is rebuilt while it is up.

const TITLE := "NEW THINGS"
const CLOSE := "CLOSE"
## One arrow key's step, in pixels: two lines of the list's type.
const STEP := 24

signal closed

var card: NoteCard
var button: Button


func setup() -> void:
	name = "NewThingsPopup"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	card = NoteCard.new()
	card.build(TITLE, "")
	card.set_note(_list())
	add_child(card)
	button = NoteCard.primary(CLOSE, close)
	card.add_buttons([button])
	NewThings.mark_seen()


## Every version, newest first.
func _list() -> Control:
	var col := VBoxContainer.new()
	col.name = "NewList"
	col.add_theme_constant_override("separation", 14)
	for e in NewThings.LIST:
		col.add_child(_entry(e))
	return col


func _entry(e: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.name = "Entry"
	box.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", 8)
	var v := UITheme.body(NewThings.heading(e), UITheme.HOT, UITheme.FS_BODY)
	v.name = "Version"
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(v)
	var d := UITheme.body(NewThings.day(e), UITheme.COLD, UITheme.FS_BODY)
	d.name = "Day"
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(d)
	box.add_child(head)
	var sc := TransferView.Scan.new()
	sc.custom_minimum_size = Vector2(0, 5)
	box.add_child(sc)
	for l in e.lines:
		box.add_child(_line(str(l)))
	return box


## One line of the list: a pip, then the words, wrapping under themselves.
func _line(text: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "Line"
	row.add_theme_constant_override("separation", 6)
	var pip := Pip.new()
	pip.custom_minimum_size = Vector2(4, 8)
	pip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(pip)
	var t := UITheme.body(text, UITheme.CHILL, UITheme.FS_BODY)
	t.name = "Text"
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_constant_override("line_spacing", 4)
	row.add_child(t)
	return row


func close() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	queue_free()
	closed.emit()


## Escape shuts it, before the title's own Escape (which shuts Settings). The
## arrow and page keys move the list; the title would eat the arrows otherwise.
func _input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed:
		return
	if k.keycode == KEY_ESCAPE:
		if not k.echo:
			get_viewport().set_input_as_handled()
			close()
		return
	var sc := card.note_scroll() if card != null else null
	if sc == null:
		return
	var page := maxi(STEP, int(sc.size.y) - STEP)
	var to := sc.scroll_vertical
	match k.keycode:
		KEY_DOWN: to += STEP
		KEY_UP: to -= STEP
		KEY_PAGEDOWN: to += page
		KEY_PAGEUP: to -= page
		KEY_HOME: to = 0
		KEY_END: to = int(sc.get_v_scroll_bar().max_value)
		_: return
	get_viewport().set_input_as_handled()
	sc.scroll_vertical = to


func panel_rect() -> Rect2:
	return card.panel_rect()


## The small square before each line, on the first line's middle.
class Pip extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(0, 3, 2, 2), UITheme.EMBER)
