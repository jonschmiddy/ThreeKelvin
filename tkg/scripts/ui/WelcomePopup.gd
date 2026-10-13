class_name WelcomePopup
extends Control

## JON'S WELCOME NOTE (`AlphaNotes.ALPHA_WELCOME`), over the title screen, as a
## letter (`NoteCard`).
##
## ONCE PER PROFILE on its own: the first time the title screen opens, and never
## again once it has been CLOSED (a player who quits with it still up sees it
## next time, since they never got past it). The seen flag sits beside the
## first-run intro's, `[hints] welcome` in settings.cfg, through the intro's
## own `store_path` -- so under a harness it is the per-process scratch file.
## Never shown by itself under a harness unless asked (`-- welcome`), the intro's
## rule, so no other harness meets it on the title screen.
##
## It never touches the first-run intro: that plays after the hull pick, and this
## covers the title until it is closed, so the two cannot be up together.
##
## The title menu's MESSAGE FROM JON opens it again at any time. ITS BUTTON SAYS
## WHERE IT GOES (Jon): START YOUR JOURNEY the first time, when the next thing is
## the game; CLOSE from the menu, where it only puts the note away. Escape shuts
## it either way.

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
	if cfg.load(FirstRunIntro.store_path()) != OK:
		return false
	return bool(cfg.get_value(SECTION, KEY, false))


static func mark_seen(v: bool = true) -> void:
	var cfg := ConfigFile.new()
	cfg.load(FirstRunIntro.store_path())
	cfg.set_value(SECTION, KEY, v)
	cfg.save(FirstRunIntro.store_path())


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
