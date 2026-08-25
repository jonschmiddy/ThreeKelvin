class_name PerkBox
extends VBoxContainer

## The perk names in the masthead's corner, and the one panel that explains them.
##
## A NODE OF ITS OWN because `_make_custom_tooltip` is a method: a plain
## VBoxContainer cannot be handed one, and a wrapped string is a poor way to
## show four perks in two groups. Every other rich tooltip in the game is built
## exactly this way — see `ModuleIcon` and `CardView`.
##
## READS `Run.hull` rather than holding a reference, because the hull changes
## under it: a chassis swap rebuilds the labels and this must not go on
## describing the frame that was sold.


## Godot only ASKS for a tooltip when `tooltip_text` is non-empty, so the string
## the screen sets is the TRIGGER, not the content — this replaces it wholesale.
## It is also what shows if the panel below ever fails to build, which is why the
## screen sets the full text rather than a placeholder.
func _make_custom_tooltip(_for_text: String) -> Object:
	if Run.hull == null:
		return null
	return Widgets.perk_readout(Run.hull)
