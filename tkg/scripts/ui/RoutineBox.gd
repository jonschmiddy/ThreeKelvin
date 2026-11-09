class_name RoutineBox
extends VBoxContainer

## THE ROUTINES ROW on the ship's left panel (science, Phase 12): one line, "ROUTINES · 4 OF 9",
## and the one panel that names them on hover.
## Why: docs/why/RoutineBox.md#the-routines-row-on-the-ships


## The rich panel. `tooltip_text` is only the trigger (and what shows if this
## ever fails to build), as on `PerkBox`.
func _make_custom_tooltip(_for_text: String) -> Object:
	if Run.owned_routines().is_empty():
		return null
	return readout()


## Every owned routine, branch by branch in the order bought: its name in EMBER,
## then what it does in COLD, indented under it (the perk panel's split, so the
## two read as one family). No plate of its own: Godot puts it on the theme's
## tooltip plate, as `Widgets.perk_readout` explains.
static func readout() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(UITheme.body("ROUTINES", UITheme.COLD, UITheme.FS_SMALL))
	box.add_child(UITheme.hsep())
	for id in Run.owned_routines():
		var r: Dictionary = DB.routines.get(id, {})
		if r.is_empty():
			continue
		box.add_child(UITheme.body(str(r.name), UITheme.EMBER, UITheme.FS_SMALL))
		# wrapped in the string, not by the label, for `_perk_rows`' reason: a
		# tooltip is measured before any container has given it a width
		box.add_child(Widgets.pad(UITheme.body(Widgets.tip(str(r.text)),
			UITheme.COLD, UITheme.FS_SMALL), 8, 0))
	box.add_child(UITheme.body(Widgets.tip(footnote()), UITheme.QUOTE, UITheme.FS_SMALL))
	return box


## The same as plain text, for `tooltip_text`.
static func tip_text() -> String:
	var out: PackedStringArray = ["ROUTINES"]
	for id in Run.owned_routines():
		var r: Dictionary = DB.routines.get(id, {})
		if not r.is_empty():
			out.append("")
			out.append(str(r.name))
			out.append(str(r.text))
	out.append("")
	out.append(footnote())
	return "\n".join(out)


## Where they live, said once under the list: why they are not with the perks.
static func footnote() -> String:
	return "They live in the flight computer, so they go with you to any hull."
