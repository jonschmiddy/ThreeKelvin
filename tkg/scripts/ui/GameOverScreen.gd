class_name GameOverScreen
extends Control

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var box := VBoxContainer.new()
	# TIGHT AROUND WHAT IT SAYS. It was 330 wide with 14 between its three
	# blocks, and the longest line in it is about 220 -- so the panel was mostly
	# air, which reads as an unfinished screen rather than a quiet one (Jon).
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(250, 0)

	# The two endings do not get the same colour. Reaching the core is the one
	# thing in this game that goes right; a run ending is the other outcome and
	# it should say so before the sentence under it is read. BAD rather than a
	# literal, so it moves with the palette like everything else.
	var title := UITheme.body("THE CORE" if Run.won else "RUN ENDED",
		UITheme.ICE if Run.won else UITheme.BAD, UITheme.FS_HEAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var lines: PackedStringArray = []
	if Run.won:
		lines.append("You cross into the light with %d hull left." % Run.hp)
	else:
		lines.append(Run.death_reason)
	lines.append("%d jumps · %d kills · danger %d when it ended" % [
		Run.jumps, Run.kills, Run.node_at().danger])
	# The whole ledger, not just the row that used to be a field — exotics you
	# never got to a bench is as much a thing you were carrying when it ended as
	# scrap you never spent.
	var held: PackedStringArray = ["%d credits unspent" % Run.credits]
	for stock in Run.material_stock():
		held.append("%d %s" % [int(stock.count), str(stock.name).to_lower()])
	lines.append(" · ".join(held))
	var body := UITheme.body("\n".join(lines), UITheme.COLD, UITheme.FS_BODY)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(Widgets.button("NEW RUN", func(): Router.new_run()))
	box.add_child(row)
	# Its own panel rather than `panel_with`, whose 12 px all round was written
	# for panels with a list in them.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		UITheme.flat(Color(UITheme.PANEL, UITheme.PANEL_A), UITheme.LINE, 0, 14, 18))
	panel.add_child(box)
	centre.add_child(panel)
