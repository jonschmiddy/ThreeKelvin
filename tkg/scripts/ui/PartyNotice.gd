class_name PartyNotice
extends PanelContainer

## A log line scrolls away, so a galaxy mismatch sits over everything until clicked.
## Why: docs/why/PartyNotice.md#party-notice

const TOP := 34.0
const W := 520.0

var _text: Label


func _ready() -> void:
	top_level = true
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_theme_stylebox_override("panel",
		UITheme.flat(Color(UITheme.PANEL, 0.96), UITheme.THEM, 1, 6, 6))
	_text = UITheme.body("", UITheme.THEM, UITheme.FS_SMALL)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.custom_minimum_size = Vector2(W - 12.0, 0)
	add_child(_text)
	Sig.party_notice.connect(show_line)
	get_viewport().size_changed.connect(_place)
	# Said before this screen existed (a mismatch can land during the swap into
	# the chassis select): shown now.
	if Net.galaxy_warning != "":
		show_line(Net.galaxy_warning)


func show_line(text: String) -> void:
	_text.text = text + "  (click to close)"
	visible = true
	reset_size()
	_place()


func _place() -> void:
	var vw := get_viewport_rect().size.x
	size.x = W
	position = Vector2(roundf((vw - W) * 0.5), TOP)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		visible = false
		accept_event()
