class_name LabScene
extends StationRoom

## The Laboratory: a lab, with the fabricator built into it as a fume hood.
##
## IT WAS A MACHINE ROOM WITH TANKS IN IT. Pipes, culture tanks and a big steel
## case read as industry -- the Exchange with a different machine in it. What
## makes a room a LAB is the kit nobody would put anywhere else: a fume hood with
## its sash and its exhaust, a whiteboard somebody has been thinking on, a bench
## of glassware with a microscope and a monitor, a shelf of specimen jars, cold
## white light. The recipes live behind the hood's glass; the rest is the room.
##
## EXACTLY ONE TANK IS ALIVE, the promise the rail's cutaway made -- and under cold
## light that one warm tank is the most alive thing on the deck.

const LAB_FLOOR_H := 60.0
## Where the fume hood stands, as fractions of the width, how tall it is and how
## far its foot sits up from the bottom edge. The screen positions it by these.
const MACHINE_L := 0.25
const MACHINE_R := 0.75
## A FIXED HEIGHT, STANDING ON THE FLOOR. The first machine ran to the ceiling
## round a single recipe; two hundred and sixty holds two recipe bays behind the
## glass and a cabinet under the bench, and the height above it is the exhaust.
const MACHINE_H := 260.0
const MACHINE_FOOT := 8.0

## COLD WHITE LIGHT, NOT THE STATION'S AMBER. The one room lit a different colour,
## because a lab is lit to see by rather than to be in.
const COOL := Color("#b8d2e2")
const GLASS := Color("#0f1b24")
const GLASS_LIT := Color("#2c4054")
const MURK := Color("#1c2a36")
const BOARD := Color("#6a7780")
const BOARD_LIT := Color("#8894a0")
const MARKER_BLUE := Color("#2c4775")
const MARKER_RED := Color("#8f3528")
const SCREEN := Color("#0a151c")
const TRACE := Color("#6fb6c6")
const TEAL := Color("#4c9aa0")
const VIOLET := Color("#7a66a4")
## What the jars and the beakers have in them, in order.
const JAR_LIQUID := [TEAL, VIOLET, LAMP, MURK, TEAL]

## Where the tanks' feed pipe runs along the ceiling.
const PIPE_Y := 22.0


func floor_h() -> float:
	return LAB_FLOOR_H


func _light() -> Color:
	return COOL


## Over the hood's left shoulder, clear of its exhaust duct -- and hung HIGH.
## A long banner from thirty-six pixels down ran into the hood's header; from
## twenty-four it clears the hood by about ten.
func banner_spots() -> Array:
	return [Vector2(0.37, 24.0)]


