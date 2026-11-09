class_name PerkBox
extends VBoxContainer

## A node of its own, as a plain container cannot take `_make_custom_tooltip`.
## Why: docs/why/PerkBox.md#perk-box


## Godot asks for a tooltip only when `tooltip_text` is set, so the text is trigger and fallback.
func _make_custom_tooltip(_for_text: String) -> Object:
	if Run.hull == null:
		return null
	return Widgets.perk_readout(Run.hull)
