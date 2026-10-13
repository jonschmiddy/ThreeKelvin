class_name WelcomePopup
extends Control

## JON'S WELCOME NOTE (`AlphaNotes.ALPHA_WELCOME`), over the title screen.
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
## The title menu's MESSAGE FROM JON opens it again at any time.
##
## Styled as the win screen: the same panel and the same note column, with one
## button. CLOSE or Escape shuts it.

const SECTION := "hints"
const KEY := "welcome"

## The win screen's width (`GameOverScreen.WIN_W`), so the two notes read as a pair.
const W := GameOverScreen.WIN_W
const EDGE := GameOverScreen.EDGE

signal closed

var _scroll: ScrollContainer = null
var _panel: PanelContainer = null


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


func _init() -> void:
	name = "WelcomePopup"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# the title's own popups' dim (`LauncherScreen._open_popup`)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.80)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(W, 0)

	var note := UITheme.body(AlphaNotes.ALPHA_WELCOME, UITheme.CHILL, UITheme.FS_BODY)
	note.name = "AlphaWelcome"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(W, 0)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(note)
	box.add_child(_scroll)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(Widgets.button("CLOSE", close))
	box.add_child(row)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel",
		UITheme.flat(Color(UITheme.PANEL, UITheme.PANEL_A), UITheme.LINE, 0, 14, 18))
	_panel.add_child(box)
	centre.add_child(_panel)
	resized.connect(_fit)


func _ready() -> void:
	_fit.call_deferred()


## Shut it and remember it was read.
func close() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	mark_seen(true)
	queue_free()
	closed.emit()


## Escape is CLOSE, before the title screen's own Escape (which shuts Settings).
func _input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


## The note scrolls only if the window is too short for the whole panel, as the
## win screen's does (`GameOverScreen._fit`).
func _fit() -> void:
	if _scroll == null or _panel == null or not is_inside_tree():
		return
	var note := _scroll.get_child(0) as Control
	var want := note.get_combined_minimum_size().y
	var rest := _panel.get_combined_minimum_size().y - _scroll.get_combined_minimum_size().y
	var room := size.y - 2.0 * EDGE - rest
	if want <= room:
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.custom_minimum_size.y = 0.0
	else:
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_scroll.custom_minimum_size.y = maxf(48.0, room)


func note_scrolls() -> bool:
	return _scroll != null and _scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED


func panel_rect() -> Rect2:
	return _panel.get_global_rect() if _panel != null else Rect2()