func _dress_wall(w: float, h: float, _floor_y: float) -> void:
	var hood_top := h - MACHINE_FOOT - MACHINE_H
	var left := w * MACHINE_L
	var right := w * MACHINE_R

	# --- THE EXHAUST DUCT, from the hood up through the ceiling.
	#
	# The piece that makes a cabinet a FUME HOOD: whatever is being worked on in
	# there is going somewhere other than the room.
	var dw := 34.0
	var dx := floorf(w * 0.5 - dw * 0.5)
	if hood_top > 40.0:
		draw_rect(Rect2(dx, 0.0, dw, hood_top), _tint(PLATE))
		draw_rect(Rect2(dx, 0.0, 2.0, hood_top), Color(STAR.r, STAR.g, STAR.b, 0.10))
		draw_rect(Rect2(dx + dw - 2.0, 0.0, 2.0, hood_top), Color(DEEP.r, DEEP.g, DEEP.b, 0.6))
		var fy := 24.0
		while fy < hood_top - 6.0:
			draw_rect(Rect2(dx - 3.0, fy, dw + 6.0, 4.0), _tint(EDGE))
			fy += 44.0
		# A hazard placard on the duct: what goes up it is not air anyone wants.
		var hz := Vector2(dx + dw * 0.5, hood_top - 30.0)
		for s in 6:
			var half := 6.0 - absf(float(s) - 2.5) * 2.0
			draw_rect(Rect2(hz.x - half, hz.y + float(s) * 2.0, half * 2.0, 2.0), LAMP)
		draw_rect(Rect2(hz.x - 1.0, hz.y + 3.0, 2.0, 4.0), DEEP)

	# --- THE TANKS' FEED PIPE, along the ceiling on the tanks' side only.
	draw_rect(Rect2(w * 0.02, PIPE_Y, left - w * 0.02 - 8.0, 4.0), _tint(EDGE))
	draw_rect(Rect2(w * 0.02, PIPE_Y, left - w * 0.02 - 8.0, 1.0),
		Color(STAR.r, STAR.g, STAR.b, 0.10))

	var zone_x := right + 12.0
	var zone_w := w * 0.98 - zone_x
	if zone_w <= 70.0:
		return

	# --- A WHITEBOARD somebody has been thinking on, over the bench.
	var wb := Rect2(zone_x, 32.0, zone_w, 60.0)
	draw_rect(Rect2(wb.position.x - 2.0, wb.position.y - 2.0, wb.size.x + 4.0,
		wb.size.y + 4.0), _tint(EDGE))
	draw_rect(wb, BOARD)
	draw_rect(Rect2(wb.position.x, wb.position.y, wb.size.x, 1.0), BOARD_LIT)
	# A ring of atoms: somebody's molecule.
	var rc := Vector2(wb.position.x + 18.0, wb.position.y + 22.0)
	for p: Vector2 in [Vector2(-6, -4), Vector2(0, -7), Vector2(6, -4), Vector2(6, 3),
			Vector2(0, 6), Vector2(-6, 3)]:
		draw_rect(Rect2(rc.x + p.x, rc.y + p.y, 3.0, 2.0), MARKER_BLUE)
	# An arrow to three lines of working.
	draw_rect(Rect2(rc.x + 14.0, rc.y, 12.0, 1.0), MARKER_BLUE)
	draw_rect(Rect2(rc.x + 24.0, rc.y - 2.0, 2.0, 5.0), MARKER_BLUE)
	for r in 3:
		var lw := zone_w - 70.0 - float((r * 9) % 14)
		if lw > 8.0:
			draw_rect(Rect2(rc.x + 32.0, rc.y - 8.0 + float(r) * 8.0, lw, 2.0), MARKER_BLUE)
	# And the one thing that got circled in red.
	draw_rect(Rect2(wb.position.x + 10.0, wb.end.y - 18.0, 40.0, 11.0), MARKER_RED, false, 1.0)
	draw_rect(Rect2(wb.position.x + 14.0, wb.end.y - 14.0, 30.0, 2.0), MARKER_RED)
	# The tray along its foot, with a marker lying in it.
	draw_rect(Rect2(wb.position.x, wb.end.y, wb.size.x, 3.0), _tint(EDGE))
	draw_rect(Rect2(wb.end.x - 20.0, wb.end.y - 1.0, 9.0, 2.0), MARKER_RED)

	# --- A SHELF OF SPECIMEN JARS under it.
	var shelf_y := 138.0
	draw_rect(Rect2(zone_x - 2.0, shelf_y, zone_w + 4.0, 4.0), CRATE_LIP)
	draw_rect(Rect2(zone_x + 6.0, shelf_y + 4.0, 3.0, 8.0), _tint(EDGE))
	draw_rect(Rect2(zone_x + zone_w - 9.0, shelf_y + 4.0, 3.0, 8.0), _tint(EDGE))
	var jx := zone_x + 6.0
	var j := 0
	while jx < zone_x + zone_w - 16.0:
		var jw := 12.0 + float((j * 5) % 7)
		var jh := 16.0 + float((j * 7) % 15)
		var liquid: Color = JAR_LIQUID[j % JAR_LIQUID.size()]
		_jar(Rect2(jx, shelf_y - jh, jw, jh), liquid, j == 2)
		jx += jw + 6.0
		j += 1


