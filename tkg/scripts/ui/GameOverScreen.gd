class_name GameOverScreen
extends Control

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(560, 0)

	var title := UITheme.body("THE CORE" if Run.won else "RUN ENDED",
		UITheme.ICE, 22)
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
	row.add_child(Widgets.cta("NEW RUN", func(): Router.new_run()))
	box.add_child(row)
	centre.add_child(Widgets.panel_with(box))
