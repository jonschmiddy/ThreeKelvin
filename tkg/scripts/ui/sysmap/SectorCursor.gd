extends Node2D

## THE SCANNING CURSOR, the star chart's (`StarchartScreen.Crosshair`) laid down
## on the sector's plane (Jon: "the same type of scanning cursor and sound like
## the starchart has ... at the same angle as the sector"). The chart crosses
## level and plumb; here the two lines run along the fabric's own diagonals, so
## on screen they lean at the plane's slant, and a ring the size of a small
## world lies flat on the plane under the cursor. Dashed like the chart's, with
## the dashes held still and only the lines moving, and a notch where each line
## leaves the frame.

const DASH := 2.0
const GAP := 3.0
const NOTCH := 4.0
## Stronger than the chart's 0.12: these lie along the fabric's own diagonals,
## and at the chart's strength they vanished into its grey lines.
const CROSS_ALPHA := 0.4
const NOTCH_ALPHA := 0.8
const RING_ALPHA := 0.6
const RING_R := 9.0

var view
## Where the cursor is on the map, or x < 0 when it is off the map.
var at := Vector2(-1, -1)


func _draw() -> void:
	if at.x < 0.0 or view == null:
		return
	var win: Rect2 = view.window
	var line := Color(UITheme.ICE, CROSS_ALPHA)
	var notch := Color(UITheme.ICE, NOTCH_ALPHA)
	var c := at.floor()
	for slope in [view.TILT, -view.TILT]:
		# one pixel a column, so the line steps like the fabric's; the dash
		# pattern counts columns from the frame's edge, so it holds still
		var x0 := win.position.x
		var x1 := win.end.x
		var x := x0
		while x < x1:
			var phase := fmod(x - x0, DASH + GAP)
			if phase < DASH:
				var y := floorf(c.y + (x - c.x) * slope)
				if y >= win.position.y and y < win.end.y:
					draw_rect(Rect2(x, y, 1.0, 1.0), line)
			x += 1.0
		# a notch where the line meets each side of the frame
		for side in [x0, x1 - NOTCH]:
			var y2 := floorf(c.y + (side - c.x) * slope)
			if y2 >= win.position.y and y2 < win.end.y:
				for k in NOTCH:
					draw_rect(Rect2(side + k, floorf(c.y + (side + k - c.x) * slope), 1.0, 1.0), notch)
	# the ring, flat on the plane: a circle seen at the plane's tilt
	var ring := Color(UITheme.ICE, RING_ALPHA)
	var n := 40
	for i in n:
		var a := float(i) / n * TAU
		var p := (c + Vector2(cos(a) * RING_R, sin(a) * RING_R * view.TILT)).floor()
		draw_rect(Rect2(p, Vector2.ONE), ring)
