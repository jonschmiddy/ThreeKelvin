class_name ManufacturerBanner
extends Control

## The card's own flag at four times scale, via `CardView.draw_cut` and `draw_emblem`.
## Thirteen units wide: hems use absolute offsets across the flag. Only the height is free.
## Why: docs/why/ChassisSelect.md#banner
const UNITS_W := 13

## Depth measured off what the draws put on it, plus a unit of air.
## Only a minimum: on chassis cards the flag hangs the header's full depth.
## Why: docs/why/ChassisSelect.md#banner
const UNITS_H := 22
const S := 3.0

## Pixels per unit per instance, so every offset scales together and a hem gets no hole.
## Set it before adding the banner, with `custom_minimum_size`: `_init` cannot see it.
## Why: docs/why/ChassisSelect.md#banner
var s: float = S

## Setting the manufacturer arms the tooltip: Godot asks only if `tooltip_text` is non-empty.
var manufacturer: StringName = &"":
	set(value):
		manufacturer = value
		var m: ManufacturerData = DB.manufacturers.get(value)
		if m == null:
			return
		tooltip_text = m.name.to_upper()
		# PASS, not STOP: a banner in a clickable card must hand the press on and still hover.
		mouse_filter = Control.MOUSE_FILTER_PASS
var mark: Color = UITheme.CHILL
var field: Color = UITheme.PANEL


## Fixed across (13 units), free down, so the flag hangs the panel's full depth.
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(UNITS_W * S, 0)
	size_flags_vertical = Control.SIZE_FILL


## The same rich-panel hook `ModuleIcon`, `CardView` and `PerkBox` use.
func _make_custom_tooltip(_for_text: String) -> Object:
	return Widgets.manufacturer_readout(manufacturer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var b := Rect2(Vector2.ZERO, size)
	draw_rect(b, field, true)
	# `UITheme.PANEL`: most hems are cut by painting the background back over the flag.
	CardView.draw_cut(self, manufacturer, b, mark, UITheme.PANEL, s)
	CardView.draw_emblem(self, manufacturer, Vector2(b.size.x * 0.5, 11.0 * s), s, mark, field)
	# Outlined in the dimmed mark: Redline's and Cygnet's fields are nearly the panel colour.
	var e := mark.darkened(0.35)
	var w := s
	draw_rect(Rect2(b.position, Vector2(b.size.x, w)), e, true)
	draw_rect(Rect2(Vector2(b.position.x, b.end.y - w), Vector2(b.size.x, w)), e, true)
	draw_rect(Rect2(b.position, Vector2(w, b.size.y)), e, true)
	draw_rect(Rect2(Vector2(b.end.x - w, b.position.y), Vector2(w, b.size.y)), e, true)