func _dress_floor(w: float, h: float, _floor_y: float) -> void:
	var base := h - 6.0
	var left := w * MACHINE_L
	var right := w * MACHINE_R

	# --- THE TANKS, on the other side of the hood from the bench.
	var zone := Vector2(w * 0.02, left - 12.0)
	var span := zone.y - zone.x
	if span >= 40.0:
		var tw := minf(50.0, (span - 14.0) * 0.5)
		for k in 2:
			var tx := zone.x + 4.0 + float(k) * (tw + 10.0)
			# Staggered heights, the way a lab collects tanks rather than orders
			# a matched set.
			var top := h * (0.36 + 0.06 * float(k))
			_tank(Rect2(tx, top, tw, base - top), k == 1)

	# --- HAZARD TAPE on the floor in front of the hood.
	var tape := left + 4.0
	while tape < right - 8.0:
		draw_rect(Rect2(tape, base + 1.0, 8.0, 2.0), Color(LAMP.r, LAMP.g, LAMP.b, 0.45))
		tape += 14.0

	# --- THE BENCH, and what is on it.
	var bx := right + 8.0
	var bw := w * 0.985 - bx
	if bw <= 90.0:
		return
	var top_y := base - 70.0
	draw_rect(Rect2(bx + 3.0, top_y + 3.0, bw, base - top_y), Color(DEEP.r, DEEP.g, DEEP.b, 0.5))
	draw_rect(Rect2(bx, top_y, bw, 6.0), CRATE_LIP)
	draw_rect(Rect2(bx, top_y, bw, 1.0), Color(STAR.r, STAR.g, STAR.b, 0.25))
	draw_rect(Rect2(bx + 2.0, top_y + 6.0, bw - 4.0, base - top_y - 6.0), CRATE)
	for d in 3:
		var dy := top_y + 10.0 + float(d) * 18.0
		draw_rect(Rect2(bx + 6.0, dy, bw - 12.0, 14.0), Color(DEEP.r, DEEP.g, DEEP.b, 0.35),
			false, 1.0)
		draw_rect(Rect2(bx + bw * 0.5 - 6.0, dy + 6.0, 12.0, 2.0), CRATE_LIP)

	# A monitor, with something being measured on it.
	var mon := Rect2(bx + 4.0, top_y - 40.0, 54.0, 34.0)
	draw_rect(Rect2(mon.position.x + 22.0, mon.end.y, 10.0, 6.0), _tint(EDGE))
	draw_rect(Rect2(mon.position.x - 2.0, mon.position.y - 2.0, mon.size.x + 4.0,
		mon.size.y + 4.0), _tint(EDGE))
	draw_rect(mon, SCREEN)
	var px := 0.0
	while px < mon.size.x - 4.0:
		var ty := mon.position.y + mon.size.y * 0.55 + sin(px * 0.35) * 6.0 + sin(px * 0.11) * 3.0
		draw_rect(Rect2(mon.position.x + 2.0 + px, floorf(ty), 2.0, 1.0), TRACE)
		px += 2.0
	draw_rect(Rect2(mon.position.x + 3.0, mon.position.y + 3.0, 16.0, 2.0),
		Color(TRACE.r, TRACE.g, TRACE.b, 0.5))

	# A microscope.
	var mx := bx + 64.0
	draw_rect(Rect2(mx, top_y - 4.0, 22.0, 4.0), _tint(EDGE))
	draw_rect(Rect2(mx + 14.0, top_y - 30.0, 4.0, 26.0), _tint(EDGE))
	draw_rect(Rect2(mx + 4.0, top_y - 16.0, 14.0, 3.0), CRATE_LIP)
	draw_rect(Rect2(mx + 6.0, top_y - 34.0, 5.0, 16.0), CRATE_LIP)
	draw_rect(Rect2(mx + 5.0, top_y - 38.0, 7.0, 4.0), _tint(EDGE))

	# Three beakers.
	for b in 3:
		var bh := 10.0 + float(b % 2) * 6.0
		var br := Rect2(bx + 94.0 + float(b) * 11.0, top_y - bh, 9.0, bh)
		var liquid: Color = JAR_LIQUID[b]
		draw_rect(br, GLASS)
		draw_rect(Rect2(br.position.x, br.position.y + bh * 0.4, br.size.x, bh * 0.6),
			Color(liquid.r, liquid.g, liquid.b, 0.6))
		draw_rect(Rect2(br.position.x, br.position.y, 1.0, bh), GLASS_LIT)

	# And a rack of test tubes.
	var rx := bx + 134.0
	if rx + 28.0 <= bx + bw:
		for t in 4:
			var tube: Color = JAR_LIQUID[t]
			draw_rect(Rect2(rx + 2.0 + float(t) * 6.0, top_y - 18.0, 3.0, 16.0), GLASS)
			draw_rect(Rect2(rx + 2.0 + float(t) * 6.0, top_y - 9.0, 3.0, 7.0),
				Color(tube.r, tube.g, tube.b, 0.7))
		draw_rect(Rect2(rx, top_y - 12.0, 28.0, 2.0), _tint(EDGE))
		draw_rect(Rect2(rx, top_y - 3.0, 28.0, 3.0), _tint(EDGE))


