class_name WelcomePopup
extends Control

## Once per profile, flagged on close. No tour follows (direction B, Oct 17); the button
## says where it goes.
## Why: docs/why/WelcomePopup.md#welcome-note

const SECTION := "hints"
const KEY := "welcome"
const TITLE := "THREE KELVIN · ALPHA"
const FIRST_BUTTON := "START YOUR JOURNEY"
const AGAIN_BUTTON := "CLOSE"

signal closed

var card: NoteCard
var button: Button


static func seen() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(DisplaySettings.hints_path()) != OK:
		return false
	return bool(cfg.get_value(SECTION, KEY, false))


static func mark_seen(v: bool = true) -> void:
	var cfg := ConfigFile.new()
	cfg.load(DisplaySettings.hints_path())
	cfg.set_value(SECTION, KEY, v)
	cfg.save(DisplaySettings.hints_path())


## Whether the title screen should open it by itself.
static func due() -> bool:
	if TestRun.active() and not "welcome" in OS.get_cmdline_user_args():
		return false
	return not seen()


## `first`: opened by itself on a fresh profile, rather than from the menu.
func setup(first: bool) -> void:
	name = "WelcomePopup"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	card = NoteCard.new()
	card.build(TITLE, AlphaNotes.ALPHA_WELCOME)
	add_child(card)
	button = NoteCard.primary(FIRST_BUTTON if first else AGAIN_BUTTON, close)
	card.add_buttons([button])


## Shut it and remember it was read.
func close() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	mark_seen(true)
	queue_free()
	closed.emit()


## Escape shuts it, before the title screen's own Escape (which shuts Settings).
func _input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func note_scrolls() -> bool:
	return card.note_scrolls()


func panel_rect() -> Rect2:
	return card.panel_rect()
