class_name SettingsMenu
extends Control

## Settings overlay, reached from the escape menu.
##
## Options show what they will do before you pick them, and the current one is
## marked — a settings screen that makes you toggle blind to find out is worse
## than no settings screen.

signal closed

var _mode_rows: VBoxContainer
var _screen_row: HBoxContainer
var _scale_row: HBoxContainer
var _blurb: Label

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim := ColorRect.new()
	scrim.color = Color(UITheme.VOID, 0.9)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 20)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 16)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.custom_minimum_size = Vector2(300, 0)
	pad.add_child(col)
	center.add_child(Widgets.panel_with(pad))

	var title := UITheme.body("DISPLAY", UITheme.ICE, UITheme.FS_HEAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(UITheme.hsep())

	_mode_rows = VBoxContainer.new()
	_mode_rows.add_theme_constant_override("separation", 3)
	col.add_child(_mode_rows)

	_blurb = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(300, 0)
	col.add_child(_blurb)

	col.add_child(UITheme.hsep())
	col.add_child(UITheme.body("MONITOR", UITheme.COLD, UITheme.FS_SMALL))
	_screen_row = HBoxContainer.new()
	_screen_row.add_theme_constant_override("separation", 4)
	col.add_child(_screen_row)

	col.add_child(UITheme.hsep())
	col.add_child(UITheme.body("WINDOW SIZE", UITheme.COLD, UITheme.FS_SMALL))
	_scale_row = HBoxContainer.new()
	_scale_row.add_theme_constant_override("separation", 4)
	col.add_child(_scale_row)

	col.add_child(UITheme.hsep())
	col.add_child(Widgets.button("BACK", func() -> void: closed.emit()))

	_refresh()

func _refresh() -> void:
	for c in _mode_rows.get_children():
		c.queue_free()
	for m in [DisplaySettings.Mode.WINDOWED, DisplaySettings.Mode.BORDERLESS,
			DisplaySettings.Mode.FULLSCREEN]:
		var picked: bool = DisplaySettings.mode == m
		var b := Widgets.button(("> " if picked else "  ") + DisplaySettings.mode_name(m),
			func() -> void:
				DisplaySettings.set_mode(m)
				_refresh())
		b.tooltip_text = DisplaySettings.mode_blurb(m)
		b.disabled = picked
		_mode_rows.add_child(b)
	_blurb.text = DisplaySettings.mode_blurb(DisplaySettings.mode)

	for c in _screen_row.get_children():
		c.queue_free()
	var count := DisplayServer.get_screen_count()
	if count <= 1:
		_screen_row.add_child(UITheme.body("only one monitor detected",
			UITheme.COLD, UITheme.FS_SMALL))
	else:
		for i in count:
			var picked_screen: bool = DisplaySettings.safe_screen() == i
			var sb := Widgets.button(("> " if picked_screen else "  ") + DisplaySettings.screen_label(i),
				func() -> void:
					DisplaySettings.set_screen(i)
					_refresh())
			sb.disabled = picked_screen
			sb.tooltip_text = "Move the game to this monitor. * marks your primary."
			_screen_row.add_child(sb)

	for c in _scale_row.get_children():
		c.queue_free()
	var top := DisplaySettings.max_window_scale()
	for s in range(1, top + 1):
		var size := DisplaySettings.BASE * s
		var b2 := Widgets.button("%dx  %d/%d" % [s, size.x, size.y],
			func() -> void:
				DisplaySettings.set_scale(s)
				_refresh())
		b2.disabled = DisplaySettings.mode == DisplaySettings.Mode.WINDOWED \
			and DisplaySettings.window_scale == s
		_scale_row.add_child(b2)
	# On a 1080p screen 2x is exactly the screen height, so the only windowed
	# size that keeps its title bar is 1x. Say so rather than hiding the option.
	if top == 1:
		_scale_row.add_child(UITheme.body("larger sizes need borderless",
			UITheme.COLD, UITheme.FS_SMALL))