## A specimen jar standing on a shelf: glass, what is in it, and a lid.
func _jar(r: Rect2, liquid: Color, specimen: bool) -> void:
	draw_rect(r, GLASS)
	var fill := Rect2(r.position.x + 1.0, r.position.y + r.size.y * 0.3, r.size.x - 2.0,
		r.size.y * 0.7 - 1.0)
	draw_rect(fill, Color(liquid.r, liquid.g, liquid.b, 0.55))
	if specimen:
		draw_rect(Rect2(fill.position.x + fill.size.x * 0.3, fill.position.y + 3.0,
			fill.size.x * 0.4, fill.size.y * 0.5), Color(0.80, 0.75, 0.60, 0.55))
	draw_rect(Rect2(r.position.x, r.position.y, 1.0, r.size.y), GLASS_LIT)
	draw_rect(Rect2(r.position.x - 1.0, r.position.y - 3.0, r.size.x + 2.0, 3.0), CRATE_LIP)


## One culture tank, standing on the floor with a riser up to the feed pipe.
func _tank(r: Rect2, alive: bool) -> void:
	if r.size.x < 16.0 or r.size.y < 40.0:
		return
	var foot := 9.0
	var cap := 8.0
	var body := Rect2(r.position.x, r.position.y + cap, r.size.x, r.size.y - cap - foot)

	# The riser to the ceiling pipe, drawn first so the cap sits over its end.
	draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 2.0, PIPE_Y + 4.0, 4.0,
		r.position.y - PIPE_Y - 4.0), _tint(EDGE))
	draw_rect(Rect2(r.position.x + 4.0, r.position.y + 4.0, r.size.x, r.size.y),
		Color(DEEP.r, DEEP.g, DEEP.b, 0.5))

	draw_rect(body, GLASS)
	# What is in it. The live tank glows warm; the rest are murk to about the same
	# level, which is what a lab looks like between batches.
	var level := body.position.y + body.size.y * (0.22 if alive else 0.46)
	var fluid := Rect2(body.position.x, level, body.size.x, body.end.y - level)
	if alive:
		draw_rect(fluid, Color(LAMP.r, LAMP.g, LAMP.b, 0.30))
		draw_rect(Rect2(fluid.position.x, fluid.position.y, fluid.size.x, 1.0),
			Color(LAMP.r, LAMP.g, LAMP.b, 0.75))
		for i in 9:
			var bxx := fluid.position.x + 3.0 + _scatter(i * 11 + 3, fluid.size.x - 6.0)
			var byy := fluid.position.y + 4.0 + _scatter(i * 5 + 7, fluid.size.y - 8.0)
			draw_rect(Rect2(floorf(bxx), floorf(byy), 1.0 + float(i % 2), 1.0 + float(i % 2)),
				Color(LAMP.r, LAMP.g, LAMP.b, 0.7))
	else:
		draw_rect(fluid, MURK)
		draw_rect(Rect2(fluid.position.x, fluid.position.y, fluid.size.x, 1.0),
			Color(GLASS_LIT.r, GLASS_LIT.g, GLASS_LIT.b, 0.8))
	draw_rect(Rect2(body.position.x, body.position.y, 2.0, body.size.y), GLASS_LIT)
	draw_rect(Rect2(body.end.x - 2.0, body.position.y, 2.0, body.size.y),
		Color(DEEP.r, DEEP.g, DEEP.b, 0.7))
	for t: float in [0.33, 0.70]:
		draw_rect(Rect2(body.position.x - 1.0, body.position.y + body.size.y * t,
			body.size.x + 2.0, 3.0), _tint(EDGE))
	draw_rect(Rect2(r.position.x - 2.0, r.position.y, r.size.x + 4.0, cap), CRATE)
	draw_rect(Rect2(r.position.x - 2.0, r.position.y, r.size.x + 4.0, 1.0), CRATE_LIP)
	draw_rect(Rect2(r.position.x - 3.0, body.end.y, r.size.x + 6.0, foot), CRATE)
	draw_rect(Rect2(r.position.x - 3.0, body.end.y, r.size.x + 6.0, 1.0), CRATE_LIP)
	if alive:
		draw_rect(Rect2(r.position.x + 3.0, body.end.y + 3.0, 4.0, 3.0), LAMP)
