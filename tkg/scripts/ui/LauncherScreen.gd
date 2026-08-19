class_name LauncherScreen
extends Control

## Title screen. The first thing the game shows, and the only screen that exists
## before a run does.
##
## It has to work with NO run loaded — Run.hull is null until something starts
## one — so nothing here may read ship state. Router hides the HUD while this is
## up for the same reason: a bar showing 0/0 hull above a title screen is a bug
## that looks like a design.
##
## CONTINUE is offered only when a suspend save is on disk, and it names the
## system and the hull so the button is a decision rather than a guess. Loading
## consumes the file — see SaveGame.

const SUBTITLE := "three degrees above absolute zero"

var _settings: SettingsMenu = null

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	col.custom_minimum_size = Vector2(330, 0)

	var title := UITheme.body("THREE KELVIN", UITheme.ICE, UITheme.FS_HEAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var sub := UITheme.body(SUBTITLE, UITheme.COLD, UITheme.FS_SMALL)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	col.add_child(UITheme.hsep())

	var save := SaveGame.summary()
	if not save.is_empty():
		col.add_child(Widgets.button("CONTINUE RUN", func() -> void: Router.continue_run()))
		var line := UITheme.body(_save_line(save), UITheme.QUOTE, UITheme.FS_SMALL)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(line)

	col.add_child(Widgets.button("NEW RUN", func() -> void: Router.new_run()))
	col.add_child(Widgets.button("FLIGHT RECORD", func() -> void: Router.show_history(true)))
	col.add_child(Widgets.button("SETTINGS", _open_settings))

	col.add_child(UITheme.hsep())
	col.add_child(Widgets.button("QUIT", func() -> void: get_tree().quit()))

	if not save.is_empty():
		var warn := UITheme.body(
			"Continuing consumes the save. There is no going back to it.",
			UITheme.COLD, UITheme.FS_SMALL)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(warn)

	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 34)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 28)
	pad.add_child(col)
	centre.add_child(Widgets.panel_with(pad))

## Where the ship is and how it is doing — enough to recognise the run without
## loading it.
func _save_line(s: Dictionary) -> String:
	return "%s — %s, danger %d · %d/%d hull · %d jumps" % [
		str(s.galaxy), str(s.system), int(s.danger),
		int(s.hp), int(s.max_hp), int(s.jumps)]

## Settings open as a child of this screen rather than of Main. Main's copy is
## reached through the escape menu, which needs a run behind it; this one has to
## work when there is nothing behind it at all.
func _open_settings() -> void:
	if _settings != null:
		return
	_settings = SettingsMenu.new()
	add_child(_settings)
	_settings.setup()
	_settings.closed.connect(func() -> void:
		if _settings != null:
			_settings.queue_free()
			_settings = null)
