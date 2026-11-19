extends Control

## A beacon's glyph at the size the map draws it, for the KEY: MapGlyphs' 11 px picture (Jon, Nov 18);
## or one of the 5x5 marks below, at two pixels a cell (one in a badge).
## Why: docs/why/MapGlyphs.md#the-key

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
	if not BODY.has(glyph):
		# (one row down, so its middle row is the words' caps' middle, as the old 10 px glyph's was)
		MapGlyphs.draw(self, Vector2(0, 1), glyph, colour, false, false, MapGlyphs.KEY_LIFT)
		return
	var m: Array = BODY[glyph]
	var o := 1 if cell == 2 else 0
	for r in 5:
		for k in 5:
			if (m[r] as String)[k] == "#":
				draw_rect(Rect2(Vector2(o + k * cell, o + r * cell), Vector2(cell, cell)), colour)
