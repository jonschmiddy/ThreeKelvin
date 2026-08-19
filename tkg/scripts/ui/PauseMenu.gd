class_name PauseMenu
extends Control
## Escape menu. Overlays the game rather than replacing it, so the run behind it
## stays intact and visible — the ship never disappears, which is the same rule
## the encounter layout follows.
##
## Built in code against UITheme/Widgets like every other screen. Nothing here
## pauses the tree: the game is turn-based and advances only on input, and the
## scrim already swallows every click.

signal resume_requested
signal new_run_requested
signal quit_requested
signal settings_requested
signal save_and_quit_requested

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Swallow clicks so the chart underneath cannot be interacted with.
	mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim := ColorRect.new()
	scrim.color = Color(UITheme.VOID, 0.86)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 34)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 28)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(300, 0)
	pad.add_child(col)
	center.add_child(Widgets.panel_with(pad))

	var title := UITheme.body("THREE KELVIN", UITheme.ICE, UITheme.FS_HEAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var sub := UITheme.body("three degrees above absolute zero", UITheme.COLD, UITheme.FS_SMALL)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	col.add_child(UITheme.hsep())

	col.add_child(Widgets.button("RESUME", func() -> void: resume_requested.emit()))
	col.add_child(Widgets.button("ABANDON RUN — START OVER",
		func() -> void: new_run_requested.emit()))
	col.add_child(Widgets.button("SETTINGS", func() -> void: settings_requested.emit()))

	col.add_child(UITheme.hsep())

	# Two ways out, and the difference between them is the whole save model.
	# SAVE & EXIT writes a bookmark you resume from once; the other throws the
	# run away. The autosave means the first is what happens anyway if the
	# process dies — this button exists so the player knows that.
	#
	# Both land on the TITLE SCREEN rather than closing the game. Leaving a run
	# and leaving the program are different intentions, and the title screen is
	# where the answer to "what now" lives — including CONTINUE, which is the
	# thing SAVE & EXIT just created.
	col.add_child(Widgets.button("SAVE & EXIT TO TITLE",
		func() -> void: save_and_quit_requested.emit()))
	col.add_child(Widgets.button("ABANDON — EXIT TO TITLE",
		func() -> void: quit_requested.emit()))

	var hint := UITheme.body("esc closes this menu", UITheme.COLD, UITheme.FS_SMALL)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

