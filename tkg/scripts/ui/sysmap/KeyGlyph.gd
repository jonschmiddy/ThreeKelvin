extends Control

## A beacon's glyph at the size the map draws it, for the KEY and the panel's
## lists: the overlay's own 5x5 pattern, at two pixels a cell.

const SystemOverlayS := preload("res://scripts/ui/sysmap/SystemOverlay.gd")

## Marks for things that are not beacons, for the panel's lists: a world, a
## belt, a hulk, a contact. A beacon glyph beside a world read as a beacon.
const BODY := {
	&"world": [".###.", "#####", "#####", "#####", ".###."],
	&"belt": ["#...#", "..#..", "#...#", "..#..", "#...#"],
	&"derelict": [".....", "####.", "#####", ".####", "....."],
	&"contact": [".....", ".#.#.", "..#..", ".#.#.", "....."],
}

var glyph: StringName = &"signal"
var colour := Color.WHITE


func _init() -> void:
	custom_minimum_size = Vector2(12, 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var m: Array = BODY[glyph] if BODY.has(glyph) else SystemOverlayS.GLYPH.get(glyph, SystemOverlayS.GLYPH[&"signal"])
	for r in 5:
		for k in 5:
			if (m[r] as String)[k] == "#":
				draw_rect(Rect2(Vector2(1 + k * 2, 1 + r * 2), Vector2(2, 2)), colour)
