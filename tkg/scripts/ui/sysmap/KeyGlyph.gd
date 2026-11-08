extends Control

## A beacon's glyph at the size the map draws it, for the KEY and the panel's
## lists: the overlay's own 5x5 pattern, at two pixels a cell.

const SystemOverlayS := preload("res://scripts/ui/sysmap/SystemOverlay.gd")

## Marks for non-beacon things in the lists: a beacon glyph beside a world read as a beacon.
## The state badges are a tick, a cross, a figure and an arrow back (Jon picked the stamp).
const BODY := {
	&"world": [".###.", "#####", "#####", "#####", ".###."],
	&"belt": ["#...#", "..#..", "#...#", "..#..", "#...#"],
	&"derelict": [".....", "####.", "#####", ".####", "....."],
	&"contact": [".....", ".#.#.", "..#..", ".#.#.", "....."],
	&"star": ["..#..", ".###.", "#####", ".###.", "..#.."],
	&"tick": ["....#", "...#.", "#.#..", ".#...", "....."],
	&"cross": ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
	&"who": ["..#..", ".###.", "..#..", ".###.", "#...#"],
	&"back": ["..#..", ".#...", "#####", ".#...", "..#.."],
}

var glyph: StringName = &"signal"
var colour := Color.WHITE
## Pixels a cell: 2 for the map's own size, 1 for a mark inside a badge.
var cell := 2


func _init() -> void:
	custom_minimum_size = Vector2(12, 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


## One pixel a cell, for a badge's mark.
func small() -> Control:
	cell = 1
	custom_minimum_size = Vector2(5, 5)
	return self


func _draw() -> void:
	var m: Array = BODY[glyph] if BODY.has(glyph) else SystemOverlayS.GLYPH.get(glyph, SystemOverlayS.GLYPH[&"signal"])
	var o := 1 if cell == 2 else 0
	for r in 5:
		for k in 5:
			if (m[r] as String)[k] == "#":
				draw_rect(Rect2(Vector2(o + k * cell, o + r * cell), Vector2(cell, cell)), colour)
